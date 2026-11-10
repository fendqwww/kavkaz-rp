#!/usr/bin/env bash
# KAVKAZ RP — автоматическая установка модов карты на сервер (Linux VPS). аналог import-mods.ps1.
# что делает:
#   1) берёт всё из /opt/kavkaz/mods-inbox (архивы .zip / .rar / .7z или распакованные папки);
#      можно сразу дать прямые ссылки на архивы — скачает сам:  kavkaz-mods https://.../mod.zip
#   2) распаковывает и проверяет: нет ли .exe/.dll/.bat и подозрительных скриптов (бэкдоры из «слитых» модов);
#   3) готовый ресурс FiveM (есть fxmanifest.lua) — кладёт как есть;
#      просто файлы карты (.ymap/.ytyp/.ydr/.ytd/.ybn…) — сам собирает ресурс kavkaz_mod_<имя> с fxmanifest;
#   4) кладёт всё в resources/[maps] сервера и пишет maps.cfg (ensure каждого мода), подключает его в server.cfg;
#   5) обработанные архивы переносит в mods-inbox/done, отчёт — mods-inbox/import-log.txt.
# моды для одиночки (Menyoo .xml) и YMAP в XML автоматически не ставятся — отчёт подскажет, что с ними делать.
#
# закинуть архив с ПК на VPS (PowerShell на ПК):  scp .\мод.zip root@IP:/opt/kavkaz/mods-inbox/
#   или программой WinSCP — перетащить файл в папку /opt/kavkaz/mods-inbox
# запуск (под root):  kavkaz-mods [ссылка ...] [--restart] [--base /opt/kavkaz/txData/Qbox_XXXX.base]
set -euo pipefail

ROOT=/opt/kavkaz
INBOX=$ROOT/mods-inbox
RUN_USER=fivem
SERVICE=kavkaz

say()  { printf '%s\n' "$*"; printf '%s\n' "$*" >> "$LOG"; }
ok()   { printf '\033[1;32m%s\033[0m\n' "$*"; printf '%s\n' "$*" >> "$LOG"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$*"; printf '%s\n' "$*" >> "$LOG"; }
bad()  { printf '\033[1;31m%s\033[0m\n' "$*"; printf '%s\n' "$*" >> "$LOG"; }
die()  { printf '\033[1;31mОшибка: %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "запусти от root (sudo -i)"

BASE=''; RESTART=0; URLS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --restart) RESTART=1 ;;
    --base) BASE=${2:-}; shift ;;
    --inbox) INBOX=${2:-}; shift ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    http://*|https://*) URLS+=("$1") ;;
    *) die "непонятный параметр: $1" ;;
  esac
  shift
done

if [ -z "$BASE" ]; then
  BASE=$(find "$ROOT/txData" -mindepth 2 -maxdepth 2 -name server.cfg -printf '%T@ %h\n' 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2-)
fi
[ -n "$BASE" ] && [ -f "$BASE/server.cfg" ] || die "не нашёл сервер Qbox (server.cfg в $ROOT/txData/*/). укажи: --base <папка>"

mkdir -p "$INBOX/done"
DEST="$BASE/resources/[maps]"
mkdir -p "$DEST"
WORK=$(mktemp -d /tmp/kavkaz-mods.XXXXXX)
trap 'rm -rf "$WORK"' EXIT
LOG=$INBOX/import-log.txt
: > "$LOG"
say "сервер: $BASE"

# программы для распаковки
need=()
command -v unzip >/dev/null || need+=(unzip)
command -v 7z >/dev/null || command -v 7zz >/dev/null || need+=(p7zip-full)
if [ ${#need[@]} -gt 0 ]; then
  say "ставлю: ${need[*]}"
  apt-get update -qq && apt-get install -y -qq "${need[@]}" >/dev/null || warn "не поставилось ${need[*]}"
fi
SEVEN=$(command -v 7zz || command -v 7z || true)

# скачать по ссылкам
for u in "${URLS[@]}"; do
  f=$(basename "${u%%\?*}"); [ -n "$f" ] || f=mod.zip
  say "скачиваю $u"
  curl -fL --progress-bar "$u" -o "$INBOX/$f" || bad "  ✕ не скачалось: $u"
done

STREAM_RE='\.(ymap|ytyp|ydr|ydd|yft|ytd|ybn|ymf|ynv|ycd|ynd|awc|rel)$'
BAD_RE='\.(exe|dll|bat|cmd|ps1|vbs|scr|msi|jar|com|lnk|sh|so)$'
# признаки бэкдоров в Lua: скачивание и запуск кода с чужого сервера
LUA_RE='PerformHttpRequest|loadstring|load[[:space:]]*\(|os\.execute|io\.popen|(\\x[0-9a-fA-F]{2}){3}'

safe_name() {
  local n
  # русские имена архивов — латиницей («Горный дом» -> gornyy_dom). по буквам, чтобы работало при любой локали
  n=$(printf '%s' "$1" | LC_ALL=C sed 's/щ/shch/g; s/Щ/shch/g; s/ш/sh/g; s/Ш/sh/g; s/ч/ch/g; s/Ч/ch/g; s/ж/zh/g; s/Ж/zh/g; s/ю/yu/g; s/Ю/yu/g; s/я/ya/g; s/Я/ya/g; s/ё/yo/g; s/Ё/yo/g; s/х/kh/g; s/Х/kh/g; s/ц/ts/g; s/Ц/ts/g; s/ы/y/g; s/Ы/y/g; s/й/y/g; s/Й/y/g; s/ъ//g; s/Ъ//g; s/ь//g; s/Ь//g; s/а/a/g; s/А/a/g; s/б/b/g; s/Б/b/g; s/в/v/g; s/В/v/g; s/г/g/g; s/Г/g/g; s/д/d/g; s/Д/d/g; s/е/e/g; s/Е/e/g; s/з/z/g; s/З/z/g; s/и/i/g; s/И/i/g; s/к/k/g; s/К/k/g; s/л/l/g; s/Л/l/g; s/м/m/g; s/М/m/g; s/н/n/g; s/Н/n/g; s/о/o/g; s/О/o/g; s/п/p/g; s/П/p/g; s/р/r/g; s/Р/r/g; s/с/s/g; s/С/s/g; s/т/t/g; s/Т/t/g; s/у/u/g; s/У/u/g; s/ф/f/g; s/Ф/f/g; s/э/e/g; s/Э/e/g' \
    | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C sed -E 's/[^a-z0-9_-]+/_/g; s/_+/_/g; s/^_+|_+$//g')
  printf '%s' "${n:-mod}"
}

# имена файлов карты, которые уже стримятся (два одинаковых файла = конфликт)
declare -A streamed=()
while IFS= read -r -d '' f; do
  streamed[$(basename "$f" | tr '[:upper:]' '[:lower:]')]=$(dirname "$f")
done < <(find "$DEST" -type f -regextype posix-extended -iregex ".*$STREAM_RE" -print0 2>/dev/null)

shopt -s nullglob
items=("$INBOX"/*)
count=0
for item in "${items[@]}"; do
  bn=$(basename "$item")
  if [ "$bn" = "done" ] || [ "$bn" = "import-log.txt" ]; then continue; fi
  count=$((count + 1))
  say ''
  printf '\033[1;36m== %s\033[0m\n' "$bn"; printf '== %s\n' "$bn" >> "$LOG"
  stem=${bn%.*}; [ -d "$item" ] && stem=$bn
  name=$(safe_name "$stem")
  src=$WORK/$name
  rm -rf "$src"; mkdir -p "$src"

  # 1) распаковка
  ext=$(printf '%s' "${bn##*.}" | tr '[:upper:]' '[:lower:]')
  if [ -d "$item" ]; then
    cp -r "$item/." "$src/"
  elif [ "$ext" = zip ]; then
    if ! unzip -qq -o "$item" -d "$src" 2>/dev/null; then
      [ -n "$SEVEN" ] && "$SEVEN" x -y -o"$src" "$item" >/dev/null || { bad '  ✕ не распаковался'; continue; }
    fi
  elif [ "$ext" = rar ] || [ "$ext" = 7z ]; then
    [ -n "$SEVEN" ] || { warn '  ! нет 7-Zip — пропускаю'; continue; }
    if ! "$SEVEN" x -y -o"$src" "$item" >/dev/null 2>&1; then
      if [ "$ext" = rar ]; then
        warn '  ! этот .rar не распаковался. пересохрани его на ПК в .zip (7-Zip → «Добавить к архиву» → zip) и закинь снова'
      else
        bad '  ✕ не распаковался'
      fi
      continue
    fi
  else
    warn "  ! неизвестный формат .$ext — пропускаю"; continue
  fi
  # ссылки внутри архива могут указывать за пределы папки — выкидываем
  find "$src" -type l -delete

  # 2) проверка безопасности
  b=$(find "$src" -type f -regextype posix-extended -iregex ".*$BAD_RE" -printf '%f\n' | head -n3 | paste -sd, - || true)
  if [ -n "$b" ]; then bad "  ✕ ОПАСНО: в моде есть исполняемые файлы ($b). не ставлю."; continue; fi
  s=$(find "$src" -type f -iname '*.lua' -print0 | xargs -0 -r grep -lE "$LUA_RE" 2>/dev/null | xargs -r -n1 basename | head -n3 | paste -sd, - || true)
  if [ -n "$s" ]; then bad "  ✕ ПОДОЗРИТЕЛЬНО: скрипты скачивают или запускают код ($s). не ставлю — покажи Claude."; continue; fi

  # 3) готовые ресурсы (есть fxmanifest.lua / __resource.lua)
  mapfile -t manifests < <(find "$src" -type f \( -name fxmanifest.lua -o -name __resource.lua \) -printf '%h\n' | sort -u)
  installed=()
  if [ ${#manifests[@]} -gt 0 ]; then
    for d in "${manifests[@]}"; do
      r=$(safe_name "$(basename "$d")")
      [ ${#manifests[@]} -eq 1 ] && r=$name
      rm -rf "${DEST:?}/$r"
      cp -r "$d" "$DEST/$r"
      installed+=("$r")
    done
  else
    # 4) просто файлы карты -> собираем ресурс сами
    mapfile -d '' stream < <(find "$src" -type f -regextype posix-extended -iregex ".*$STREAM_RE" -print0)
    if [ ${#stream[@]} -eq 0 ]; then
      if [ -n "$(find "$src" -type f -iname '*.xml' -print -quit)" ]; then
        warn '  ? в моде только .xml — это мод для одиночки (Menyoo / Map Editor) или YMAP в XML.'
        warn '    автоматически не ставится: открой в CodeWalker и сохрани как .ymap, или покажи файл Claude.'
      else
        warn '  ? не нашёл файлов карты (.ymap/.ytyp/.ydr/.ytd/.ybn) — пропускаю'
      fi
      continue
    fi
    r=kavkaz_mod_$name
    rm -rf "${DEST:?}/$r"
    mkdir -p "$DEST/$r/stream"
    for f in "${stream[@]}"; do cp "$f" "$DEST/$r/stream/"; done
    {
      printf -- "-- собрано setup/import-mods.sh из «%s»\n" "$bn"
      printf "fx_version 'cerulean'\ngame 'gta5'\nlua54 'yes'\nthis_is_a_map 'yes'\n\n"
      for f in "$DEST/$r/stream/"*; do
        case "${f,,}" in *.ytyp) printf "data_file 'DLC_ITYP_REQUEST' 'stream/%s'\n" "$(basename "$f")" ;; esac
      done
    } > "$DEST/$r/fxmanifest.lua"
    installed+=("$r")
  fi

  # 5) конфликты по именам файлов
  for r in "${installed[@]}"; do
    while IFS= read -r -d '' f; do
      k=$(basename "$f" | tr '[:upper:]' '[:lower:]')
      prev=${streamed[$k]:-}
      if [ -n "$prev" ] && [[ "$prev" != "$DEST/$r"* ]]; then
        p=${prev#"$DEST/"}
        warn "  ! конфликт: $(basename "$f") уже есть в ${p%%/*}. включится только один из модов"
      fi
      streamed[$k]=$(dirname "$f")
    done < <(find "$DEST/$r" -type f -regextype posix-extended -iregex ".*$STREAM_RE" -print0)
    ok "  ✓ установлен: [maps]/$r"
  done
  mv -f "$item" "$INBOX/done/"
done
[ $count -eq 0 ] && warn "в $INBOX пусто — закинь туда архивы модов (или дай ссылки: kavkaz-mods https://...) и запусти снова."

# maps.cfg — ensure всех модов из [maps], подключается в server.cfg
MAPS=$BASE/maps.cfg
{
  printf '## KAVKAZ RP: моды карты — файл пишет setup/import-mods.sh, руками не править\n'
  printf '## выключить мод: поставь # в начале строки\n'
  for d in "$DEST"/*/; do
    [ -f "$d/fxmanifest.lua" ] || [ -f "$d/__resource.lua" ] || continue
    printf 'ensure %s\n' "$(basename "$d")"
  done | sort
} > "$MAPS"
CFG=$BASE/server.cfg
if ! grep -Eq '^[[:space:]]*exec[[:space:]]+maps\.cfg[[:space:]]*\r?$' "$CFG"; then
  [ -n "$(tail -c1 "$CFG")" ] && printf '\n' >> "$CFG"
  printf '\n## KAVKAZ RP: моды карты (setup/import-mods)\nexec maps.cfg\n' >> "$CFG"
  ok '+ server.cfg: добавлена строка exec maps.cfg'
fi
id "$RUN_USER" >/dev/null 2>&1 && chown -R "$RUN_USER:$RUN_USER" "$DEST" "$MAPS" "$CFG"

n=$(grep -c '^ensure ' "$MAPS" || true)
say ''
ok "готово. модов на сервере: $n. список — $MAPS"
if [ "$RESTART" = 1 ]; then
  systemctl restart "$SERVICE" && say "сервер перезапускается."
else
  say 'перезапусти сервер (txAdmin → Restart, или kavkaz-mods --restart) и зайди проверить.'
fi
