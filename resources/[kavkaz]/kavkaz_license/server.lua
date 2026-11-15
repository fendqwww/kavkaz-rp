-- KAVKAZ RP: водительские права — сервер. вся логика здесь: права, сроки, проверка ДПС.
-- хранение: metadata.licences.driver (есть / нет) и metadata.driver_ban = { untilTs, reason, by } — лишение.

local function notify(src, text, kind) exports.qbx_core:Notify(src, text, kind or 'inform', 7000) end
local function charName(p) return ('%s %s'):format(p.PlayerData.charinfo.firstname, p.PlayerData.charinfo.lastname) end
local function dateStr(ts) return os.date('%d.%m.%Y %H:%M', ts) end

local function officerOk(src)
    local p = exports.qbx_core:GetPlayer(src)
    local job = p and p.PlayerData.job
    local min = job and Config.Jobs[job.name]
    return min ~= nil and job.onduty and (job.grade.level or 0) >= min, p
end

local function near(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    return pa ~= 0 and pb ~= 0 and #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= Config.Distance
end

local function adminOk(src)
    local ok, lvl = pcall(function() return exports.kavkaz_admin:GetDutyLevel(src) end)
    return ok and (lvl or 0) >= Config.AdminLevel
end

-- текущее состояние прав персонажа
local function status(p)
    local md = p.PlayerData.metadata or {}
    local lic = md.licences or {}
    local ban = md.driver_ban
    if ban and ban.untilTs and ban.untilTs > os.time() then
        return 'banned', ban
    end
    if lic.driver then return 'ok' end
    return 'none'
end

local function setDriver(p, value)
    local lic = p.PlayerData.metadata.licences or {}
    lic.driver = value
    p.Functions.SetMetaData('licences', lic)
end

local function giveCard(src)
    local meta
    pcall(function() meta = exports.qbx_idcard:GetMetaLicense(src, { 'driver_license' }) end)
    if type(meta) ~= 'table' then
        local p = exports.qbx_core:GetPlayer(src)
        local ci = p and p.PlayerData.charinfo or {}
        meta = { cardtype = 'driver_license', citizenid = p and p.PlayerData.citizenid, firstname = ci.firstname, lastname = ci.lastname, birthdate = ci.birthdate }
    end
    pcall(function() exports.ox_inventory:AddItem(src, 'driver_license', 1, meta) end)
end

local function takeCard(src)
    pcall(function()
        local n = exports.ox_inventory:Search(src, 'count', 'driver_license') or 0
        if n > 0 then exports.ox_inventory:RemoveItem(src, 'driver_license', n) end
    end)
end

-- срок лишения вышел — права возвращаются сами (при входе и раз в минуту)
local function checkReturn(src)
    local p = exports.qbx_core:GetPlayer(src)
    if not p then return end
    local ban = p.PlayerData.metadata.driver_ban
    if ban and ban.untilTs and ban.untilTs <= os.time() then
        p.Functions.SetMetaData('driver_ban', nil)
        setDriver(p, true)
        giveCard(src)
        notify(src, 'Срок лишения прав закончился — права вернули, они снова в кармане', 'success')
    end
end

AddEventHandler('QBCore:Server:OnPlayerLoaded', function() local src = source SetTimeout(5000, function() checkReturn(src) end) end)
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function() local src = source SetTimeout(5000, function() checkReturn(src) end) end)
CreateThread(function()
    while true do
        Wait(60000)
        for _, src in ipairs(GetPlayers()) do checkReturn(tonumber(src)) end
    end
end)

-- клиент спрашивает при посадке за руль: есть ли права
lib.callback.register('kavkaz_license:status', function(src)
    local p = exports.qbx_core:GetPlayer(src)
    if not p then return 'ok' end
    local st, ban = status(p)
    return st, ban and ban.untilTs and dateStr(ban.untilTs) or nil
end)

local function describe(p)
    local st, ban = status(p)
    if st == 'ok' then return 'права категории B есть' end
    if st == 'banned' then return ('лишён прав до %s (%s)'):format(dateStr(ban.untilTs), ban.reason or 'без причины') end
    return 'прав нет'
end

-- /prava — свои права; /prava ID — проверить водителя (ДПС на смене, рядом)
RegisterCommand('prava', function(src, args)
    if src == 0 then return end
    local me = exports.qbx_core:GetPlayer(src)
    if not me then return end
    local target = tonumber(args[1])
    if not target or target == src then
        return notify(src, 'Твои права: ' .. describe(me))
    end
    local ok = officerOk(src)
    if not ok then return notify(src, 'Проверять права может только сотрудник ДПС на смене', 'error') end
    local p = exports.qbx_core:GetPlayer(target)
    if not p or not near(src, target) then return notify(src, 'Водитель должен быть рядом', 'error') end
    notify(src, ('%s [%d]: %s'):format(charName(p), target, describe(p)))
    notify(target, 'Инспектор проверил твои права по базе')
end, false)

-- /lishit ID дни причина — лишить прав (ДПС на смене, рядом). права-карточка изымается.
RegisterCommand('lishit', function(src, args)
    if src == 0 then return end
    local ok, officer = officerOk(src)
    if not ok then return notify(src, 'Лишать прав может только сотрудник ДПС на смене', 'error') end
    local target, days = tonumber(args[1]), math.floor(tonumber(args[2]) or 0)
    local reason = table.concat(args, ' ', 3)
    if not target or days < 1 or days > Config.MaxDays or reason == '' then
        return notify(src, ('Как: /lishit ID дни причина (срок 1–%d дней)'):format(Config.MaxDays), 'error')
    end
    local p = exports.qbx_core:GetPlayer(target)
    if not p or not near(src, target) then return notify(src, 'Водитель должен быть рядом', 'error') end
    local untilTs = os.time() + days * 86400
    p.Functions.SetMetaData('driver_ban', { untilTs = untilTs, reason = reason:sub(1, 120), by = charName(officer) })
    setDriver(p, false)
    takeCard(target)
    notify(src, ('%s лишён прав до %s'):format(charName(p), dateStr(untilTs)), 'success')
    notify(target, ('Тебя лишили прав до %s: %s. Права изъяты, вернутся сами после срока'):format(dateStr(untilTs), reason), 'error')
    pcall(function() exports.kavkaz_admin:Log(src, 'lishit', target, ('%d дн.: %s'):format(days, reason)) end)
end, false)

-- админам: выдать / забрать права (для тестов и разбора жалоб)
RegisterCommand('agivelicense', function(src, args)
    if src ~= 0 and not adminOk(src) then return notify(src, 'Нет доступа', 'error') end
    local target = tonumber(args[1])
    local p = target and exports.qbx_core:GetPlayer(target)
    if not p then return src ~= 0 and notify(src, 'Нет игрока с таким ID', 'error') end
    p.Functions.SetMetaData('driver_ban', nil)
    setDriver(p, true)
    giveCard(target)
    notify(target, 'Администратор выдал тебе водительские права', 'success')
    if src ~= 0 then notify(src, 'Права выданы', 'success') pcall(function() exports.kavkaz_admin:Log(src, 'agivelicense', target, '') end) end
end, false)

RegisterCommand('atakelicense', function(src, args)
    if src ~= 0 and not adminOk(src) then return notify(src, 'Нет доступа', 'error') end
    local target = tonumber(args[1])
    local p = target and exports.qbx_core:GetPlayer(target)
    if not p then return src ~= 0 and notify(src, 'Нет игрока с таким ID', 'error') end
    p.Functions.SetMetaData('driver_ban', nil)
    setDriver(p, false)
    takeCard(target)
    notify(target, 'Администратор забрал у тебя водительские права', 'error')
    if src ~= 0 then notify(src, 'Права забраны', 'success') pcall(function() exports.kavkaz_admin:Log(src, 'atakelicense', target, '') end) end
end, false)

exports('HasLicense', function(src)
    local p = exports.qbx_core:GetPlayer(src)
    return p ~= nil and status(p) == 'ok'
end)
