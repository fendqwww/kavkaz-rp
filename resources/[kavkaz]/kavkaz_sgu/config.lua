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
Config.Keys = { quack = 'G', tone = 'J', next = 'U', strobe = 'O' }
