-- KAVKAZ RP — меню игрока: данные для вкладок, время в игре, промокоды. всё считает сервер.

local LICENCES = { driver = 'Водительские права', weapon = 'Лицензия на оружие', id = 'Паспорт', business = 'Предприниматель' }
local prevLogin = {} -- citizenid -> прошлый вход (до этого захода)

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS kavkaz_playtime (
        citizenid VARCHAR(50) NOT NULL PRIMARY KEY, license VARCHAR(80) NULL, minutes INT NOT NULL DEFAULT 0,
        first_seen TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, last_login TIMESTAMP NULL)]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS kavkaz_promo (
        code VARCHAR(24) NOT NULL PRIMARY KEY, reward VARCHAR(64) NOT NULL, amount INT NOT NULL DEFAULT 0,
        uses_left INT NOT NULL DEFAULT 1, created_by VARCHAR(64) NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS kavkaz_promo_used (
        code VARCHAR(24) NOT NULL, license VARCHAR(80) NOT NULL, citizenid VARCHAR(50) NULL,
        used_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (code, license))]])
end)

local function license(src)
    return GetPlayerIdentifierByType(src, 'license2') or GetPlayerIdentifierByType(src, 'license')
end

local function getPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

-- вход персонажа: запомнить прошлый вход и отметить новый
AddEventHandler('QBCore:Server:PlayerLoaded', function(p)
    local src = p and p.PlayerData and p.PlayerData.source
    if not src then return end
    local cid = p.PlayerData.citizenid
    prevLogin[cid] = MySQL.scalar.await("SELECT DATE_FORMAT(last_login, '%d.%m.%Y %H:%i') FROM kavkaz_playtime WHERE citizenid = ?", { cid })
    MySQL.query('INSERT INTO kavkaz_playtime (citizenid, license, last_login) VALUES (?, ?, NOW()) ON DUPLICATE KEY UPDATE last_login = NOW(), license = VALUES(license)',
        { cid, license(src) })
end)

-- время в игре: раз в минуту всем, кто в персонаже
CreateThread(function()
    while true do
        Wait(60000)
        local ids = {}
        for _, id in ipairs(GetPlayers()) do
            local p = getPlayer(tonumber(id))
            if p then ids[#ids + 1] = p.PlayerData.citizenid end
        end
        if #ids > 0 then
            MySQL.query(('UPDATE kavkaz_playtime SET minutes = minutes + 1 WHERE citizenid IN (%s)'):format(('?,'):rep(#ids):sub(1, -2)), ids)
        end
    end
end)

local function mask(s)
    if not s then return 'нет' end
    local v = s:gsub('^[^:]+:', '')
    return v:sub(1, 4) .. '…' .. v:sub(-4)
end

lib.callback.register('kavkaz_menu:data', function(src)
    local p = getPlayer(src)
    if not p then return nil end
    local pd = p.PlayerData
    local ci = pd.charinfo or {}
    local cid = pd.citizenid
    local pt = MySQL.single.await("SELECT minutes, DATE_FORMAT(first_seen, '%d.%m.%Y') AS first, DATEDIFF(NOW(), first_seen) AS days FROM kavkaz_playtime WHERE citizenid = ?", { cid }) or {}
    local cars = MySQL.scalar.await('SELECT COUNT(*) FROM player_vehicles WHERE citizenid = ?', { cid }) or 0
    local fines = MySQL.single.await('SELECT COUNT(*) AS n, COALESCE(SUM(amount), 0) AS sum FROM kavkaz_fines WHERE citizenid = ? AND paid = 0', { cid }) or {}
    local lic = {}
    for k, v in pairs(pd.metadata and pd.metadata.licences or {}) do
        if v then lic[#lic + 1] = LICENCES[k] or k end
    end
    local adminLevel = 0
    if GetResourceState('kavkaz_admin') == 'started' then
        adminLevel = exports.kavkaz_admin:GetLevel(src) or 0
    end
    return {
        profile = {
            name = ('%s %s'):format(ci.firstname or '', ci.lastname or ''),
            cid = cid, id = src,
            birth = ci.birthdate, place = ci.nationality, phone = ci.phone,
            gender = ci.gender == 1 and 'женский' or 'мужской',
            job = pd.job and ('%s · %s'):format(pd.job.label or '', pd.job.grade and pd.job.grade.name or '') or 'без работы',
            onduty = pd.job and pd.job.onduty,
            gang = pd.gang and pd.gang.name ~= 'none' and pd.gang.label or nil,
            cash = pd.money and pd.money.cash or 0, bank = pd.money and pd.money.bank or 0,
            licences = lic, cars = cars,
        },
        stats = {
            hours = math.floor((pt.minutes or 0) / 60), minutes = (pt.minutes or 0) % 60,
            first = pt.first, days = pt.days or 0,
            fines = fines.n or 0, finesSum = fines.sum or 0,
        },
        security = {
            lastLogin = prevLogin[cid],
            license = mask(license(src)),
            discord = GetPlayerIdentifierByType(src, 'discord') ~= nil,
            steam = GetPlayerIdentifierByType(src, 'steam') ~= nil,
            admin = adminLevel > 0,
        },
        referral = Config.Referral,
    }
end)

-- промокод
local lastTry = {}
lib.callback.register('kavkaz_menu:promo', function(src, code)
    if type(code) ~= 'string' then return false, 'введи код' end
    code = code:upper():gsub('[^%w%-_]', ''):sub(1, Config.PromoMaxLength)
    if code == '' then return false, 'введи код' end
    if (lastTry[src] or 0) + 3000 > GetGameTimer() then return false, 'не так быстро' end
    lastTry[src] = GetGameTimer()
    local p = getPlayer(src)
    local lic = license(src)
    if not p or not lic then return false, 'сначала зайди в персонажа' end
    local promo = MySQL.single.await('SELECT * FROM kavkaz_promo WHERE code = ?', { code })
    if not promo then return false, 'такого промокода нет' end
    if promo.uses_left <= 0 then return false, 'промокод закончился' end
    if MySQL.scalar.await('SELECT 1 FROM kavkaz_promo_used WHERE code = ? AND license = ?', { code, lic }) then
        return false, 'ты уже активировал этот промокод'
    end
    -- сначала списываем использование (защита от двойного ввода), потом выдаём
    local ok = MySQL.update.await('UPDATE kavkaz_promo SET uses_left = uses_left - 1 WHERE code = ? AND uses_left > 0', { code })
    if ok ~= 1 then return false, 'промокод закончился' end
    MySQL.insert.await('INSERT INTO kavkaz_promo_used (code, license, citizenid) VALUES (?, ?, ?)', { code, lic, p.PlayerData.citizenid })
    local reward, amount = promo.reward, promo.amount
    local text
    if reward == 'cash' or reward == 'bank' then
        p.Functions.AddMoney(reward, amount, 'promo-' .. code)
        text = ('%d ₽ %s'):format(amount, reward == 'cash' and 'наличными' or 'на карту')
    elseif reward:sub(1, 5) == 'item:' then
        local item = reward:sub(6)
        exports.ox_inventory:AddItem(src, item, math.max(1, amount))
        local data = exports.ox_inventory:Items(item)
        text = ('%s ×%d'):format(data and data.label or item, math.max(1, amount))
    elseif reward:sub(1, 4) == 'car:' and GetResourceState('kavkaz_cars') == 'started' then
        local okCar = exports.kavkaz_cars:GiveCar(src, reward:sub(5), { reason = 'promo ' .. code, ignoreLimit = true })
        text = okCar and ('машина в гараже мотеля') or 'машину выдать не удалось — напиши в /report'
    else
        text = 'награда не настроена — напиши в /report'
    end
    print(('[kavkaz_menu] %s активировал промокод %s: %s'):format(GetPlayerName(src), code, text))
    return true, 'Промокод активирован: ' .. text
end)

lib.callback.register('kavkaz_menu:switchChar', function(src)
    if not getPlayer(src) then return false end
    exports.qbx_core:Logout(src)
    return true
end)

-- /apromo КОД тип сумма [раз] — создать промокод (админ 5+ на смене)
lib.addCommand('apromo', {
    help = 'Создать промокод: /apromo START cash 50000 100 (тип: cash, bank, item:water, car:kv_priora)',
    params = {
        { name = 'code', type = 'string', help = 'код (латиница и цифры)' },
        { name = 'reward', type = 'string', help = 'cash, bank, item:название, car:kv_модель' },
        { name = 'amount', type = 'number', help = 'сумма или количество' },
        { name = 'uses', type = 'number', help = 'сколько раз можно активировать (по умолчанию 1)', optional = true },
    },
}, function(src, args)
    local level = src == 0 and 99 or (GetResourceState('kavkaz_admin') == 'started' and exports.kavkaz_admin:GetDutyLevel(src) or 0)
    if level < 5 then return exports.qbx_core:Notify(src, 'нужно 5+ уровень админки на смене', 'error') end
    local code = args.code:upper():gsub('[^%w%-_]', ''):sub(1, Config.PromoMaxLength)
    local r = args.reward:lower()
    if not (r == 'cash' or r == 'bank' or r:find('^item:') or r:find('^car:')) then
        return exports.qbx_core:Notify(src, 'тип: cash, bank, item:название, car:kv_модель', 'error')
    end
    MySQL.insert.await('REPLACE INTO kavkaz_promo (code, reward, amount, uses_left, created_by) VALUES (?, ?, ?, ?, ?)',
        { code, r, math.floor(args.amount), math.floor(args.uses or 1), src == 0 and 'консоль' or GetPlayerName(src) })
    local msg = ('промокод %s создан: %s %d, активаций %d'):format(code, r, math.floor(args.amount), math.floor(args.uses or 1))
    if src == 0 then print(msg) else exports.qbx_core:Notify(src, msg, 'success') end
end)

AddEventHandler('playerDropped', function() lastTry[source] = nil end)
