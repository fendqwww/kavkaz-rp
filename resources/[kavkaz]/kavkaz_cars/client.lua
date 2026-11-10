-- русские названия настоящих моделей в игре (подпись при посадке, меню тюнинга).
-- setup/cars/build.py пишет в vehicles.meta gameName = имя спавна заглавными (KV_CAMRY80) — подставляем к нему название из cars.lua.
local Cars = assert(load(LoadResourceFile(GetCurrentResourceName(), 'cars.lua'), '@@kavkaz_cars/cars.lua', 't', {}))()

for _, car in ipairs(Cars.List) do
    if car.model and not car.placeholder then
        AddTextEntry(car.model:upper(), ('%s %s'):format(car.brand, car.name))
    end
end
