# KAVKAZ RP — установка сервера на Windows одним запуском.
# Запуск (PowerShell):  powershell -ExecutionPolicy Bypass -File .\install.ps1
# Скрипт можно запускать повторно: уже сделанные шаги пропускаются.

$ErrorActionPreference = 'Stop'
$Root      = 'C:\kavkaz'
$ServerDir = Join-Path $Root 'server'
$TxData    = Join-Path $Root 'txData'
$Secrets   = Join-Path $Root 'secrets.cfg'
$RepoUrl   = 'https://github.com/fendqwww/kavkaz-rp.git'
$RepoDir   = 'C:\project\kavkaz'   # рабочая папка проекта
$DbName    = 'qbox'
$DbUser    = 'kavkaz'

function Step($t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }

# --- 0. права администратора --------------------------------------------------
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Write-Host 'Перезапускаю с правами администратора...'
    Start-Process powershell -Verb RunAs -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

function New-Password([int]$len = 24) {
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789'
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] $len
    $rng.GetBytes($bytes)
    -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

# --- 1. программы через winget -------------------------------------------------
Step 'Устанавливаю Git, Node.js, Python, MariaDB, 7-Zip'
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget не найден. Обнови "Установщик приложений" (App Installer) в Microsoft Store и запусти скрипт снова.'
}
$pkgs = 'Git.Git', 'OpenJS.NodeJS.LTS', 'Python.Python.3.12', 'MariaDB.Server', '7zip.7zip'
foreach ($p in $pkgs) {
    $installed = winget list --id $p -e --accept-source-agreements 2>$null | Select-String $p
    if ($installed) { Write-Host "$p уже стоит"; continue }
    Write-Host "Ставлю $p..."
    $ErrorActionPreference = 'Continue'
    winget install --id $p -e --silent --accept-package-agreements --accept-source-agreements
}
Refresh-Path

# --- 2. папки ------------------------------------------------------------------
Step "Создаю $Root"
New-Item -ItemType Directory -Force -Path $Root, $ServerDir, $TxData | Out-Null

# --- 3. пароли -----------------------------------------------------------------
Step 'Пароли'
if (Test-Path $Secrets) {
    $txt = Get-Content $Secrets -Raw
    $RootPass = [regex]::Match($txt, 'mariadb_root_password\s*=\s*(\S+)').Groups[1].Value
    $DbPass   = [regex]::Match($txt, 'mariadb_kavkaz_password\s*=\s*(\S+)').Groups[1].Value
    Write-Host "Беру существующие пароли из $Secrets"
} else {
    $RootPass = New-Password
    $DbPass   = New-Password
    @"
# KAVKAZ RP — секреты. НЕ КОММИТИТЬ, НЕ ПЕРЕСЫЛАТЬ.
# mariadb_root_password = $RootPass
# mariadb_kavkaz_password = $DbPass
# Подключается в server.cfg строкой:  exec C:/kavkaz/secrets.cfg
set mysql_connection_string "mysql://${DbUser}:${DbPass}@127.0.0.1:3306/${DbName}?charset=utf8mb4"
# sv_licenseKey "ВСТАВЬ_КЛЮЧ_CFX_СЮДА"
"@ | Set-Content -Path $Secrets -Encoding UTF8
    # доступ к файлу только у текущего пользователя и администраторов
    icacls $Secrets /inheritance:r /grant:r "${env:USERNAME}:F" 'Administrators:F' 'SYSTEM:F' | Out-Null
    Write-Host "Пароли сохранены в $Secrets"
}

# --- 4. MariaDB ------------------------------------------------------------------
Step 'Настраиваю MariaDB'
$mysql = Get-ChildItem 'C:\Program Files\MariaDB*\bin\mysql.exe' -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
if (-not $mysql) { throw 'mysql.exe не найден — MariaDB не установилась. Проверь вывод winget выше.' }
$bin = $mysql.DirectoryName

$svc = Get-Service -Name 'MariaDB*', 'MySQL*' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $svc) {
    Write-Host 'Служба не найдена — создаю свою базу в C:\kavkaz\mariadb-data'
    & (Join-Path $bin 'mysql_install_db.exe') "--datadir=$Root\mariadb-data" '--service=MariaDB' "--password=$RootPass"
    $svc = Get-Service MariaDB
}
if ($svc.Status -ne 'Running') { Start-Service $svc.Name; Start-Sleep 3 }

function Sql($pass, $q) {
    $ErrorActionPreference = 'Continue'
    $a = @('-uroot', '-h127.0.0.1', '-e', $q)
    if ($pass) { $a = @("-p$pass") + $a }
    & $mysql.FullName @a 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
}
# пробуем наш пароль, если не вышло — пустой (свежая установка) и сразу ставим наш
if (-not (Sql $RootPass 'SELECT 1')) {
    if (-not (Sql '' "ALTER USER 'root'@'localhost' IDENTIFIED BY '$RootPass'; FLUSH PRIVILEGES;")) { throw "Не удалось войти в MariaDB под root. Если root-пароль задавался раньше вручную — впиши его в $Secrets (mariadb_root_password) и запусти снова." }
}
$ok = Sql $RootPass @"
CREATE USER IF NOT EXISTS '$DbUser'@'localhost' IDENTIFIED BY '$DbPass';
CREATE USER IF NOT EXISTS '$DbUser'@'127.0.0.1' IDENTIFIED BY '$DbPass';
ALTER USER '$DbUser'@'localhost' IDENTIFIED BY '$DbPass';
ALTER USER '$DbUser'@'127.0.0.1' IDENTIFIED BY '$DbPass';
GRANT ALL PRIVILEGES ON ``$DbName``.* TO '$DbUser'@'localhost';
GRANT ALL PRIVILEGES ON ``$DbName``.* TO '$DbUser'@'127.0.0.1';
FLUSH PRIVILEGES;
"@
if (-not $ok) { throw 'Не удалось создать пользователя БД.' }
Write-Host "MariaDB готова: пользователь $DbUser, база $DbName (её создаст txAdmin)"

# --- 5. серверные файлы FiveM (recommended) -------------------------------------
Step 'Скачиваю серверные файлы FiveM (recommended)'
if (Test-Path (Join-Path $ServerDir 'FXServer.exe')) {
    Write-Host 'FXServer уже скачан'
} else {
    $info = Invoke-RestMethod 'https://changelogs-live.fivem.net/api/changelog/versions/win32/server'
    $url  = $info.recommended_download
    $ext  = [IO.Path]::GetExtension(([uri]$url).AbsolutePath)
    $arc  = Join-Path $Root "server$ext"
    Write-Host "Билд $($info.recommended): $url"
    Invoke-WebRequest $url -OutFile $arc -UseBasicParsing
    $7z = 'C:\Program Files\7-Zip\7z.exe'
    if (Test-Path $7z) { & $7z x $arc "-o$ServerDir" -y | Out-Null }
    else { Expand-Archive $arc -DestinationPath $ServerDir -Force }
    Remove-Item $arc
}

# --- 6. репозиторий проекта ------------------------------------------------------
Step 'Клонирую репозиторий проекта'
$ErrorActionPreference = 'Continue'   # git пишет прогресс в stderr
if (-not (Test-Path (Join-Path $RepoDir '.git'))) {
    New-Item -ItemType Directory -Force -Path $RepoDir | Out-Null
    Push-Location $RepoDir
    git init -b main | Out-Null
    git remote add origin $RepoUrl 2>$null
    git fetch origin
    git checkout -t origin/main 2>$null
    if ($LASTEXITCODE -ne 0) { git checkout -t origin/claude/nice-edison-6f7dhr }
    Pop-Location
} else { Write-Host "Репозиторий уже есть в $RepoDir" }

# --- 7. скрипты запуска/остановки и ярлыки ---------------------------------------
Step 'Ярлыки на рабочем столе'
$start = Join-Path $Root 'start-server.bat'
$stop  = Join-Path $Root 'stop-server.bat'
@"
@echo off
set TXHOST_DATA_PATH=$TxData
cd /d $ServerDir
start "KAVKAZ RP server" FXServer.exe
timeout /t 8 /nobreak >nul
start "" http://localhost:40120
"@ | Set-Content $start -Encoding ASCII
@"
@echo off
taskkill /IM FXServer.exe /T /F
echo Server stopped.
timeout /t 3 >nul
"@ | Set-Content $stop -Encoding ASCII

$desk = [Environment]::GetFolderPath('Desktop')
$sh = New-Object -ComObject WScript.Shell
foreach ($l in @(@('Запустить сервер', $start), @('Остановить сервер', $stop))) {
    $lnk = $sh.CreateShortcut((Join-Path $desk "$($l[0]).lnk"))
    $lnk.TargetPath = $l[1]
    $lnk.WorkingDirectory = $Root
    $lnk.IconLocation = (Join-Path $ServerDir 'FXServer.exe') + ',0'
    $lnk.Save()
}

# --- 8. запуск ---------------------------------------------------------------------
Step 'Запускаю сервер (txAdmin)'
Start-Process $start
Start-Process 'https://portal.cfx.re/servers/registration-keys'

Write-Host @"

ГОТОВО. Дальше 3 шага руками (их нельзя автоматизировать — нужен твой вход в Cfx.re):

1) КЛЮЧ CFX — открылась страница portal.cfx.re:
   войди через аккаунт Cfx.re -> нажми "Generate Key" -> название KAVKAZ RP,
   IP: свой IP или 127.0.0.1 -> скопируй ключ (cfxk_...).

2) TXADMIN — открылась вкладка http://localhost:40120:
   введи PIN из чёрного окна "KAVKAZ RP server" -> "Link Account" (вход Cfx.re)
   -> придумай пароль админа -> "Popular Recipes" -> выбери "Qbox"
   -> вставь ключ из шага 1.
   База данных: host 127.0.0.1, port 3306, user $DbUser,
   пароль = mariadb_kavkaz_password из $Secrets, имя базы $DbName.
   Дальше Next/Run Recipe -> Save & Run Server.

3) ВХОД — запусти FiveM, нажми F8 и введи:  connect 127.0.0.1

Пароли: $Secrets   Запуск/остановка: ярлыки на рабочем столе.
"@ -ForegroundColor Green
