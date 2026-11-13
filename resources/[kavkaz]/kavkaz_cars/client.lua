-- русские названия настоящих моделей в игре (подпись при посадке, меню тюнинга).
-- setup/cars/build.py пишет в vehicles.meta gameName = имя спавна заглавными (KV_CAMRY80) — подставляем к нему название из cars.lua.
local Cars = assert(load(LoadResourceFile(GetCurrentResourceName(), 'cars.lua'), '@@kavkaz_cars/cars.lua', 't', {}))()

for _, car in ipairs(Cars.List) do
    if car.model and not car.placeholder then
        AddTextEntry(car.model:upper(), ('%s %s'):format(car.brand, car.name))
    end
end

-- KAVKAZ: заранее скачать модели своих машин (11.11: у игроков медленный интернет — машина из гаража грузилась минутами
-- или не появлялась: сервер ждёт игру лишь несколько секунд). качаем по одной, в фоне, сразу после входа.
-- пока это идёт, kavkaz_traffic не качает новые модели (LocalPlayer.state.kvCarsCached).
local PREFETCH_WAIT = 180000 -- сколько ждать одну модель, мс

RegisterNetEvent('kavkaz_cars:client:prefetch', function(models)
    CreateThread(function()
        for _, name in ipairs(models or {}) do
            local hash = type(name) == 'number' and name or joaat(name)
            if IsModelInCdimage(hash) and not HasModelLoaded(hash) then
                RequestModel(hash)
                local deadline = GetGameTimer() + PREFETCH_WAIT
                while not HasModelLoaded(hash) and GetGameTimer() < deadline do
                    Wait(500)
                    RequestModel(hash)
                end
                SetModelAsNoLongerNeeded(hash) -- на диске (кэш FiveM) модель остаётся
            end
        end
        LocalPlayer.state:set('kvCarsCached', true, false)
    end)
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    LocalPlayer.state:set('kvCarsCached', false, false)
    SetTimeout(3000, function() TriggerServerEvent('kavkaz_cars:server:prefetch') end)
end)
