Config = {}

-- обычный чат = речь персонажа, слышно рядом (а не на весь сервер, как в чистом Qbox)
Config.LocalChat = true

-- дальность в метрах (docs/vision/07-mechanics.md)
Config.Range = { say = 15.0, shout = 40.0, whisper = 2.5, action = 20.0, ooc = 20.0 }

-- госструктуры: общая рация /d и госновости /gov (лидеры и замы = ранги isboss)
Config.GovJobs = { police = true, sheriff = true, ambulance = true, fire = true, fsb = true, mchs = true, government = true }

-- /pay: только наличными, рядом, без спама
Config.Pay = { distance = 3.0, max = 10000000, cooldown = 3 }

-- цвета сообщений (небесно-синяя палитра чата)
Config.Colors = {
    say = { 238, 248, 255 }, shout = { 255, 255, 255 }, whisper = { 169, 196, 230 },
    me = { 127, 211, 255 }, ['do'] = { 90, 190, 255 }, try = { 127, 211, 255 },
    ooc = { 140, 160, 190 }, pm = { 255, 200, 87 },
    radio = { 78, 224, 166 }, radioOoc = { 110, 170, 150 }, dep = { 255, 140, 90 }, gov = { 42, 180, 255 }, fam = { 200, 150, 255 },
}

-- автодействия: игра сама пишет в чат рядом «* Ахмед [7] пристегнул ремень безопасности» (как у RMRP)
Config.AutoMe = true
Config.AutoMeText = {
    belt_on = 'пристегнул ремень безопасности',
    belt_off = 'отстегнул ремень безопасности',
    engine_on = 'завёл двигатель',
    engine_off = 'заглушил двигатель',
    lock = 'закрыл машину на ключ',
    unlock = 'открыл машину ключом',
    armor = 'надел бронежилет',
    weapon_in = 'убрал оружие',
    ['weapon_out:pistol'] = 'достал пистолет',
    ['weapon_out:smg'] = 'достал пистолет-пулемёт',
    ['weapon_out:rifle'] = 'достал автомат',
    ['weapon_out:shotgun'] = 'достал дробовик',
    ['weapon_out:sniper'] = 'достал снайперскую винтовку',
    ['weapon_out:heavy'] = 'достал тяжёлое оружие',
    ['weapon_out:melee'] = 'взял в руки холодное оружие',
    ['weapon_out:other'] = 'достал оружие',
}

-- двигатель заводится кнопкой (engine.lua). клавишу игрок меняет в Настройки → Назначение клавиш → FiveM
Config.Engine = {
    Key = 'I', -- Y занят круизом (qbx_cruise), H — поиском ключей, K — присесть
    CrankMs = 1100, -- сколько крутит стартёр
    Anim = { dict = 'oddjobs@towing', clip = 'start_engine', delay = 450 },
    AnimBike = { dict = 'veh@bike@quad@front@base', clip = 'start_engine', delay = 700 },
    -- старые машины: шанс не завестись с первой попытки «на холодную» и с повторной
    OldCars = { kv_vaz2107 = true, kv_vaz2109 = true, kv_vaz2110 = true, kv_vaz2114 = true, kv_niva_legend = true,
                kv_gazel = true, kv_gazel_taxi = true, kv_gazel_ems = true, kv_uaz_dps = true, kv_liaz = true },
    OldCold = 0.35,
    OldRetry = 0.15,
}
