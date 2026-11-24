# 19. Модели машин: что скачать

Сейчас (этап 1) весь автопарк ездит на **встроенных машинах GTA**: салон, цены и названия уже наши, модели — заглушки.
Список машин, цены и заглушки — `resources/[kavkaz]/kavkaz_cars/cars.lua`. Этот файл — по каждой машине: что найти, как искать, что проверить.

**На ПК готовых моделей нет** (проверено 10.11.2026: `C:\kavkaz\mods-inbox` нет, в «Загрузках» и на рабочем столе машин нет, на `D:\` только файлы самой GTA V).

## Как работаем
1. открыть страницы поиска: `powershell -ExecutionPolicy Bypass -File setup\open-mod-pages.ps1 -Cars` (первые 9 машин);
   все машины — `-Cars all`, выборочно — `-Cars kv_priora,kv_g63`;
2. на каждой странице выбрать мод по чек-листу ниже, **скачать самому** (на сайтах нужен вход и капча, Claude не скачивает);
3. положить архив в `C:\kavkaz\mods-inbox\cars\` и **назвать его именем спавна из таблицы**: `kv_priora.zip`, `kv_g63.rar`;
4. сказать Claude «модели в mods-inbox». дальше — по одной-две машины: проверка веса и текстур, ресурс `resources/[cars]/<имя_спавна>`,
   handling, строка в `cars.lua` (`model = 'kv_priora', placeholder = false`), запуск, `/aveh kv_priora`, проверка руками.

Модели **в git не кладём** (`resources/[cars]/` в `.gitignore`, репозиторий публичный). На VPS они копируются напрямую по ключу.

## Ограничения (слабые ПК у игроков)
| что | лимит |
|---|---|
| одна машина (все `.yft` + `.ytd`) | **до 25–30 МБ** |
| текстуры | **до 2K** (2048×2048). 4K и 8K не берём |
| весь стрим машин | **до 5 ГБ** (40 машин × 25 МБ ≈ 1 ГБ — запас большой) |
| полигоны | лучше до ~250 тыс. в `_hi`; машины на 500 тыс.+ на RX 560 дают просадки |

Модель тяжелее — не ставим, ищем лёгкую замену (часто у того же автора есть «optimized» / «lite» / «FiveM ready»).
Текстуры 4K иногда можно ужать до 2K в OpenIV / Texture Toolkit, если **лицензия разрешает изменения**.

## Чек-лист описания мода (обязательно)
- [ ] **разрешено ли использование на сервере / FiveM.** ищем в описании: «FiveM allowed», «can be used on servers», «free to use».
      «Do not upload to FiveM», «singleplayer only», «not for FiveM» — **не берём**;
- [ ] **автор настоящий**: мод выложил сам автор, а не перезалив («converted by», «leak», чужая модель без ссылки на оригинал);
- [ ] **бесплатно**: без Patreon/Tebex-ключа, без «paid version for servers». платный или «за донат» — пропускаем, ищем замену;
- [ ] **не конверт из игр** (Forza, NFS, The Crew, Assetto): такие модели принадлежат издателям игр, разрешения на сервер у автора нет;
- [ ] есть **Add-On** версия (а не только Replace) — нам нужно отдельное имя спавна;
- [ ] размер архива и текстуры (смотрим в комментариях или после скачивания — Claude проверит);
- [ ] для служебных (ДПС, скорая): ливрея без настоящих гербов и надписей «Полиция» с реальными номерами частей — у нас «ДПС Нагорье».

Где лучше искать: **forum.cfx.re** (раздел Releases: моды сразу под FiveM, автор сам выкладывает для серверов),
**gta5-mods.com** (много, но читать лицензию у каждого). libertycity и «слитые» паки — не берём.

## Выбрано (10.11.2026, решение: берём моды, где автор не запрещает FiveM; без переписки с авторами)
Страницы открывает `setup\open-mod-pages.ps1 -Cars`. Скачанные файлы остаются в «Загрузках», Claude забирает их сам.

| имя спавна | мод | автор | вес архива | заметки |
|---|---|---|---|---|
| `kv_camry80` | [Toyota Camry 2022 GLE](https://www.gta5-mods.com/vehicles/toyota-camry-2022-gle-replace-unlocked-exrtas) | AboM7sn | 79 МБ | Camry 80 нигде нет — ставим Camry 70 2022; автор разрешает правки; ужать до 30 МБ |
| `kv_priora` | [Lada Priora Hatchback](https://www.gta5-mods.com/vehicles/lada-priora-hatchback) | agen001 | 36 МБ | единственная хэтчбек, старая (2016), Replace — переделаем в Add-On; позже искать красивее |
| `kv_lc300` | [Land Cruiser 300 2021](https://www.gta5-mods.com/vehicles/toyota-land-cruiser-300-2021-add-on) | GCM_mood_cars | 39 МБ | ужать текстуры |
| `kv_g63` | [Mercedes G63 AMG 2019](https://www.gta5-mods.com/vehicles/mercedes-g63-amg-2019-addon-extras) | Solid Soup | 33 МБ | «free mod for everyone»; не брали Topcar (Forza) и RAZ3R (CSR2) |
| `kv_m5f90` | [2018 BMW M5 F90](https://www.gta5-mods.com/vehicles/bmw-m5-f90-2018-add-on-hq-template) | S4MuEL | ? | 568 тыс. скачиваний |
| `kv_vaz2114` | [VAZ-2114 Samara 2](https://www.gta5-mods.com/vehicles/vaz-2114-lada-samara-2-add-on) | Leopoldas (модель AKROM) | ? | |
| `kv_uaz_dps` | [UAZ Patriot Police](https://www.gta5-mods.com/vehicles/uaz-patriot-police) | AKROM | ? | ливрею поменять на «ДПС Нагорье» |
| `kv_octavia_dps` | [Skoda Octavia 2017](https://www.gta5-mods.com/vehicles/2017-skoda-octavia-add-on-replace-dirt-map) | mmods | ? | та же модель пойдёт на `kv_octavia`; ливрея ДПС — позже |
| `kv_vaz2107` | [VAZ-2107 (Lada Riva)](https://www.gta5-mods.com/vehicles/vaz-2107-lada-riva-add-on-tuning) | DragoN777 | 62 МБ | лучшая «Семёрка»; ужать; запасной вариант 7,7 МБ — [Leopoldas/AKROM](https://www.gta5-mods.com/vehicles/vaz-2105-2107-lada-add-on-extras-tuning) |

## Первые 9 (картинки уже в лаунчере + «Семёрка» для новичков)
| имя спавна | машина | запрос для gta5-mods.com | на что смотреть | handling |
|---|---|---|---|---|
| `kv_camry80` | Toyota Camry 80 (2025+) | `toyota camry 2025` | новой модели может не быть — тогда Camry 70 рестайлинг (XV70 2021) под тем же именем | плавная, мягкая подвеска, разгон 0–100 ~8 с |
| `kv_priora` | Lada Priora **хэтчбек** (ВАЗ-2172) | `lada priora hatchback` | хэтчбек, не седан; у agen001 есть отдельный Hatchback | слабая и лёгкая: ~1100 кг, 98 л. с., 0–100 ~11 с |
| `kv_lc300` | Toyota Land Cruiser 300 | `land cruiser 300` | один мод, цвета чёрный и белый задаём сами (carvariations) | тяжёлая (~2600 кг), плавная, хорошо по бездорожью |
| `kv_g63` | Mercedes-AMG G 63 W464 | `mercedes g63 2019` | часто тяжёлые (40–80 МБ) — искать «optimized»/«FiveM»; Brabus-версии не берём | тяжёлая (~2500 кг), мощная, высокий центр тяжести, валкая в поворотах |
| `kv_m5f90` | BMW M5 F90 | `bmw m5 f90` | Competition подходит | быстрая: 600 л. с., полный привод, 0–100 ~3,5 с |
| `kv_vaz2114` | ВАЗ-2114 | `vaz 2114` | 5-дверный хэтчбек | слабая, лёгкая, мягкая |
| `kv_uaz_dps` | УАЗ Патриот ДПС | `uaz patriot police` | или гражданский УАЗ Патриот + своя ливрея «ДПС Нагорье» | тяжёлый, неторопливый, проходимый |
| `kv_octavia_dps` | Skoda Octavia ДПС | `skoda octavia police` | или гражданская Octavia A7 + ливрея; та же модель пойдёт на `kv_octavia` | средняя, устойчивая |
| `kv_vaz2107` | ВАЗ-2107 «Семёрка» — первая машина новичка (дарит Румиса) | `vaz 2107` | классика, без «бпан»-тюнинга в базе (тюнинг — в СТО) | слабая (~1000 кг, 75 л. с.), задний привод, валкая |

## Остальные
| имя спавна | машина | запрос | handling |
|---|---|---|---|
| `kv_granta` | Lada Granta | `lada granta` | слабая и лёгкая, как Приора |
| `kv_vesta` | Lada Vesta | `lada vesta` | средняя |
| `kv_vesta_dps` | Lada Vesta ДПС | `lada vesta police` (или Vesta + ливрея) | средняя, чуть мощнее гражданской |
| `kv_niva_legend` | Lada Niva Legend (3 двери) | `lada niva` | слабая, короткая, отличная проходимость |
| `kv_niva_travel` | Lada Niva Travel | `niva travel` / `chevrolet niva` | слабая, проходимая |
| `kv_focus2` | Ford Focus 2 | `ford focus 2` | средняя, лёгкая |
| `kv_solaris` | Hyundai Solaris | `hyundai solaris` | слабая, лёгкая |
| `kv_solaris_taxi` | Hyundai Solaris такси | та же модель + ливрея такси (одна модель на две записи не годится — копия под своим именем) | как Солярис |
| `kv_rio` | Kia Rio | `kia rio` | слабая, лёгкая |
| `kv_corolla` | Toyota Corolla | `toyota corolla 2020` | средняя, плавная |
| `kv_octavia` | Skoda Octavia | `skoda octavia a7` | средняя |
| `kv_camry70` | Toyota Camry 70 | `toyota camry 2018` | плавная |
| `kv_mazda6` | Mazda 6 | `mazda 6 2019` | средняя, острый руль |
| `kv_w212` | Mercedes E-класс W212 | `mercedes w212` | плавная, мощная |
| `kv_f10` | BMW 5 F10 | `bmw f10` | быстрая, задний привод |
| `kv_prado150` | Toyota Land Cruiser Prado 150 | `prado 150` | тяжёлая, плавная |
| `kv_lc200` | Toyota Land Cruiser 200 | `land cruiser 200` | тяжёлая, плавная |
| `kv_lx600` | Lexus LX 600 | `lexus lx600` | тяжёлая, мощная, мягкая |
| `kv_rrsport` | Range Rover Sport | `range rover sport 2023` | тяжёлая, быстрая |
| `kv_w223` | Mercedes S-класс W223 | `mercedes w223` | плавная, мощная |
| `kv_maybach` | Mercedes-Maybach S 680 | `maybach s680` | тяжёлая, мягкая, мощная |
| `kv_cayenne` | Porsche Cayenne | `porsche cayenne 2018` | быстрая для своего веса |
| `kv_e36` | BMW E36 (синяя — у Аминат) | `bmw e36` | лёгкая, задний привод, дрифт |
| `kv_e46` | BMW E46 | `bmw e46` | задний привод, дрифт |
| `kv_s15` | Nissan Silvia S15 | `nissan silvia s15` | лёгкая, задний привод, дрифт |
| `kv_gazel_taxi` | ГАЗель маршрутка | `gazel next` | медленная, тяжёлая |
| `kv_gazel_ems` | ГАЗель скорая | `gazel ambulance` | медленная, тяжёлая |
| `kv_liaz` | ЛиАЗ-5292 автобус | `liaz 5292` | автобус |
| `kv_tow` | эвакуатор | `gaz tow truck` / `kamaz evacuator` | грузовик |
| `kv_truck` | КАМАЗ-тягач дальнобойщика | `kamaz 5490` | грузовик |
| `kv_mchs` | пожарный КАМАЗ МЧС | `kamaz fire truck` | грузовик |

Для служебных и рабочих машин отдельная проверка: надписи и номера телефонов на ливреях — **выдуманные** (Нагорье), не настоящие.

## Установленные модели (заполняем по ходу)
Сборка: распаковать `dlc.rpf` — `python -I setup/cars/rpf.py dlc.rpf <папка>`, собрать — `python -I setup/cars/build.py <папка> <имя_спавна> --old <модель мода> --id <база id> --out resources/[cars] [handling]`,
поставить — `powershell -ExecutionPolicy Bypass -File setup\install-cars.ps1`. id тюнинга/фар/сирен: у каждой машины своя база (7710, 7720 … шаг 10).

| имя спавна | мод | автор | вес, МБ | текстуры | id | заметки | дата |
|---|---|---|---|---|---|---|---|
| `kv_camry80` | Camry 2022 GLE | AboM7sn | 26.6 | 2K | 7710 | `_hi` не берём; FiveM: ytd 92 МБ в памяти — тяжёлая | 10.11.2026 |
| `kv_lc300` | Land Cruiser 300 2021 | GCM_mood_cars | 26.6 | 2K | 7720 | цвета чёрный и белый; ytd 70 МБ в памяти | 10.11.2026 |
| `kv_g63` | G63 AMG 2019 | Trgworks | 30.1 | 1920 | 7730 | ytd 60 МБ в памяти | 10.11.2026 |
| `kv_m5f90` | M5 F90 2018 | S4MuEL | 23.6 | 2K | 7740 | детали тюнинга с префиксом kv_m5f90_ | 10.11.2026 |
| `kv_vaz2114` | VAZ-2114 Samara 2 | Leopoldas / AKROM | 12.9 | 2K | 7750 | | 10.11.2026 |
| `kv_vaz2107` | VAZ-2107 Lada Riva | DragoN777 | 31.4 | 1K | 7760 | с тюнингом (каркас, обвесы) | 10.11.2026 |
| `kv_octavia` | Skoda Octavia 2017 | mmods | 9.9 | 2K | 7770 | гражданская; для ДПС нет точек под мигалки | 10.11.2026 |
| `kv_priora` | Lada Priora Hatchback | agen001 | 17.7 | 1K | 7780 | Replace-мод → Add-On, meta по шаблону 2114 | 10.11.2026 |
| `kv_uaz_dps` | UAZ Patriot Police | AKROM | 7.4 | 2912 (одна) | 7790 | meta по шаблону LC300, свои сирены (18 огней) | 10.11.2026 |

Итог по весу: 186 МБ из 5 ГБ (9 машин). Осталось на заглушках: 31.
