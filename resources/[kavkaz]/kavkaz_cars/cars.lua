-- KAVKAZ RP: весь автопарк сервера в одном файле.
-- отсюда читают: автосалон (qbx_vehicleshop), список машин сервера (qbx_core), гаражи полиции и скорой,
-- выдача машин (kavkaz_cars: квест Румисы, организации, админ), номера (kavkaz_plates).
-- поменял файл — перезапусти сервер целиком (qbx_core читает список один раз при старте).
--
-- поля:
--   spawn       уникальное имя спавна настоящей модели (префикс kv_, оригиналы GTA не трогаем)
--   brand, name русское название в салоне и гаражах («Тойота» + «Камри 80»). при жалобе правообладателя меняем здесь за 5 минут
--   price       цена в ₽ (docs/vision/04-cars.md; если там нет — ориентир из задачи)
--   category    раздел салона (Categories ниже)
--   class       класс машины словами
--   stub        встроенная модель GTA, которая ездит вместо машины, пока нет настоящей
--   model       настоящая модель (имя спавна из resources/[cars]/<spawn>), пока nil
--   placeholder true — в игре ездит stub. когда ставим настоящую модель: model = '<spawn>', placeholder = false
--   sale        'shop' — продаётся в салоне, 'quest' — только по квесту, 'job' — выдаёт работа, 'org' — служебная, только организациям
--   org         для 'org': { работа = минимальный ранг } — кому выдаётся в служебном гараже
--   limit       сколько штук всего может быть на сервере (nil — без ограничений)
--   mb, tex     вес модели в МБ и самая большая текстура (заполняем при установке, лимит 25–30 МБ и 2K)
--   source, author, license  откуда модель, автор, лицензия (заполняем при установке, см. docs/vision/19-car-models-todo.md)
--
-- одна встроенная модель = одна наша машина (stub не повторяются): по имени модели салон отличает машины друг от друга.

local Cars = {}

Cars.Categories = {
    narod   = 'Народные',
    foreign = 'Иномарки до 2 млн',
    sedan   = 'Седаны',
    suv     = 'Внедорожники',
    premium = 'Премиум',
    electro = 'Электромобили',
    super   = 'Суперкары',
    drift   = 'Дрифт и тусовка',
    work    = 'Рабочие',
    service = 'Служебные',
}

Cars.List = {
    ---------------------------------------------------------------- народные
    { spawn = 'kv_vaz2107', brand = 'ВАЗ', name = '2107 «Семёрка»', price = 120000, category = 'narod', class = 'старт, классика',
      stub = 'emperor', model = 'kv_vaz2107', placeholder = false,
      mb = 31.4, tex = '1K', source = 'https://www.gta5-mods.com/vehicles/vaz-2107-lada-riva-add-on-tuning', author = 'DragoN777, Sashka_Bro', license = 'FiveM не запрещён', sale = 'quest' }, -- первая машина новичка, выдаёт Румиса
    { spawn = 'kv_vaz2114', brand = 'ВАЗ', name = '2114 «Четырка»', price = 190000, category = 'narod', class = 'старт, хэтчбек',
      stub = 'blista', model = 'kv_vaz2114', placeholder = false,
      mb = 12.9, tex = '2K', source = 'https://www.gta5-mods.com/vehicles/vaz-2114-lada-samara-2-add-on', author = 'Leopoldas, модель AKROM', license = 'FiveM не запрещён', sale = 'shop' },
    { spawn = 'kv_priora', brand = 'Лада', name = 'Приора хэтчбек', price = 350000, category = 'narod', class = 'легенда, тонировка и музыка',
      stub = 'club', model = 'kv_priora', placeholder = false,
      mb = 17.7, tex = '1K', source = 'https://www.gta5-mods.com/vehicles/lada-priora-hatchback', author = 'agen001 (agens)', license = 'FiveM не запрещён; meta по шаблону 2114', sale = 'shop' },
    { spawn = 'kv_vaz2109', brand = 'ВАЗ', name = '2109 «Девятка»', price = 150000, category = 'narod', class = 'старт, зубило',
      stub = 'warrener', model = 'kv_vaz2109', placeholder = false,
      mb = 19.8, tex = '2K', source = 'https://www.gta5-mods.com/vehicles/vaz-2109-and-vaz-2110-by-akrom-add-on', author = 'AKROM', license = 'FiveM не запрещён; без деталей тюнинга (вес)', sale = 'shop' },
    { spawn = 'kv_vaz2110', brand = 'ВАЗ', name = '2110 «Десятка»', price = 220000, category = 'narod', class = 'старт, седан',
      stub = 'glendale', model = 'kv_vaz2110', placeholder = false,
      mb = 27.2, tex = '2K', source = 'https://www.gta5-mods.com/vehicles/vaz-2109-and-vaz-2110-by-akrom-add-on', author = 'AKROM', license = 'FiveM не запрещён; без деталей тюнинга (вес)', sale = 'shop' },
    { spawn = 'kv_largus', brand = 'Лада', name = 'Ларгус', price = 1600000, category = 'narod', class = 'семейный универсал, 7 мест',
      stub = 'minivan', model = 'kv_largus', placeholder = false,
      mb = 11.5, tex = '2K (ужато)', source = 'https://www.gta5-mods.com/vehicles/2024-lada-largus-2-add-on-plates-extras-livery-template', author = 'LxstFxme', license = 'шаблон ливреи', sale = 'shop' },
    { spawn = 'kv_granta', brand = 'Лада', name = 'Гранта', price = 650000, category = 'narod', class = 'эконом, такси',
      stub = 'premier', model = 'kv_granta', placeholder = false,
      mb = 15.1, tex = '2K (ужато)', source = 'https://www.gta5-mods.com/vehicles/2018-lada-granta-fl-add-on-extras-livery-template', author = 'LxstFxme', license = 'шаблон ливреи, есть «Яндекс Такси»', sale = 'shop' },
    { spawn = 'kv_vesta', brand = 'Лада', name = 'Веста', price = 1300000, category = 'narod', class = 'средний седан',
      stub = 'primo', model = 'kv_vesta', placeholder = false,
      mb = 21.4, tex = '1K', source = 'https://www.gta5-mods.com/vehicles/2016-lada-vesta', author = 'Reshiramman', license = 'Add-On', sale = 'shop' },
    { spawn = 'kv_gazel', brand = 'ГАЗ', name = 'Газель Next', price = 2200000, category = 'narod', class = 'фургон, бизнес и переезды',
      stub = 'speedo', model = 'kv_gazel', placeholder = false,
      mb = 21.8, tex = '2K (ужато)', source = 'https://www.gta5-mods.com/vehicles/gazel-next', author = 'AlbertoM93', license = 'Add-On', sale = 'shop' },
    { spawn = 'kv_niva_legend', brand = 'Лада', name = 'Нива Легенд', price = 800000, category = 'narod', class = 'горы, внедорожник',
      stub = 'bjxl', model = nil, placeholder = true, sale = 'shop' },

    ---------------------------------------------------------------- иномарки до 2 млн
    { spawn = 'kv_focus2', brand = 'Форд', name = 'Фокус 2', price = 450000, category = 'foreign', class = 'народная иномарка',
      stub = 'asterope', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_focus3', brand = 'Форд', name = 'Фокус 3', price = 600000, category = 'foreign', class = 'народная иномарка',
      stub = 'washington', model = 'kv_focus3', placeholder = false,
      mb = 9.1, tex = '1K', source = 'архив 2014 Ford Focus 3 Sedan v1.2 (скачал основатель)', author = 'Saveliev', license = 'Add-On', sale = 'shop' },
    { spawn = 'kv_logan', brand = 'Рено', name = 'Логан', price = 750000, category = 'foreign', class = 'эконом, такси',
      stub = 'stanier', model = 'kv_logan', placeholder = false,
      mb = 10.5, tex = '1K', source = 'https://www.gta5-mods.com/vehicles/dacia-logan-renault-tondar-90-l90', author = 'gtafnedit', license = 'Add-On', sale = 'shop' },
    { spawn = 'kv_mondeo', brand = 'Форд', name = 'Мондео', price = 1500000, category = 'foreign', class = 'большой седан',
      stub = 'oracle', model = 'kv_mondeo', placeholder = false,
      mb = 25.0, tex = '1K', source = 'https://www.gta5-mods.com/vehicles/2016-2017-ford-mondeo-saloon', author = 'BritishGamer88', license = 'Replace-мод, переделан в Add-On; meta от Камри 70', sale = 'shop' },
    { spawn = 'kv_solaris', brand = 'Хёндай', name = 'Солярис', price = 850000, category = 'foreign', class = 'эконом-седан',
      stub = 'intruder', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_rio', brand = 'Киа', name = 'Рио', price = 900000, category = 'foreign', class = 'эконом-седан',
      stub = 'surge', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_corolla', brand = 'Тойота', name = 'Королла', price = 1600000, category = 'foreign', class = 'надёжный седан',
      stub = 'fugitive', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_octavia', brand = 'Шкода', name = 'Октавия', price = 1500000, category = 'foreign', class = 'семейный лифтбек',
      stub = 'tailgater', model = 'kv_octavia', placeholder = false,
      mb = 9.9, tex = '2K', source = 'https://www.gta5-mods.com/vehicles/2017-skoda-octavia-add-on-replace-dirt-map', author = 'mmods', license = 'FiveM не запрещён', sale = 'shop' },

    ---------------------------------------------------------------- седаны
    { spawn = 'kv_camry70', brand = 'Тойота', name = 'Камри 70', price = 3000000, category = 'sedan', class = 'бизнес, мечта на проспекте',
      stub = 'tailgater2', model = 'kv_camry70', placeholder = false,
      mb = 26.6, tex = '2K', source = 'https://www.gta5-mods.com/vehicles/toyota-camry-2022-gle-replace-unlocked-exrtas', author = 'AboM7sn', license = 'unlocked, правки разрешены; Camry 2022 (рестайлинг XV70)', sale = 'shop' },
    { spawn = 'kv_camry80', brand = 'Тойота', name = 'Камри 80', price = 4500000, category = 'sedan', class = 'бизнес, новинка',
      stub = 'cinquemila', model = 'kv_camry80', placeholder = false,
      mb = 28.2, tex = '2K', source = 'архив toyota-camry-xv80-llhprod (скачал основатель)', author = 'llhprod', license = 'Replace-мод, переделан в Add-On; meta от Камри 70', sale = 'shop' },
    { spawn = 'kv_camry40', brand = 'Тойота', name = 'Камри 40', price = 1300000, category = 'sedan', class = 'народный бизнес-класс',
      stub = 'fusilade', model = 'kv_camry40', placeholder = false,
      mb = 13.2, tex = '2K', source = 'архив 2009 Toyota camry GLX (скачал основатель 11.11)', author = 'см. архив', license = 'Replace-мод (premier), переделан в Add-On; meta от Камри 70', sale = 'shop' },
    { spawn = 'kv_v70', brand = 'Вольво', name = 'V70', price = 1100000, category = 'foreign', class = 'универсал',
      stub = 'dilettante', model = 'kv_v70', placeholder = false,
      mb = 27.5, tex = '2K (видеопамять ужата 81 -> 20 МБ)', source = 'архив V70_S-edition (скачал основатель 11.11)', author = 'см. Readme в архиве', license = 'Replace-мод (dilettante), переделан в Add-On; meta от Мондео', sale = 'shop' },
    { spawn = 'kv_mazda6', brand = 'Мазда', name = '6', price = 2400000, category = 'sedan', class = 'седан D-класса',
      stub = 'rhinehart', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_w212', brand = 'Мерседес', name = 'E-класс W212', price = 3500000, category = 'sedan', class = 'бизнес',
      stub = 'schafter2', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_f10', brand = 'БМВ', name = '5 F10', price = 3800000, category = 'sedan', class = 'бизнес',
      stub = 'oracle2', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_m5f90', brand = 'БМВ', name = 'M5 F90', price = 11000000, category = 'sedan', class = 'быстрый бизнес-седан',
      stub = 'schafter3', model = 'kv_m5f90', placeholder = false,
      mb = 23.6, tex = '2K', source = 'https://www.gta5-mods.com/vehicles/bmw-m5-f90-2018-add-on-hq-template', author = 'S4MuEL', license = 'FiveM не запрещён', sale = 'shop' },

    ---------------------------------------------------------------- внедорожники
    { spawn = 'kv_niva_travel', brand = 'Лада', name = 'Нива Тревел', price = 1200000, category = 'suv', class = 'горы',
      stub = 'seminole', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_prado150', brand = 'Тойота', name = 'Ленд Крузер Прадо 150', price = 5000000, category = 'suv', class = 'рамный внедорожник',
      stub = 'landstalker2', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_lc200', brand = 'Тойота', name = 'Ленд Крузер 200', price = 7000000, category = 'suv', class = 'большой внедорожник',
      stub = 'cavalcade2', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_lc300', brand = 'Тойота', name = 'Ленд Крузер 300', price = 12000000, category = 'suv', class = 'большой внедорожник',
      stub = 'granger2', model = 'kv_lc300', placeholder = false,
      mb = 26.6, tex = '2K', source = 'https://www.gta5-mods.com/vehicles/toyota-land-cruiser-300-2021-add-on', author = 'GCM_mood_cars (A.M.N MOOD)', license = 'FiveM не запрещён', sale = 'shop',
      colors = { 0, 111 } }, -- в лаунчере чёрный и белый: цвета по умолчанию для carvariations.meta (0 чёрный, 111 белый)
    { spawn = 'kv_lx600', brand = 'Лексус', name = 'LX 600', price = 16000000, category = 'suv', class = 'люкс-внедорожник',
      stub = 'xls', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_rrsport', brand = 'Рендж Ровер', name = 'Спорт', price = 11000000, category = 'suv', class = 'люкс-внедорожник',
      stub = 'baller3', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_g63', brand = 'Мерседес', name = 'G 63 «Гелик»', price = 25000000, category = 'suv', class = 'король проспекта, редкость',
      stub = 'dubsta', model = 'kv_g63', placeholder = false,
      mb = 32.0, tex = '1K (ужато с 4K)', source = 'https://www.gta5-mods.com/vehicles/2019-mercedes-benz-amg-g-63', author = 'Topcar-Design', license = 'широкий W464 по просьбе основателя; чуть больше лимита 30 МБ', sale = 'shop', limit = 20 },

    ---------------------------------------------------------------- премиум
    { spawn = 'kv_w223', brand = 'Мерседес', name = 'S-класс W223', price = 14000000, category = 'premium', class = 'представительский',
      stub = 'cog55', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_maybach', brand = 'Мерседес', name = 'Майбах S', price = 30000000, category = 'premium', class = 'представительский люкс',
      stub = 'deity', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_cullinan', brand = 'Роллс-Ройс', name = 'Куллинан', price = 45000000, category = 'premium', class = 'самый дорогой внедорожник',
      stub = 'baller4', model = 'kv_cullinan', placeholder = false,
      mb = 24.7, tex = '2K (видеопамять ужата 78 -> 20 МБ)', source = 'архив 2026 Rolls-Royce Cullinan HAMMER (скачал основатель 11.11)', author = 'HAMMER', license = 'Add-On, Legacy-версия', sale = 'shop', limit = 10 },
    { spawn = 'kv_urus', brand = 'Ламборгини', name = 'Урус SE', price = 32000000, category = 'premium', class = 'суперкроссовер',
      stub = 'toros', model = 'kv_urus', placeholder = false,
      mb = 18.2, tex = '2K (видеопамять ужата 68 -> 20 МБ)', source = 'архив 2025 Lamborghini Urus SE (скачал основатель 11.11)', author = 'LegEnh, модели со Sketchfab', license = 'Add-On, Legacy-версия', sale = 'shop', limit = 10 },
    { spawn = 'kv_m4', brand = 'БМВ', name = 'M4 Widebody', price = 13000000, category = 'premium', class = 'спорткупе',
      stub = 'zion3', model = 'kv_m4', placeholder = false,
      mb = 24.7, tex = '2K (видеопамять ужата 82 -> 16 МБ)', source = 'архив BMW M4 Modified Widebody HAMMER (скачал основатель 11.11)', author = 'HAMMER', license = 'Add-On, Legacy-версия', sale = 'shop' },
    { spawn = 'kv_cayenne', brand = 'Порше', name = 'Кайен', price = 10000000, category = 'premium', class = 'спортивный кроссовер',
      stub = 'novak', model = nil, placeholder = true, sale = 'shop' },

    ---------------------------------------------------------------- электромобили
    { spawn = 'kv_zeekr001', brand = 'Зикр', name = '001', price = 6000000, category = 'electro', class = 'электро-лифтбек',
      stub = 'iwagen', model = 'kv_zeekr001', placeholder = false,
      mb = 20.6, tex = '2K', source = 'https://www.gta5-mods.com/vehicles/2023-zeekr-001-add-on-fivem', author = 'Akkariin', license = 'FiveM-версия от автора', sale = 'shop' },
    { spawn = 'kv_roadster', brand = 'Тесла', name = 'Родстер', price = 25000000, category = 'electro', class = 'электро-суперкар',
      stub = 'neon', model = 'kv_roadster', placeholder = false,
      mb = 19.3, tex = '2K (ужато)', source = 'архив Tesla Roadster 2020 (скачал основатель)', author = 'неизвестен', license = 'Add-On', sale = 'shop', limit = 5 },
    { spawn = 'kv_cybertruck', brand = 'Тесла', name = 'Кибертрак', price = 12000000, category = 'electro', class = 'электро-пикап',
      stub = 'sandking2', model = 'kv_cybertruck', placeholder = false,
      mb = 6.3, tex = '2K (ужато)', source = 'архив Tesla Cybertruck 1.2 (скачал основатель)', author = 'неизвестен', license = 'Replace-мод, переделан в Add-On; meta от Крузака 300', sale = 'shop', limit = 10 },

    ---------------------------------------------------------------- суперкары
    { spawn = 'kv_chiron', brand = 'Бугатти', name = 'Широн Мансори', price = 250000000, category = 'super', class = 'гиперкар, единицы на республику',
      stub = 'zentorno', model = 'kv_chiron', placeholder = false,
      mb = 24.9, tex = '2K', source = 'архив Bugatti Chiron Mansory HAMMER (скачал основатель)', author = 'неизвестен', license = 'Add-On', sale = 'shop', limit = 3 },
    { spawn = 'kv_jesko', brand = 'Кёнигсегг', name = 'Еско', price = 200000000, category = 'super', class = 'гиперкар, единицы на республику',
      stub = 't20', model = 'kv_jesko', placeholder = false,
      mb = 31.6, tex = '1K (ужато)', source = 'архив Jesko 2020 (скачал основатель)', author = 'неизвестен', license = 'Add-On; второй вариант кузова убран (вес)', sale = 'shop', limit = 3 },

    ---------------------------------------------------------------- дрифт и тусовка
    { spawn = 'kv_e36', brand = 'БМВ', name = 'E36', price = 500000, category = 'drift', class = 'дрифт', -- синяя E36 у Аминат
      stub = 'sentinel3', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_e46', brand = 'БМВ', name = 'E46', price = 700000, category = 'drift', class = 'дрифт',
      stub = 'sentinel', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_s15', brand = 'Ниссан', name = 'Сильвия S15', price = 1800000, category = 'drift', class = 'дрифт, японская классика',
      stub = 'remus', model = nil, placeholder = true, sale = 'shop' },

    ---------------------------------------------------------------- рабочие (выдаёт работа)
    { spawn = 'kv_gazel_taxi', brand = 'ГАЗ', name = 'Газель маршрутка', price = 1800000, category = 'work', class = 'такси-фургон',
      stub = 'rumpo', model = nil, placeholder = true, sale = 'job' },
    { spawn = 'kv_solaris_taxi', brand = 'Хёндай', name = 'Солярис такси', price = 850000, category = 'work', class = 'такси',
      stub = 'taxi', model = nil, placeholder = true, sale = 'job' },
    { spawn = 'kv_liaz', brand = 'Нагорсктранс', name = 'городской автобус', price = 0, category = 'work', class = 'городской автобус',
      stub = 'bus', model = 'kv_liaz', placeholder = false,
      mb = 7.1, tex = '2K (ужато)', source = 'архив design-x4 (скачал основатель)', author = 'неизвестен', license = 'двухэтажный городской автобус', sale = 'job' },
    { spawn = 'kv_tow', brand = 'ГАЗ', name = 'эвакуатор', price = 0, category = 'work', class = 'эвакуатор',
      stub = 'flatbed', model = nil, placeholder = true, sale = 'job' },
    { spawn = 'kv_truck', brand = 'КАМАЗ', name = 'тягач дальнобойщика', price = 0, category = 'work', class = 'грузовик',
      stub = 'phantom', model = nil, placeholder = true, sale = 'job' },

    ---------------------------------------------------------------- служебные (не продаются)
    { spawn = 'kv_2114_dps', brand = 'Лада', name = '2114 ДПС', price = 0, category = 'service', class = 'ДПС, патруль в городе',
      stub = 'police4', model = 'kv_2114_dps', placeholder = false,
      mb = 11.1, tex = '2K (видеопамять ужата 26 -> 15 МБ)', source = 'https://www.gta5-mods.com/vehicles/vaz-2114-2115-lada-police-add-on', author = 'AKROM', license = 'Add-On (ladapol), переименован', sale = 'org', org = { police = 0, sasp = 0 }, plate = 'ru_police' },
    { spawn = 'kv_uaz_dps', brand = 'УАЗ', name = 'Патриот ДПС', price = 0, category = 'service', class = 'ДПС, внедорожник',
      stub = 'sheriff2', model = 'kv_uaz_dps', placeholder = false,
      mb = 7.4, tex = '2912', source = 'https://www.gta5-mods.com/vehicles/uaz-patriot-police', author = 'AKROM', license = 'FiveM не запрещён; meta по шаблону LC300, сирены свои', sale = 'org', org = { police = 0, sasp = 0 }, plate = 'ru_police' },
    { spawn = 'kv_octavia_dps', brand = 'Шкода', name = 'Октавия ДПС', price = 0, category = 'service', class = 'ДПС, патруль',
      stub = 'police', model = nil, placeholder = true, sale = 'org', org = { police = 0, sasp = 0 }, plate = 'ru_police' },
    { spawn = 'kv_vesta_dps', brand = 'Лада', name = 'Веста ДПС', price = 0, category = 'service', class = 'ДПС, патруль',
      stub = 'police3', model = nil, placeholder = true, sale = 'org', org = { police = 0, sasp = 0 }, plate = 'ru_police' },
    { spawn = 'kv_fsb_van', brand = 'Форд', name = 'Транзит ФСБ', price = 0, category = 'service', class = 'ФСБ, оперативный фургон',
      stub = 'policet', model = nil, placeholder = true, sale = 'org', org = { fsb = 0 },
      source = 'замена policet: Ford Transit CRS + раскраска «ФСБ России» (kv_peds)' },
    { spawn = 'kv_gazel_ems', brand = 'ГАЗ', name = 'Газель скорая', price = 0, category = 'service', class = 'скорая помощь',
      stub = 'ambulance', model = nil, placeholder = true, sale = 'org', org = { ambulance = 0 } },
    { spawn = 'kv_mchs', brand = 'КАМАЗ', name = 'пожарный МЧС', price = 0, category = 'service', class = 'МЧС',
      stub = 'firetruk', model = nil, placeholder = true, sale = 'org', org = { fire = 0, mchs = 0 } },
}

-- модель, которая сейчас ездит в игре: настоящая, если поставлена, иначе заглушка
function Cars.current(car)
    if car.model and not car.placeholder then return car.model end
    return car.stub
end

return Cars
