-- KAVKAZ RP: что на что меняем. места — data.lua (генерирует setup/maps/make_replace_data.py из карты игры).
-- with: список наших моделей (берётся по очереди, чтобы не было одинаковых рядом); nil — просто спрятать.
-- yaw: доворот нашей модели относительно американской (если остановка стоит задом к дороге — 180).
Config = {}

Config.Replace = {
    prop_busstop_02 = { with = { 'kv_p_stop_bus_ussr', 'kv_p_old_russian_bus_stop' }, yaw = 0.0 },
    prop_busstop_04 = { with = { 'kv_p_stop_bus_ussr', 'kv_p_old_russian_bus_stop' }, yaw = 0.0 },
    prop_busstop_05 = { with = { 'kv_p_stop_bus_ussr', 'kv_p_old_russian_bus_stop' }, yaw = 0.0 },
    prop_bus_stop_sign = { with = nil },
}
-- пальмы: в предгорьях Кавказа их нет — на их месте обычные деревья (модели GTA, есть у всех)
Config.PalmTrees = { 'prop_tree_birch_01', 'prop_tree_birch_02', 'prop_tree_birch_03', 'prop_tree_maple_02', 'prop_tree_oak_01' }
Config.PalmPattern = '^prop_.*palm'

Config.Radius = 250.0 -- в каком радиусе от игрока ставим наши объекты
Config.Cell = 200.0   -- размер клетки сетки
