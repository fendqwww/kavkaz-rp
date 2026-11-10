-- ядро админки: уровни, смена (/alogin с PIN), проверка прав, логи.
-- общий для всех серверных файлов ресурса объект — Admin.

Admin = {
    rows = {},  -- license -> строка kavkaz_admins
    duty = {},  -- source -> { level, since }
}

local webhook = GetConvar('kavkaz_admin_webhook', '') -- задаётся в secrets.cfg, в git не попадает

---------------------------------------------------------------------------
-- база
---------------------------------------------------------------------------

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `kavkaz_admins` (
        `license` VARCHAR(60) NOT NULL, `name` VARCHAR(64) NOT NULL DEFAULT '',
        `level` TINYINT NOT NULL DEFAULT 0, `pin_hash` VARCHAR(100) NULL DEFAULT NULL,
        `pin_fails` TINYINT NOT NULL DEFAULT 0, `locked_until` INT NOT NULL DEFAULT 0,
        `duty_seconds` INT NOT NULL DEFAULT 0, `reports_done` INT NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`license`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `kavkaz_admin_log` (
        `id` INT NOT NULL AUTO_INCREMENT, `admin` VARCHAR(64) NOT NULL DEFAULT '',
        `admin_license` VARCHAR(60) NULL DEFAULT NULL, `action` VARCHAR(32) NOT NULL,
        `target` VARCHAR(64) NULL DEFAULT NULL, `target_license` VARCHAR(60) NULL DEFAULT NULL,
        `details` VARCHAR(512) NULL DEFAULT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `idx_admin` (`admin_license`), KEY `idx_target` (`target_license`), KEY `idx_action` (`action`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `kavkaz_bans` (
        `id` INT NOT NULL AUTO_INCREMENT, `name` VARCHAR(64) NOT NULL DEFAULT '',
        `license` VARCHAR(60) NULL DEFAULT NULL, `fivem` VARCHAR(60) NULL DEFAULT NULL, `discord` VARCHAR(60) NULL DEFAULT NULL,
        `reason` VARCHAR(255) NOT NULL DEFAULT '', `admin` VARCHAR(64) NOT NULL DEFAULT '',
        `expires` INT NOT NULL DEFAULT 0, `active` TINYINT NOT NULL DEFAULT 1,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `idx_license` (`license`), KEY `idx_fivem` (`fivem`), KEY `idx_discord` (`discord`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `kavkaz_warns` (
        `id` INT NOT NULL AUTO_INCREMENT, `license` VARCHAR(60) NOT NULL,
        `reason` VARCHAR(255) NOT NULL DEFAULT '', `admin` VARCHAR(64) NOT NULL DEFAULT '',
        `active` TINYINT NOT NULL DEFAULT 1, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `idx_license` (`license`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `kavkaz_punish` (
        `license` VARCHAR(60) NOT NULL, `kind` VARCHAR(8) NOT NULL,
        `until_ts` INT NOT NULL DEFAULT 0, `seconds_left` INT NOT NULL DEFAULT 0,
        `reason` VARCHAR(255) NOT NULL DEFAULT '', `admin` VARCHAR(64) NOT NULL DEFAULT '',
        PRIMARY KEY (`license`, `kind`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

---------------------------------------------------------------------------
-- игроки и идентификаторы
---------------------------------------------------------------------------

function Admin.ids(src)
    return {
        license = GetPlayerIdentifierByType(src, 'license'),
        fivem = GetPlayerIdentifierByType(src, 'fivem'),
        discord = GetPlayerIdentifierByType(src, 'discord'),
    }
end

function Admin.license(src)
    return GetPlayerIdentifierByType(src, 'license')
end

-- «Ник [ID]» для логов и сообщений
function Admin.label(src)
    if src == 0 then return 'консоль' end
    return ('%s [%d]'):format(GetPlayerName(src) or '?', src)
end

function Admin.notify(src, text, kind)
    if src == 0 then
        print(('[kavkaz_admin] %s'):format(text))
        return
    end
    exports.qbx_core:Notify(src, text, kind or 'inform', 6000)
end

function Admin.chat(src, text, color)
    TriggerClientEvent('chat:addMessage', src, { color = color or { 255, 170, 60 }, multiline = true, args = { 'АДМИН', text } })
end

---------------------------------------------------------------------------
-- уровни
---------------------------------------------------------------------------

function Admin.isFounder(src)
    return src ~= 0 and IsPlayerAceAllowed(src, Config.FounderAce)
end

-- уровень по базе (или 6 для основателя), независимо от смены
function Admin.getLevel(src)
    if src == 0 then return Config.MaxLevel end
    if Admin.isFounder(src) then return Config.MaxLevel end
    local row = Admin.rows[Admin.license(src) or '']
    return row and row.level or 0
end

-- уровень на смене (0 — не на смене)
function Admin.dutyLevel(src)
    if src == 0 then return Config.MaxLevel end
    local d = Admin.duty[src]
    return d and d.level or 0
end

function Admin.levelName(level)
    return Config.Levels[level] or 'игрок'
end

-- проверка права. консоль сервера может всё.
function Admin.can(src, perm, silent)
    if src == 0 then return true end
    local need = Config.Perms[perm] or Config.MaxLevel
    local have = Admin.dutyLevel(src)
    if have >= need then return true end
    if not silent then
        if have == 0 and Admin.getLevel(src) > 0 then
            Admin.notify(src, 'ты не на смене: сначала /alogin', 'error')
        else
            Admin.notify(src, 'недостаточно прав', 'error')
        end
    end
    return false
end

-- можно ли действовать против цели: нельзя наказывать админа своего уровня и выше
function Admin.canTouch(src, target)
    if src == 0 or src == target then return true end
    if Admin.getLevel(target) >= Admin.getLevel(src) then
        Admin.notify(src, 'нельзя: у игрока такой же или более высокий админ-уровень', 'error')
        return false
    end
    return true
end

-- все админы на смене с уровнем >= minLevel
function Admin.onDutyList(minLevel)
    local list = {}
    for src, d in pairs(Admin.duty) do
        if d.level >= (minLevel or 1) then list[#list + 1] = src end
    end
    return list
end

-- сообщение всем админам на смене
function Admin.broadcast(text, minLevel)
    for _, src in ipairs(Admin.onDutyList(minLevel)) do
        Admin.chat(src, text, { 255, 120, 60 })
    end
    print(('[kavkaz_admin] %s'):format(text))
end

local function setStateLevel(src, level)
    Player(src).state:set('kavkazAdmin', level, true)
end

-- админ-уровень вне смены: по нему kavkaz_help показывает подсказки /alogin и /apin только админам
local function setStateRank(src)
    Player(src).state:set('kavkazAdminRank', Admin.getLevel(src), true)
end

---------------------------------------------------------------------------
-- лог: база + консоль + закрытый канал Discord
---------------------------------------------------------------------------

local function sendDiscord(text)
    if webhook == '' then return end
    PerformHttpRequest(webhook, function() end, 'POST',
        json.encode({ username = 'KAVKAZ админ-лог', content = text:sub(1, 1900) }),
        { ['Content-Type'] = 'application/json' })
end
Admin.discord = sendDiscord

function Admin.log(src, action, target, details)
    local adminName = Admin.label(src)
    local adminLicense = src ~= 0 and Admin.license(src) or nil
    local targetName, targetLicense
    if type(target) == 'number' then
        targetName, targetLicense = Admin.label(target), Admin.license(target)
    elseif type(target) == 'string' then
        targetName = target
    end
    details = details and tostring(details):sub(1, 512) or nil

    MySQL.insert('INSERT INTO kavkaz_admin_log (admin, admin_license, action, target, target_license, details) VALUES (?, ?, ?, ?, ?, ?)',
        { adminName, adminLicense, action, targetName, targetLicense, details })

    local line = ('**%s** → `%s`%s%s'):format(adminName, action,
        targetName and (' → ' .. targetName) or '', details and (': ' .. details) or '')
    print(('[kavkaz_admin] %s'):format(line:gsub('%*', ''):gsub('`', '')))
    sendDiscord(line)
end

---------------------------------------------------------------------------
-- загрузка админов
---------------------------------------------------------------------------

local function loadRow(src)
    local license = Admin.license(src)
    if not license then return end
    local row = MySQL.single.await('SELECT * FROM kavkaz_admins WHERE license = ?', { license })
    Admin.rows[license] = row
    if row and row.name ~= GetPlayerName(src) then
        MySQL.update('UPDATE kavkaz_admins SET name = ? WHERE license = ?', { GetPlayerName(src) or '', license })
    end
end

-- строка в базе нужна, чтобы хранить PIN и часы; у основателя её может не быть — создаём
local function ensureRow(src)
    local license = Admin.license(src)
    if not license then return nil end
    if not Admin.rows[license] then
        local level = Admin.getLevel(src)
        MySQL.insert.await('INSERT IGNORE INTO kavkaz_admins (license, name, level) VALUES (?, ?, ?)',
            { license, GetPlayerName(src) or '', level })
        loadRow(src)
    end
    return Admin.rows[license]
end

---------------------------------------------------------------------------
-- смена: /alogin, /alogout, PIN
---------------------------------------------------------------------------

local function isPin(value)
    return type(value) == 'string' and #value == Config.PinLength and value:match('^%d+$') ~= nil
end

local function startDuty(src, level)
    Admin.duty[src] = { level = level, since = os.time() }
    setStateLevel(src, level)
    Admin.broadcast(('%s %s заступил на смену'):format(Admin.levelName(level), GetPlayerName(src)), 1)
    Admin.log(src, 'alogin', nil, Admin.levelName(level))
end

local function stopDuty(src, why)
    local d = Admin.duty[src]
    if not d then return end
    Admin.duty[src] = nil
    local seconds = os.time() - d.since
    local license = Admin.license(src)
    if license then
        MySQL.update('UPDATE kavkaz_admins SET duty_seconds = duty_seconds + ? WHERE license = ?', { seconds, license })
    end
    if GetPlayerName(src) then setStateLevel(src, 0) end
    TriggerClientEvent('kavkaz_admin:client:dutyOff', src)
    Admin.broadcast(('%s %s сдал смену (%d мин)'):format(Admin.levelName(d.level), GetPlayerName(src) or '?', seconds // 60), 1)
    Admin.log(src, 'alogout', nil, why)
end
Admin.stopDuty = stopDuty

-- что показывать на клиенте: ввод PIN или создание нового
lib.callback.register('kavkaz_admin:pinStatus', function(src)
    local level = Admin.getLevel(src)
    if level <= 0 then return { error = 'ты не администратор' } end
    if Admin.duty[src] then return { error = 'ты уже на смене' } end
    local row = ensureRow(src)
    if not row then return { error = 'не удалось определить лицензию Rockstar' } end
    if row.locked_until > os.time() then
        return { error = ('вход заблокирован ещё на %d мин'):format(math.ceil((row.locked_until - os.time()) / 60)) }
    end
    return { hasPin = row.pin_hash ~= nil, level = level, levelName = Admin.levelName(level) }
end)

lib.callback.register('kavkaz_admin:login', function(src, pin, newPin)
    local level = Admin.getLevel(src)
    if level <= 0 or Admin.duty[src] then return false, 'нельзя' end
    local row = ensureRow(src)
    if not row then return false, 'нет лицензии' end
    if row.locked_until > os.time() then return false, 'вход временно заблокирован' end

    -- первый вход: создаём PIN
    if not row.pin_hash then
        if not isPin(pin) or pin ~= newPin then
            return false, ('PIN — ровно %d цифр, оба поля должны совпадать'):format(Config.PinLength)
        end
        local hash = GetPasswordHash(pin)
        MySQL.update.await('UPDATE kavkaz_admins SET pin_hash = ?, pin_fails = 0 WHERE license = ?', { hash, row.license })
        row.pin_hash = hash
        Admin.log(src, 'apin', nil, 'создан PIN')
        startDuty(src, level)
        return true
    end

    if isPin(pin) and VerifyPasswordHash(pin, row.pin_hash) then
        row.pin_fails = 0
        MySQL.update('UPDATE kavkaz_admins SET pin_fails = 0 WHERE license = ?', { row.license })
        startDuty(src, level)
        return true
    end

    row.pin_fails = row.pin_fails + 1
    if row.pin_fails >= Config.PinMaxFails then
        row.pin_fails = 0
        row.locked_until = os.time() + Config.PinLockMinutes * 60
        MySQL.update('UPDATE kavkaz_admins SET pin_fails = 0, locked_until = ? WHERE license = ?', { row.locked_until, row.license })
        Admin.log(src, 'pin_block', nil, ('%d неверных PIN подряд'):format(Config.PinMaxFails))
        sendDiscord(('@here **%s**: %d неверных PIN подряд, вход заблокирован на %d мин')
            :format(Admin.label(src), Config.PinMaxFails, Config.PinLockMinutes))
        Admin.broadcast(('%s: 3 неверных PIN, вход заблокирован'):format(Admin.label(src)), 5)
        return false, ('неверный PIN. вход заблокирован на %d минут'):format(Config.PinLockMinutes)
    end
    MySQL.update('UPDATE kavkaz_admins SET pin_fails = ? WHERE license = ?', { row.pin_fails, row.license })
    return false, ('неверный PIN, осталось попыток: %d'):format(Config.PinMaxFails - row.pin_fails)
end)

lib.callback.register('kavkaz_admin:changePin', function(src, oldPin, newPin)
    local row = Admin.rows[Admin.license(src) or '']
    if not row or not row.pin_hash then return false, 'PIN ещё не создан: зайди через /alogin' end
    if not isPin(oldPin) or not VerifyPasswordHash(oldPin, row.pin_hash) then return false, 'старый PIN неверный' end
    if not isPin(newPin) then return false, ('новый PIN — ровно %d цифр'):format(Config.PinLength) end
    row.pin_hash = GetPasswordHash(newPin)
    MySQL.update.await('UPDATE kavkaz_admins SET pin_hash = ? WHERE license = ?', { row.pin_hash, row.license })
    Admin.log(src, 'apin', nil, 'PIN изменён')
    return true
end)

lib.addCommand('alogout', { help = 'Сдать админ-смену' }, function(src)
    if not Admin.duty[src] then return Admin.notify(src, 'ты не на смене', 'error') end
    stopDuty(src, 'сам')
end)

-- /aresetpin ID — основатель сбрасывает PIN (при следующем /alogin админ задаст новый)
lib.addCommand('aresetpin', {
    help = 'Сбросить PIN администратору',
    params = { { name = 'target', type = 'playerId', help = 'ID игрока' } },
}, function(src, args)
    if not Admin.can(src, 'resetpin') then return end
    local license = Admin.license(args.target)
    MySQL.update.await('UPDATE kavkaz_admins SET pin_hash = NULL, pin_fails = 0, locked_until = 0 WHERE license = ?', { license })
    local row = Admin.rows[license or '']
    if row then row.pin_hash, row.pin_fails, row.locked_until = nil, 0, 0 end
    Admin.log(src, 'aresetpin', args.target)
    Admin.notify(src, 'PIN сброшен', 'success')
    Admin.notify(args.target, 'твой PIN сброшен: при /alogin задай новый', 'inform')
end)

---------------------------------------------------------------------------
-- /setadmin ID уровень
---------------------------------------------------------------------------

function Admin.setLevel(src, target, level)
    if level < 0 or level > Config.MaxLevel then
        return false, ('уровень от 0 до %d'):format(Config.MaxLevel)
    end
    if src ~= 0 then
        local my = Admin.dutyLevel(src)
        local current = Admin.getLevel(target)
        if my < Config.MaxLevel then
            -- главный админ назначает и снимает только уровни 1–4
            if level >= my or current >= my then
                return false, ('ты можешь назначать только уровни ниже своего (до %d)'):format(my - 1)
            end
        end
        if target == src then return false, 'себе уровень менять нельзя' end
    end
    if Admin.isFounder(target) and level < Config.MaxLevel then
        return false, 'основатель задаётся через permissions (ACE kavkaz.founder), не командой'
    end

    local license = Admin.license(target)
    if not license then return false, 'у игрока нет лицензии Rockstar' end
    MySQL.insert.await([[INSERT INTO kavkaz_admins (license, name, level) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE level = VALUES(level), name = VALUES(name)]], { license, GetPlayerName(target) or '', level })
    loadRow(target)
    setStateRank(target)

    if Admin.duty[target] then
        if level == 0 then stopDuty(target, 'снят с админки')
        else
            Admin.duty[target].level = level
            setStateLevel(target, level)
        end
    end
    Admin.log(src, 'setadmin', target, ('уровень %d (%s)'):format(level, Admin.levelName(level)))
    return true
end

lib.addCommand('setadmin', {
    help = 'Назначить админ-уровень (0 — снять)',
    params = {
        { name = 'target', type = 'playerId', help = 'ID игрока' },
        { name = 'level', type = 'number', help = '0–6' },
    },
}, function(src, args)
    if not Admin.can(src, 'setadmin') then return end
    local ok, err = Admin.setLevel(src, args.target, math.floor(args.level))
    if not ok then return Admin.notify(src, err, 'error') end
    local level = math.floor(args.level)
    Admin.notify(src, ('%s теперь: %s'):format(Admin.label(args.target), Admin.levelName(level)), 'success')
    Admin.notify(args.target, level > 0
        and ('тебе выдан админ-уровень %d (%s). войти на смену: /alogin'):format(level, Admin.levelName(level))
        or 'ты снят с администрации', 'inform')
end)

---------------------------------------------------------------------------
-- жизненный цикл
---------------------------------------------------------------------------

AddEventHandler('playerJoining', function()
    local src = source
    setStateLevel(src, 0)
    loadRow(src)
    setStateRank(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    if Admin.duty[src] then stopDuty(src, 'вышел с сервера') end
end)

MySQL.ready(function()
    for _, q in ipairs(SCHEMA) do MySQL.query.await(q) end
    -- перезапуск ресурса: подгружаем тех, кто уже онлайн (смена при этом сбрасывается)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        setStateLevel(src, 0)
        loadRow(src)
        setStateRank(src)
    end
    TriggerEvent('kavkaz_admin:server:ready')
end)

-- экспорт для других наших ресурсов: exports.kavkaz_admin:GetLevel(src), :IsOnDuty(src)
exports('GetLevel', Admin.getLevel)
exports('GetDutyLevel', Admin.dutyLevel)
exports('IsOnDuty', function(src) return Admin.duty[src] ~= nil end)
exports('Log', Admin.log)
