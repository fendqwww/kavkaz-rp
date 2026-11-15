-- KAVKAZ RP: что на что меняем. места — data.lua (генерирует setup/maps/make_replace_data.py из карты игры).
-- with: список наших моделей (берётся по очереди, чтобы не было одинаковых рядом); nil — просто спрятать.
-- yaw: доворот нашей модели относительно американской (если остановка стоит задом к дороге — 180).
Config = {}

Config.Replace = {
    prop_busstop_02 = { with = { 'kv_p_stop_bus_ussr', 'kv_p_old_russian_bus_stop' }, yaw = 0.0 },
    prop_busstop_04 = { with = { 'kv_p_stop_bus_ussr', 'kv_p_old_russian_bus_stop' }, yaw = 0.0 },
    prop_busstop_05 = { with = { 'kv_p_stop_bus_ussr', 'kv_p_old_russian_bus_stop' }, yaw = 0.0 },
    prop_bus_stop_sign = { with = nil },
    -- 12.11: американские П-образные светофоры над дорогой -> наш русский светофор на столбе (kv_traffic_lights) там же
    prop_traffic_03a = { with = { 'prop_traffic_01a' }, yaw = 0.0 },
    prop_traffic_03b = { with = { 'prop_traffic_01a' }, yaw = 0.0 },
}
Config.TrafficLights = true -- data_lights.lua (297 мест из скана карты)
-- пальмы: в предгорьях Кавказа их нет — на их месте обычные деревья (модели GTA, есть у всех)
-- большие пальмы -> деревья, маленькие веерные пальмы в клумбах -> кусты (чтобы деревья не выросли посреди тротуара)
Config.PalmTrees = { 'prop_tree_birch_01', 'prop_tree_birch_02', 'prop_tree_birch_03', 'prop_tree_maple_02', 'prop_tree_oak_01' }
Config.PalmBushes = { 'prop_bush_lrg_01', 'prop_bush_lrg_04b', 'prop_bush_med_03', 'prop_bush_lrg_02' }
Config.PalmPattern = '^prop_.*palm'
Config.SmallPalm = { '^prop_palm_fan_0[34]', '^prop_palm_sm_', '^prop_fan_palm' } -- шаблоны Lua (без «|»)

Config.Radius = 250.0 -- в каком радиусе от игрока ставим наши объекты
Config.Cell = 200.0   -- размер клетки сетки

-- готовые расстановки объектов (data_rublevka.lua — «Рублёвка» у Песчаного, 1760 объектов GTA). false — выключить
Config.Placements = true

-- русские кварталы: хрущёвки, панельки, гаражи, киоски на пустых местах (data_rublocks.lua, setup/maps/make_rublocks.py)
Config.RuBlocks = true
Config.MaxSlope = 2.0 -- м: если земля под домом неровнее — место пропускаем

-- 15.11: дворы у жилых домов русских кварталов — лавочки, мусорные контейнеры, беседка, припаркованные машины.
-- ставятся только вместе с домом, каждый предмет — на землю у дома (не на дорогу, не на крышу, не в обрыв).
-- машины — наш автопарк (запертые, неподвижные, у каждого игрока свои); модели, которой нет, просто пропускается
Config.Yards = {
    houses = { kv_p_khrushchevka = true, kv_p_soviet_residential_building = true, kv_p_russian_panel_house = true },
    benches = { 'prop_bench_01a', 'prop_bench_06', 'prop_bench_09' },
    bins = { 'prop_dumpster_01a', 'prop_dumpster_02a' },
    extra = { 'prop_picnictable_01', 'prop_bbq_1' }, -- беседка не влезает в свободные 7 м вокруг дома
    cars = { 'kv_vaz2107', 'kv_vaz2109', 'kv_vaz2114', 'kv_priora' }, -- 4 модели: каждая машина — до 30 МБ памяти
    carColors = { 111, 4, 1, 27, 62, 53, 99, 0 },
}
