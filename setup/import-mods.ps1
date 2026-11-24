# KAVKAZ RP — автоматическая установка скачанных модов карты (Windows).
# что делает:
#   1) берёт всё из C:\kavkaz\mods-inbox (архивы .zip / .rar / .7z или распакованные папки);
#   2) распаковывает и проверяет: нет ли .exe/.dll/.bat и подозрительных скриптов (бэкдоры из «слитых» модов);
#   3) готовый ресурс FiveM (есть fxmanifest.lua) — кладёт как есть;
#      просто файлы карты (.ymap/.ytyp/.ydr/.ytd/.ybn…) — сам собирает ресурс kavkaz_mod_<имя> с fxmanifest;
#   4) кладёт всё в resources\[maps] сервера и пишет maps.cfg (ensure каждого мода), подключает его в server.cfg;
#   5) обработанные архивы переносит в mods-inbox\done, отчёт — mods-inbox\import-log.txt.
# моды для одиночки (Menyoo .xml) и YMAP в XML автоматически не ставятся — отчёт подскажет, что с ними делать.
# запуск: powershell -ExecutionPolicy Bypass -File setup\import-mods.ps1 [-Inbox C:\kavkaz\mods-inbox] [-Base "C:\kavkaz\txData\Qbox_XXXX.base"]
param([string]$Inbox = 'C:\kavkaz\mods-inbox', [string]$Base)

$ErrorActionPreference = 'Stop'

if (-not $Base) {
    $Base = Get-ChildItem -LiteralPath 'C:\kavkaz\txData' -Directory -Filter '*.base' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $Base -or -not (Test-Path -LiteralPath (Join-Path $Base 'server.cfg'))) {
    throw "не нашёл папку сервера с server.cfg. укажи её: -Base 'C:\kavkaz\txData\Qbox_XXXX.base'"
}
New-Item -ItemType Directory -Force -Path $Inbox | Out-Null
$done = Join-Path $Inbox 'done'
New-Item -ItemType Directory -Force -Path $done | Out-Null
$dest = Join-Path $Base 'resources\[maps]'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$work = Join-Path $env:TEMP ('kavkaz-mods-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $work | Out-Null

$log = New-Object System.Collections.Generic.List[string]
function Say([string]$text, [string]$color = 'Gray') { Write-Host $text -ForegroundColor $color; $script:log.Add($text) }

$streamExt = @('.ymap', '.ytyp', '.ydr', '.ydd', '.yft', '.ytd', '.ybn', '.ymf', '.ynv', '.ycd', '.ynd', '.awc', '.rel')
$badExt = @('.exe', '.dll', '.bat', '.cmd', '.ps1', '.vbs', '.scr', '.msi', '.jar', '.com', '.lnk')
# признаки бэкдоров в Lua: скачивание и запуск кода с чужого сервера
$badLua = 'PerformHttpRequest|loadstring|load\s*\(|os\.execute|io\.popen|\\x[0-9a-fA-F]{2}\\x[0-9a-fA-F]{2}\\x[0-9a-fA-F]{2}'

$sevenZip = @('C:\Program Files\7-Zip\7z.exe', 'C:\Program Files (x86)\7-Zip\7z.exe') | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

function SafeName([string]$name) {
    $n = ($name.ToLower() -replace '[^a-z0-9_\-]', '_' -replace '_+', '_').Trim('_')
    if (-not $n) { $n = 'mod' }
    return $n
}

# имена файлов, которые уже стримятся другими модами (два одинаковых файла = конфликт)
$streamed = @{}
Get-ChildItem -LiteralPath $dest -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $streamExt -contains $_.Extension.ToLower() } |
    ForEach-Object { $streamed[$_.Name.ToLower()] = $_.Directory.FullName }

$items = Get-ChildItem -LiteralPath $Inbox | Where-Object { $_.Name -ne 'done' -and $_.Name -ne 'import-log.txt' }
if (-not $items) { Say "в $Inbox пусто — положи туда скачанные архивы модов и запусти снова." 'Yellow' }

foreach ($item in $items) {
    Say ''
    Say "== $($item.Name)" 'Cyan'
    $name = SafeName ([IO.Path]::GetFileNameWithoutExtension($item.Name))
    $src = Join-Path $work $name

    # 1) распаковка
    try {
        if ($item.PSIsContainer) {
            Copy-Item -LiteralPath $item.FullName -Destination $src -Recurse -Force
        } elseif ($item.Extension -eq '.zip') {
            Expand-Archive -LiteralPath $item.FullName -DestinationPath $src -Force
        } elseif ($item.Extension -in @('.rar', '.7z')) {
            if (-not $sevenZip) { Say '  ! для .rar/.7z нужен 7-Zip (winget install 7zip.7zip) — пропускаю' 'Yellow'; continue }
            & $sevenZip x $item.FullName "-o$src" -y | Out-Null
        } else {
            Say "  ! неизвестный формат $($item.Extension) — пропускаю" 'Yellow'; continue
        }
    } catch { Say "  ! не распаковалось: $($_.Exception.Message)" 'Red'; continue }

    $files = Get-ChildItem -LiteralPath $src -Recurse -File

    # 2) проверка безопасности
    $bad = $files | Where-Object { $badExt -contains $_.Extension.ToLower() }
    if ($bad) {
        Say "  ✕ ОПАСНО: в моде есть исполняемые файлы ($(($bad | Select-Object -First 3 | ForEach-Object Name) -join ', ')). не ставлю." 'Red'
        continue
    }
    $suspicious = $files | Where-Object { $_.Extension -eq '.lua' } | Where-Object { (Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue) -cmatch $badLua }
    if ($suspicious) {
        Say "  ✕ ПОДОЗРИТЕЛЬНО: скрипты скачивают или запускают код ($(($suspicious | Select-Object -First 3 | ForEach-Object Name) -join ', ')). не ставлю — покажи Claude." 'Red'
        continue
    }

    # 3) готовые ресурсы (есть fxmanifest.lua / __resource.lua)
    $manifests = $files | Where-Object { $_.Name -in @('fxmanifest.lua', '__resource.lua') }
    $installed = @()
    if ($manifests) {
        foreach ($m in $manifests) {
            $resDir = $m.Directory
            $resName = SafeName $resDir.Name
            if ($resName -eq $name -or $manifests.Count -eq 1) { $resName = $name }
            $target = Join-Path $dest $resName
            if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
            Copy-Item -LiteralPath $resDir.FullName -Destination $target -Recurse -Force
            $installed += $resName
        }
    } else {
        # 4) просто файлы карты -> собираем ресурс сами
        $stream = $files | Where-Object { $streamExt -contains $_.Extension.ToLower() }
        if (-not $stream) {
            $xml = $files | Where-Object { $_.Extension -eq '.xml' }
            if ($xml) {
                Say '  ? в моде только .xml — это мод для одиночки (Menyoo / Map Editor) или YMAP в XML.' 'Yellow'
                Say '    автоматически не ставится: открой в CodeWalker и сохрани как .ymap, или покажи файл Claude.' 'Yellow'
            } else {
                Say '  ? не нашёл файлов карты (.ymap/.ytyp/.ydr/.ytd/.ybn) — пропускаю' 'Yellow'
            }
            continue
        }
        $resName = 'kavkaz_mod_' + $name
        $target = Join-Path $dest $resName
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
        $streamDir = Join-Path $target 'stream'
        New-Item -ItemType Directory -Force -Path $streamDir | Out-Null
        foreach ($f in $stream) { Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $streamDir $f.Name) -Force }
        $ytyp = $stream | Where-Object { $_.Extension -eq '.ytyp' } | ForEach-Object { "data_file 'DLC_ITYP_REQUEST' 'stream/$($_.Name)'" }
        $manifest = @(
            "-- собрано setup/import-mods.ps1 из «$($item.Name)»",
            "fx_version 'cerulean'", "game 'gta5'", "lua54 'yes'", "this_is_a_map 'yes'", ''
        ) + $ytyp
        [IO.File]::WriteAllText((Join-Path $target 'fxmanifest.lua'), ($manifest -join "`r`n") + "`r`n", (New-Object Text.UTF8Encoding($false)))
        $installed += $resName
    }

    # 5) конфликты по именам файлов
    foreach ($r in $installed) {
        Get-ChildItem -LiteralPath (Join-Path $dest $r) -Recurse -File | Where-Object { $streamExt -contains $_.Extension.ToLower() } | ForEach-Object {
            $k = $_.Name.ToLower()
            if ($streamed.ContainsKey($k) -and -not $streamed[$k].StartsWith((Join-Path $dest $r))) {
                Say "  ! конфликт: $($_.Name) уже есть в $($streamed[$k] | Split-Path -Leaf). включится только один из модов" 'Yellow'
            }
            $streamed[$k] = $_.Directory.FullName
        }
        Say "  ✓ установлен: [maps]\$r" 'Green'
    }
    Move-Item -LiteralPath $item.FullName -Destination (Join-Path $done $item.Name) -Force
}

# maps.cfg — ensure всех модов из [maps], подключается в server.cfg
$mapsCfg = Join-Path $Base 'maps.cfg'
$names = Get-ChildItem -LiteralPath $dest -Directory | Where-Object {
    (Test-Path -LiteralPath (Join-Path $_.FullName 'fxmanifest.lua')) -or (Test-Path -LiteralPath (Join-Path $_.FullName '__resource.lua'))
} | Sort-Object Name | ForEach-Object { "ensure $($_.Name)" }
$cfg = @('## KAVKAZ RP: моды карты — файл пишет setup/import-mods.ps1, руками не править', '## выключить мод: поставь # в начале строки') + $names
[IO.File]::WriteAllText($mapsCfg, ($cfg -join "`r`n") + "`r`n", (New-Object Text.UTF8Encoding($false)))
$serverCfg = Join-Path $Base 'server.cfg'
$text = [IO.File]::ReadAllText($serverCfg)
if ($text -notmatch '(?m)^\s*exec\s+maps\.cfg\s*$') {
    $nl = if ($text -match "`r`n") { "`r`n" } else { "`n" }
    if (-not $text.EndsWith("`n")) { $text += $nl }
    $text += "$nl## KAVKAZ RP: моды карты (setup/import-mods)${nl}exec maps.cfg$nl"
    [IO.File]::WriteAllText($serverCfg, $text, (New-Object Text.UTF8Encoding($false)))
    Say '+ server.cfg: добавлена строка exec maps.cfg' 'Green'
}

Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
Say ''
Say "готово. модов на сервере: $($names.Count). список — $mapsCfg" 'Green'
Say 'перезапусти сервер (или в консоли txAdmin: ensure <имя мода>) и зайди проверить.'
[IO.File]::WriteAllLines((Join-Path $Inbox 'import-log.txt'), $log, (New-Object Text.UTF8Encoding($false)))
