#!/usr/bin/env bash
# KAVKAZ RP — установка сервера на VPS (Ubuntu 22.04 / 24.04, Debian 12) одной командой.
# Запуск (под root):
#   curl -fsSL https://raw.githubusercontent.com/fendqwww/kavkaz-rp/claude/zen-allen-mjpj7c/setup/install-linux.sh | bash
# другая ветка репозитория:  ... | KAVKAZ_BRANCH=имя-ветки bash
# Скрипт можно запускать повторно: уже сделанные шаги пропускаются.
# после него: txAdmin -> рецепт Qbox, затем  kavkaz-update --restart  (ставит наши ресурсы).
set -euo pipefail

ROOT=/opt/kavkaz
SERVER_DIR=$ROOT/server
TXDATA=$ROOT/txData
SECRETS=$ROOT/secrets.cfg
RUN_USER=fivem
SERVICE=kavkaz
DB_NAME=qbox
DB_USER=kavkaz
REPO=$ROOT/repo
REPO_URL=https://github.com/fendqwww/kavkaz-rp.git
BRANCH=${KAVKAZ_BRANCH:-$(cat $ROOT/branch 2>/dev/null || echo claude/zen-allen-mjpj7c)}

step() { printf '\n\033[1;36m=== %s ===\033[0m\n' "$1"; }
die()  { printf '\033[1;31mОшибка: %s\033[0m\n' "$1" >&2; exit 1; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$1"; }

[ "$(id -u)" -eq 0 ] || die "запусти от root (sudo -i)"
. /etc/os-release
case "${ID:-}" in ubuntu|debian) ;; *) die "скрипт рассчитан на Ubuntu 22.04 / 24.04 или Debian 12, а у тебя ${PRETTY_NAME:-неизвестная система}. переустанови ОС на VPS в панели хостинга" ;; esac
[ "$(uname -m)" = x86_64 ] || die "нужен процессор x86-64 (у тебя $(uname -m)). FiveM на ARM не работает"
# FXServer требует x86-64-v2 (POPCNT, SSE4.2). на VPS с CPU «QEMU Virtual CPU» без этих флагов сервер не стартует
grep -qw popcnt /proc/cpuinfo && grep -qw sse4_2 /proc/cpuinfo || die "процессор VPS не поддерживает POPCNT/SSE4.2 (x86-64-v2) — FXServer на нём не запустится. попроси у хостинга нормальный CPU (host-passthrough) или возьми другой тариф"

# --- 0. железо: что тянет VPS ---------------------------------------------------
RAM_GB=$(awk '/MemTotal/ {printf "%d", ($2/1024/1024)+0.5}' /proc/meminfo)
DISK_GB=$(df -BG --output=avail / | tail -1 | tr -dc 0-9)
CPUS=$(nproc)
step "Железо VPS: ядер $CPUS, памяти ${RAM_GB} ГБ, свободно на диске ${DISK_GB} ГБ"
[ "$RAM_GB" -ge 4 ] || die "памяти ${RAM_GB} ГБ — FiveM + база не поместятся. нужно минимум 4 ГБ (лучше 8–16)"
[ "$RAM_GB" -ge 8 ] || warn "памяти ${RAM_GB} ГБ: на тест с друзьями хватит, для открытия нужно 8–16 ГБ"
[ "$DISK_GB" -ge 10 ] || die "на диске свободно ${DISK_GB} ГБ — не хватит даже на сервер с рецептом Qbox (~5 ГБ) и базу. нужно минимум 10 ГБ"
[ "$DISK_GB" -ge 40 ] || warn "диска ${DISK_GB} ГБ: сервер встанет, но моды карты (здания, машины) быстро съедят место. для модов бери 40+ ГБ"
[ "$CPUS" -ge 2 ] || warn "одно ядро: сервер запустится, но с 10+ игроками будет тормозить"

# head закрывает трубу раньше tr -> SIGPIPE (код 141); с pipefail это валило скрипт
gen_pass() { local p; p=$(LC_ALL=C tr -dc 'A-HJ-NP-Za-km-z2-9' </dev/urandom | head -c 24) || true; printf '%s' "$p"; }

# --- 1. пакеты ------------------------------------------------------------------
step "Ставлю пакеты (MariaDB, curl, xz, ufw, git, архиваторы)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq mariadb-server curl xz-utils ufw ca-certificates tzdata git unzip p7zip-full >/dev/null
# 7zip (новый 7-Zip, умеет все .rar) есть не во всех версиях — не страшно, если не встанет
apt-get install -y -qq 7zip >/dev/null 2>&1 || true
timedatectl set-timezone Europe/Moscow 2>/dev/null || true

# --- 2. пользователь и папки ------------------------------------------------------
step "Создаю пользователя $RUN_USER и папки в $ROOT"
id "$RUN_USER" >/dev/null 2>&1 || useradd --system --create-home --shell /usr/sbin/nologin "$RUN_USER"
mkdir -p "$SERVER_DIR" "$TXDATA" "$ROOT/backups" "$ROOT/mods-inbox"

# --- 3. swap, если памяти мало и swap нет ------------------------------------------
if ! swapon --show | grep -q . && [ "$(awk '/MemTotal/ {print int($2/1024/1024)}' /proc/meminfo)" -lt 12 ]; then
  SWAP_GB=4; [ "$DISK_GB" -lt 30 ] && SWAP_GB=2   # маленький диск — swap поменьше
  step "Создаю swap $SWAP_GB ГБ"
  fallocate -l ${SWAP_GB}G /swapfile && chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# --- 4. секреты -------------------------------------------------------------------
step "Пароли"
if [ -f "$SECRETS" ]; then
  DB_PASS=$(sed -n 's/^# mariadb_kavkaz_password = //p' "$SECRETS")
  [ -n "$DB_PASS" ] || die "в $SECRETS нет строки mariadb_kavkaz_password"
  echo "Беру существующий пароль из $SECRETS"
else
  DB_PASS=$(gen_pass)
  umask 077
  cat > "$SECRETS" <<EOF
# KAVKAZ RP — секреты. НЕ КОММИТИТЬ, НЕ ПЕРЕСЫЛАТЬ.
# mariadb_kavkaz_password = $DB_PASS
# Подключается в server.cfg строкой:  exec $SECRETS
set mysql_connection_string "mysql://$DB_USER:$DB_PASS@127.0.0.1:3306/$DB_NAME?charset=utf8mb4"
# sv_licenseKey "ВСТАВЬ_КЛЮЧ_CFX_СЮДА"
EOF
  umask 022
  echo "Пароль сохранён в $SECRETS"
fi

# --- 5. MariaDB --------------------------------------------------------------------
step "Настраиваю MariaDB"
systemctl enable --now mariadb >/dev/null 2>&1
# root входит через unix_socket (по умолчанию в Ubuntu), снаружи база не видна
mariadb <<EOF
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
ALTER USER '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF
# слушать только localhost
if ! grep -qs '^bind-address *= *127.0.0.1' /etc/mysql/mariadb.conf.d/50-server.cnf; then
  sed -i 's/^#\?bind-address.*/bind-address = 127.0.0.1/' /etc/mysql/mariadb.conf.d/50-server.cnf 2>/dev/null || true
  systemctl restart mariadb
fi
echo "MariaDB готова: пользователь $DB_USER, база $DB_NAME (её создаст txAdmin)"

# --- 6. FXServer (recommended) -------------------------------------------------------
step "Скачиваю серверные файлы FiveM (recommended)"
if [ -x "$SERVER_DIR/run.sh" ]; then
  echo "FXServer уже скачан"
else
  INFO=$(curl -fsSL https://changelogs-live.fivem.net/api/changelog/versions/linux/server)
  URL=$(printf '%s' "$INFO" | grep -o '"recommended_download":"[^"]*"' | cut -d'"' -f4)
  [ -n "$URL" ] || die "не удалось узнать ссылку на recommended-билд"
  echo "Билд: $URL"
  curl -fL --progress-bar "$URL" -o /tmp/fx.tar.xz
  tar -xJf /tmp/fx.tar.xz -C "$SERVER_DIR"
  rm -f /tmp/fx.tar.xz
fi

# --- 6.5 наш код и команды kavkaz-update / kavkaz-mods --------------------------------
step "Скачиваю наш код (ветка $BRANCH) и ставлю команды kavkaz-update, kavkaz-mods"
if [ -d "$REPO/.git" ]; then
  git -c safe.directory="$REPO" -C "$REPO" fetch --quiet --depth 20 origin "+refs/heads/$BRANCH:refs/remotes/origin/$BRANCH"
  git -c safe.directory="$REPO" -C "$REPO" checkout --quiet -B "$BRANCH" "origin/$BRANCH"
  git -c safe.directory="$REPO" -C "$REPO" reset --quiet --hard "origin/$BRANCH"
else
  git clone --quiet --depth 20 --branch "$BRANCH" "$REPO_URL" "$REPO" || die "не скачался репозиторий $REPO_URL (ветка $BRANCH)"
fi
echo "$BRANCH" > "$ROOT/branch"
cat > /usr/local/bin/kavkaz-update <<'CMD'
#!/usr/bin/env bash
# KAVKAZ RP: скачать свежий код с GitHub и поставить наши ресурсы на сервер (setup/kavkaz-update.sh)
exec bash /opt/kavkaz/repo/setup/kavkaz-update.sh "$@"
CMD
cat > /usr/local/bin/kavkaz-mods <<'CMD'
#!/usr/bin/env bash
# KAVKAZ RP: поставить моды карты из /opt/kavkaz/mods-inbox (setup/import-mods.sh)
exec bash /opt/kavkaz/repo/setup/import-mods.sh "$@"
CMD
chmod 755 /usr/local/bin/kavkaz-update /usr/local/bin/kavkaz-mods
echo "Код: $REPO ($(git -c safe.directory="$REPO" -C "$REPO" log -1 --format='%h %s'))"

chown -R "$RUN_USER:$RUN_USER" "$ROOT"
chown -R root:root "$REPO"   # код ставит и обновляет root; сервер получает копию через kavkaz-update
chmod 600 "$SECRETS"

# --- 7. служба (автозапуск, перезапуск при падении) ----------------------------------
step "Создаю службу $SERVICE (автозапуск)"
cat > /etc/systemd/system/$SERVICE.service <<EOF
[Unit]
Description=KAVKAZ RP (FXServer + txAdmin)
After=network-online.target mariadb.service
Wants=network-online.target

[Service]
User=$RUN_USER
WorkingDirectory=$SERVER_DIR
Environment=TXHOST_DATA_PATH=$TXDATA
ExecStart=$SERVER_DIR/run.sh
Restart=always
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable "$SERVICE" >/dev/null 2>&1
systemctl restart "$SERVICE"

# --- 8. файрвол ------------------------------------------------------------------------
step "Настраиваю файрвол"
SSH_PORT=$(ss -tlnpH 2>/dev/null | awk '/sshd/ {split($4,a,":"); print a[length(a)]; exit}') || true
ufw allow "${SSH_PORT:-22}"/tcp >/dev/null
ufw allow 30120/tcp >/dev/null     # игра
ufw allow 30120/udp >/dev/null     # игра
ufw allow 40120/tcp >/dev/null     # txAdmin
ufw --force enable >/dev/null
echo "Открыты порты: SSH ${SSH_PORT:-22}, игра 30120, txAdmin 40120"

# --- 8.5 ежедневный бэкап базы ---------------------------------------------------------
step "Настраиваю ежедневный бэкап базы (04:00, хранится 14 копий)"
cat > /usr/local/bin/kavkaz-backup <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
DIR=/opt/kavkaz/backups
mkdir -p "$DIR"
STAMP=$(date +%Y-%m-%d_%H-%M)
mariadb-dump --single-transaction --routines --databases qbox 2>/dev/null | gzip > "$DIR/qbox_$STAMP.sql.gz"
ls -1t "$DIR"/qbox_*.sql.gz 2>/dev/null | tail -n +15 | xargs -r rm -f
EOF
chmod 755 /usr/local/bin/kavkaz-backup
echo '0 4 * * * root /usr/local/bin/kavkaz-backup' > /etc/cron.d/kavkaz-backup
echo "Бэкапы: $ROOT/backups (ручной запуск: kavkaz-backup)"

# --- 9. итог ---------------------------------------------------------------------------
IP=$(curl -fsS -4 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
sleep 8
PIN=$(journalctl -u "$SERVICE" -n 200 --no-pager 2>/dev/null | grep -A1 'PIN below' | grep -oE '[0-9]{4}' | tail -1 || true)

printf '\n\033[1;32mГОТОВО.\033[0m\n'
cat <<EOF
Сервер работает как служба и сам запускается после перезагрузки VPS.

1) Открой в браузере:   http://$IP:40120
2) PIN для txAdmin:      ${PIN:-посмотри командой ниже}
   (если не виден:  journalctl -u $SERVICE -n 80 --no-pager | grep -A1 'PIN below')
   Данные сервера лежат в $TXDATA/default
3) Дальше как в прошлый раз: Link Account -> Popular Recipes -> Qbox.
   База данных: host 127.0.0.1, port 3306, user $DB_USER, имя базы $DB_NAME
   Пароль базы:  cat $SECRETS     (строка mariadb_kavkaz_password)
   Ключ сервера (Cfx.re): создай новый на portal.cfx.re для IP $IP
4) Когда рецепт Qbox встал и сервер один раз запустился — поставь наши ресурсы:
      kavkaz-update --restart
   (этой же командой потом ставятся все обновления с GitHub)
5) Вход в игру:  F8 -> connect $IP
6) Моды карты: закинь архивы в $ROOT/mods-inbox (WinSCP или scp) и запусти  kavkaz-mods --restart

Бэкап на свой ПК (в PowerShell на ПК):  scp root@$IP:$ROOT/backups/* .
Управление:  systemctl restart $SERVICE | systemctl stop $SERVICE | journalctl -u $SERVICE -f
EOF
