# KAVKAZ RP — открыть в браузере страницы бесплатных модов стартового набора (docs/vision/17-map-mods.md).
# на каждой странице: нажать Download, сохранить архив в C:\kavkaz\mods-inbox. потом: setup\import-mods.ps1
# запуск: powershell -ExecutionPolicy Bypass -File setup\open-mod-pages.ps1
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
