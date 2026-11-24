-- KAVKAZ RP: места города — продавцы в магазинах ox_inventory, детейлинг, ремонт у дороги, аптеки, почта.
-- деньги, цены и дистанцию проверяет сервер (server.lua), клиент только показывает меню и делает анимацию.
-- координаты с пометкой «сверить» — встань на место в игре, набери /mypos и поменяй строку.

Config = {}

Config.SpawnDistance = 60.0 -- NPC появляются, когда игрок ближе
Config.Debug = false

-- одна подпись на все точки одного вида: в легенде карты — одна строка, а не десять
Config.BlipLabels = {
    detailing = 'Детейлинг-центр',
    repair    = 'Шиномонтаж и ремонт',
    store     = 'Аптека',
    post      = 'Почта',
}

---------------------------------------------------------------------------
-- 1. продавцы за прилавками магазинов ox_inventory (overrides/resources/[ox]/ox_inventory/data/shops.lua)
-- shop — ключ магазина, id — номер точки в его locations. ox_target на продавце открывает тот же магазин.
-- места у прилавков — стандартные кассы GTA (24/7, Rob's Liquor, LTD, оружейные), «сверить» по месту.
---------------------------------------------------------------------------
local clerk24 = 'mp_m_shopkeep_01'
Config.Clerks = {
    -- «Продукты 24» (General)
    { shop = 'General', id = 1,  model = clerk24, coords = vec4(24.47, -1346.62, 29.50, 271.66) },
    { shop = 'General', id = 2,  model = clerk24, coords = vec4(-3039.54, 584.38, 7.91, 17.27) },
    { shop = 'General', id = 3,  model = clerk24, coords = vec4(-3242.97, 1000.01, 12.83, 357.57) },
    { shop = 'General', id = 4,  model = clerk24, coords = vec4(1728.07, 6415.63, 35.04, 242.95) },
    { shop = 'General', id = 5,  model = clerk24, coords = vec4(1697.80, 4922.69, 42.06, 322.50) },
    { shop = 'General', id = 6,  model = clerk24, coords = vec4(1959.82, 3740.48, 32.34, 301.57) },
    { shop = 'General', id = 7,  model = clerk24, coords = vec4(549.13, 2670.85, 42.16, 99.39) },
    { shop = 'General', id = 8,  model = clerk24, coords = vec4(2677.47, 3279.76, 55.24, 335.08) },
    { shop = 'General', id = 9,  model = clerk24, coords = vec4(2556.66, 380.84, 108.62, 356.67) },
    { shop = 'General', id = 10, model = clerk24, coords = vec4(372.66, 326.98, 103.57, 253.73) },
    -- KAVKAZ 16.11: три магазина LTD добавлены в «Продукты 24» (точки 11–13), открываются только через продавца
    { shop = 'General', id = 11, model = clerk24, coords = vec4(-46.56, -1757.98, 29.42, 48.43) },   -- Спальный район (Дэвис), сверить
    { shop = 'General', id = 12, model = clerk24, coords = vec4(1164.71, -322.94, 69.21, 101.72) },  -- «Зеркальный», сверить
    { shop = 'General', id = 13, model = clerk24, coords = vec4(-1819.96, 793.73, 138.09, 132.66) }, -- Рублёвый, сверить
    -- «Напитки» (Liquor)
    { shop = 'Liquor', id = 1, model = clerk24, coords = vec4(1134.20, -983.26, 46.42, 277.24) },
    { shop = 'Liquor', id = 2, model = clerk24, coords = vec4(-1221.58, -908.15, 12.33, 35.49) },
    { shop = 'Liquor', id = 3, model = clerk24, coords = vec4(-1486.59, -377.68, 40.16, 139.51) },
    { shop = 'Liquor', id = 4, model = clerk24, coords = vec4(-2966.39, 391.42, 15.04, 87.48) },
    { shop = 'Liquor', id = 5, model = clerk24, coords = vec4(1165.17, 2710.88, 38.16, 179.43) },
    { shop = 'Liquor', id = 6, model = clerk24, coords = vec4(1392.00, 3606.39, 34.98, 201.69) },
    -- «Хозтовары» (YouTool)
    { shop = 'YouTool', id = 1, model = 'a_m_m_salton_01', coords = vec4(2747.71, 3472.85, 55.67, 255.08) }, -- сверить
    -- «Охота и рыбалка» (Ammunation)
    { shop = 'Ammunation', id = 1, model = 'a_m_m_farmer_01', coords = vec4(-661.96, -933.53, 21.83, 177.05) },
    { shop = 'Ammunation', id = 2, model = 'a_m_m_farmer_01', coords = vec4(809.68, -2159.13, 29.62, 1.43) },
    { shop = 'Ammunation', id = 3, model = 'a_m_m_farmer_01', coords = vec4(1692.67, 3761.38, 34.71, 227.65) },
    { shop = 'Ammunation', id = 4, model = 'a_m_m_farmer_01', coords = vec4(-331.23, 6085.37, 31.45, 228.02) },
    { shop = 'Ammunation', id = 5, model = 'a_m_m_farmer_01', coords = vec4(253.63, -51.02, 69.94, 72.91) },
    { shop = 'Ammunation', id = 6, model = 'a_m_m_farmer_01', coords = vec4(23.00, -1105.67, 29.80, 162.91) },
    { shop = 'Ammunation', id = 7, model = 'a_m_m_farmer_01', coords = vec4(2567.48, 292.59, 108.73, 349.68) },
    { shop = 'Ammunation', id = 8, model = 'a_m_m_farmer_01', coords = vec4(-1118.59, 2700.05, 18.55, 221.89) },
    { shop = 'Ammunation', id = 9, model = 'a_m_m_farmer_01', coords = vec4(841.92, -1035.32, 28.19, 1.56) },
}

---------------------------------------------------------------------------
-- 2. детейлинг: пакеты (цена в ₽, время в мс). полировка — машина не пачкается Config.PolishHours часов
---------------------------------------------------------------------------
Config.PolishHours = 2
Config.Detailing = {
    { id = 'express', label = 'Экспресс-мойка', desc = 'кузов и стёкла', price = 300, time = 8000 },
    { id = 'polish', label = 'Мойка и полировка', desc = 'блестит, грязь не липнет 2 часа', price = 1500, time = 15000, polish = true },
    { id = 'full', label = 'Полный детейлинг', desc = 'полировка, химчистка салона, выправим мелкие вмятины', price = 4500, time = 25000, polish = true, body = true },
}
Config.DetailBodyMin = 600.0 -- «мелкие вмятины»: кузов не хуже этого, иначе — в ремонт

---------------------------------------------------------------------------
-- 3. ремонт у дороги: цена = база + за двигатель + за кузов + за каждое пробитое колесо (считает сервер)
---------------------------------------------------------------------------
Config.Repair = { base = 500, engine = 3.0, body = 2.0, tyre = 400, time = 20000 }

---------------------------------------------------------------------------
-- 4. магазины-NPC (аптека). предметы — из ox_inventory items.lua
---------------------------------------------------------------------------
Config.MaxPerBuy = 5
Config.Stores = {
    pharmacy = {
        title = 'Аптека «Здоровье»',
        items = {
            { name = 'bandage', label = 'Бинт', price = 300 },
            { name = 'painkillers', label = 'Обезболивающее', price = 450 },
            { name = 'firstaid', label = 'Аптечка', price = 3500 },
            { name = 'ifaks', label = 'Индивидуальная аптечка (ИПП)', price = 6000 },
        },
    },
}

---------------------------------------------------------------------------
-- 5. почта: перевод денег другому игроку с карты на карту
---------------------------------------------------------------------------
Config.Post = { min = 100, max = 500000, fee = 0.02 }

---------------------------------------------------------------------------
-- 6. места. radius — в каком радиусе от продавца должна стоять машина / игрок (проверяет и сервер)
---------------------------------------------------------------------------
Config.Places = {
    { id = 'detail_morning', kind = 'detailing', label = 'Детейлинг-центр «Блеск»',
      ped = { model = 's_m_y_xmech_01', coords = vec4(-1418.9, -448.5, 35.9, 120.0) }, radius = 15.0, -- автосервис в Утреннем, сверить
      blip = { sprite = 100, color = 3 } },
    { id = 'detail_sandy', kind = 'detailing', label = 'Детейлинг «Блеск» — Песчаный',
      ped = { model = 's_m_y_xmech_01', coords = vec4(1365.5, 3605.5, 34.9, 200.0) }, radius = 15.0, -- у мойки Песчаного, сверить
      blip = { sprite = 100, color = 3 } },

    { id = 'repair_grapeseed', kind = 'repair', label = 'Шиномонтаж «24 часа»',
      ped = { model = 's_m_y_xmech_02', coords = vec4(1700.6, 4790.9, 41.9, 90.0) }, radius = 15.0, -- Седа-Юрт, у заправки, сверить
      blip = { sprite = 446, color = 5 } },
    { id = 'repair_senora', kind = 'repair', label = 'Шиномонтаж у трассы',
      ped = { model = 's_m_y_xmech_02', coords = vec4(2547.7, 2589.4, 37.9, 290.0) }, radius = 15.0, -- трасса «Кавказ», сверить
      blip = { sprite = 446, color = 5 } },

    { id = 'pharm_center', kind = 'store', store = 'pharmacy', label = 'Аптека «Здоровье»',
      ped = { model = 's_f_y_scrubs_01', coords = vec4(312.2, -592.9, 43.28, 70.0) }, radius = 3.0, -- холл больницы, сверить
      blip = { sprite = 51, color = 2 } },
    { id = 'pharm_sandy', kind = 'store', store = 'pharmacy', label = 'Аптека «Здоровье» — Песчаный',
      ped = { model = 's_f_y_scrubs_01', coords = vec4(1834.5, 3677.0, 34.28, 210.0) }, radius = 3.0, -- сверить
      blip = { sprite = 51, color = 2 } },
    { id = 'pharm_paleto', kind = 'store', store = 'pharmacy', label = 'Аптека «Здоровье» — Лам-Юрт',
      ped = { model = 's_f_y_scrubs_01', coords = vec4(-251.5, 6329.0, 32.43, 315.0) }, radius = 3.0, -- сверить
      blip = { sprite = 51, color = 2 } },

    { id = 'post_center', kind = 'post', label = 'Почта Нагорска',
      ped = { model = 'a_f_y_business_02', coords = vec4(438.5, -647.5, 28.5, 90.0) }, radius = 3.0, -- у автовокзала, сверить
      blip = { sprite = 568, color = 5 } },
}
