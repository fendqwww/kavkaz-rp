# Что скачать (16.11.2026): машины вместо заглушек, форма, интерьеры

Все ссылки открыты и проверены 16.11.2026: страница на месте, размер и тип взяты со страницы.
Лицензии почти нигде нет. Это значит «нигде не запрещено», а не «разрешено». Для сервера на 1–2 друзей риск небольшой,
но выкладывать архивы в публичный git нельзя (`[cars]`/`[maps]` и так в `.gitignore`).
«Replace» — не беда: файлы переименуем в своё имя (`kv_…`), как сделали с 2114 ДПС (`ladapol` → `kv_2114_dps`).
Порог памяти машины — 16 МиБ ([[cars-oversize-16mb]]): всё тяжелее ужимаем `car_planar` и проверяем рендером рядом с оригиналом.

## Скачать в первую очередь (самое заметное в игре)

| # | что | ссылка | размер | что заменит у нас |
|---|---|---|---|---|
| 1 | КАМАЗ 5490 тягач [Add-On] (AKROM) | https://www.gta5-mods.com/vehicles/kamaz-5490-add-on | 17,9 МБ | `kv_truck`, дальнобой |
| 2 | прицепы к КАМАЗ 5490 (AKROM) | https://www.gta5-mods.com/vehicles/kamaz-5490-trucks | 19,9 МБ | прицепы дальнобоя (без них тягач пишет «invalid model» — комментарий на странице) |
| 3 | Лада Веста полиция (AKROM) | https://www.gta5-mods.com/vehicles/lada-vesta-police | 15 МБ | `kv_vesta_dps` |
| 4 | Ford Transit CRS (joachim), модель | https://www.gta5-mods.com/vehicles/replace-non-els-ford-transit-crs | 12,9 МБ | основа фургона ФСБ |
| 5 | раскраска «ФСБ России» на этот Транзит | https://www.gta5-mods.com/vehicles/fsb-russia | 6,5 МБ | `kv_fsb_van` (вместе с п. 4) |
| 6 | УАЗ-3962 скорая (AKROM) | https://www.gta5-mods.com/vehicles/uaz-3962-ambulance | 15 МБ | `kv_gazel_ems` (Газели-скорой бесплатной нет) |
| 7 | форма врача скорой (Mr_Wolf866) | https://www.gta5-mods.com/player/russian-paramedic-uniform | 2,8 МБ | NPC-медики (`s_m_m_paramedic_01`) |
| 8 | ОМОН (Dima4887) | https://www.gta5-mods.com/player/omon-russian | 24,3 МБ | спецгруппа/ОМОН у NPC-силовиков |
| 9 | Лада Гранта FL 2018 [Add-On] (LxstFxme) | https://www.gta5-mods.com/vehicles/2018-lada-granta-fl-add-on-extras-livery-template | 22 МБ, тяжёлая | `kv_solaris_taxi` → такси на Гранте; в моде раскраска «Яндекс Такси», её перекрасим в своё такси (чужой бренд не ставим) |
| 10 | ПАЗ-3205 [Add-On] (AKROM) | https://www.gta5-mods.com/vehicles/paz-3205-by-akrom-add-on | 9,7 МБ | автобус ОМОН/пригородный рейс |

## 1. Машины-заглушки (`kavkaz_cars/cars.lua`, `placeholder = true`)

### служебные и рабочие
| что | ссылка | размер | что заменит | заметки |
|---|---|---|---|---|
| Веста ДПС | https://www.gta5-mods.com/vehicles/lada-vesta-police | 15 МБ | `kv_vesta_dps` | Replace `police3`, автор AKROM (как у нашей 2114 ДПС) |
| Октавия ДПС | — | — | `kv_octavia_dps` | **бесплатной нет**: раскраска https://www.gta5-mods.com/paintjobs/2020-skoda-octavia-russian-police требует модель Octavia, страница модели удалена. Предлагаю убрать запись или взять Весту |
| фургон ФСБ | п. 4 + п. 5 выше | 12,9 + 6,5 МБ | `kv_fsb_van` | модель Replace `policet`, раскраска отдельно |
| скорая | https://www.gta5-mods.com/vehicles/uaz-3962-ambulance | 15 МБ | `kv_gazel_ems` | Replace `ambulance`; Газели-скорой нет нигде (на странице УАЗа её только просят) |
| пожарный МЧС (КАМАЗ) | — | — | `kv_mchs` | **бесплатного нет**. Есть только раскраска «Пожарная охрана» на Волгу: https://www.gta5-mods.com/paintjobs/russian-gaz-31105-fire-protection (нужна модель Волги). Пожарных на старте нет — запись можно оставить заглушкой |
| тягач дальнобоя | https://www.gta5-mods.com/vehicles/kamaz-5490-add-on | 17,9 МБ | `kv_truck` | Add-On; прицепы — https://www.gta5-mods.com/vehicles/kamaz-5490-trucks |
| маршрутка | https://www.gta5-mods.com/vehicles/gazel-next | 29,2 МБ, **тяжёлая** | `kv_gazel_taxi` | Газель Next Add-On (AlbertoM93); раскраски маршрутки нет — нарисуем сами; ужимать до 16 МиБ |
| эвакуатор Газель Next | https://libertycity.net/files/219553-gazel-next-jevakuator.html | 73,8 МБ, **очень тяжёлая** | `kv_tow` | Replace; автор **запрещает перезаливку и правки без разрешения** — только себе на сервер, без публикации |
| такси | https://www.gta5-mods.com/vehicles/2018-lada-granta-fl-add-on-extras-livery-template | 22 МБ, тяжёлая | `kv_solaris_taxi` | бесплатного Солярис-такси нет; Гранта с раскраской «Яндекс» → своя раскраска. Модель — конверт из GTA SA (Diamond Studio) |
| автобус ОМОН / пригород | https://www.gta5-mods.com/vehicles/paz-3205-by-akrom-add-on | 9,7 МБ | новый `kv_paz` | Add-On, spawn `paz` |

Всё одним архивом (вместо пп. выше): Grand Russian Pack — 13 машин ДПС/ППС/Росгвардии/СК/МЧС (Октавия, Веста, Приора, УАЗы, ПАЗ,
Спринтер-скорая): https://www.lcpdfr.com/downloads/gta5mods/vehiclemodels/42326-grand-russian-pack-els-addonreplace/ — **415 МБ**, для
скачивания нужен вход на lcpdfr.com; под ELS (мигалки скриптом) — для FiveM мигалки надо переделывать. Брать, только если по одной не выйдет.

### гражданские (по одной, после служебных)
| что | ссылка | размер | что заменит | заметки |
|---|---|---|---|---|
| Нива 4x4 (2329, 2010) | https://www.gta5-mods.com/vehicles/2010-lada-2329-niva-4x4-add-on-extras-livery-template | 19,6 МБ, тяжёлая | `kv_niva_legend` / `kv_niva_travel` | Add-On, spawn `2010lada2329`; «Легенд» отдельно нет |
| Прадо 150 | https://www.gta5-mods.com/vehicles/toyota-prado-150 | 4,8 МБ | `kv_prado150` | Add-On, лёгкая; конверт из GTA SA |
| BMW M5 F10 | https://www.gta5-mods.com/vehicles/2012-bmw-m5-f10-13stewartc | 49,5 МБ, **очень тяжёлая** | `kv_f10` | Add-On; автор **разрешает FiveM**, «если не награда за донат и не эксклюзив одному человеку» |
| Солярис, Рио | — | — | `kv_solaris`, `kv_rio` | **готовых бесплатных нет** (есть только тюнинг-детали и dev-модель Рио без конвертации) |
| Мерседес E W212 | — | — | `kv_w212` | бесплатного Add-On W212 не нашлось (есть такси Вены W212 и E-класс 2023 — другие поколения) |
| остальные (Королла, Мазда 6, LC200, LX600, РР Спорт, W223, Майбах, Кайен, E36, E46, S15, Фокус 2) | — | — | — | не искал: сначала служебные. Это следующий проход |

## 2. Форма и NPC (педы)
Уже есть `kv_peds`: `s_m_y_ranger_01` — ДПС, `s_m_y_blackops_01` — ФСБ.

| что | ссылка | размер | что даст | заметки |
|---|---|---|---|---|
| ОМОН (Dima4887) | https://www.gta5-mods.com/player/omon-russian | 24,3 МБ | спецгруппа, ОМОН | ставится заменой файлов `componentpeds_s_m_y` (модель из BF4) — ped для замены уточнить в архиве |
| форма полиции и Росгвардии для своего персонажа (KERRY) | https://www.gta5-mods.com/player/russian-police-v1 | 70,1 МБ | ППС/полиция у игрока (мужская и женская) | заменяет одежду MP-персонажа; автор в 03.2026 писал, что структура файлов поменялась — проверить архив |
| врач скорой (Mr_Wolf866) | https://www.gta5-mods.com/player/russian-paramedic-uniform | 2,8 МБ | NPC-медики | `s_m_m_paramedic_01.ytd` + `_p.ytd` — просто кладём в stream |
| следователь в штатском | — | — | — | отдельного нет: берём игровых `s_m_m_ciasec_01` (костюм) без правок |
| русские гражданские NPC-водители | — | — | — | бесплатных наборов не нашёл |

## 3. Интерьеры (MLO) для госструктур
Бесплатного **русского** отдела полиции, ГИБДД, ФСБ, поста ДПС или ИВС **не нашлось**. Есть бесплатные американские; на стенах
меняем таблички и гербы своими текстурами.

| что | ссылка | заметки |
|---|---|---|
| Pillbox — больница (бесплатно) | https://forum.cfx.re/t/release-pillbox-hospital-interior-mlo/609786 | старый релиз; в обсуждении: без зависимости нет дверей — читать тему до конца |
| Bolingbroke — блок с камерами | https://forum.cfx.re/t/mlo-bolingbroke-penitentiary-cell-block/2368074 | все камеры открываются (по комментариям) — под ИВС/СИЗО |
| Vespucci PD (бесплатно) | https://forum.cfx.re/t/vespucci-pd-mlo/5141238 | планировка Mission Row; жалобы: этажи иногда не грузятся |
| K9 Police Station (бесплатно) | https://forum.cfx.re/t/k9-police-station-mlo/5401298 | небольшой отдел; под отдел полиции/ГИБДД |

С металлодетектором-рамкой бесплатного нет (у платного Alta PD он есть). Сайты «free repack» платных MLO (fivemx, vertexmods)
**не брать**: это перезаливы чужого платного, и в таких архивах бывают вирусы.

## 4. Пропсы
| что | итог |
|---|---|
| жезл ДПС | **бесплатного нет**, есть только дубинки. Делаем сами: полосатая палка — простейшая модель для `props_blender.py` |
| радар, алкотестер | **нет**. Делаем сами (коробка + экран-текстура) или берём игровой `prop_police_radio_main` |
| конусы, блоки | в игре есть (`prop_roadcone02a`, `prop_mp_barrier_02b`); русских бесплатных не нашёл |
| рамка металлодетектора | бесплатной нет |

## 5. Звуки
- СГУ и крякалка у нас уже свои (`kavkaz_sgu`: Хазард, вой, йелп, кря-кря — синтез в браузере, файлы `krya`/`hazard`). Качать нечего.
- «Российская полиция» для громкоговорителя: https://www.gta5-mods.com/misc/megaphoneaudio — 96 МБ, одна запись, по комментариям
  «акцент, похоже на украинский/итальянский». **Не советую**. Фразы «Водитель, прижмитесь к обочине» лучше записать голосом самим.

## 6. Где игрок ещё видит стандартный Qbox (только список, экраны — в конце)
Проверено по `C:/kavkaz/txData/Qbox_EE0B2B.base` (на VPS может отличаться) и `overrides/resources`.

| экран | ресурс | что видно | у нас правлено? |
|---|---|---|---|
| телефон | `npwd` | весь телефон; `config.json`: `"defaultLanguage": "en"` — **английский** | нет |
| банк | `Renewed-Banking` (NUI) | окно банка; русский перевод в моде **есть** (`locales/ru.json`) — проверить, что включён | нет |
| список игроков | `qbx_scoreboard` (NUI) | «Total Players» — **английский**, перевода нет | нет |
| таксометр | `qbx_taxijob` (NUI) | счётчик такси; **русского перевода нет** | нет |
| продажа авто с рук | `qbx_vehiclesales` (NUI) | окно продажи — стандартное | нет |
| гонки | `qbx_lapraces` (NUI) | стандартное окно | нет |
| ограбления | `qbx_bankrobbery`, `qbx_storerobbery`, `mhacking`, `ultra-voltlab` (NUI) | мини-игры взлома — стандартные, английские | нет |
| полиция | `qbx_police` (NUI) | окна полиции (улики, MDT) — стандартные; правлен только `config` | частично |
| HUD | `qbx_hud` (NUI) | правлены `config`/`locales`, но вид — стандартный | частично |
| удостоверение | `qbx_idcard` (NUI) | правлено | да |
| редактор внешности | `illenium-appearance` (NUI) | правлены `locales`/`shared`, вид — стандартный | частично |
| выбор персонажа, спавн | `qbx_core`, `qbx_spawn` | меню ox_lib (наша тема), переводы правлены | да |
| радиальное меню, эмоции | `qbx_radialmenu`, `scully_emotemenu` | стандартные | нет |
| гаражи, магазин авто, мэрия | `qbx_garages`, `qbx_vehicleshop`, `qbx_cityhall` | ox_lib + переводы | да |
| загрузка | `loadscreen` в `[standalone]` и наш `kavkaz_loadscreen` | проверить, что стоит наш, а стандартный не запускается | — |

## Куда класть
Каждый скачанный архив — в **свою новую пустую папку**, архив не распаковывать (распакую сам):

```
C:\kavkaz\incoming-1116\kamaz5490\        ← п. 1
C:\kavkaz\incoming-1116\kamaz_trailers\   ← п. 2
C:\kavkaz\incoming-1116\vesta_dps\        ← п. 3
C:\kavkaz\incoming-1116\transit\          ← п. 4
C:\kavkaz\incoming-1116\fsb_skin\         ← п. 5
C:\kavkaz\incoming-1116\uaz_ambulance\    ← п. 6
C:\kavkaz\incoming-1116\medic_uniform\    ← п. 7
C:\kavkaz\incoming-1116\omon\             ← п. 8
C:\kavkaz\incoming-1116\granta\           ← п. 9
C:\kavkaz\incoming-1116\paz\              ← п. 10
```
Остальное — по тому же правилу: `C:\kavkaz\incoming-1116\<короткое_имя>\`. Так архивы не смешаются со скриптами.
