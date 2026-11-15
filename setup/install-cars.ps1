# KAVKAZ RP — поставить собранные машины (resources\[cars], их собирает setup\cars\build.py) на локальный сервер.
# что делает: копирует resources\[cars]\<имя_спавна> в resources\[cars] сервера, пишет cars.cfg (ensure каждой машины)
# и добавляет в конец server.cfg строку exec cars.cfg. модели в git не идут (.gitignore). на VPS: scp в resources/[cars] сервера, cars.cfg пишет kavkaz-update.
# запуск: powershell -ExecutionPolicy Bypass -File setup\install-cars.ps1 [-Base "C:\kavkaz\txData\Qbox_XXXX.base"]
param([string]$Base)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $Base) {
    $Base = Get-ChildItem -LiteralPath 'C:\kavkaz\txData' -Directory -Filter '*.base' | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $Base -or -not (Test-Path -LiteralPath (Join-Path $Base 'server.cfg'))) {
    throw "не нашёл папку сервера с server.cfg. укажи её: -Base 'C:\kavkaz\txData\Qbox_XXXX.base'"
}
$src = Join-Path $repo 'resources\[cars]'
if (-not (Test-Path -LiteralPath $src)) { throw "нет $src — сначала собери машины (setup\cars\build.py)" }
$dst = Join-Path $Base 'resources\[cars]'
New-Item -ItemType Directory -Force -Path $dst | Out-Null

$names = @()
$total = 0
foreach ($car in Get-ChildItem -LiteralPath $src -Directory | Sort-Object Name) {
    if (-not (Test-Path -LiteralPath (Join-Path $car.FullName 'fxmanifest.lua'))) { continue }
    $target = Join-Path $dst $car.Name
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    Copy-Item -LiteralPath $car.FullName -Destination $target -Recurse -Force
    $mb = (Get-ChildItem -LiteralPath (Join-Path $car.FullName 'stream') -File | Measure-Object Length -Sum).Sum / 1MB
    $total += $mb
    Write-Host ('  + {0,-16} {1,5:N1} МБ' -f $car.Name, $mb)
    $names += "ensure $($car.Name)"
}

$cfg = @('## KAVKAZ RP: машины — файл пишет setup/install-cars.ps1, руками не править') + $names
[IO.File]::WriteAllText((Join-Path $Base 'cars.cfg'), ($cfg -join "`r`n") + "`r`n", (New-Object Text.UTF8Encoding($false)))
$serverCfg = Join-Path $Base 'server.cfg'
$text = [IO.File]::ReadAllText($serverCfg)
if ($text -notmatch '(?m)^\s*exec\s+cars\.cfg\s*$') {
    $nl = if ($text -match "`r`n") { "`r`n" } else { "`n" }
    if (-not $text.EndsWith("`n")) { $text += $nl }
    $text += "$nl## KAVKAZ RP: машины (setup/install-cars)${nl}exec cars.cfg$nl"
    [IO.File]::WriteAllText($serverCfg, $text, (New-Object Text.UTF8Encoding($false)))
    Write-Host '+ server.cfg: добавлена строка exec cars.cfg'
}
Write-Host ('готово: машин {0}, стрим {1:N0} МБ из 5120. перезапусти сервер.' -f $names.Count, $total)
