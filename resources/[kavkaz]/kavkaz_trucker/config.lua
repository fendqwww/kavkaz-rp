-- KAVKAZ RP: дальнобой. все числа здесь; логика денег — server.lua.
Config = {}

-- автобаза в порту. координаты ангара и выдачи грузовиков взяты из qbx_truckerjob (там проверены).
-- сверить: стандартный qbx_truckerjob стоит в 5 м — если он включён, его маркер рядом с нашим инспектором.
Config.Depot = {
    label = 'Автобаза «Нагорск-Транс»',
    ped = { model = 's_m_m_trucker_01', coords = vec4(149.6, -3214.6, 5.9, 274.5) }, -- сверить
    truckSpawn = vec4(141.12, -3204.31, 5.85, 267.5),
    talk = 3.0,          -- с какого расстояния говорить с диспетчером
    reuseTruck = 80.0,   -- свой тягач ближе этого к базе — новый не выдаём
    blip = { sprite = 477, color = 5 },
}

-- тягач: имя из kavkaz_cars/cars.lua (пока заглушка phantom, модель берётся оттуда же)
Config.Truck = 'kv_truck'
Config.TruckFallback = 'phantom'

-- уровни водителя: опыт = км × множитель груза × 10
Config.Levels = {
    { xp = 0,    maxKm = 6.5, label = 'стажёр' },
    { xp = 120,  maxKm = 9.0, label = 'водитель' },
    { xp = 400,  maxKm = 12.0, label = 'опытный водитель' },
    { xp = 900,  maxKm = 99.0, label = 'дальнобойщик' },
    { xp = 1800, maxKm = 99.0, label = 'асфальтовый волк', payBonus = 0.15 },
}
Config.LevelPay = 0.06 -- +6 % оплаты за каждый уровень после первого

-- грузы. trailers — модели прицепов GTA, to — список точек назначения (Config.Points[...].tags)
Config.Cargo = {
    food  = { label = 'продукты', trailers = { 'trailers2', 'trailers3' }, base = 1800, perKm = 760, xp = 1.0, minLevel = 1,
              perishable = true, to = 'store', note = 'скоропорт: опоздание −50 %' },
    build = { label = 'стройматериалы', trailers = { 'trailerlogs', 'docktrailer' }, base = 1600, perKm = 720, xp = 1.0, minLevel = 1,
              overweight = 0.25, to = 'build', note = 'может быть перевес на посту' },
    mail  = { label = 'срочная почта', trailers = { 'trailers' }, base = 1400, perKm = 820, xp = 0.8, minLevel = 1,
              urgent = true, to = 'store', note = 'срок короче, оплата выше' },
    fuel  = { label = 'топливо', trailers = { 'tanker', 'tanker2' }, base = 2600, perKm = 980, xp = 1.4, minLevel = 2,
              fragile = true, to = 'fuel', note = 'цистерна: бить нельзя' },
    tech  = { label = 'автомобили в салон', trailers = { 'tr4' }, base = 2400, perKm = 900, xp = 1.2, minLevel = 3,
              fragile = true, to = 'tech', note = 'дорогой груз: каждая вмятина в минус' },
}

-- «левый» груз от частника: без документов, +60 % к оплате, на посту ДПС могут найти
Config.Contraband = {
    chance = 0.35, minLevel = 2, payMul = 1.6, foundChance = 0.6, fine = 25000, ignoreFine = 15000,
    label = 'попутный груз «без лишних вопросов»',
    from = 'Частник у ворот порта',
}

-- точки. tags — какие грузы туда возят. радиус разгрузки — Config.UnloadRadius.
-- store/fuel — места из конфига qbx_truckerjob (проверены), build/tech — «сверить» по игре.
Config.Points = {
    { id = 'grove',    label = 'АЗС на Южной',              coords = vec3(-41.07, -1747.91, 29.4),  tags = { fuel = true, store = true } },
    { id = 'center247', label = 'магазин «24/7» в центре',  coords = vec3(31.62, -1315.87, 29.52),  tags = { store = true } },
    { id = 'vespucci', label = 'винный на Береговой',       coords = vec3(-1226.48, -907.58, 12.32), tags = { store = true } },
    { id = 'ltd2',     label = 'АЗС у Литейного',           coords = vec3(-714.13, -909.13, 19.21),  tags = { fuel = true, store = true } },
    { id = 'morn',     label = 'винный на холмах',          coords = vec3(-1469.78, -366.72, 40.2),  tags = { store = true } },
    { id = 'ltd3',     label = 'АЗС на серпантине',         coords = vec3(-1829.15, 791.99, 138.26), tags = { fuel = true, store = true } },
    { id = 'coast1',   label = 'магазин на побережье',      coords = vec3(-2959.92, 396.77, 15.02),  tags = { store = true } },
    { id = 'coast2',   label = '«24/7» у пляжа',            coords = vec3(-3047.58, 589.89, 7.78),   tags = { store = true } },
    { id = 'coast3',   label = '«24/7» на трассе у моря',   coords = vec3(-3245.85, 1008.25, 12.83), tags = { store = true } },
    { id = 'paleto',   label = 'АЗС «24/7» у Палето',       coords = vec3(1735.54, 6416.28, 35.03),  tags = { fuel = true, store = true } },
    { id = 'grape',    label = '«24/7» Грейпсид',           coords = vec3(1702.84, 4917.28, 42.22),  tags = { store = true } },
    { id = 'sandy',    label = '«24/7» Песчаный',           coords = vec3(1960.47, 3753.59, 32.26),  tags = { store = true } },
    { id = 'route68',  label = 'магазин на трассе 68',      coords = vec3(1169.27, 2707.7, 38.15),   tags = { store = true } },
    { id = 'harmony',  label = '«24/7» Степной',            coords = vec3(543.47, 2658.81, 42.17),   tags = { store = true } },
    { id = 'senora',   label = 'АЗС «24/7» на трассе «Кавказ»', coords = vec3(2678.09, 3288.43, 55.24), tags = { fuel = true, store = true } },
    { id = 'tataviam', label = '«24/7» на перевале',        coords = vec3(2553.0, 399.32, 108.61),   tags = { store = true } },
    { id = 'mirror',   label = 'АЗС у Зеркального парка',   coords = vec3(1155.97, -319.76, 69.2),   tags = { fuel = true, store = true } },
    { id = 'murrieta', label = 'винный на Мурьете',         coords = vec3(1119.78, -983.99, 46.29),  tags = { store = true } },
    -- сверить по игре:
    { id = 'sawmill',  label = 'лесопилка Палето',          coords = vec3(-575.0, 5260.0, 70.5),     tags = { build = true } },
    { id = 'quarry',   label = 'карьер на трассе «Кавказ»', coords = vec3(2569.0, 2720.0, 42.9),     tags = { build = true } },
    { id = 'airfield', label = 'аэродром Песчаный',         coords = vec3(1712.0, 3280.0, 41.1),     tags = { build = true, tech = true } },
    { id = 'power',    label = 'электростанция',            coords = vec3(2670.0, 1600.0, 24.5),     tags = { build = true } },
    { id = 'salon',    label = 'автосалон «Нагорье Моторс»', coords = vec3(-31.0, -1090.0, 26.4),    tags = { tech = true } },
}
Config.UnloadRadius = 40.0

-- посты ДПС (координаты те же, что у kavkaz_world Config.Posts: точка у трассы, сам пост встаёт у дороги рядом)
Config.Posts = {
    { label = 'Пост ДПС «Восточный въезд»', coords = vec3(2341.0, -391.0, 68.0) },
    { label = 'Пост ДПС «Западный»',        coords = vec3(-3003.0, 290.0, 14.0) },
    { label = 'Пост ДПС «Мост»',            coords = vec3(-1608.0, 2826.0, 17.0) },
    { label = 'Пост ДПС «Гармония»',        coords = vec3(718.0, 2710.0, 39.0) },
    { label = 'Пост ДПС «Сенора»',          coords = vec3(2517.0, 3027.0, 41.0) },
    { label = 'Пост ДПС «Песчаный»',        coords = vec3(1509.1, 3481.6, 35.2) },
    { label = 'Пост ДПС «Песчаный-Восток»', coords = vec3(2134.9, 3770.8, 32.0) },
    { label = 'Пост ДПС «Грейпсид»',        coords = vec3(1662.0, 4941.0, 41.0) },
    { label = 'Пост ДПС «Палето»',          coords = vec3(-543.0, 6161.0, 6.0) },
}
Config.PostCheck = {
    nearRoute = 700.0,   -- пост считается «по пути», если до прямой маршрута меньше
    chance = 0.45,       -- проверка обычного груза
    contrabandChance = 0.8,
    radius = 110.0,      -- зона поста: тут надо остановиться
    waitSeconds = 30,    -- сколько ждёт инспектор
    overweightFine = 3000,
    ignoreFine = 5000,
}

-- поломки в пути
Config.Breakdown = { chance = 0.3, kinds = { 'tyre', 'tyre', 'engine' }, repairSeconds = 12 }

-- деньги и сроки
Config.RoadFactor = 1.3     -- дорога длиннее прямой
Config.AvgSpeed = 14.0      -- м/с для срока (≈50 км/ч с городом и поворотами)
Config.MinSpeed = 42.0      -- м/с: быстрее по прямой не доехать (защита от телепорта)
Config.OnTimeBonus = 0.15
Config.LatePenalty = 0.25
Config.NightMul = 1.3       -- 22:00–6:00 по игровым часам (Renewed-Weathersync)
Config.CancelFine = 1000    -- отмена после погрузки
Config.CranePrice = 5000    -- поставить перевёрнутый прицеп
Config.EvacPrice = 8000     -- новый тягач на месте
Config.DestroyedFine = { default = 3000, fuel = 10000 }
Config.AbandonMinutes = 10  -- игрок дальше 400 м от тягача и прицепа столько минут — рейс отменяется
Config.TruckIdleMinutes = 20
Config.OffersTtl = 300      -- секунд держится список рейсов
