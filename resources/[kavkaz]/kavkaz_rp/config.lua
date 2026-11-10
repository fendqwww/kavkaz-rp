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
