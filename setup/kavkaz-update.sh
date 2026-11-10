#!/usr/bin/env bash
# KAVKAZ RP — поставить / обновить наши правки на сервере Qbox (Linux VPS). аналог apply-overrides.ps1.
# что делает:
#   0) скачивает свежий код из GitHub в /opt/kavkaz/repo (ветка — в /opt/kavkaz/branch);
#   1) копирует overrides/resources/... поверх ресурсов сервера (переводы ru.json, конфиги);
#   2) копирует наши ресурсы resources/[kavkaz]/... ;
#   3) кладёт overrides/kavkaz.cfg рядом с server.cfg, дописывает в server.cfg "exec kavkaz.cfg"
#      и (первой строкой) "exec /opt/kavkaz/secrets.cfg" — вебхук и прочие секреты;
#   4) включает русский язык в ox.cfg;
#   5) подключает наши темы ox_inventory и ox_lib (строка <link> в их web/build/index.html);
#      применяет новые файлы sql/*.sql к базе (каждый один раз);
#   6) отдаёт файлы пользователю fivem и (с --restart) перезапускает сервер.
# заменённые файлы сохраняются в /opt/kavkaz/backup-overrides/<дата>/ — ничего не теряется.
#
# запуск (под root):  kavkaz-update            — скачать свежее и поставить
#                     kavkaz-update --restart  — то же + перезапуск сервера
#                     kavkaz-update --branch claude/xxx   — переключить ветку (запоминается)
#                     kavkaz-update --base /opt/kavkaz/txData/Qbox_XXXX.base   — если серверов несколько
#                     kavkaz-update --no-pull  — без скачивания (поставить то, что уже лежит в repo)
set -euo pipefail

ROOT=/opt/kavkaz
REPO=$ROOT/repo
REPO_URL=https://github.com/fendqwww/kavkaz-rp.git
BRANCH_FILE=$ROOT/branch
DEFAULT_BRANCH=claude/zen-allen-mjpj7c
SECRETS=$ROOT/secrets.cfg
RUN_USER=fivem
SERVICE=kavkaz

say()  { printf '%s\n' "$*"; }
step() { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mОшибка: %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "запусти от root (sudo -i)"

BASE='' ; RESTART=0 ; PULL=1 ; NEW_BRANCH=''
while [ $# -gt 0 ]; do
  case "$1" in
    --restart) RESTART=1 ;;
    --no-pull) PULL=0 ;;
    --base)    BASE=${2:-}; shift ;;
    --branch)  NEW_BRANCH=${2:-}; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) die "непонятный параметр: $1 (смотри kavkaz-update --help)" ;;
  esac
  shift
done

# --- 0. свежий код ------------------------------------------------------------------
if [ "$PULL" = 1 ] && [ -z "${KAVKAZ_PULLED:-}" ]; then
  command -v git >/dev/null || { apt-get update -qq; apt-get install -y -qq git >/dev/null; }
  [ -n "$NEW_BRANCH" ] && printf '%s\n' "$NEW_BRANCH" > "$BRANCH_FILE"
  BRANCH=$(cat "$BRANCH_FILE" 2>/dev/null || true); BRANCH=${BRANCH:-$DEFAULT_BRANCH}
  step "0) скачиваю код: ветка $BRANCH"
  if [ ! -d "$REPO/.git" ]; then
    rm -rf "$REPO"
    git clone --quiet --depth 20 --branch "$BRANCH" "$REPO_URL" "$REPO" || die "не скачался репозиторий (ветка $BRANCH есть на GitHub?)"
  else
    git -C "$REPO" fetch --quiet --depth 20 origin "+refs/heads/$BRANCH:refs/remotes/origin/$BRANCH" || die "не скачалась ветка $BRANCH (есть на GitHub? есть интернет?)"
    # на VPS repo только для установки, руками там не правим — поэтому просто ставим как на GitHub
    git -C "$REPO" checkout --quiet -B "$BRANCH" "origin/$BRANCH"
    git -C "$REPO" reset --quiet --hard "origin/$BRANCH"
  fi
  say "  версия: $(git -C "$REPO" log -1 --format='%h %s')"
  printf '%s\n' "$BRANCH" > "$BRANCH_FILE"
  # дальше работает уже свежая версия этого скрипта
  export KAVKAZ_PULLED=1
  args=(--no-pull); [ "$RESTART" = 1 ] && args+=(--restart); [ -n "$BASE" ] && args+=(--base "$BASE")
  exec bash "$REPO/setup/kavkaz-update.sh" "${args[@]}"
fi

# repo = папка, где лежит этот скрипт (../)
SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
[ -d "$SRC/resources/[kavkaz]" ] || die "не нашёл resources/[kavkaz] рядом со скриптом ($SRC)"

# --- папка сервера (txAdmin кладёт её в txData/<имя>.base) ---------------------------
if [ -z "$BASE" ]; then
  mapfile -t found < <(find "$ROOT/txData" -mindepth 2 -maxdepth 2 -name server.cfg -printf '%T@ %h\n' 2>/dev/null | sort -rn | cut -d' ' -f2-)
  [ ${#found[@]} -gt 0 ] || die "не нашёл сервер Qbox (server.cfg в $ROOT/txData/*/). сначала поставь рецепт Qbox в txAdmin"
  BASE=${found[0]}
  [ ${#found[@]} -gt 1 ] && warn "серверов несколько, беру самый свежий. другой — так: kavkaz-update --base <папка>"
fi
[ -f "$BASE/server.cfg" ] || die "в $BASE нет server.cfg"
say "сервер: $BASE"

BACKUP=$ROOT/backup-overrides/$(date +%Y-%m-%d_%H-%M-%S)
changed=0; same=0

backup() { # $1 — файл внутри BASE
  local rel=${1#"$BASE"/}
  mkdir -p "$BACKUP/$(dirname "$rel")"
  cp -p "$1" "$BACKUP/$rel"
}

copy_tree() { # $1 откуда, $2 куда
  local from=$1 to=$2 f rel dst
  while IFS= read -r -d '' f; do
    rel=${f#"$from"/}
    dst=$to/$rel
    if [ -f "$dst" ]; then
      if cmp -s "$f" "$dst"; then same=$((same + 1)); continue; fi
      backup "$dst"
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$f" "$dst"
    say "  + $rel"
    changed=$((changed + 1))
  done < <(find "$from" -type f -print0)
}

step '1) переводы и конфиги чужих ресурсов'
copy_tree "$SRC/overrides/resources" "$BASE/resources"

step '2) наши ресурсы [kavkaz]'
# ресурсы, которых больше нет в репозитории, убираем (иначе старый код останется на сервере)
if [ -d "$BASE/resources/[kavkaz]" ]; then
  for d in "$BASE/resources/[kavkaz]"/*/; do
    [ -d "$d" ] || continue
    n=$(basename "$d")
    if [ ! -d "$SRC/resources/[kavkaz]/$n" ]; then
      mkdir -p "$BACKUP/resources/[kavkaz]"
      mv "$d" "$BACKUP/resources/[kavkaz]/$n"
      say "  - $n (удалён из репозитория, перенёс в бэкап)"
    else
      # файлы, удалённые из ресурса в репозитории
      while IFS= read -r -d '' f; do
        rel=${f#"$BASE/resources/[kavkaz]/"}
        [ -e "$SRC/resources/[kavkaz]/$rel" ] && continue
        # файлы, которые кладут прямо на сервер мимо git (.gitignore), не трогаем: модели карты и записи звуков СГУ
        case "/$rel" in */stream/*|*/html/sounds/*.ogg|*/html/sounds/*.wav) continue ;; esac
        backup "$f"; rm -f "$f"; say "  - $rel"
      done < <(find "$d" -type f -print0)
    fi
  done
fi
copy_tree "$SRC/resources/[kavkaz]" "$BASE/resources/[kavkaz]"

step '3) kavkaz.cfg и server.cfg'
if ! cmp -s "$SRC/overrides/kavkaz.cfg" "$BASE/kavkaz.cfg" 2>/dev/null; then
  [ -f "$BASE/kavkaz.cfg" ] && backup "$BASE/kavkaz.cfg"
  cp "$SRC/overrides/kavkaz.cfg" "$BASE/kavkaz.cfg"
  say '  + kavkaz.cfg'
fi
CFG=$BASE/server.cfg
need_kavkaz=0; need_secrets=0
grep -Eq '^[[:space:]]*exec[[:space:]]+kavkaz\.cfg[[:space:]]*\r?$' "$CFG" || need_kavkaz=1
if [ -f "$SECRETS" ] && ! grep -Fq "exec $SECRETS" "$CFG"; then need_secrets=1; fi
if [ $need_kavkaz = 1 ] || [ $need_secrets = 1 ]; then
  backup "$CFG"
  if [ $need_secrets = 1 ]; then
    # первой строкой: строки, которые txAdmin записал в server.cfg ниже, имеют приоритет — ничего не сломается
    { printf '## KAVKAZ RP: секреты (пароли, ключи, вебхук) — только в этом файле, не в git\nexec %s\n\n' "$SECRETS"; cat "$CFG"; } > "$CFG.new"
    mv "$CFG.new" "$CFG"
    say "  + server.cfg: exec $SECRETS"
  fi
  if [ $need_kavkaz = 1 ]; then
    [ -n "$(tail -c1 "$CFG")" ] && printf '\n' >> "$CFG"
    printf '\n## KAVKAZ RP: наши настройки и ресурсы (setup/kavkaz-update.sh)\nexec kavkaz.cfg\n' >> "$CFG"
    say '  + server.cfg: exec kavkaz.cfg'
  fi
fi

# автопарк kavkaz_cars должен стартовать раньше qbx_core: qbx_core при старте читает kavkaz_cars/cars.lua (названия, цены)
if [ -d "$SRC/resources/[kavkaz]/kavkaz_cars" ] && ! grep -Eq '^[[:space:]]*ensure[[:space:]]+kavkaz_cars[[:space:]]*\r?$' "$CFG"; then
  if grep -Eq '^[[:space:]]*ensure[[:space:]]+qbx_core[[:space:]]*\r?$' "$CFG"; then
    [ -f "$BACKUP/server.cfg" ] || backup "$CFG"
    n=$(grep -En '^[[:space:]]*ensure[[:space:]]+qbx_core[[:space:]]*\r?$' "$CFG" | head -n1 | cut -d: -f1)
    sed -i "${n}i ## KAVKAZ RP: автопарк — раньше qbx_core (setup/kavkaz-update.sh)\nensure kavkaz_cars" "$CFG"
    say '  + server.cfg: ensure kavkaz_cars перед ensure qbx_core'
  else
    warn 'в server.cfg нет строки ensure qbx_core — поставь ensure kavkaz_cars перед ней вручную'
  fi
fi

step '3.5) машины [cars]'
# модели в git не идут: их кладут на VPS в resources/[cars] сервера (scp / WinSCP). здесь — только cars.cfg (аналог install-cars.ps1)
CARS="$BASE/resources/[cars]"
if [ -d "$CARS" ]; then
  {
    printf '## KAVKAZ RP: машины — файл пишет setup/kavkaz-update.sh, руками не править\n'
    for d in "$CARS"/*/; do
      [ -f "$d/fxmanifest.lua" ] && printf 'ensure %s\n' "$(basename "$d")"
    done | sort
  } > "$BASE/cars.cfg.new"
  if cmp -s "$BASE/cars.cfg.new" "$BASE/cars.cfg" 2>/dev/null; then rm -f "$BASE/cars.cfg.new"; else mv "$BASE/cars.cfg.new" "$BASE/cars.cfg"; say "  + cars.cfg"; fi
  if ! grep -Eq '^[[:space:]]*exec[[:space:]]+cars\.cfg[[:space:]]*\r?$' "$CFG"; then
    [ -f "$BACKUP/server.cfg" ] || backup "$CFG"
    printf '\n## KAVKAZ RP: машины (setup/kavkaz-update.sh)\nexec cars.cfg\n' >> "$CFG"
    say '  + server.cfg: exec cars.cfg'
  fi
  mb=$(du -smc "$CARS"/*/stream 2>/dev/null | tail -n1 | cut -f1)
  say "  машин: $(grep -c '^ensure ' "$BASE/cars.cfg" || true), стрим ${mb:-0} МБ"
else
  say "  моделей машин на сервере нет ($CARS) — пропускаю"
fi

step '4) язык в ox.cfg'
OX=$BASE/ox.cfg
if [ -f "$OX" ] && grep -Eq '^setr ox:locale "[a-z-]+"' "$OX" && ! grep -q '^setr ox:locale "ru"' "$OX"; then
  backup "$OX"
  sed -i -E 's/^setr ox:locale "[a-z-]+"/setr ox:locale "ru"/' "$OX"
  say '  + ox.cfg: ox:locale = ru'
fi

step '5) темы ox_inventory и ox_lib'
# KAVKAZ: код ресурсов не меняем — только добавляем строку <link> на свою тему в их web/build/index.html
theme() { # $1 ресурс, $2 css внутри ресурса, $3 href
  local dir html css
  dir=$(find "$BASE/resources" -type f -name fxmanifest.lua -path "*/$1/fxmanifest.lua" -printf '%h\n' 2>/dev/null | head -n1)
  [ -n "$dir" ] || { warn "$1 не найден, тему пропускаю"; return; }
  html=$dir/web/build/index.html
  [ -f "$html" ] || { warn "у $1 нет web/build/index.html"; return; }
  css=$(find "$SRC/overrides/resources" -type f -path "*/$1/$2" | head -n1)
  [ -n "$css" ] || { warn "нет файла темы для $1"; return; }
  mkdir -p "$(dirname "$dir/$2")"
  cmp -s "$css" "$dir/$2" || { cp "$css" "$dir/$2"; say "  + $1: $2"; }
  if ! grep -q 'kavkaz-theme\.css' "$html"; then
    backup "$html"
    sed -i "s#</head>#<link rel=\"stylesheet\" href=\"$3\"></head>#" "$html"
    say "  + $1: подключена тема"
  fi
}
theme ox_inventory web/build/assets/kavkaz-theme.css ./assets/kavkaz-theme.css
theme ox_lib       web/build/kavkaz-theme.css        ./kavkaz-theme.css

step '5.5) база данных: sql/*.sql'
# каждый файл из sql/ применяется один раз (список — /opt/kavkaz/sql-applied). все файлы безопасны для повтора (IF NOT EXISTS)
APPLIED=$ROOT/sql-applied
if command -v mariadb >/dev/null 2>&1; then
  # имя базы — из строки подключения сервера (сама строка никуда не печатается)
  DB=$(cat "$CFG" "$SECRETS" 2>/dev/null | sed -n 's/^[[:space:]]*set[[:space:]]\+mysql_connection_string[[:space:]]\+"\?mysql:\/\/[^@]*@[^/]*\/\([A-Za-z0-9_]\+\).*/\1/p' | head -n1 || true)
  [ -n "$DB" ] || DB=$(cat "$CFG" "$SECRETS" 2>/dev/null | sed -n 's/^[[:space:]]*set[[:space:]]\+mysql_connection_string.*[;"]database=\([A-Za-z0-9_]\+\).*/\1/p' | head -n1 || true)
  if [ -z "$DB" ]; then
    warn 'не понял имя базы из mysql_connection_string — sql пропускаю'
  elif ! mariadb -N -e "SHOW TABLES LIKE 'players'" "$DB" 2>/dev/null | grep -q players; then
    warn "в базе $DB ещё нет таблиц Qbox (сервер ни разу не запускался?) — sql применю в следующий раз"
  else
    touch "$APPLIED"
    for f in "$SRC"/sql/*.sql; do
      [ -f "$f" ] || continue
      n=$(basename "$f")
      grep -Fxq "$n" "$APPLIED" && continue
      if mariadb "$DB" < "$f" 2>"$ROOT/sql-error.log"; then
        printf '%s\n' "$n" >> "$APPLIED"; say "  + $n"
      else
        warn "$n не применился: $(head -n1 "$ROOT/sql-error.log")"
      fi
    done
    rm -f "$ROOT/sql-error.log"
  fi
else
  warn 'нет программы mariadb — sql пропускаю'
fi

step '6) права на файлы'
if id "$RUN_USER" >/dev/null 2>&1; then
  chown -R "$RUN_USER:$RUN_USER" "$BASE"
  [ -f "$SECRETS" ] && { chown "$RUN_USER:$RUN_USER" "$SECRETS"; chmod 600 "$SECRETS"; }
  say "  файлы принадлежат $RUN_USER"
fi

printf '\n\033[1;32mготово:\033[0m обновлено файлов %s, без изменений %s.\n' "$changed" "$same"
[ -d "$BACKUP" ] && say "старые версии файлов: $BACKUP"
if [ "$RESTART" = 1 ]; then
  systemctl restart "$SERVICE" && say "сервер перезапускается (systemctl restart $SERVICE)."
else
  say 'чтобы изменения заработали — перезапусти сервер: в txAdmin кнопка Restart, или  kavkaz-update --restart'
fi
