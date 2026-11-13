-- наказания: кик, бан, предупреждения, мут (чат + голос), админ-тюрьма.

local muted = {}  -- source -> unix-время конца мута
local jailed = {} -- source -> секунд осталось

local function fmtDate(ts)
    return os.date('%d.%m.%Y %H:%M', ts)
end

---------------------------------------------------------------------------
-- баны
---------------------------------------------------------------------------

local function findBan(ids)
    local now = os.time()
    return MySQL.single.await([[SELECT * FROM kavkaz_bans WHERE active = 1 AND (expires = 0 OR expires > ?)
        AND ((license IS NOT NULL AND license = ?) OR (fivem IS NOT NULL AND fivem = ?) OR (discord IS NOT NULL AND discord = ?))
        ORDER BY expires = 0 DESC, expires DESC LIMIT 1]], { now, ids.license or '-', ids.fivem or '-', ids.discord or '-' })
end

local function banText(ban)
    local untilText = ban.expires == 0 and 'навсегда' or ('до ' .. fmtDate(ban.expires))
    return ('KAVKAZ RP: ты забанен %s.\nПричина: %s\nАдмин: %s\nНомер бана: %d. Обжалование — на форуме.')
        :format(untilText, ban.reason, ban.admin, ban.id)
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update('KAVKAZ RP: проверяем аккаунт…')
    local ok, ban = pcall(findBan, Admin.ids(src))
    if ok and ban then
        deferrals.done(banText(ban))
        return
    end
    deferrals.done()
end)

-- days = 0 -> навсегда
function Admin.ban(src, target, days, reason)
    local level = Admin.dutyLevel(src)
    if src ~= 0 then
        local max = Config.BanMaxDays[level]
        if max == nil then return false, 'недостаточно прав для бана' end
        if max ~= 0 and (days == 0 or days > max) then
            return false, ('твой максимум — %d дней (навсегда — с 5 уровня)'):format(max)
        end
    end
    local ids = Admin.ids(target)
    local expires = days == 0 and 0 or os.time() + days * 86400
    local by = src == 0 and 'консоль' or GetPlayerName(src)
    local id = MySQL.insert.await('INSERT INTO kavkaz_bans (name, license, fivem, discord, reason, admin, expires) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { GetPlayerName(target) or '', ids.license, ids.fivem, ids.discord, reason, by, expires })
    Admin.log(src, 'ban', target, ('%s, %s'):format(days == 0 and 'навсегда' or (days .. ' дн.'), reason))
    DropPlayer(target, banText({ id = id or 0, expires = expires, reason = reason, admin = by }))
    TriggerClientEvent('chat:addMessage', -1, { color = { 220, 60, 60 }, args = { 'НАКАЗАНИЕ',
        ('%s забанен %s. Причина: %s'):format(GetPlayerName(target) or '?', days == 0 and 'навсегда' or ('на ' .. days .. ' дн.'), reason) } })
    return true
end

lib.addCommand('ban', {
    help = 'Забанить игрока (0 дней — навсегда, с 5 уровня)',
    params = {
        { name = 'target', type = 'playerId', help = 'ID игрока' },
        { name = 'days', type = 'number', help = 'дней, 0 = навсегда' },
        { name = 'reason', type = 'longString', help = 'причина' },
    },
}, function(src, args)
    if not Admin.can(src, 'ban') or not Admin.canTouch(src, args.target) then return end
    local ok, err = Admin.ban(src, args.target, math.max(0, math.floor(args.days)), args.reason)
    if not ok then Admin.notify(src, err, 'error') end
end)

-- /unban номер_бана  или  /unban ник  (снимает последний активный бан с таким ником)
lib.addCommand('unban', {
    help = 'Разбанить по номеру бана или нику',
    params = { { name = 'who', type = 'longString', help = 'номер бана или ник' } },
}, function(src, args)
    if not Admin.can(src, 'unban') then return end
    local banId = tonumber(args.who)
    local ban = banId
        and MySQL.single.await('SELECT * FROM kavkaz_bans WHERE id = ? AND active = 1', { banId })
        or MySQL.single.await('SELECT * FROM kavkaz_bans WHERE name = ? AND active = 1 ORDER BY id DESC LIMIT 1', { args.who })
    if not ban then return Admin.notify(src, 'активный бан не найден', 'error') end
    MySQL.update.await('UPDATE kavkaz_bans SET active = 0 WHERE id = ?', { ban.id })
    Admin.log(src, 'unban', ban.name, ('бан №%d (%s)'):format(ban.id, ban.reason))
    Admin.notify(src, ('%s разбанен (бан №%d)'):format(ban.name, ban.id), 'success')
end)

---------------------------------------------------------------------------
-- кик и предупреждения
---------------------------------------------------------------------------

lib.addCommand('kick', {
    help = 'Кикнуть игрока',
    params = {
        { name = 'target', type = 'playerId', help = 'ID игрока' },
        { name = 'reason', type = 'longString', help = 'причина' },
    },
}, function(src, args)
    if not Admin.can(src, 'kick') or not Admin.canTouch(src, args.target) then return end
    Admin.log(src, 'kick', args.target, args.reason)
    DropPlayer(args.target, ('KAVKAZ RP: тебя кикнул администратор.\nПричина: %s'):format(args.reason))
end)

function Admin.warn(src, target, reason)
    local license = Admin.license(target)
    if not license then return end
    local by = src == 0 and 'консоль' or GetPlayerName(src)
    MySQL.insert.await('INSERT INTO kavkaz_warns (license, reason, admin) VALUES (?, ?, ?)', { license, reason, by })
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM kavkaz_warns WHERE license = ? AND active = 1', { license })
    Admin.log(src, 'warn', target, ('%s (%d/%d)'):format(reason, count, Config.WarnsToBan))
    Admin.notify(target, ('предупреждение %d/%d: %s'):format(count, Config.WarnsToBan, reason), 'error')
    if count >= Config.WarnsToBan then
        MySQL.update.await('UPDATE kavkaz_warns SET active = 0 WHERE license = ?', { license })
        Admin.ban(0, target, Config.WarnBanDays, ('%d предупреждения (последнее: %s)'):format(Config.WarnsToBan, reason))
    end
end

lib.addCommand('warn', {
    help = 'Выдать предупреждение (3 = бан на 3 дня)',
    params = {
        { name = 'target', type = 'playerId', help = 'ID игрока' },
        { name = 'reason', type = 'longString', help = 'причина' },
    },
}, function(src, args)
    if not Admin.can(src, 'warn') or not Admin.canTouch(src, args.target) then return end
    Admin.warn(src, args.target, args.reason)
    Admin.notify(src, 'предупреждение выдано', 'success')
end)

---------------------------------------------------------------------------
-- мут: обычный чат и голос (pma-voice слушает MumbleSetPlayerMuted)
---------------------------------------------------------------------------

local function applyMute(src, untilTs)
    muted[src] = untilTs
    MumbleSetPlayerMuted(src, untilTs ~= nil)
    Player(src).state:set('kavkazMuted', untilTs ~= nil, true)
end

function Admin.mute(src, target, minutes, reason)
    local untilTs = os.time() + minutes * 60
    applyMute(target, untilTs)
    MySQL.insert.await([[INSERT INTO kavkaz_punish (license, kind, until_ts, reason, admin) VALUES (?, 'mute', ?, ?, ?)
        ON DUPLICATE KEY UPDATE until_ts = VALUES(until_ts), reason = VALUES(reason), admin = VALUES(admin)]],
        { Admin.license(target), untilTs, reason, src == 0 and 'консоль' or GetPlayerName(src) })
    Admin.log(src, 'mute', target, ('%d мин: %s'):format(minutes, reason))
    Admin.notify(target, ('тебе выдан мут на %d мин (чат и голос). причина: %s'):format(minutes, reason), 'error')
end

function Admin.unmute(src, target)
    applyMute(target, nil)
    MySQL.update.await("DELETE FROM kavkaz_punish WHERE license = ? AND kind = 'mute'", { Admin.license(target) })
    if src then Admin.log(src, 'unmute', target) end
    Admin.notify(target, 'мут снят', 'success')
end

lib.addCommand('mute', {
    help = 'Мут чата и голоса',
    params = {
        { name = 'target', type = 'playerId', help = 'ID игрока' },
        { name = 'minutes', type = 'number', help = 'минут' },
        { name = 'reason', type = 'longString', help = 'причина' },
    },
}, function(src, args)
    if not Admin.can(src, 'mute') or not Admin.canTouch(src, args.target) then return end
    local minutes = math.floor(args.minutes)
    if minutes < 1 or minutes > Config.MuteMaxMinutes then
        return Admin.notify(src, ('от 1 до %d минут'):format(Config.MuteMaxMinutes), 'error')
    end
    Admin.mute(src, args.target, minutes, args.reason)
    Admin.notify(src, 'мут выдан', 'success')
end)

lib.addCommand('unmute', {
    help = 'Снять мут',
    params = { { name = 'target', type = 'playerId', help = 'ID игрока' } },
}, function(src, args)
    if not Admin.can(src, 'mute') then return end
    Admin.unmute(src, args.target)
    Admin.notify(src, 'мут снят', 'success')
end)

-- обычные сообщения чата от замученного не проходят
AddEventHandler('chatMessage', function(src)
    if muted[src] then
        CancelEvent()
        Admin.notify(src, ('у тебя мут ещё %d мин'):format(math.ceil((muted[src] - os.time()) / 60)), 'error')
    end
end)

exports('IsMuted', function(src) return muted[src] ~= nil end)

---------------------------------------------------------------------------
-- админ-тюрьма (время идёт только пока игрок в игре)
---------------------------------------------------------------------------

local function saveJail(src)
    local license = Admin.license(src)
    if not license then return end
    if jailed[src] and jailed[src] > 0 then
        MySQL.update("UPDATE kavkaz_punish SET seconds_left = ? WHERE license = ? AND kind = 'jail'", { jailed[src], license })
    end
end

local function putInJail(target, seconds)
    jailed[target] = seconds
    Player(target).state:set('kavkazJail', true, true)
    local ped = GetPlayerPed(target)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then TaskLeaveVehicle(ped, veh, 16) end
    TriggerClientEvent('kavkaz_admin:client:jail', target, seconds)
end

function Admin.release(src, target)
    if not jailed[target] then return false end
    jailed[target] = nil
    Player(target).state:set('kavkazJail', false, true)
    MySQL.update.await("DELETE FROM kavkaz_punish WHERE license = ? AND kind = 'jail'", { Admin.license(target) })
    local r = Config.Jail.release
    SetEntityCoords(GetPlayerPed(target), r.x, r.y, r.z, false, false, false, false)
    SetEntityHeading(GetPlayerPed(target), r.w)
    TriggerClientEvent('kavkaz_admin:client:unjail', target)
    Admin.notify(target, 'ты вышел из админ-тюрьмы. не нарушай больше', 'success')
    if src then Admin.log(src, 'unjail', target) end
    return true
end

function Admin.jail(src, target, minutes, reason)
    local level = Admin.dutyLevel(src)
    local max = Config.JailMaxMinutes[level] or 0
    if src ~= 0 and minutes > max then return false, ('твой максимум — %d мин'):format(max) end
    if minutes < 1 then return false, 'минимум 1 минута' end
    MySQL.insert.await([[INSERT INTO kavkaz_punish (license, kind, seconds_left, reason, admin) VALUES (?, 'jail', ?, ?, ?)
        ON DUPLICATE KEY UPDATE seconds_left = VALUES(seconds_left), reason = VALUES(reason), admin = VALUES(admin)]],
        { Admin.license(target), minutes * 60, reason, src == 0 and 'консоль' or GetPlayerName(src) })
    putInJail(target, minutes * 60)
    Admin.log(src, 'ajail', target, ('%d мин: %s'):format(minutes, reason))
    Admin.notify(target, ('админ-тюрьма на %d мин. причина: %s'):format(minutes, reason), 'error')
    TriggerClientEvent('chat:addMessage', -1, { color = { 220, 60, 60 }, args = { 'НАКАЗАНИЕ',
        ('%s посажен в админ-тюрьму на %d мин. Причина: %s'):format(GetPlayerName(target) or '?', minutes, reason) } })
    return true
end

lib.addCommand('ajail', {
    help = 'Админ-тюрьма',
    params = {
        { name = 'target', type = 'playerId', help = 'ID игрока' },
        { name = 'minutes', type = 'number', help = 'минут' },
        { name = 'reason', type = 'longString', help = 'причина' },
    },
}, function(src, args)
    if not Admin.can(src, 'ajail') or not Admin.canTouch(src, args.target) then return end
    local ok, err = Admin.jail(src, args.target, math.floor(args.minutes), args.reason)
    Admin.notify(src, ok and 'игрок в тюрьме' or err, ok and 'success' or 'error')
end)

lib.addCommand('unjail', {
    help = 'Выпустить из админ-тюрьмы',
    params = { { name = 'target', type = 'playerId', help = 'ID игрока' } },
}, function(src, args)
    if not Admin.can(src, 'ajail') then return end
    Admin.notify(src, Admin.release(src, args.target) and 'выпущен' or 'игрок не в тюрьме', 'inform')
end)

-- отсчёт срока и защита от побега (сервер сам проверяет дистанцию, клиенту не доверяем)
CreateThread(function()
    local tick = 0
    while true do
        Wait(1000)
        tick = tick + 1
        local now = os.time()
        for src, left in pairs(jailed) do
            if not GetPlayerName(src) then
                jailed[src] = nil
            else
                left = left - 1
                jailed[src] = left
                if left <= 0 then
                    Admin.release(nil, src)
                elseif tick % 5 == 0 then
                    local c = Config.Jail.coords
                    local pos = GetEntityCoords(GetPlayerPed(src))
                    if #(pos - c.xyz) > Config.Jail.radius + 10.0 then
                        SetEntityCoords(GetPlayerPed(src), c.x, c.y, c.z, false, false, false, false)
                    end
                end
                if tick % 60 == 0 then saveJail(src) end
            end
        end
        for src, untilTs in pairs(muted) do
            if not GetPlayerName(src) then muted[src] = nil
            elseif now >= untilTs then Admin.unmute(nil, src) end
        end
    end
end)

-- при входе персонажа возвращаем недосиженный срок и мут
local function restore(src)
    local license = Admin.license(src)
    if not license then return end
    local rows = MySQL.query.await('SELECT * FROM kavkaz_punish WHERE license = ?', { license })
    for _, row in ipairs(rows or {}) do
        if row.kind == 'mute' then
            if row.until_ts > os.time() then applyMute(src, row.until_ts)
            else MySQL.update("DELETE FROM kavkaz_punish WHERE license = ? AND kind = 'mute'", { license }) end
        elseif row.kind == 'jail' and row.seconds_left > 0 then
            putInJail(src, row.seconds_left)
            Admin.notify(src, ('ты не досидел админ-тюрьму: осталось %d мин'):format(math.ceil(row.seconds_left / 60)), 'error')
        end
    end
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    restore(player.PlayerData.source)
end)

AddEventHandler('kavkaz_admin:server:ready', function()
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if exports.qbx_core:GetPlayer(src) then restore(src) end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    saveJail(src)
    jailed[src] = nil
    muted[src] = nil
end)

exports('IsJailed', function(src) return jailed[src] ~= nil end)
