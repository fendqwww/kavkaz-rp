# KAVKAZ RP — накатить наши правки на развёрнутый сервер Qbox (Windows).
# что делает:
#   1) копирует overrides\resources\... поверх ресурсов сервера (переводы ru.json, конфиги);
#   2) копирует наши ресурсы resources\[kavkaz]\... ;
#   3) кладёт overrides\kavkaz.cfg рядом с server.cfg и добавляет в конец server.cfg строку "exec kavkaz.cfg";
#   4) включает русский язык в ox.cfg.
# заменённые файлы сохраняются в C:\kavkaz\backup-overrides\<дата>\ — ничего не теряется.
# запуск: powershell -ExecutionPolicy Bypass -File setup\apply-overrides.ps1 [-Base "C:\kavkaz\txData\Qbox_XXXX.base"]
param([string]$Base)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot

if (-not $Base) {
    $Base = Get-ChildItem -LiteralPath 'C:\kavkaz\txData' -Directory -Filter '*.base' | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $Base -or -not (Test-Path -LiteralPath (Join-Path $Base 'server.cfg'))) {
    throw "не нашёл папку сервера с server.cfg. укажи её: -Base 'C:\kavkaz\txData\Qbox_XXXX.base'"
}
Write-Host "сервер: $Base"

$backup = Join-Path 'C:\kavkaz\backup-overrides' (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')
$changed = 0; $same = 0

function Copy-Tree([string]$from, [string]$to) {
    $from = (Resolve-Path -LiteralPath $from).ProviderPath
    Get-ChildItem -LiteralPath $from -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($from.Length).TrimStart('\')
        $dst = Join-Path $to $rel
        if (Test-Path -LiteralPath $dst) {
            if ((Get-FileHash -LiteralPath $dst).Hash -eq (Get-FileHash -LiteralPath $_.FullName).Hash) { $script:same++; return }
            $bak = Join-Path $backup $dst.Substring($Base.Length).TrimStart('\')
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $bak) | Out-Null
            Copy-Item -LiteralPath $dst -Destination $bak -Force
        }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $dst -Force
        Write-Host "  + $rel"
        $script:changed++
    }
}

Write-Host '1) переводы и конфиги чужих ресурсов'
Copy-Tree (Join-Path $repo 'overrides\resources') (Join-Path $Base 'resources')

Write-Host '2) наши ресурсы [kavkaz]'
Copy-Tree (Join-Path $repo 'resources\[kavkaz]') (Join-Path $Base 'resources\[kavkaz]')

Write-Host '3) kavkaz.cfg'
$cfgSrc = Join-Path $repo 'overrides\kavkaz.cfg'
$cfgDst = Join-Path $Base 'kavkaz.cfg'
Copy-Item -LiteralPath $cfgSrc -Destination $cfgDst -Force
$serverCfg = Join-Path $Base 'server.cfg'
$text = [IO.File]::ReadAllText($serverCfg)
if ($text -notmatch '(?m)^\s*exec\s+kavkaz\.cfg\s*$') {
    $bak = Join-Path $backup 'server.cfg'
    New-Item -ItemType Directory -Force -Path $backup | Out-Null
    Copy-Item -LiteralPath $serverCfg -Destination $bak -Force
    $nl = if ($text -match "`r`n") { "`r`n" } else { "`n" }
    if (-not $text.EndsWith("`n")) { $text += $nl }
    $text += "$nl## KAVKAZ RP: наши настройки и ресурсы (setup/apply-overrides)${nl}exec kavkaz.cfg$nl"
    [IO.File]::WriteAllText($serverCfg, $text, (New-Object Text.UTF8Encoding($false)))
    Write-Host '  + server.cfg: добавлена строка exec kavkaz.cfg'
}

Write-Host '4) язык в ox.cfg'
$oxCfg = Join-Path $Base 'ox.cfg'
if (Test-Path -LiteralPath $oxCfg) {
    $ox = [IO.File]::ReadAllText($oxCfg)
    $new = [regex]::Replace($ox, '(?m)^setr ox:locale "[a-z-]+"', 'setr ox:locale "ru"')
    if ($new -ne $ox) {
        New-Item -ItemType Directory -Force -Path $backup | Out-Null
        Copy-Item -LiteralPath $oxCfg -Destination (Join-Path $backup 'ox.cfg') -Force
        [IO.File]::WriteAllText($oxCfg, $new, (New-Object Text.UTF8Encoding($false)))
        Write-Host '  + ox.cfg: ox:locale = ru'
    }
}

Write-Host ''
Write-Host "готово: обновлено файлов $changed, без изменений $same."
if (Test-Path -LiteralPath $backup) { Write-Host "старые версии файлов: $backup" }
Write-Host 'чтобы изменения заработали — перезапусти сервер.'
