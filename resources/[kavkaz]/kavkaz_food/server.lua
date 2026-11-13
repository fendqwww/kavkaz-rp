-- KAVKAZ RP: покупка еды. всё проверяется здесь: место, меню, цена, дистанция, деньги, место в инвентаре

local byId = {}
for _, p in ipairs(Config.Places) do byId[p.id] = p end

local lastBuy = {}

lib.callback.register('kavkaz_food:buy', function(src, placeId, item, count)
    local now = GetGameTimer()
    if lastBuy[src] and now - lastBuy[src] < 1000 then return false, 'не так быстро' end
    lastBuy[src] = now

    local place = type(placeId) == 'string' and byId[placeId]
    if not place then return false, 'такого места нет' end
    local price = type(item) == 'string' and place.menu[item]
    if not price then return false, 'этого здесь не продают' end
    count = math.floor(tonumber(count) or 0)
    if count < 1 or count > Config.MaxPerBuy then return false, 'неверное количество' end

    local ped = GetPlayerPed(src)
    local c = place.seller.coords
    if #(GetEntityCoords(ped) - vec3(c.x, c.y, c.z)) > Config.Distance + 2.0 then
        return false, 'подойди к продавцу'
    end

    if not exports.ox_inventory:CanCarryItem(src, item, count) then
        return false, 'в карманах нет места'
    end

    local total = price * count
    local reason = 'еда: ' .. place.label
    local paid = exports.qbx_core:RemoveMoney(src, 'cash', total, reason)
        or exports.qbx_core:RemoveMoney(src, 'bank', total, reason)
    if not paid then return false, ('не хватает денег: нужно %d ₽'):format(total) end

    if not exports.ox_inventory:AddItem(src, item, count) then
        exports.qbx_core:AddMoney(src, 'cash', total, 'возврат: ' .. reason)
        return false, 'не получилось отдать заказ, деньги вернули'
    end

    local label = (Config.Items[item] and Config.Items[item].label) or item
    return true, ('%s × %d — %d ₽. приятного аппетита'):format(label, count, total)
end)

AddEventHandler('playerDropped', function() lastBuy[source] = nil end)
