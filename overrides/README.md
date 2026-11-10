# overrides — наши правки поверх ресурсов Qbox

чужие ресурсы ставит txAdmin (рецепт Qbox). мы их код не правим, а кладём сверху свои файлы:
переводы, конфиги и `kavkaz.cfg`. накатить на сервер:

```
powershell -ExecutionPolicy Bypass -File setup\apply-overrides.ps1
```

скрипт сам найдёт `C:\kavkaz\txData\*.base`, скопирует файлы, сохранит старые версии в
`C:\kavkaz\backup-overrides\<дата>\` и добавит в конец `server.cfg` строку `exec kavkaz.cfg`.
после этого перезапусти сервер.

## что здесь

| файл | что меняет |
|---|---|
| `kavkaz.cfg` | русский язык, синий цвет окон ox_lib, наш экран загрузки, право основателя `kavkaz.founder` для `group.admin`, `ensure` наших ресурсов |
| `[qbx]/qbx_core/locales/ru.json` | дополнен перевод: выбор и создание персонажа («Паспорт жителя Нагорья»), очередь, команды |
| `[qbx]/qbx_core/config/client.lua` | надпись на карте паузы `KAVKAZ RP`, возраст 18+ (`dateMax 2008-12-31`), выключен Discord-статус «Qbox Ducky» |
| `[qbx]/qbx_core/config/shared.lua` | название сервера `KAVKAZ RP`, стартовый набор + 2 воды и 2 бутерброда |
| `[qbx]/qbx_core/data/nationalities.lua` | вместо национальностей — «место рождения»: Нагорск, Лам-Юрт, Седа-Юрт, Песчаный и города |
| `[qbx]/qbx_spawn/config/client.lua` | места появления по лору: «Нагорск, центр», «Мотель», «Лам-Юрт» |
| `[qbx]/qbx_properties/config/shared.lua` | стартовые квартиры на русском («Морской берег», «Сити-Тауэр» …) |
| `*/locales/ru.json` | переводы: qbx_spawn, qbx_properties, qbx_cityhall, qbx_hud, qbx_seatbelt, ox_target |
| `[ox]/ox_inventory/.../kavkaz-theme.css`, `[ox]/ox_lib/web/build/kavkaz-theme.css` | темы инвентаря и меню ox_lib: шрифт Golos Text, плоский спокойный стиль. исходники — `overrides/theme/*.css`, пересборка — `python setup/build-theme.py`. `apply-overrides` сам подключает их строкой `<link>` в `web/build/index.html` |
| `[qbx]/qbx_hud/config/shared.lua` | миникарта видна и пешком (`isOutMapChecked = true`) |
| `[qbx]/qbx_core/shared/main.lua` | подмешивает автопарк из `kavkaz_cars/cars.lua` (русские названия, цены, разделы) в список машин сервера. строки `-- KAVKAZ:` |
| `[qbx]/qbx_vehicleshop/config/shared.lua` | салон «Нагорье Моторс»: только наши машины, русские разделы, витрина; лодки и авиация как были |
| `[qbx]/qbx_vehicleshop/config/server.lua` | `giveKeys` — номер от kavkaz_plates вместо случайного; `removePlayerFunds` — лимит редких машин |
| `[qbx]/qbx_vehicleshop/locales/ru.json` | перевод салона, цены в ₽ |
| `[qbx]/qbx_police/config/client.lua`, `[qbx]/qbx_ambulancejob/config/client.lua` | служебные гаражи берут машины из `cars.lua` (`sale = 'org'`) |
| `server.cfg` (правит скрипт) | строка `ensure kavkaz_cars` перед `ensure qbx_core` |
| `[standalone]/illenium-appearance/locales/ru.lua` + `fxmanifest.lua` | русский редактор внешности (в манифест добавлена строка `-- KAVKAZ:`) |

если txAdmin обновит ресурс Qbox, просто запусти скрипт ещё раз. если у обновлённого ресурса
поменялся формат конфига — сравни файл здесь с новым и перенеси правки (они помечены `KAVKAZ:`).
