Config = {}

-- мелодии (звук делает html/index.html, без файлов). id -> название в уведомлении
Config.Tones = {
    wail   = 'Вой',
    yelp   = 'Йелп',
    hilo   = 'Двухтон',
    hazard = '«Хазард»',
    phaser = 'Фазер',
    pulse  = 'Пульс',
    horn   = 'Горн',
    krya   = 'Кря-кря',
}

-- модели (docs/vision/04-cars.md, «СГУ Хазард 7007»). кряк на H есть у всех
Config.Models = {
    mini    = { label = 'Хазард 7007 Мини', price = 30000,  tones = { 'krya' } },
    std     = { label = 'Хазард 7007',      price = 120000, tones = { 'hazard', 'wail', 'yelp', 'hilo' } },
    pro     = { label = 'Хазард 7007 Про',  price = 250000, tones = { 'hazard', 'wail', 'yelp', 'hilo', 'phaser', 'pulse', 'horn', 'krya' }, strobe = true },
    service = { label = 'Служебное СГУ',    tones = { 'wail', 'yelp', 'hilo', 'phaser', 'pulse', 'horn' } },
}
Config.ShopOrder = { 'mini', 'std', 'pro' }

-- служебное СГУ: на работе (onduty) с таким типом работы и в машине экстренного класса (18) или из kavkaz_cars (sale = 'org')
Config.ServiceJobTypes = { leo = true, ems = true }

-- гараж Бислана «Крякалка» (kavkaz_quests: NPC bislan). подъехать на своей машине и встать рядом
Config.Garage = { coords = vec3(731.0, -1088.0, 22.17), radius = 12.0, blip = false }

-- кто может проверить и изъять СГУ (работа = минимальный ранг)
Config.PoliceJobs = { police = 0, fsb = 0 }

-- слышимость, метров
Config.Range = { quack = 140.0, loop = 180.0 }

-- клавиши по умолчанию (игрок меняет в Настройки → Назначение клавиш → FiveM)
-- H занята (фары GTA, поиск ключей qbx_vehiclekeys), K — присесть, Y — круиз, N — рация/голос
Config.Keys = { quack = 'G', tone = 'J', next = 'U', strobe = 'O', manual = 'CAPITAL' } -- manual — держать: ручной тон (кнопка MAN)

-- ручной тон (MAN) есть у этих моделей
Config.ManualModels = { std = true, pro = true, service = true }

-- стробоскопы в решётке радиатора (у моделей со strobe = true): красный и синий, двойная вспышка, как у настоящих
Config.Grille = {
    distance = 120.0,      -- дальше не рисуем
    spread = 0.30,         -- насколько разнесены огни от центра решётки (доля расстояния между фарами)
    down = 0.10,           -- ниже линии фар, м
    forward = 0.06,        -- вперёд от линии фар, м
    flash = 55,            -- вспышка, мс
    gap = 55,              -- пауза внутри двойной вспышки, мс
    pause = 140,           -- пауза между цветами, мс
    range = 7.0, intensity = 9.0,
}

-- 3D-пульт на торпеде (dash.lua). место по умолчанию — от руля; своё для машины: /sgupos -> строку в cars
Config.Dash = {
    range = 30.0,
    default = { fromWheel = vec3(0.36, 0.10, -0.12), rot = vec3(-20.0, 0.0, -15.0), fallback = vec3(0.0, 0.45, 0.30) },
    selStart = -125.0, selStep = 22.0, -- угол ручки: STANDBY и шаг на мелодию
    cars = {
        -- ['kv_priora'] = { offset = vec3(0.0, 0.5, 0.3), rot = vec3(-20.0, 0.0, -15.0) },
    },
}

-- 11.11 по просьбе основателя: СГУ только руками — мышью по 3D-пульту в салоне (от первого лица: навёл — колесо крутит
-- ручку, ЛКМ — кнопки). клавиши на клавиатуре и 2D-окно выключены (окно наезжало на спидометр). вернуть: true
Config.KeyboardControls = false
Config.ShowPanel = false
