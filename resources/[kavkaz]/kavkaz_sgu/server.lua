-- KAVKAZ RP — СГУ «Хазард 7007». всё решает сервер: есть ли СГУ, какая мелодия разрешена, оплата, изъятие.
-- звук: кряк — событие игрокам рядом; мелодия и стробоскоп — state bag машины (sgu_tone, sgu_strobe).

local installed = {} -- vkey -> model

CreateThread(function()
    local rows = MySQL.query.await('SELECT vkey, model FROM kavkaz_sgu') or {}
    for _, r in ipairs(rows) do installed[r.vkey] = r.model end
    print(('[kavkaz_sgu] СГУ на машинах: %d'):format(#rows))
end)

-- служебные модели: из kavkaz_cars (sale = 'org') + штатные машины экстренных служб GTA
local SERVICE = {}
for _, m in ipairs({ 'police', 'police2', 'police3', 'police4', 'policeb', 'policet', 'sheriff', 'sheriff2', 'fbi', 'fbi2',
    'pranger', 'riot', 'riot2', 'ambulance', 'firetruk', 'lguard', 'pbus', 'policeold1', 'policeold2' }) do
    SERVICE[joaat(m)] = true
end
CreateThread(function()
    local code = LoadResourceFile('kavkaz_cars', 'cars.lua')
    if not code then return end
    local env = {}
    local fn = load(code, '@kavkaz_cars/cars.lua', 't', env)
    if not fn then return end
    local ok, Cars = pcall(fn)
    Cars = ok and (Cars or env.Cars) or env.Cars
    if not Cars or not Cars.List then return end
    for _, car in ipairs(Cars.List) do
        if car.sale == 'org' then
            if car.stub then SERVICE[joaat(car.stub)] = true end
            if car.model then SERVICE[joaat(car.model)] = true end
        end
    end
end)

local function vkeyOf(veh)
    local id = Entity(veh).state.vehicleid
    if id then return 'id:' .. id end
    return nil
end

local function getPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

local function isService(src, veh)
    if not SERVICE[GetEntityModel(veh)] then return false end
    local p = getPlayer(src)
    local job = p and p.PlayerData.job
    return job and job.onduty and Config.ServiceJobTypes[job.type] == true
end

-- какое СГУ доступно водителю этой машины (nil — никакого)
local function modelFor(src, veh)
    if isService(src, veh) then return 'service' end
    local key = vkeyOf(veh)
    return key and installed[key] or nil
end

local function driverVehicle(src, net)
    local veh = NetworkGetEntityFromNetworkId(tonumber(net) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    if GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(src) then return nil end
    return veh
end

local function hasTone(model, tone)
    for _, t in ipairs(Config.Models[model].tones) do
        if t == tone then return true end
    end
    return false
end

lib.callback.register('kavkaz_sgu:get', function(src, net)
    local veh = driverVehicle(src, net)
    if not veh then return nil end
    return modelFor(src, veh)
end)

-- кряк: только игрокам поблизости
local lastQuack = {}
RegisterNetEvent('kavkaz_sgu:server:quack', function(net)
    local src = source
    local now = GetGameTimer()
    if (lastQuack[src] or 0) + 250 > now then return end
    lastQuack[src] = now
    local veh = driverVehicle(src, net)
    if not veh or not modelFor(src, veh) then return end
    local pos = GetEntityCoords(veh)
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(id)
        if ped ~= 0 and #(GetEntityCoords(ped) - pos) < Config.Range.quack then
            TriggerClientEvent('kavkaz_sgu:client:quack', id, net)
        end
    end
end)

RegisterNetEvent('kavkaz_sgu:server:tone', function(net, tone)
    local src = source
    local veh = driverVehicle(src, net)
    if not veh then return end
    local model = modelFor(src, veh)
    if tone ~= false and (not model or type(tone) ~= 'string' or not hasTone(model, tone)) then return end
    Entity(veh).state:set('sgu_tone', tone or false, true)
end)

RegisterNetEvent('kavkaz_sgu:server:strobe', function(net, on)
    local src = source
    local veh = driverVehicle(src, net)
    if not veh then return end
    local model = modelFor(src, veh)
    if on and not (model and Config.Models[model].strobe) then return end
    Entity(veh).state:set('sgu_strobe', on and true or false, true)
end)

---------------------------------------------------------------------------
-- гараж Бислана: установка и снятие
---------------------------------------------------------------------------

local function ownedVehicle(src, net)
    local veh = driverVehicle(src, net)
    if not veh then return nil, 'сядь за руль своей машины' end
    if #(GetEntityCoords(veh) - Config.Garage.coords) > Config.Garage.radius + 5.0 then return nil, 'подъедь к гаражу Бислана' end
    local id = Entity(veh).state.vehicleid
    if not id then return nil, 'Бислан ставит только на машины из гаража (с документами)' end
    local p = getPlayer(src)
    local owner = MySQL.scalar.await('SELECT citizenid FROM player_vehicles WHERE id = ?', { id })
    if not p or owner ~= p.PlayerData.citizenid then return nil, 'это не твоя машина' end
    return veh, nil, 'id:' .. id, p
end

lib.callback.register('kavkaz_sgu:garageInfo', function(src, net)
    local veh, err, key = ownedVehicle(src, net)
    if not veh then return { error = err } end
    return { current = installed[key] }
end)

lib.callback.register('kavkaz_sgu:buy', function(src, net, model)
    local m = Config.Models[model]
    if not m or not m.price then return false, 'нет такой модели' end
    local veh, err, key, p = ownedVehicle(src, net)
    if not veh then return false, err end
    if installed[key] == model then return false, 'уже стоит' end
    local paid = p.Functions.RemoveMoney('cash', m.price, 'kavkaz-sgu') or p.Functions.RemoveMoney('bank', m.price, 'kavkaz-sgu')
    if not paid then return false, ('не хватает денег: нужно %d ₽'):format(m.price) end
    MySQL.query.await('REPLACE INTO kavkaz_sgu (vkey, model, citizenid) VALUES (?, ?, ?)', { key, model, p.PlayerData.citizenid })
    installed[key] = model
    Entity(veh).state:set('sgu_tone', false, true)
    print(('[kavkaz_sgu] %s поставил %s на %s'):format(GetPlayerName(src), model, key))
    return true, m.label
end)

lib.callback.register('kavkaz_sgu:removeOwn', function(src, net)
    local veh, err, key = ownedVehicle(src, net)
    if not veh then return false, err end
    if not installed[key] then return false, 'СГУ не стоит' end
    MySQL.query.await('DELETE FROM kavkaz_sgu WHERE vkey = ?', { key })
    installed[key] = nil
    Entity(veh).state:set('sgu_tone', false, true)
    Entity(veh).state:set('sgu_strobe', false, true)
    return true
end)

---------------------------------------------------------------------------
-- ДПС: проверить и изъять
---------------------------------------------------------------------------

local function isPolice(src)
    local p = getPlayer(src)
    local job = p and p.PlayerData.job
    if not job or not job.onduty then return false end
    local min = Config.PoliceJobs[job.name]
    return min ~= nil and (job.grade and job.grade.level or 0) >= min
end

local function nearVehicle(src, net)
    local veh = NetworkGetEntityFromNetworkId(tonumber(net) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    if #(GetEntityCoords(veh) - GetEntityCoords(GetPlayerPed(src))) > 6.0 then return nil end
    return veh
end

lib.callback.register('kavkaz_sgu:check', function(src, net)
    if not isPolice(src) then return nil end
    local veh = nearVehicle(src, net)
    if not veh then return nil end
    local key = vkeyOf(veh)
    local model = key and installed[key]
    return { model = model, label = model and Config.Models[model].label, plate = GetVehicleNumberPlateText(veh) }
end)

lib.callback.register('kavkaz_sgu:seize', function(src, net)
    if not isPolice(src) then return false end
    local veh = nearVehicle(src, net)
    if not veh then return false end
    local key = vkeyOf(veh)
    if not key or not installed[key] then return false end
    MySQL.query.await('DELETE FROM kavkaz_sgu WHERE vkey = ?', { key })
    installed[key] = nil
    Entity(veh).state:set('sgu_tone', false, true)
    Entity(veh).state:set('sgu_strobe', false, true)
    print(('[kavkaz_sgu] %s изъял СГУ с %s (%s)'):format(GetPlayerName(src), GetVehicleNumberPlateText(veh), key))
    return true
end)

---------------------------------------------------------------------------
-- админ: /asgu mini|std|pro|off — на машину, в которой сидишь (только своя машина из гаража)
---------------------------------------------------------------------------

lib.addCommand('asgu', {
    help = 'Поставить или снять СГУ «Хазард» на машину, в которой сидишь',
    params = { { name = 'model', type = 'string', help = 'mini, std, pro или off' } },
    restricted = 'group.admin',
}, function(src, args)
    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return exports.qbx_core:Notify(src, 'сядь в машину', 'error') end
    local key = vkeyOf(veh)
    if not key then return exports.qbx_core:Notify(src, 'это не машина из гаража — СГУ не сохранится', 'error') end
    if args.model == 'off' then
        MySQL.query.await('DELETE FROM kavkaz_sgu WHERE vkey = ?', { key })
        installed[key] = nil
        Entity(veh).state:set('sgu_tone', false, true)
        return exports.qbx_core:Notify(src, 'СГУ снято', 'success')
    end
    local m = Config.Models[args.model]
    if not m or not m.price then return exports.qbx_core:Notify(src, 'модель: mini, std, pro или off', 'error') end
    MySQL.query.await('REPLACE INTO kavkaz_sgu (vkey, model) VALUES (?, ?)', { key, args.model })
    installed[key] = args.model
    exports.qbx_core:Notify(src, 'поставлено: ' .. m.label, 'success')
end)

AddEventHandler('playerDropped', function() lastQuack[source] = nil end)
