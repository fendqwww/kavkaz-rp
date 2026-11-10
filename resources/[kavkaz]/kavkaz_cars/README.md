# kavkaz_cars — автопарк KAVKAZ RP

Один файл `cars.lua` — весь автопарк: имя спавна, русское название, цена в ₽, раздел салона, класс, встроенная модель-заглушка,
настоящая модель, вес, источник и лицензия. Его читают:

| кто | что берёт |
|---|---|
| `qbx_core` (overrides: `shared/main.lua`) | названия, цены, разделы → весь сервер (гаражи, `/agivecar`, пробивка номера) |
| `qbx_vehicleshop` (overrides: `config/shared.lua`) | салон «Нагорье Моторс»: только машины с `sale = 'shop'`, витрина, разделы |
| `qbx_vehicleshop` (overrides: `config/server.lua`) | номер от `kavkaz_plates` при покупке, лимит редких машин (`limit`) |
| `qbx_police`, `qbx_ambulancejob` (overrides: `config/client.lua`) | служебный гараж: машины с `sale = 'org'` и полем `org` |
| `kavkaz_plates` | вид номера служебной машины (`plate = 'ru_police'`) |
| `kavkaz_quests` | «Семёрка» Румисы (`Config.StarterCar`) |

`kavkaz_cars` стартует **раньше `qbx_core`** — строку `ensure kavkaz_cars` перед `ensure qbx_core` в `server.cfg` ставит `setup/apply-overrides.ps1`.
Поменял `cars.lua` → перезапусти сервер целиком (qbx_core читает список один раз).

## Как продаётся
- `shop` — салон «Нагорье Моторс» (у PDM). у `kv_g63` `limit = 20`: 21-го «Гелика» салон не продаст, деньги не спишет;
- `quest` — «Семёрка» `kv_vaz2107`: у Румисы «Мне бы машину…», нужны права и доверие 5, один раз на персонажа, в гараж мотеля;
- `job` — рабочие (такси, автобус, эвакуатор, тягач): выдают работы qbx;
- `org` — служебные (ДПС, скорая, МЧС): только в служебных гаражах, не продаются.

## Номер новой машины
Любая новая машина (салон, Румиса, `/agivecar`) получает номер от `kavkaz_plates`, а не случайный qbx:
по умолчанию транзит `TR123456`, номер «А 123 ВС 95» — в МРЭО. Сразу на учёт — `Config.NewVehiclePlate = 'register'` в `kavkaz_plates/config.lua`.
Служебные машины ДПС выезжают с синим номером «А 1234 95».

## Заглушка → настоящая модель
1. ресурс модели `resources/[cars]/<spawn>` (в git не идёт, см. `docs/vision/19-car-models-todo.md`);
2. в `cars.lua` у машины: `model = '<spawn>', placeholder = false`, заполнить `mb`, `tex`, `source`, `author`, `license`;
3. перезапуск сервера. в консоли `kavkaz_cars` — сводка, `kavkaz_cars_migrate` — сколько купленных машин ещё на заглушке,
   `kavkaz_cars_migrate apply` — перевести их на настоящую модель (номер, тюнинг и владелец сохраняются).

Одна заглушка — одна машина: салон различает машины по имени модели, поэтому `stub` не повторяются (сервер ругнётся при старте).

## Команды
| где | команда | что |
|---|---|---|
| консоль | `kavkaz_cars` | все машины, заглушка или настоящая, вес стрима |
| консоль | `kavkaz_cars_migrate [apply]` | перевод купленных машин с заглушки на настоящую модель |
| игра (админ) | `/aveh kv_camry80` | заспавнить машину по имени из `cars.lua` |
| игра (админ) | `/agivecar ID kv_camry80 причина` | выдать в гараж, номер от kavkaz_plates |

## Экспорты (сервер)
`GiveCar(src|citizenid, spawn, { garage, reason, ignoreLimit })`, `GetCar(name)`, `Label(name)`, `CanBuy(src)`.
