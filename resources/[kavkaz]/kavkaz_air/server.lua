-- KAVKAZ RP — пневмоподвеска. сервер решает: стоит ли подвеска, можно ли менять уровень, оплата установки.

local installed = {} -- vkey -> true

CreateThread(function()
    local rows = MySQL.query.await('SELECT vkey FROM kavkaz_air') or {}
    for _, r in ipairs(rows) do installed[r.vkey] = true end
end)

local function vkeyOf(veh)
    local id = Entity(veh).state.vehicleid
    return id and ('id:' .. id) or nil
end

local function driverVehicle(src, net)
    local veh = NetworkGetEntityFromNetworkId(tonumber(net) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    if GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(src) then return nil end
    return veh
end

lib.callback.register('kavkaz_air:has', function(src, net)
    local veh = driverVehicle(src, net)
    local key = veh and vkeyOf(veh)
    return key and installed[key] or false
end)

local last = {}
RegisterNetEvent('kavkaz_air:server:level', function(net, level)
    local src = source
    level = math.floor(tonumber(level) or 0)
    if level < Config.Min or level > Config.Max then return end
    if (last[src] or 0) + 250 > GetGameTimer() then return end
    last[src] = GetGameTimer()
    local veh = driverVehicle(src, net)
    local key = veh and vkeyOf(veh)
    if not key or not installed[key] then return end
    Entity(veh).state:set('kv_air', level, true)
end)
AddEventHandler('playerDropped', function() last[source] = nil end)

-- установка: зовёт меню гаража Бислана (kavkaz_sgu), там же проверка, что машина рядом и своя
local function owned(src, net, garage)
    local veh = driverVehicle(src, net)
    if not veh then return nil, 'сядь за руль своей машины' end
    if garage and #(GetEntityCoords(veh) - garage) > 17.0 then return nil, 'подъедь к гаражу Бислана' end
    local id = Entity(veh).state.vehicleid
    if not id then return nil, 'ставим только на машины из гаража (с документами)' end
    local p = exports.qbx_core:GetPlayer(src)
    local owner = MySQL.scalar.await('SELECT citizenid FROM player_vehicles WHERE id = ?', { id })
    if not p or owner ~= p.PlayerData.citizenid then return nil, 'это не твоя машина' end
    return veh, nil, 'id:' .. id, p
end

local function garageCoords()
    local ok, c = pcall(function() return exports.kavkaz_sgu:GarageCoords() end)
    return ok and c or nil
end

lib.callback.register('kavkaz_air:info', function(src, net)
    local veh, err, key = owned(src, net, garageCoords())
    if not veh then return { error = err } end
    return { installed = installed[key] == true, price = Config.Price }
end)

lib.callback.register('kavkaz_air:buy', function(src, net)
    local veh, err, key, p = owned(src, net, garageCoords())
    if not veh then return false, err end
    if installed[key] then return false, 'уже стоит' end
    local paid = p.Functions.RemoveMoney('cash', Config.Price, 'kavkaz-air') or p.Functions.RemoveMoney('bank', Config.Price, 'kavkaz-air')
    if not paid then return false, ('не хватает денег: нужно %d ₽'):format(Config.Price) end
    MySQL.query.await('REPLACE INTO kavkaz_air (vkey, citizenid) VALUES (?, ?)', { key, p.PlayerData.citizenid })
    installed[key] = true
    TriggerClientEvent('kavkaz_air:client:installed', src, NetworkGetNetworkIdFromEntity(veh))
    return true
end)

lib.callback.register('kavkaz_air:remove', function(src, net)
    local veh, err, key = owned(src, net, garageCoords())
    if not veh then return false, err end
    MySQL.query.await('DELETE FROM kavkaz_air WHERE vkey = ?', { key })
    installed[key] = nil
    Entity(veh).state:set('kv_air', 0, true)
    return true
end)

-- выдать из админки или основателям: exports.kavkaz_air:SetById(player_vehicles.id, true|false)
exports('SetById', function(id, on, citizenid)
    local key = 'id:' .. id
    if on then
        MySQL.query.await('REPLACE INTO kavkaz_air (vkey, citizenid) VALUES (?, ?)', { key, citizenid })
        installed[key] = true
    else
        MySQL.query.await('DELETE FROM kavkaz_air WHERE vkey = ?', { key })
        installed[key] = nil
    end
end)
