#!/usr/bin/env bash
# KAVKAZ RP — установка сервера на VPS (Ubuntu 22.04 / 24.04) одной командой.
# Запуск (под root):
#   curl -fsSL https://raw.githubusercontent.com/fendqwww/kavkaz-rp/claude/serene-franklin-9x1dw5/setup/install-linux.sh | bash
# Скрипт можно запускать повторно: уже сделанные шаги пропускаются.
set -euo pipefail

ROOT=/opt/kavkaz
SERVER_DIR=$ROOT/server
TXDATA=$ROOT/txData
SECRETS=$ROOT/secrets.cfg
RUN_USER=fivem
SERVICE=kavkaz
DB_NAME=qbox
DB_USER=kavkaz

step() { printf '\n\033[1;36m=== %s ===\033[0m\n' "$1"; }
die()  { printf '\033[1;31mОшибка: %s\033[0m\n' "$1" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "запусти от root (sudo -i)"
. /etc/os-release
[ "${ID:-}" = "ubuntu" ] || die "скрипт рассчитан на Ubuntu 22.04 или 24.04, а у тебя ${PRETTY_NAME:-неизвестная система}"

gen_pass() { tr -dc 'A-HJ-NP-Za-km-z2-9' </dev/urandom | head -c 24; }

# --- 1. пакеты ------------------------------------------------------------------
step "Ставлю пакеты (MariaDB, curl, xz, ufw)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq mariadb-server curl xz-utils ufw ca-certificates tzdata >/dev/null
timedatectl set-timezone Europe/Moscow 2>/dev/null || true

# --- 2. пользователь и папки ------------------------------------------------------
step "Создаю пользователя $RUN_USER и папки в $ROOT"
id "$RUN_USER" >/dev/null 2>&1 || useradd --system --create-home --shell /usr/sbin/nologin "$RUN_USER"
mkdir -p "$SERVER_DIR" "$TXDATA" "$ROOT/backups"

# --- 3. swap, если памяти мало и swap нет ------------------------------------------
if ! swapon --show | grep -q . && [ "$(awk '/MemTotal/ {print int($2/1024/1024)}' /proc/meminfo)" -lt 12 ]; then
  step "Создаю swap 4 ГБ"
  fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile
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
chown -R "$RUN_USER:$RUN_USER" "$ROOT"
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
SSH_PORT=$(ss -tlnpH 2>/dev/null | awk '/sshd/ {split($4,a,":"); print a[length(a)]; exit}')
ufw allow "${SSH_PORT:-22}"/tcp >/dev/null
ufw allow 30120/tcp >/dev/null     # игра
ufw allow 30120/udp >/dev/null     # игра
ufw allow 40120/tcp >/dev/null     # txAdmin
ufw --force enable >/dev/null
echo "Открыты порты: SSH ${SSH_PORT:-22}, игра 30120, txAdmin 40120"

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
4) Вход в игру:  F8 -> connect $IP

Управление:  systemctl restart $SERVICE | systemctl stop $SERVICE | journalctl -u $SERVICE -f
EOF
