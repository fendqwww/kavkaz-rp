-- репорты игроков и данные для панели F10.

local reports, nextId = {}, 0
local closed = {} -- закрытые репорты, ждущие оценки игрока (5 минут)
local lastReport = {} -- source -> время последнего репорта (антиспам)
local REPORT_COOLDOWN = 60

local function reportLine(r)
    return ('№%d от %s: %s'):format(r.id, Admin.label(r.src), r.text)
end

-- /report текст — любой игрок
lib.addCommand('report', {
    help = 'Написать администрации (вопрос или жалоба)',
    params = { { name = 'text', type = 'longString', help = 'что случилось' } },
}, function(src, args)
    if src == 0 then return end
    local now = os.time()
    if lastReport[src] and now - lastReport[src] < REPORT_COOLDOWN then
        return Admin.notify(src, ('следующий репорт можно через %d сек'):format(REPORT_COOLDOWN - (now - lastReport[src])), 'error')
    end
    lastReport[src] = now
    nextId = nextId + 1
    local r = { id = nextId, src = src, text = args.text:sub(1, 300), time = now }
    reports[r.id] = r

    local admins = Admin.onDutyList(1)
    for _, id in ipairs(admins) do
        Admin.chat(id, ('РЕПОРТ %s  ·  /reports'):format(reportLine(r)), { 255, 90, 90 })
        TriggerClientEvent('kavkaz_admin:client:newReport', id, r.id, GetPlayerName(src), r.text)
    end
    Admin.notify(src, #admins > 0 and ('репорт №%d отправлен, админов на смене: %d'):format(r.id, #admins)
        or ('репорт №%d отправлен. сейчас админов на смене нет — ответят, как только зайдут'):format(r.id), 'success')
end)

lib.callback.register('kavkaz_admin:getReports', function(src)
    if not Admin.can(src, 'reports') then return nil end
    local list = {}
    for _, r in pairs(reports) do
        list[#list + 1] = { id = r.id, from = Admin.label(r.src), src = r.src, text = r.text,
            ago = (os.time() - r.time) // 60, takenBy = r.takenBy and Admin.label(r.takenBy) }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end)

lib.callback.register('kavkaz_admin:reportAction', function(src, id, action)
    if not Admin.can(src, 'reports') then return false end
    local r = reports[id]
    if not r then return false, 'репорт уже закрыт' end
    if action == 'take' then
        if r.takenBy and r.takenBy ~= src and Admin.duty[r.takenBy] then return false, 'репорт уже взял ' .. Admin.label(r.takenBy) end
        r.takenBy = src
        Admin.notify(r.src, ('твой репорт №%d взял %s'):format(id, GetPlayerName(src)), 'inform')
        Admin.broadcast(('%s взял репорт №%d'):format(Admin.label(src), id), 1)
        return true
    elseif action == 'close' then
        reports[id] = nil
        local license = Admin.license(src)
        if license then MySQL.update('UPDATE kavkaz_admins SET reports_done = reports_done + 1 WHERE license = ?', { license }) end
        Admin.log(src, 'report_close', GetPlayerName(r.src) and r.src or nil, r.text)
        if GetPlayerName(r.src) then
            closed[id] = { admin = src, player = r.src, untilTs = os.time() + 300 }
            Admin.notify(r.src, ('репорт №%d закрыл %s'):format(id, GetPlayerName(src)), 'inform')
            TriggerClientEvent('kavkaz_admin:client:rateReport', r.src, id, GetPlayerName(src))
        end
        return true
    end
    return false
end)

-- оценка 1–5 после закрытия репорта
RegisterNetEvent('kavkaz_admin:server:rate', function(id, stars)
    local src = source
    local c = closed[id]
    if not c or c.player ~= src or os.time() > c.untilTs then return end
    closed[id] = nil
    stars = math.floor(tonumber(stars) or 0)
    if stars < 1 or stars > 5 then return end
    Admin.log(src, 'report_rate', GetPlayerName(c.admin) and c.admin or nil, ('репорт №%d: %d★'):format(id, stars))
    if GetPlayerName(c.admin) then Admin.notify(c.admin, ('оценка за репорт №%d: %d из 5'):format(id, stars), 'inform') end
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastReport[src] = nil
    for id, r in pairs(reports) do
        if r.src == src then reports[id] = nil end
    end
end)

---------------------------------------------------------------------------
-- данные для панели
---------------------------------------------------------------------------

lib.callback.register('kavkaz_admin:getPlayers', function(src)
    if not Admin.can(src, 'tpto', true) then return nil end
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local pid = tonumber(id)
        local player = exports.qbx_core:GetPlayer(pid)
        local char = player and ('%s %s'):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname)
        list[#list + 1] = {
            id = pid, name = GetPlayerName(pid), char = char, ping = GetPlayerPing(pid),
            admin = Admin.duty[pid] and Admin.duty[pid].level or 0,
            job = player and player.PlayerData.job.label,
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end)

lib.callback.register('kavkaz_admin:getCard', function(src, target)
    if not Admin.can(src, 'check') then return nil end
    target = tonumber(target)
    if not target or not GetPlayerName(target) then return nil end
    Admin.log(src, 'check', target)
    return Admin.card(target)
end)

-- логи: фильтр по тексту (ник админа, игрока или действие)
lib.callback.register('kavkaz_admin:getLogs', function(src, filter)
    if not Admin.can(src, 'logs') then return nil end
    filter = type(filter) == 'string' and filter:sub(1, 64) or ''
    if filter ~= '' then
        local like = '%' .. filter:gsub('[%%_]', '') .. '%'
        return MySQL.query.await([[SELECT id, admin, action, target, details, DATE_FORMAT(created_at, '%d.%m %H:%i') AS t
            FROM kavkaz_admin_log WHERE admin LIKE ? OR target LIKE ? OR action LIKE ? ORDER BY id DESC LIMIT ?]],
            { like, like, like, Config.LogsInPanel })
    end
    return MySQL.query.await([[SELECT id, admin, action, target, details, DATE_FORMAT(created_at, '%d.%m %H:%i') AS t
        FROM kavkaz_admin_log ORDER BY id DESC LIMIT ?]], { Config.LogsInPanel })
end)

-- статистика админов (часы смен, репорты) — для отчёта за неделю
lib.callback.register('kavkaz_admin:getStaff', function(src)
    if not Admin.can(src, 'logs') then return nil end
    return MySQL.query.await('SELECT name, level, duty_seconds, reports_done FROM kavkaz_admins WHERE level > 0 ORDER BY level DESC, duty_seconds DESC')
end)
