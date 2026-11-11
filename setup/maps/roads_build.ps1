# KAVKAZ RP: собрать ресурс европейской разметки (Roads of Europe DE, бесплатный мод) в лёгком виде.
# +hi.ytd (высокое качество текстур) — цвет до 1024, рельеф/блеск до 512; обычные .ytd — 512/256.
# запуск: powershell -File setup\maps\roads_build.ps1 <распакованная папка stream> <resources\[maps]\kv_map_roads>
param([string]$Src, [string]$Dst)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force "$Dst\stream" | Out-Null
Copy-Item "$Src\*.ytd" "$Dst\stream\" -Force
$repack = Join-Path $PSScriptRoot '..\cars\repack_ytd.py'
$hi = Get-ChildItem -LiteralPath "$Dst\stream" -Filter '*+hi.ytd' | ForEach-Object FullName
$lo = Get-ChildItem -LiteralPath "$Dst\stream" -Filter '*.ytd' | Where-Object Name -notlike '*+hi.ytd' | ForEach-Object FullName
python -I $repack @hi --cap 1024 --budget 9999
python -I $repack @lo --cap 512 --budget 9999
@"
fx_version 'cerulean'
game 'gta5'
this_is_a_map 'yes'
-- KAVKAZ: европейская (белая) разметка — Roads of Europe Definitive Edition, бесплатный мод, текстуры ужаты setup/maps/roads_build.ps1.
-- в git не кладём (resources/[maps] в .gitignore)
"@ | Set-Content -Encoding utf8 "$Dst\fxmanifest.lua"
"{0:N0} MB" -f ((Get-ChildItem -LiteralPath "$Dst\stream" | Measure-Object Length -Sum).Sum / 1MB)
