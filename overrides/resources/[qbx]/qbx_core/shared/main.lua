local qbShared = {}
qbShared.ForceJobDefaultDutyAtLogin = true -- true: Force duty state to jobdefaultDuty | false: set duty state from database last saved
qbShared.Locations = require 'shared.locations'
qbShared.Vehicles = require 'shared.vehicles'
qbShared.Weapons = require 'shared.weapons'

-- KAVKAZ: автопарк KAVKAZ RP из resources/[kavkaz]/kavkaz_cars/cars.lua — русские названия, цены в ₽, разделы салона.
-- пока у машины нет настоящей модели, запись встроенной модели-заглушки (stub) переименовывается в нашу машину;
-- когда модель поставлена (model + placeholder = false), добавляется новая запись под её именем спавна.
-- kavkaz_cars должен стартовать раньше qbx_core: строку ensure kavkaz_cars в server.cfg ставит setup/apply-overrides.
do
    local code = LoadResourceFile('kavkaz_cars', 'cars.lua')
    local chunk = code and load(code, '@@kavkaz_cars/cars.lua', 't', {})
    local ok, cars = false, nil
    if chunk then ok, cars = pcall(chunk) end
    if ok and type(cars) == 'table' and type(cars.List) == 'table' then
        for _, car in ipairs(cars.List) do
            local model = cars.current(car)
            local base = qbShared.Vehicles[model] or qbShared.Vehicles[car.stub] or {}
            local forSale = car.sale == 'shop' or car.sale == 'quest'
            qbShared.Vehicles[model] = {
                name = car.name,
                brand = car.brand,
                model = model,
                price = car.price,
                -- служебные и рабочие оставляют категорию GTA (emergency, service): от неё зависят ключи и гаражи
                category = forSale and car.category or base.category or car.category,
                type = base.type or 'automobile',
                hash = joaat(model),
            }
        end
    else
        print('^3[qbx_core] KAVKAZ: kavkaz_cars/cars.lua не прочитан — салон и гаражи будут со списком машин GTA. ensure kavkaz_cars должен стоять до ensure qbx_core^7')
    end
end

---@type table<number, Vehicle>
qbShared.VehicleHashes = {}

for _, v in pairs(qbShared.Vehicles) do
    qbShared.VehicleHashes[v.hash] = v
end

return qbShared
