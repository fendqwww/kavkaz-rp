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
    drift   = 'Дрифт и тусовка',
    work    = 'Рабочие',
    service = 'Служебные',
}

Cars.List = {
    ---------------------------------------------------------------- народные
    { spawn = 'kv_vaz2107', brand = 'ВАЗ', name = '2107 «Семёрка»', price = 120000, category = 'narod', class = 'старт, классика',
      stub = 'emperor', model = nil, placeholder = true, sale = 'quest' }, -- первая машина новичка, выдаёт Румиса
    { spawn = 'kv_vaz2114', brand = 'ВАЗ', name = '2114 «Четырка»', price = 190000, category = 'narod', class = 'старт, хэтчбек',
      stub = 'blista', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_priora', brand = 'Лада', name = 'Приора хэтчбек', price = 350000, category = 'narod', class = 'легенда, тонировка и музыка',
      stub = 'club', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_granta', brand = 'Лада', name = 'Гранта', price = 650000, category = 'narod', class = 'эконом, такси',
      stub = 'premier', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_vesta', brand = 'Лада', name = 'Веста', price = 1300000, category = 'narod', class = 'средний седан',
      stub = 'primo', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_niva_legend', brand = 'Лада', name = 'Нива Легенд', price = 800000, category = 'narod', class = 'горы, внедорожник',
      stub = 'bjxl', model = nil, placeholder = true, sale = 'shop' },

    ---------------------------------------------------------------- иномарки до 2 млн
    { spawn = 'kv_focus2', brand = 'Форд', name = 'Фокус 2', price = 450000, category = 'foreign', class = 'народная иномарка',
      stub = 'asterope', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_solaris', brand = 'Хёндай', name = 'Солярис', price = 850000, category = 'foreign', class = 'эконом-седан',
      stub = 'intruder', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_rio', brand = 'Киа', name = 'Рио', price = 900000, category = 'foreign', class = 'эконом-седан',
      stub = 'surge', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_corolla', brand = 'Тойота', name = 'Королла', price = 1600000, category = 'foreign', class = 'надёжный седан',
      stub = 'fugitive', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_octavia', brand = 'Шкода', name = 'Октавия', price = 1500000, category = 'foreign', class = 'семейный лифтбек',
      stub = 'tailgater', model = nil, placeholder = true, sale = 'shop' },

    ---------------------------------------------------------------- седаны
    { spawn = 'kv_camry70', brand = 'Тойота', name = 'Камри 70', price = 3000000, category = 'sedan', class = 'бизнес, мечта на проспекте',
      stub = 'tailgater2', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_camry80', brand = 'Тойота', name = 'Камри 80', price = 4500000, category = 'sedan', class = 'бизнес, новинка',
      stub = 'cinquemila', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_mazda6', brand = 'Мазда', name = '6', price = 2400000, category = 'sedan', class = 'седан D-класса',
      stub = 'rhinehart', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_w212', brand = 'Мерседес', name = 'E-класс W212', price = 3500000, category = 'sedan', class = 'бизнес',
      stub = 'schafter2', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_f10', brand = 'БМВ', name = '5 F10', price = 3800000, category = 'sedan', class = 'бизнес',
      stub = 'oracle2', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_m5f90', brand = 'БМВ', name = 'M5 F90', price = 11000000, category = 'sedan', class = 'быстрый бизнес-седан',
      stub = 'schafter3', model = nil, placeholder = true, sale = 'shop' },

    ---------------------------------------------------------------- внедорожники
    { spawn = 'kv_niva_travel', brand = 'Лада', name = 'Нива Тревел', price = 1200000, category = 'suv', class = 'горы',
      stub = 'seminole', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_prado150', brand = 'Тойота', name = 'Ленд Крузер Прадо 150', price = 5000000, category = 'suv', class = 'рамный внедорожник',
      stub = 'landstalker2', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_lc200', brand = 'Тойота', name = 'Ленд Крузер 200', price = 7000000, category = 'suv', class = 'большой внедорожник',
      stub = 'cavalcade2', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_lc300', brand = 'Тойота', name = 'Ленд Крузер 300', price = 12000000, category = 'suv', class = 'большой внедорожник',
      stub = 'granger2', model = nil, placeholder = true, sale = 'shop',
      colors = { 0, 111 } }, -- в лаунчере чёрный и белый: цвета по умолчанию для carvariations.meta (0 чёрный, 111 белый)
    { spawn = 'kv_lx600', brand = 'Лексус', name = 'LX 600', price = 16000000, category = 'suv', class = 'люкс-внедорожник',
      stub = 'xls', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_rrsport', brand = 'Рендж Ровер', name = 'Спорт', price = 11000000, category = 'suv', class = 'люкс-внедорожник',
      stub = 'baller3', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_g63', brand = 'Мерседес', name = 'G 63 «Гелик»', price = 25000000, category = 'suv', class = 'король проспекта, редкость',
      stub = 'dubsta', model = nil, placeholder = true, sale = 'shop', limit = 20 },

    ---------------------------------------------------------------- премиум
    { spawn = 'kv_w223', brand = 'Мерседес', name = 'S-класс W223', price = 14000000, category = 'premium', class = 'представительский',
      stub = 'cog55', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_maybach', brand = 'Мерседес', name = 'Майбах S', price = 30000000, category = 'premium', class = 'представительский люкс',
      stub = 'deity', model = nil, placeholder = true, sale = 'shop' },
    { spawn = 'kv_cayenne', brand = 'Порше', name = 'Кайен', price = 10000000, category = 'premium', class = 'спортивный кроссовер',
      stub = 'novak', model = nil, placeholder = true, sale = 'shop' },

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
    { spawn = 'kv_liaz', brand = 'ЛиАЗ', name = 'автобус', price = 0, category = 'work', class = 'городской автобус',
      stub = 'bus', model = nil, placeholder = true, sale = 'job' },
    { spawn = 'kv_tow', brand = 'ГАЗ', name = 'эвакуатор', price = 0, category = 'work', class = 'эвакуатор',
      stub = 'flatbed', model = nil, placeholder = true, sale = 'job' },
    { spawn = 'kv_truck', brand = 'КАМАЗ', name = 'тягач дальнобойщика', price = 0, category = 'work', class = 'грузовик',
      stub = 'phantom', model = nil, placeholder = true, sale = 'job' },

    ---------------------------------------------------------------- служебные (не продаются)
    { spawn = 'kv_uaz_dps', brand = 'УАЗ', name = 'Патриот ДПС', price = 0, category = 'service', class = 'ДПС, внедорожник',
      stub = 'sheriff2', model = nil, placeholder = true, sale = 'org', org = { police = 0, sasp = 0 }, plate = 'ru_police' },
    { spawn = 'kv_octavia_dps', brand = 'Шкода', name = 'Октавия ДПС', price = 0, category = 'service', class = 'ДПС, патруль',
      stub = 'police', model = nil, placeholder = true, sale = 'org', org = { police = 0, sasp = 0 }, plate = 'ru_police' },
    { spawn = 'kv_vesta_dps', brand = 'Лада', name = 'Веста ДПС', price = 0, category = 'service', class = 'ДПС, патруль',
      stub = 'police3', model = nil, placeholder = true, sale = 'org', org = { police = 0, sasp = 0 }, plate = 'ru_police' },
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
