-- KAVKAZ RP: деньги мест города. всё проверяется здесь: место, услуга, цена, дистанция, кто за рулём, деньги, место в карманах

local byId = {}
for _, p in ipairs(Config.Places) do byId[p.id] = p end
local packages = {}
for _, d in ipairs(Config.Detailing) do packages[d.id] = d end

local last = {} -- src -> время последнего запроса (защита от спама)

local function money(n)
    return (tostring(math.floor(n)):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')) .. ' ₽'
end

local function tooFast(src, ms)
    local now = GetGameTimer()
    if last[src] and now - last[src] < (ms or 1000) then return true end
    last[src] = now
    return false
end

-- игрок у места этого вида
local function placeNear(src, placeId, kind)
    local place = type(placeId) == 'string' and byId[placeId]
    if not place or place.kind ~= kind then return nil, 'такого места нет' end
    local c = place.ped.coords
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - vec3(c.x, c.y, c.z)) > (place.radius or 3.0) + 3.0 then
        return nil, 'подойди ближе'
    end
    return place
end

-- машина рядом с местом, игрок — за рулём
local function vehicleOf(src, place, netId)
    netId = tonumber(netId)
    if not netId then return nil, 'нужна машина' end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil, 'машина не найдена' end
    if GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(src) then return nil, 'сядь за руль своей машины' end
    local c = place.ped.coords
    if #(GetEntityCoords(veh) - vec3(c.x, c.y, c.z)) > (place.radius or 15.0) + 3.0 then return nil, 'подъезжай ближе' end
    return veh
end

-- сначала наличные, потом карта
local function charge(src, amount, reason)
    if amount <= 0 then return true end
    return exports.qbx_core:RemoveMoney(src, 'cash', amount, reason) or exports.qbx_core:RemoveMoney(src, 'bank', amount, reason)
end

---------------------------------------------------------------------------
-- детейлинг
---------------------------------------------------------------------------
lib.callback.register('kavkaz_places:detail', function(src, placeId, pkgId, netId)
    if tooFast(src, 3000) then return false, 'не так быстро' end
    local place, err = placeNear(src, placeId, 'detailing')
    if not place then return false, err end
    local pkg = type(pkgId) == 'string' and packages[pkgId]
    if not pkg then return false, 'такой услуги нет' end
    local veh, verr = vehicleOf(src, place, netId)
    if not veh then return false, verr end

    if not charge(src, pkg.price, ('%s: %s'):format(place.label, pkg.label)) then
        return false, ('не хватает денег: нужно %s'):format(money(pkg.price))
    end
    local body = false
    if pkg.body then body = GetVehicleBodyHealth(veh) >= Config.DetailBodyMin end
    if pkg.polish then
        Entity(veh).state:set('kvPolishUntil', os.time() + Config.PolishHours * 3600, true)
    end
    local msg = ('%s — %s'):format(pkg.label, money(pkg.price))
    if pkg.body and not body then msg = msg .. '. вмятины серьёзные — это в ремонт' end
    return true, msg, body
end)

---------------------------------------------------------------------------
-- ремонт у дороги
---------------------------------------------------------------------------
local function repairPrice(veh, tyres)
    local r = Config.Repair
    local engine = math.max(0.0, math.min(1000.0, GetVehicleEngineHealth(veh) + 0.0))
    local body = math.max(0.0, math.min(1000.0, GetVehicleBodyHealth(veh) + 0.0))
    tyres = math.max(0, math.min(8, math.floor(tonumber(tyres) or 0)))
    local damage = (1000.0 - engine) * r.engine + (1000.0 - body) * r.body + tyres * r.tyre
    if damage < 50 then return 0 end
    return math.floor((r.base + damage) / 10) * 10
end

lib.callback.register('kavkaz_places:repairQuote', function(src, placeId, netId, tyres)
    local place, err = placeNear(src, placeId, 'repair')
    if not place then return false, err end
    local veh, verr = vehicleOf(src, place, netId)
    if not veh then return false, verr end
    return true, repairPrice(veh, tyres)
end)

lib.callback.register('kavkaz_places:repair', function(src, placeId, netId, tyres)
    if tooFast(src, 3000) then return false, 'не так быстро' end
    local place, err = placeNear(src, placeId, 'repair')
    if not place then return false, err end
    local veh, verr = vehicleOf(src, place, netId)
    if not veh then return false, verr end
    local price = repairPrice(veh, tyres)
    if price <= 0 then return false, 'машина в порядке, чинить нечего' end
    if not charge(src, price, place.label .. ': ремонт') then
        return false, ('не хватает денег: нужно %s'):format(money(price))
    end
    return true, ('ремонт — %s. счастливого пути'):format(money(price))
end)

---------------------------------------------------------------------------
-- магазины-NPC (аптека)
---------------------------------------------------------------------------
lib.callback.register('kavkaz_places:buy', function(src, placeId, item, count)
    if tooFast(src, 1000) then return false, 'не так быстро' end
    local place, err = placeNear(src, placeId, 'store')
    if not place then return false, err end
    local store = Config.Stores[place.store]
    local entry
    for _, it in ipairs(store and store.items or {}) do
        if it.name == item then entry = it break end
    end
    if not entry then return false, 'этого здесь не продают' end
    count = math.floor(tonumber(count) or 0)
    if count < 1 or count > Config.MaxPerBuy then return false, 'неверное количество' end
    if not exports.ox_inventory:CanCarryItem(src, item, count) then return false, 'в карманах нет места' end
    local total = entry.price * count
    local reason = place.label .. ': ' .. entry.label
    if not charge(src, total, reason) then return false, ('не хватает денег: нужно %s'):format(money(total)) end
    if not exports.ox_inventory:AddItem(src, item, count) then
        exports.qbx_core:AddMoney(src, 'cash', total, 'возврат: ' .. reason)
        return false, 'не получилось выдать покупку, деньги вернули'
    end
    return true, ('%s × %d — %s'):format(entry.label, count, money(total))
end)

---------------------------------------------------------------------------
-- почта: перевод с карты на карту
---------------------------------------------------------------------------
lib.callback.register('kavkaz_places:transfer', function(src, placeId, target, amount)
    if tooFast(src, 3000) then return false, 'не так быстро' end
    local place, err = placeNear(src, placeId, 'post')
    if not place then return false, err end
    target = math.floor(tonumber(target) or 0)
    amount = math.floor(tonumber(amount) or 0)
    if target == src then return false, 'себе переводить не нужно' end
    local to = target > 0 and exports.qbx_core:GetPlayer(target)
    if not to then return false, 'получатель не в городе (нет такого ID)' end
    local cfg = Config.Post
    if amount < cfg.min or amount > cfg.max then
        return false, ('сумма от %s до %s'):format(money(cfg.min), money(cfg.max))
    end
    local fee = math.ceil(amount * cfg.fee)
    local from = exports.qbx_core:GetPlayer(src)
    if not from then return false, 'ошибка персонажа' end
    local fromName = ('%s %s'):format(from.PlayerData.charinfo.firstname, from.PlayerData.charinfo.lastname)
    local toName = ('%s %s'):format(to.PlayerData.charinfo.firstname, to.PlayerData.charinfo.lastname)
    if not exports.qbx_core:RemoveMoney(src, 'bank', amount + fee, 'почта: перевод ' .. toName) then
        return false, ('на карте не хватает: нужно %s (с комиссией %s)'):format(money(amount + fee), money(fee))
    end
    exports.qbx_core:AddMoney(target, 'bank', amount, 'почта: перевод от ' .. fromName)
    exports.qbx_core:Notify(target, ('Почта: %s перевёл вам %s на карту'):format(fromName, money(amount)), 'success', 8000)
    return true, ('%s отправлено: %s (комиссия %s)'):format(toName, money(amount), money(fee))
end)

AddEventHandler('playerDropped', function() last[source] = nil end)
