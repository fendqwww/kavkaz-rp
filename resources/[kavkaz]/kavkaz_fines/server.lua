-- штрафы. всё на сервере: проверка работы, дистанции, сумм; оплата и доля инспектору.

local byId = {}
for _, a in ipairs(Config.Articles) do byId[a.id] = a end

MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `kavkaz_fines` (
        `id` INT NOT NULL AUTO_INCREMENT, `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(64) NOT NULL DEFAULT '',
        `officer` VARCHAR(64) NOT NULL DEFAULT '', `officer_cid` VARCHAR(50) NULL DEFAULT NULL,
        `article` VARCHAR(16) NOT NULL, `note` VARCHAR(160) NULL DEFAULT NULL, `amount` INT NOT NULL,
        `doubled` TINYINT NOT NULL DEFAULT 0, `paid` TINYINT NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `paid_at` TIMESTAMP NULL DEFAULT NULL,
        PRIMARY KEY (`id`), KEY `idx_cid` (`citizenid`, `paid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end)

local function notify(src, text, kind) exports.qbx_core:Notify(src, text, kind or 'inform', 6000) end
local function money(n) return (tostring(math.floor(n)):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')) .. ' ₽' end

local function officerOk(src)
    local p = exports.qbx_core:GetPlayer(src)
    local job = p and p.PlayerData.job
    local min = job and Config.Jobs[job.name]
    return min ~= nil and job.onduty and (job.grade.level or 0) >= min, p
end

local function charName(p) return ('%s %s'):format(p.PlayerData.charinfo.firstname, p.PlayerData.charinfo.lastname) end

-- просроченные удваиваем один раз
local function doubleOld(cid)
    MySQL.update.await([[UPDATE kavkaz_fines SET amount = amount * 2, doubled = 1
        WHERE citizenid = ? AND paid = 0 AND doubled = 0 AND created_at < (NOW() - INTERVAL ? DAY)]], { cid, Config.DoubleAfterDays })
end

lib.callback.register('kavkaz_fines:canFine', function(src)
    local ok = officerOk(src)
    return ok and Config.Articles or nil
end)

RegisterNetEvent('kavkaz_fines:server:issue', function(target, articleId, amount, note)
    local src = source
    local ok, officer = officerOk(src)
    if not ok then return notify(src, 'штрафы выписывают сотрудники на смене', 'error') end
    target = tonumber(target)
    local a = byId[articleId or '']
    if not a or not target or target == src or not GetPlayerName(target) then return notify(src, 'неверные данные', 'error') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target))) > Config.Distance then return notify(src, 'нарушитель слишком далеко', 'error') end
    local victim = exports.qbx_core:GetPlayer(target)
    if not victim then return end
    amount = math.floor(tonumber(amount) or a.amount)
    if amount < 1 or amount > a.max then return notify(src, ('сумма по статье: до %s'):format(money(a.max)), 'error') end
    note = type(note) == 'string' and note:gsub('[\r\n]', ' '):sub(1, 160) or nil

    local id = MySQL.insert.await('INSERT INTO kavkaz_fines (citizenid, name, officer, officer_cid, article, note, amount) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { victim.PlayerData.citizenid, charName(victim), charName(officer), officer.PlayerData.citizenid, a.id, note, amount })
    notify(src, ('штраф №%d выписан: %s, %s'):format(id, a.label, money(amount)), 'success')
    notify(target, ('вам выписан штраф №%d: %s, %s. оплатить: /fines (через %d дн. сумма удвоится)'):format(id, a.label, money(amount), Config.DoubleAfterDays), 'error')
    print(('[kavkaz_fines] %s -> %s: %s %d'):format(GetPlayerName(src), GetPlayerName(target), a.id, amount))
end)

lib.callback.register('kavkaz_fines:list', function(src)
    local p = exports.qbx_core:GetPlayer(src)
    if not p then return {} end
    doubleOld(p.PlayerData.citizenid)
    local rows = MySQL.query.await([[SELECT id, article, note, amount, doubled, officer, DATE_FORMAT(created_at, '%d.%m %H:%i') AS t
        FROM kavkaz_fines WHERE citizenid = ? AND paid = 0 ORDER BY id]], { p.PlayerData.citizenid }) or {}
    for _, r in ipairs(rows) do r.label = byId[r.article] and byId[r.article].label or r.article end
    return rows
end)

lib.callback.register('kavkaz_fines:pay', function(src, id)
    local p = exports.qbx_core:GetPlayer(src)
    if not p then return false end
    local row = MySQL.single.await('SELECT * FROM kavkaz_fines WHERE id = ? AND citizenid = ? AND paid = 0', { tonumber(id), p.PlayerData.citizenid })
    if not row then return false, 'штраф не найден или уже оплачен' end
    if (exports.qbx_core:GetMoney(src, 'bank') or 0) < row.amount then return false, 'на карте не хватает денег' end
    if not exports.qbx_core:RemoveMoney(src, 'bank', row.amount, 'штраф №' .. row.id) then return false, 'оплата не прошла' end
    MySQL.update.await('UPDATE kavkaz_fines SET paid = 1, paid_at = NOW() WHERE id = ?', { row.id })
    local share = math.floor(row.amount * Config.OfficerShare)
    if share > 0 and row.officer_cid then pcall(function() exports.qbx_core:AddMoney(row.officer_cid, 'bank', share, 'доля за штраф №' .. row.id) end) end
    return true, ('штраф №%d оплачен: %s'):format(row.id, money(row.amount))
end)

-- для других ресурсов (пробивка ДПС, МРЭО): сколько неоплаченных
exports('GetUnpaid', function(citizenid)
    return MySQL.scalar.await('SELECT COUNT(*) FROM kavkaz_fines WHERE citizenid = ? AND paid = 0', { citizenid }) or 0
end)
