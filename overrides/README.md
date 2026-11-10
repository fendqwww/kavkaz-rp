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
| `[standalone]/illenium-appearance/locales/ru.lua` + `fxmanifest.lua` | русский редактор внешности (в манифест добавлена строка `-- KAVKAZ:`) |

если txAdmin обновит ресурс Qbox, просто запусти скрипт ещё раз. если у обновлённого ресурса
поменялся формат конфига — сравни файл здесь с новым и перенеси правки (они помечены `KAVKAZ:`).
