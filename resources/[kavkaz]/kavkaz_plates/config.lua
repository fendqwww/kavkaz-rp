Config = {}

-- МРЭО ГИБДД. здания пока нет: окно стоит у мэрии Рокфорд-Хиллз. когда поставим своё MLO — меняем только координаты.
Config.Office = {
    label = 'МРЭО ГИБДД',
    ped = { model = 'a_f_y_business_02', coords = vec4(-545.08, -204.13, 38.22, 210.0) },
    radius = 4.0,          -- игрок должен стоять у окна
    vehicleRadius = 60.0,  -- выгнанная машина должна стоять рядом с МРЭО (или в гараже)
    blip = { sprite = 498, color = 3, scale = 0.8 },
}

-- регионы (docs/vision/04-cars.md). 95 — Нагорск, основной.
Config.Regions = {
    { code = '95', label = '95 — Нагорск' },
    { code = '20', label = '20 — «старые» (машины старше 20 лет)' },
    { code = '05', label = '05 — соседняя республика' },
    { code = '06', label = '06 — соседняя республика' },
    { code = '07', label = '07 — соседняя республика' },
    { code = '15', label = '15 — соседняя республика' },
    { code = '26', label = '26 — соседний край' },
}
Config.DefaultRegion = '95'

Config.Prices = {
    window = 7000,     -- случайный номер в окне МРЭО (NPC)
    choose = 25000,    -- выбрать из 5 вариантов
    dps = 3000,        -- выдача игроком-ДПС
    dpsShare = 1000,   -- из них сотруднику ДПС
    swap = 2000,       -- перевесить номер на другую свою машину
    commission = 0.05, -- комиссия при продаже номера другому игроку
    foreign = 50000,   -- номер другой страны (машина «на учёте за границей»)
}

-- виды номеров. sale: 'window' — продаётся всем в МРЭО, 'foreign' — иностранный (дороже), 'job' — только своим работам.
-- index — какой фон номера ставить машине в GTA (SetVehicleNumberPlateTextIndex): 0 белый, 1 жёлтый/чёрный,
-- 2 жёлтый/синий, 3 и 4 белые варианты. с модом текстур номеров (см. README) индексы заменяются на наши фоны.
Config.Styles = {
    { id = 'ru',        label = 'Россия',           sale = 'window',  index = 0 },
    { id = 'ru_taxi',   label = 'Такси (жёлтый)',   sale = 'job', jobs = { taxi = 0, bus = 0 }, index = 1 },
    { id = 'ru_police', label = 'Полиция (синий)',  sale = 'job', jobs = { police = 0, sheriff = 0 }, index = 4 },
    { id = 'ru_army',   label = 'Военный (чёрный)', sale = 'job', jobs = { army = 0 }, index = 3 },
    { id = 'kz',        label = 'Казахстан',        sale = 'foreign', index = 0 },
    { id = 'by',        label = 'Беларусь',         sale = 'foreign', index = 0 },
    { id = 'am',        label = 'Армения',          sale = 'foreign', index = 0 },
    { id = 'ge',        label = 'Грузия',           sale = 'foreign', index = 0 },
    { id = 'az',        label = 'Азербайджан',      sale = 'foreign', index = 0 },
}

-- рамки номера (пластик вокруг знака с надписью снизу). jobs — только для сотрудников, price — цена в МРЭО.
-- свою надпись ставит админ: /setframe
-- color — цвет пластика рамки, textColor — цвет надписи
Config.Frames = {
    { id = 'none',      label = 'Без рамки', price = 0 },
    -- обычные
    { id = 'black',     label = 'Чёрная без надписи',            text = ' ', price = 500 },
    { id = 'chrome',    label = 'Хром «Нагорск»',                text = 'НАГОРСК', color = '#c7ccd2', textColor = '#1d232a', price = 2500 },
    { id = 'republic',  label = 'Республика Нагорье',            text = 'РЕСПУБЛИКА НАГОРЬЕ · 95', price = 1500 },
    { id = 'lamyurt',   label = 'Лам-Юрт',                       text = 'ЛАМ-ЮРТ', price = 1500 },
    { id = 'sedayurt',  label = 'Седа-Юрт',                      text = 'СЕДА-ЮРТ', price = 1500 },
    { id = 'mountains', label = 'Горы зовут',                    text = 'ГОРЫ ЗОВУТ', color = '#1e3a2a', textColor = '#e8f1ea', price = 2000 },
    -- дилеры и автосервисы
    { id = 'dealer',    label = 'Нагорье Моторс (дилер)',        text = 'НАГОРЬЕ МОТОРС', price = 1500 },
    { id = 'market',    label = 'Авторынок Ахмеда-Падишаха',     text = 'АВТОРЫНОК · АХМЕД-ПАДИШАХ', textColor = '#d9b44a', price = 2000 },
    { id = 'bislan',    label = 'Гараж Бислана',                 text = 'ГАРАЖ БИСЛАНА', textColor = '#ff5a4e', price = 2000 },
    { id = 'borz',      label = 'Борз Тюнинг',                   text = 'БОРЗ ТЮНИНГ', textColor = '#7fd3ff', price = 2000 },
    -- праздник
    { id = 'lovzar',    label = 'Ловзар (свадебная, белая)',     text = 'ЛОВЗАР', color = '#f3f1ec', textColor = '#a9822c', price = 3000 },
    { id = 'gold',      label = 'Золотая',                       text = 'НАГОРЬЕ', color = '#1a1712', textColor = '#d4af37', price = 10000 },
    -- служебные (только своим работам)
    { id = 'taxi',      label = 'Такси (только таксистам)',      text = 'ТАКСИ НАГОРЬЕ', color = '#f5c400', textColor = '#111111', price = 0, jobs = { taxi = 0 } },
    { id = 'ems',       label = 'Скорая (только медикам)',       text = 'СКОРАЯ МЕДИЦИНСКАЯ ПОМОЩЬ', color = '#f4f4f4', textColor = '#d32f2f', price = 0, jobs = { ambulance = 0 } },
    { id = 'mchs',      label = 'МЧС (только сотрудникам)',      text = 'МЧС РОССИИ', color = '#1d3d8f', textColor = '#ffffff', price = 0, jobs = { fire = 0, mchs = 0 } },
    { id = 'mvd',       label = 'МВД (только сотрудникам)',      text = 'МВД ПО РЕСПУБЛИКЕ НАГОРЬЕ', price = 0, jobs = { police = 0, sheriff = 0 } },
    { id = 'fsb',       label = 'ФСБ (только сотрудникам)',      text = 'ФЕДЕРАЛЬНАЯ СЛУЖБА БЕЗОПАСНОСТИ', price = 0, jobs = { fsb = 0 } },
    { id = 'fso',       label = 'ФСО (только сотрудникам)',      text = 'ФСО РОССИИ', price = 0, jobs = { fso = 0 } },
}

-- документы: без паспорта номер не выдают. предмет из qbx_idcard (выдаётся новичку) и паспорт, если появится свой.
-- паспорт должен быть свой (citizenid в метаданных совпадает с персонажем).
Config.Documents = { 'id_card', 'passport' }

-- «случайный регион» при получении номера: из каких регионов выбирать (у «20» и соседних — меньше шанс)
Config.RandomRegions = { ['95'] = 70, ['05'] = 6, ['06'] = 6, ['07'] = 6, ['15'] = 6, ['26'] = 6 }

-- красивые номера не выпадают случайно: только аукцион, ивенты и админы (/setplate)
Config.Tiers = {
    kra     = { label = 'серия «КРА»', start = 10000000 }, -- К *** РА 95, например К 013 РА 95
    blat    = { label = 'полный блат', start = 5000000 },
    zero    = { label = '«нулевые» 001–009', start = 1500000 },
    region  = { label = 'регион «095»', start = 700000 },
    triple  = { label = 'тройки', start = 500000 },
    letters = { label = 'одинаковые буквы', start = 100000 },
}

-- кто может выдавать номера и пробивать по базе (имена работ qbx_core)
Config.PoliceJobs = { police = 0, sheriff = 0, sasp = 0 } -- sasp = ГИБДД / полк ДПС -- работа = минимальный ранг
Config.DpsDistance = 6.0

-- уровень админа для /setplate (kavkaz_admin)
Config.AdminLevel = 4

-- сколько минут держатся 5 предложенных вариантов
Config.ChoiceMinutes = 5
