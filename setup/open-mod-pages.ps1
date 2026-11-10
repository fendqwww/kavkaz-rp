# KAVKAZ RP — открыть в браузере страницы бесплатных модов стартового набора (docs/vision/17-map-mods.md).
# на каждой странице: нажать Download, сохранить архив в C:\kavkaz\mods-inbox. потом: setup\import-mods.ps1
# запуск: powershell -ExecutionPolicy Bypass -File setup\open-mod-pages.ps1
#
# машины (docs/vision/19-car-models-todo.md): открыть поиск моделей на gta5-mods.com и forum.cfx.re
#   -Cars                    первые 9 (Камри 80, Приора, LC300, G 63, M5, 2114, УАЗ ДПС, Октавия ДПС, «Семёрка»)
#   -Cars all                все машины
#   -Cars kv_priora,kv_g63   выборочно, по именам спавна
# скачанный архив назови именем спавна (kv_priora.zip) и положи в C:\kavkaz\mods-inbox\cars
param([string[]]$Cars)

if ($PSBoundParameters.ContainsKey('Cars')) {
    $query = [ordered]@{
        kv_camry80 = 'toyota camry 2025'; kv_priora = 'lada priora hatchback'; kv_lc300 = 'land cruiser 300'; kv_g63 = 'mercedes g63 2019'
        kv_m5f90 = 'bmw m5 f90'; kv_vaz2114 = 'vaz 2114'; kv_uaz_dps = 'uaz patriot police'; kv_octavia_dps = 'skoda octavia police'
        kv_vaz2107 = 'vaz 2107'; kv_granta = 'lada granta'; kv_vesta = 'lada vesta'; kv_vesta_dps = 'lada vesta police'
        kv_niva_legend = 'lada niva'; kv_niva_travel = 'niva travel'; kv_focus2 = 'ford focus 2'; kv_solaris = 'hyundai solaris'
        kv_rio = 'kia rio'; kv_corolla = 'toyota corolla 2020'; kv_octavia = 'skoda octavia a7'; kv_camry70 = 'toyota camry 2018'
        kv_mazda6 = 'mazda 6 2019'; kv_w212 = 'mercedes w212'; kv_f10 = 'bmw f10'; kv_prado150 = 'prado 150'; kv_lc200 = 'land cruiser 200'
        kv_lx600 = 'lexus lx600'; kv_rrsport = 'range rover sport 2023'; kv_w223 = 'mercedes w223'; kv_maybach = 'maybach s680'
        kv_cayenne = 'porsche cayenne 2018'; kv_e36 = 'bmw e36'; kv_e46 = 'bmw e46'; kv_s15 = 'nissan silvia s15'
        kv_gazel_taxi = 'gazel next'; kv_gazel_ems = 'gazel ambulance'; kv_liaz = 'liaz 5292'; kv_tow = 'kamaz evacuator'
        kv_truck = 'kamaz 5490'; kv_mchs = 'kamaz fire truck'
    }
    $first = @('kv_camry80', 'kv_priora', 'kv_lc300', 'kv_g63', 'kv_m5f90', 'kv_vaz2114', 'kv_uaz_dps', 'kv_octavia_dps', 'kv_vaz2107')
    $list = if (-not $Cars -or $Cars.Count -eq 0) { $first } elseif ($Cars[0] -eq 'all') { @($query.Keys) } else { $Cars -split ',' | ForEach-Object { $_.Trim() } }
    New-Item -ItemType Directory -Force -Path 'C:\kavkaz\mods-inbox\cars' | Out-Null
    $opened = 0
    foreach ($name in $list) {
        if (-not $query.Contains($name)) { Write-Host "  ? нет такой машины: $name" -ForegroundColor Yellow; continue }
        $q = [uri]::EscapeDataString($query[$name])
        Start-Process "https://www.gta5-mods.com/search/$q"; Start-Sleep -Milliseconds 400
        Start-Process "https://forum.cfx.re/search?q=$q%20free%20release"; Start-Sleep -Milliseconds 400
        Write-Host ("  {0,-16} {1}" -f $name, $query[$name])
        $opened++
    }
    Start-Process 'C:\kavkaz\mods-inbox\cars'
    Write-Host "открыт поиск для машин: $opened. проверь лицензию по чек-листу (docs/vision/19-car-models-todo.md),"
    Write-Host 'архив назови именем спавна (kv_priora.zip) и положи в C:\kavkaz\mods-inbox\cars'
    return
}

New-Item -ItemType Directory -Force -Path 'C:\kavkaz\mods-inbox' | Out-Null
$pages = @(
    'https://forum.cfx.re/t/release-free-map-hunt-cabin-with-trees/4823524',          # изба в горах
    'https://forum.cfx.re/t/farmer-house-barn-mlo-pack-farm-interior/5399481',         # ферма Седа-Юрт
    'https://forum.cfx.re/t/mlo-ballroom-in-the-observatory/5409581',                  # зал «Ловзар»
    'https://fivemecho.gumroad.com/l/redline',                                         # СТО Бислана (цена 0 — ввести 0)
    'https://fivemx.com/free-patoche-car-dealer-mlo/',                                 # автосалон
    'https://www.gta5-mods.com/maps/russian-border-ymap',                              # пост ДПС
    'https://forum.cfx.re/t/hookah-lounge-free-mlo/4765067',                           # кальянная
    'https://www.gta5-mods.com/maps/new-drag-strip-drifting-spot-sandy-shores-smilemore', # дрифт
    'https://forum.cfx.re/t/mlo-free-armadillo-bakery-coffeeshop/5008264',             # пекарня Лам-Юрт
    'https://forum.cfx.re/t/release-mlo-la-mesa-police-department/4874033'             # отдел полиции
)
foreach ($p in $pages) { Start-Process $p; Start-Sleep -Milliseconds 400 }
Start-Process 'C:\kavkaz\mods-inbox'
Write-Host "открыто страниц: $($pages.Count). скачай архивы в C:\kavkaz\mods-inbox и запусти setup\import-mods.ps1"
