-- KAVKAZ RP: силовики — сервер. всё, что про деньги, звания и «что нарушил водитель», решается здесь:
-- клиент только показывает и двигает NPC. профиль водителя (нарушения) генерирует сервер и не отдаёт клиенту целиком.

local Officers = {}   -- [src] = { cid, org, rank, xp, name, car, complaints, shift = {...}, checks, fines, detains }
local Stops = {}      -- [id] = { id, src, netId, p (профиль), state, found = {}, fined = {}, rewarded, created }
local stopByNet = {}  -- [netId] = id
local ignored = {}    -- [netId] = os.time() — водитель уже проигнорировал требование
local nextStop = 0
local modeAt = 0
local playerChecked = {} -- [src] = os.time() — пост проверял игрока

local function dbg(...) if Config.Debug then print('[kavkaz_law]', ...) end end
local function notify(src, text, kind) TriggerClientEvent('ox_lib:notify', src, { title = 'Служба', description = text, type = kind or 'inform', duration = 7000 }) end
local function money(n) return (tostring(math.floor(math.abs(n))):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')) .. ' ₽' end
local function pick(t) return t[math.random(#t)] end
local function chance(p) return math.random() < p end

local function getPlayer(src) return exports.qbx_core:GetPlayer(src) end
local function charName(p)
    local ci = p and p.PlayerData and p.PlayerData.charinfo
    return ci and ('%s %s'):format(ci.firstname or '', ci.lastname or '') or 'сотрудник'
end
local function isAdmin(src)
    local ok, level = pcall(function() return exports.kavkaz_admin:GetLevel(src) end)
    return ok and (level or 0) >= 1
end
local function pedPos(src)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and GetEntityCoords(ped) or nil
end
local function entityPos(netId)
    local ent = NetworkGetEntityFromNetworkId(netId or 0)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil, nil end
    return GetEntityCoords(ent), ent
end

---------------------------------------------------------------------------
-- база: звания и счётчики по персонажу и службе
---------------------------------------------------------------------------
MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `kavkaz_law_officers` (
        `citizenid` VARCHAR(50) NOT NULL, `org` VARCHAR(10) NOT NULL,
        `xp` INT NOT NULL DEFAULT 0, `checks` INT NOT NULL DEFAULT 0, `fines` INT NOT NULL DEFAULT 0, `detains` INT NOT NULL DEFAULT 0,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`, `org`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end)

local function rankFor(xp)
    local r = 0
    for i = 0, #Config.RankXp do
        if xp >= Config.RankXp[i] then r = i end
    end
    return r
end

local function publish(src)
    local o = Officers[src]
    pcall(function() -- игрок мог уже выйти
        local st = Player(src).state
        if not o then st:set('kvLaw', nil, true) return end
        st:set('kvLaw', { org = o.org, rank = o.rank, leader = o.leader, car = o.car }, true)
    end)
end

local function save(o)
    MySQL.query('INSERT INTO kavkaz_law_officers (citizenid, org, xp, checks, fines, detains) VALUES (?, ?, ?, ?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE xp = VALUES(xp), checks = VALUES(checks), fines = VALUES(fines), detains = VALUES(detains)',
        { o.cid, o.org, o.xp, o.checks, o.fines, o.detains }, function() end)
end

local function deleteCar(o)
    if not o or not o.car then return end
    local ent = NetworkGetEntityFromNetworkId(o.car)
    if ent and ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
    o.car = nil
end

local function closeStopsOf(src)
    for id, s in pairs(Stops) do
        if s.src == src then
            stopByNet[s.netId] = nil
            Stops[id] = nil
        end
    end
end

-- деньги и опыт за действие. money < 0 — вычет (если на карте есть)
local function reward(src, m, xp, reason)
    local o = Officers[src]
    if not o then return end
    if m and m ~= 0 then
        if m > 0 then
            exports.qbx_core:AddMoney(src, 'bank', m, ('%s: %s'):format(Config.Orgs[o.org].label, reason))
        else
            local have = exports.qbx_core:GetMoney(src, 'bank') or 0
            if have >= -m then exports.qbx_core:RemoveMoney(src, 'bank', -m, ('%s: %s'):format(Config.Orgs[o.org].label, reason)) end
        end
        o.shift.money = o.shift.money + m
    end
    if xp and xp ~= 0 then
        o.xp = math.max(0, o.xp + xp)
        o.shift.xp = o.shift.xp + xp
        local r = rankFor(o.xp)
        if r ~= o.rank then
            local up = r > o.rank
            o.rank = r
            o.leader = r >= Config.LeaderRank or (Config.AdminIsLeader and isAdmin(src))
            notify(src, up and ('новое звание: %s'):format(Config.Orgs[o.org].ranks[r]) or ('понижен в звании: %s'):format(Config.Orgs[o.org].ranks[r]), up and 'success' or 'error')
            publish(src)
        end
    end
    save(o)
end

local function summary(o)
    local s = o.shift
    return ('**%s, %s**\n\nпроверено машин: %d  \nверных штрафов: %d  \nзадержано: %d  \nжалоб: %d  \n\nзаработано за смену: **%s%s**  \nопыт: %+d (всего %d)'):format(
        Config.Orgs[o.org].full, Config.Orgs[o.org].ranks[o.rank], s.checks, s.fines, s.detains, o.complaints,
        s.money < 0 and '−' or '', money(s.money), s.xp, o.xp)
end

local function endDuty(src, why)
    local o = Officers[src]
    if not o then return nil end
    deleteCar(o)
    closeStopsOf(src)
    save(o)
    local text = summary(o)
    Officers[src] = nil
    publish(src)
    if why then notify(src, why, 'error') end
    TriggerClientEvent('kavkaz_law:client:dutyEnded', src, text)
    return text
end

---------------------------------------------------------------------------
-- смена
---------------------------------------------------------------------------
local function nearDutyPoint(src, org)
    local pos = pedPos(src)
    if not pos then return false end
    local st = Config.Orgs[org].station
    if #(pos - st.xyz) < 40.0 then return true end
    for _, p in ipairs(Config.Posts) do
        if #(pos - p.coords.xyz) < 140.0 then return true end
    end
    for _, t in ipairs(GlobalState.kvLawTemp or {}) do
        if #(pos - vec3(t.x, t.y, t.z)) < 60.0 then return true end
    end
    return false
end

lib.callback.register('kavkaz_law:duty', function(src, org)
    if Officers[src] then
        return { ended = true, summary = endDuty(src) }
    end
    if not Config.Orgs[org] then return { error = 'нет такой службы' } end
    local p = getPlayer(src)
    if not p then return { error = 'персонаж не загружен' } end
    if not nearDutyPoint(src, org) then return { error = 'заступить можно в отделе или на посту' } end
    local cid = p.PlayerData.citizenid
    local row = MySQL.single.await('SELECT xp, checks, fines, detains FROM kavkaz_law_officers WHERE citizenid = ? AND org = ?', { cid, org })
    local o = {
        cid = cid, org = org, name = charName(p), xp = row and row.xp or 0,
        checks = row and row.checks or 0, fines = row and row.fines or 0, detains = row and row.detains or 0,
        complaints = 0, shift = { money = 0, xp = 0, checks = 0, fines = 0, detains = 0 }, started = os.time(),
    }
    o.rank = rankFor(o.xp)
    o.leader = o.rank >= Config.LeaderRank or (Config.AdminIsLeader and isAdmin(src))
    Officers[src] = o
    publish(src)
    if not row then save(o) end
    print(('[kavkaz_law] %s (%s) заступил: %s, %s'):format(GetPlayerName(src), cid, org, Config.Orgs[org].ranks[o.rank]))
    return { started = true, org = org, rank = o.rank, leader = o.leader }
end)

-- служебная машина: модель выбирает клиент из списка службы (что есть на сервере), место — у дороги рядом с ним
lib.callback.register('kavkaz_law:car', function(src, model, x, y, z, h)
    local o = Officers[src]
    if not o then return { error = 'вы не на смене' } end
    local org = Config.Orgs[o.org]
    local okModel = false
    for _, m in ipairs(org.cars) do if m == model then okModel = true end end
    if not okModel then return { error = 'нет такой машины' } end
    local pos = pedPos(src)
    x, y, z, h = tonumber(x), tonumber(y), tonumber(z), tonumber(h) or 0.0
    if not pos or not x or not y or not z or #(pos - vec3(x, y, z)) > 80.0 then return { error = 'машину подают только рядом с вами' } end
    if not nearDutyPoint(src, o.org) then return { error = 'служебную машину выдают в отделе или на посту' } end
    deleteCar(o)
    local veh = CreateVehicleServerSetter(joaat(model), 'automobile', x, y, z + 0.5, h)
    local untilT = GetGameTimer() + 5000
    while (not veh or veh == 0 or not DoesEntityExist(veh)) and GetGameTimer() < untilT do Wait(50) end
    if not veh or veh == 0 or not DoesEntityExist(veh) then return { error = 'машина не появилась, попробуйте ещё раз' } end
    local plate
    if o.org == 'dps' then
        plate = ('%s%04d95'):format(pick({ 'A', 'B', 'E', 'K', 'M', 'H', 'O', 'P', 'C', 'T', 'Y', 'X' }), math.random(1, 9999))
    else
        local L = { 'A', 'B', 'E', 'K', 'M', 'H', 'O', 'P', 'C', 'T', 'Y', 'X' }
        plate = ('%s%03d%s%s95'):format(pick(L), math.random(1, 999), pick(L), pick(L))
    end
    SetVehicleNumberPlateText(veh, plate)
    Entity(veh).state:set('fuel', 100.0, true)
    Entity(veh).state:set('kvLawCar', src, true)
    o.car = NetworkGetNetworkIdFromEntity(veh)
    pcall(function() exports.qbx_vehiclekeys:GiveKeys(src, veh, true) end)
    publish(src)
    return { netId = o.car, plate = plate, color = org.carColor, plateIndex = org.plateIndex }
end)

---------------------------------------------------------------------------
-- профиль NPC-водителя
---------------------------------------------------------------------------
local Names = {
    male = { 'Александр', 'Алексей', 'Андрей', 'Антон', 'Артём', 'Борис', 'Вадим', 'Виктор', 'Владимир', 'Геннадий', 'Григорий', 'Денис',
        'Дмитрий', 'Евгений', 'Егор', 'Иван', 'Игорь', 'Илья', 'Кирилл', 'Константин', 'Максим', 'Михаил', 'Никита', 'Николай', 'Олег',
        'Павел', 'Пётр', 'Роман', 'Сергей', 'Станислав', 'Степан', 'Тимофей', 'Фёдор', 'Юрий', 'Ярослав' },
    female = { 'Анна', 'Алина', 'Валентина', 'Вера', 'Галина', 'Дарья', 'Евгения', 'Екатерина', 'Елена', 'Ирина', 'Ксения', 'Лариса',
        'Любовь', 'Марина', 'Мария', 'Наталья', 'Нина', 'Ольга', 'Полина', 'Светлана', 'Софья', 'Татьяна', 'Юлия' },
    -- фамилии на -ов/-ев/-ин: женская форма — плюс «а»
    last = { 'Иванов', 'Смирнов', 'Кузнецов', 'Попов', 'Васильев', 'Петров', 'Соколов', 'Михайлов', 'Новиков', 'Фёдоров', 'Морозов',
        'Волков', 'Алексеев', 'Лебедев', 'Семёнов', 'Егоров', 'Павлов', 'Козлов', 'Степанов', 'Николаев', 'Орлов', 'Андреев', 'Макаров',
        'Никитин', 'Захаров', 'Зайцев', 'Соловьёв', 'Борисов', 'Яковлев', 'Григорьев', 'Романов', 'Воробьёв', 'Сергеев', 'Кузьмин',
        'Фролов', 'Александров', 'Дмитриев', 'Королёв', 'Гусев', 'Киселёв', 'Ильин', 'Максимов', 'Поляков', 'Сорокин', 'Виноградов',
        'Ковалёв', 'Белов', 'Медведев', 'Антонов', 'Тарасов', 'Жуков', 'Баранов', 'Филиппов', 'Комаров', 'Давыдов', 'Беляев', 'Герасимов' },
    middle = { { 'Александрович', 'Александровна' }, { 'Алексеевич', 'Алексеевна' }, { 'Андреевич', 'Андреевна' }, { 'Викторович', 'Викторовна' },
        { 'Владимирович', 'Владимировна' }, { 'Дмитриевич', 'Дмитриевна' }, { 'Евгеньевич', 'Евгеньевна' }, { 'Иванович', 'Ивановна' },
        { 'Игоревич', 'Игоревна' }, { 'Михайлович', 'Михайловна' }, { 'Николаевич', 'Николаевна' }, { 'Олегович', 'Олеговна' },
        { 'Павлович', 'Павловна' }, { 'Петрович', 'Петровна' }, { 'Сергеевич', 'Сергеевна' }, { 'Юрьевич', 'Юрьевна' } },
}
local WantedReasons = { 'кража (ст. 158 УК)', 'мошенничество (ст. 159 УК)', 'уклонение от алиментов', 'угон (ст. 166 УК)',
    'неявка в суд', 'побег из-под административного ареста', 'грабёж (ст. 161 УК)' }
local Contraband = { 'незарегистрированный пистолет', 'пакет с наличными без документов — 2,4 млн ₽', 'ящик контрафактного алкоголя',
    'партия поддельных номеров', 'запчасти со спиленными номерами', 'поддельные документы на машину', 'сумка с нарезанными сим-картами',
    'обрез охотничьего ружья' }

local function plateOf(ent) return (GetVehicleNumberPlateText(ent) or ''):gsub('^%s+', ''):gsub('%s+$', '') end

local VehNames
local function vehicleName(ent)
    if not VehNames then
        VehNames = {}
        local ok, list = pcall(function() return exports.qbx_core:GetVehiclesByName() end)
        if ok and type(list) == 'table' then
            for model, v in pairs(list) do
                VehNames[joaat(model)] = ((v.brand and v.brand ~= '') and (v.brand .. ' ') or '') .. (v.name or model)
            end
        end
    end
    return VehNames[GetEntityModel(ent)] or 'автомобиль'
end

local function genProfile(male)
    local p = { male = male }
    local hour = tonumber(os.date('%H'))
    local night = hour >= 22 or hour < 5
    local mode = (GlobalState.kvLawMode or {}).id or 'normal'
    local m = pick(Names.middle)
    p.name = ('%s %s %s'):format(pick(Names.last) .. (male and '' or 'а'), pick(male and Names.male or Names.female), male and m[1] or m[2])
    p.born = tonumber(os.date('%Y')) - math.random(19, 68)
    local r = math.random()
    p.license = r < 0.05 and 'none' or r < 0.08 and 'revoked' or r < 0.12 and 'expired' or 'ok'
    p.licNumber = ('%02d %02d %06d'):format(math.random(10, 99), math.random(10, 99), math.random(0, 999999))
    p.sts = chance(0.05) and 'none' or 'ok'
    r = math.random()
    p.osago = r < 0.04 and 'none' or r < 0.11 and 'expired' or 'ok'
    if chance(night and 0.22 or 0.08) then p.bac = math.random(18, 120) / 100
    elseif chance(0.10) then p.bac = math.random(4, 12) / 100
    else p.bac = 0.0 end
    p.belt = not chance(0.15)
    p.phone = chance(0.07)
    p.wanted = chance((mode == 'intercept' or mode == 'kto') and 0.07 or 0.03) and pick(WantedReasons) or nil
    p.stolen = chance(0.02)
    p.contraband = chance(mode == 'kto' and 0.12 or 0.06) and pick(Contraband) or nil
    p.temper = pick({ 'calm', 'calm', 'polite', 'nervous', 'rude', 'joker' })
    -- нарушения, которые доказывают статьи Config.Fines
    p.viol = {
        belt = not p.belt, phone = p.phone, osago = p.osago ~= 'ok', sts = p.sts ~= 'ok',
        nolic = p.license == 'none' or p.license == 'expired', revoked = p.license == 'revoked', drunk = p.bac > 0.16,
    }
    p.flee = math.min(0.6, 0.03 + (p.wanted and 0.30 or 0) + (p.stolen and 0.35 or 0) + (p.viol.drunk and 0.12 or 0)
        + (p.viol.revoked and 0.15 or 0) + (p.contraband and 0.12 or 0))
    return p
end

---------------------------------------------------------------------------
-- остановка NPC
---------------------------------------------------------------------------
lib.callback.register('kavkaz_law:stopRequest', function(src, netId, male)
    local o = Officers[src]
    if not o then return { error = 'вы не на смене' } end
    netId = tonumber(netId)
    local vpos, ent = entityPos(netId)
    local pos = pedPos(src)
    if not vpos or not pos then return { error = 'машина пропала' } end
    if GetEntityType(ent) ~= 2 then return { error = 'это не машина' } end
    if #(pos - vpos) > 80.0 then return { error = 'слишком далеко' } end
    for id, s in pairs(Stops) do -- одна остановка за раз; старые (10+ минут) закрываются сами
        if s.src == src and s.state ~= 'done' then
            if os.time() - s.created > 600 then stopByNet[s.netId] = nil; Stops[id] = nil
            else return { error = 'сначала закончите с прошлой машиной' } end
        end
    end
    local other = stopByNet[netId]
    if other and Stops[other] then return { error = 'эту машину уже проверяет другой сотрудник' } end

    local again = ignored[netId] and os.time() - ignored[netId] < 120
    nextStop = nextStop + 1
    local s = { id = nextStop, src = src, netId = netId, p = genProfile(male and true or false), state = 'pending',
        found = {}, fined = {}, created = os.time(), plate = plateOf(ent), car = vehicleName(ent) }
    local outcome
    local r = math.random()
    if again then outcome = r < 0.3 and 'flee' or 'comply'
    elseif r < s.p.flee then outcome = 'flee'
    elseif r < s.p.flee + 0.08 then outcome = 'ignore'
    else outcome = 'comply' end
    if outcome == 'ignore' then
        ignored[netId] = os.time()
        return { outcome = 'ignore' }
    end
    ignored[netId] = nil
    if outcome == 'flee' then s.fled = true; s.p.viol.flee = true end
    Stops[s.id] = s
    stopByNet[netId] = s.id
    dbg('stop', s.id, outcome, s.p.name)
    return { id = s.id, outcome = outcome, temper = s.p.temper, male = s.p.male, plate = s.plate, car = s.car,
        drunkHint = s.p.bac > 0.4, belt = s.p.belt, phone = s.p.phone }
end)

-- клиент сообщает, чем кончилось: остановился / сдался после погони / ушёл / машина пропала
lib.callback.register('kavkaz_law:stopState', function(src, id, state)
    local s = Stops[tonumber(id) or -1]
    if not s or s.src ~= src then return false end
    if state == 'stopped' and s.state == 'pending' then
        s.state = 'stopped'
    elseif state == 'surrendered' and s.state == 'pending' and s.fled then
        s.state = 'stopped'
        s.found.flee = true
        local o = Officers[src]
        if o then
            reward(src, Config.Reward.caught.money, Config.Reward.caught.xp, 'задержан после погони')
            notify(src, ('догнали: +%s'):format(money(Config.Reward.caught.money)), 'success')
        end
    elseif state == 'escaped' or state == 'lost' then
        stopByNet[s.netId] = nil
        Stops[s.id] = nil
    else
        return false
    end
    return true
end)

local function near(src, s, maxDist)
    local vpos = entityPos(s.netId)
    local pos = pedPos(src)
    if not pos then return false end
    if s.detaineeNet then -- задержанный уже вне машины — меряем до него
        local dpos = entityPos(s.detaineeNet)
        if dpos and #(pos - dpos) <= maxDist then return true end
    end
    return vpos ~= nil and #(pos - vpos) <= maxDist
end

local function finish(s)
    s.state = 'done'
    stopByNet[s.netId] = nil
    Stops[s.id] = nil
end

local function fineById(id)
    for _, f in ipairs(Config.Fines) do if f.id == id then return f end end
end

lib.callback.register('kavkaz_law:action', function(src, id, action, arg)
    local o = Officers[src]
    local s = Stops[tonumber(id) or -1]
    if not o or not s or s.src ~= src then return { error = 'проверка уже закончена' } end
    if s.state ~= 'stopped' then return { error = 'машина ещё не остановлена' } end
    if not near(src, s, 8.0) then return { error = 'подойдите ближе' } end
    local p = s.p

    if action == 'docs' then
        s.found.docs = true
        s.found.nolic = p.viol.nolic; s.found.revoked = p.viol.revoked
        s.found.sts = p.viol.sts; s.found.osago = p.viol.osago
        s.found.belt = p.viol.belt; s.found.phone = p.viol.phone
        return { name = p.name, born = p.born, license = p.license, licNumber = p.licNumber, sts = p.sts, osago = p.osago,
            plate = s.plate, car = s.car, belt = p.belt, phone = p.phone, smell = p.bac > 0.3 }
    elseif action == 'alco' then
        s.found.drunk = p.viol.drunk
        s.found.alco = true
        return { bac = p.bac }
    elseif action == 'search' then
        s.found.search = true
        s.found.contraband = p.contraband ~= nil
        return { item = p.contraband }
    elseif action == 'base' then
        s.found.base = true
        s.found.wanted = p.wanted ~= nil
        s.found.stolen = p.stolen
        return { wanted = p.wanted, stolen = p.stolen, plate = s.plate }
    elseif action == 'fine' then
        local f = fineById(arg)
        if not f then return { error = 'нет такой статьи' } end
        if s.fined[f.id] then return { error = 'по этой статье уже выписан' } end
        s.fined[f.id] = true
        if p.viol[f.viol] then
            o.shift.fines = o.shift.fines + 1
            o.fines = o.fines + 1
            local m = math.floor(f.amount * Config.Reward.fineShare)
            reward(src, m, Config.Reward.fineXp, 'штраф ' .. f.label)
            return { ok = true, text = ('штраф выписан: %s, %s. ваша премия %s'):format(f.label, money(f.amount), money(m)) }
        end
        o.complaints = o.complaints + 1
        reward(src, Config.Reward.wrongFine.money, Config.Reward.wrongFine.xp, 'жалоба водителя')
        if o.complaints >= Config.MaxComplaints then
            SetTimeout(4000, function() if Officers[src] then endDuty(src, 'три жалобы за смену — служебная проверка, смена закрыта') end end)
        end
        return { complaint = true, text = ('водитель обжалует штраф: нарушения не было. жалоба %d из %d, вычет %s'):format(
            o.complaints, Config.MaxComplaints, money(Config.Reward.wrongFine.money)) }
    elseif action == 'detain' then
        local why
        for k in pairs(Config.DetainReasons) do
            if s.found[k] then why = k break end
        end
        if not why then
            reward(src, Config.Reward.wrongDetain.money, Config.Reward.wrongDetain.xp, 'задержание без оснований')
            o.complaints = o.complaints + 1
            return { refused = true, text = ('оснований для задержания нет — превышение полномочий. жалоба %d из %d'):format(o.complaints, Config.MaxComplaints) }
        end
        s.why = why -- состояние не меняем: если клиент не довёл задержание, проверку можно продолжить
        return { ok = true, why = why }
    elseif action == 'detain_confirm' then -- водитель вышел и в наручниках: клиент передаёт его netId
        if not s.why then return { error = 'сначала основание для задержания' } end
        local dNet = tonumber(arg)
        local dpos, dent = entityPos(dNet)
        if not dpos or GetEntityType(dent) ~= 1 then return { error = 'задержанный пропал' } end
        s.detaineeNet = dNet
        s.state = 'detained'
        return { ok = true }
    elseif action == 'release' then
        local text
        if s.found.docs and not s.rewarded then
            s.rewarded = true
            o.shift.checks = o.shift.checks + 1
            o.checks = o.checks + 1
            reward(src, Config.Reward.check.money, Config.Reward.check.xp, 'проверка документов')
            text = ('проверка закончена: +%s'):format(money(Config.Reward.check.money))
        end
        finish(s)
        return { ok = true, text = text }
    end
    return { error = 'неизвестное действие' }
end)

-- задержанный доставлен в отдел
lib.callback.register('kavkaz_law:deliver', function(src, id)
    local o = Officers[src]
    local s = Stops[tonumber(id) or -1]
    if not o or not s or s.src ~= src or s.state ~= 'detained' then return { error = 'некого сдавать' } end
    local pos = pedPos(src)
    local okPlace = false
    for _, org in pairs(Config.Orgs) do
        if pos and #(pos - org.station.xyz) <= Config.DeliverRadius then okPlace = true end
    end
    if not okPlace then return { error = 'сдать задержанного можно у отдела ГИБДД или управления ФСБ' } end
    o.shift.detains = o.shift.detains + 1
    o.detains = o.detains + 1
    local m, xp = Config.Reward.detain.money, Config.Reward.detain.xp
    if s.p.wanted or s.p.contraband then m = m + 1500; xp = xp + 20 end -- розыск и находка — дороже
    reward(src, m, xp, 'задержанный доставлен')
    finish(s)
    return { ok = true, text = ('задержанный доставлен: +%s, +%d опыта'):format(money(m), xp) }
end)

-- задержанный пропал по дороге (убит, удалён) — проверка закрывается без награды
lib.callback.register('kavkaz_law:detaineeLost', function(src, id)
    local s = Stops[tonumber(id) or -1]
    if s and s.src == src then finish(s) end
    return true
end)

---------------------------------------------------------------------------
-- пост проверяет игрока (NPC-инспектор остановил игрока)
---------------------------------------------------------------------------
local function issueFine(src, article, amount, note)
    local ok, err = pcall(function() return exports.kavkaz_fines:IssueFine(src, article, amount, note, 'инспектор поста ДПС') end)
    if not ok then print('[kavkaz_law] штраф игроку не выписан: ' .. tostring(err)) end
end

lib.callback.register('kavkaz_law:playerStopped', function(src, postId)
    if Officers[src] then return { skip = true } end
    if playerChecked[src] and os.time() - playerChecked[src] < Config.PlayerStop.cooldown then return { skip = true } end
    playerChecked[src] = os.time()
    local p = getPlayer(src)
    if not p then return { skip = true } end
    local lic = true
    local ok, has = pcall(function() return exports.kavkaz_license:HasLicense(src) end)
    if ok then lic = has and true or false end
    local unpaid = 0
    pcall(function()
        local list = exports.kavkaz_fines:GetUnpaid(p.PlayerData.citizenid)
        unpaid = type(list) == 'table' and #list or tonumber(list) or 0
    end)
    if not lic then issueFine(src, Config.PlayerStop.fineNoLicense, nil, 'пост ДПС: управление без водительского удостоверения') end
    return { license = lic, unpaid = unpaid, name = charName(p) }
end)

lib.callback.register('kavkaz_law:playerIgnored', function(src, postId)
    if Officers[src] then return false end
    if playerChecked[src] and os.time() - playerChecked[src] < 60 then return false end
    playerChecked[src] = os.time()
    issueFine(src, Config.PlayerStop.fineIgnore, Config.PlayerStop.fineIgnoreAmount, 'ст. 12.25 ч.2 — не остановился по требованию инспектора поста ДПС')
    return true
end)

-- инспектор поста идёт к машине: пересылаем игрокам рядом (у каждого свои «декорации» поста)
local animAt = {}
RegisterNetEvent('kavkaz_law:server:postAnim', function(postId, netId, holdMs)
    local src = source
    if type(postId) ~= 'string' or #postId > 40 then return end
    if animAt[src] and GetGameTimer() - animAt[src] < 3000 then return end
    animAt[src] = GetGameTimer()
    local pos = pedPos(src)
    if not pos then return end
    holdMs = math.max(5000, math.min(25000, tonumber(holdMs) or 12000))
    for _, id in ipairs(GetPlayers()) do
        local p = pedPos(tonumber(id))
        if p and #(p - pos) < 300.0 then
            TriggerClientEvent('kavkaz_law:client:postAnim', tonumber(id), postId, tonumber(netId), holdMs)
        end
    end
end)

---------------------------------------------------------------------------
-- лидер: режимы, посты, наряды
---------------------------------------------------------------------------
local function leader(src)
    local o = Officers[src]
    if o and o.leader then return true end
    return Config.AdminIsLeader and isAdmin(src)
end

local function broadcastMode(m, byName)
    GlobalState.kvLawMode = { id = m, label = Config.Modes[m].label, by = byName,
        ends = Config.Modes[m].minutes > 0 and (os.time() + Config.Modes[m].minutes * 60) or 0 }
end

lib.callback.register('kavkaz_law:mode', function(src, m)
    if not leader(src) then return { error = 'нет полномочий' } end
    if not Config.Modes[m] then return { error = 'нет такого режима' } end
    if os.time() - modeAt < Config.ModeCooldown and m ~= 'normal' then
        return { error = ('режим меняли недавно, подождите %d с'):format(Config.ModeCooldown - (os.time() - modeAt)) }
    end
    modeAt = os.time()
    local name = charName(getPlayer(src))
    broadcastMode(m, name)
    print(('[kavkaz_law] %s объявил: %s'):format(GetPlayerName(src), Config.Modes[m].label))
    pcall(function() exports.kavkaz_admin:Log(src, 'law_mode', nil, Config.Modes[m].label) end)
    return { ok = true }
end)

lib.callback.register('kavkaz_law:post', function(src, postId, org)
    if not leader(src) then return { error = 'нет полномочий' } end
    local found = false
    for _, p in ipairs(Config.Posts) do if p.id == postId then found = true end end
    if not found then return { error = 'нет такого поста' } end
    if org ~= 'dps' and org ~= 'fsb' and org ~= 'mixed' and org ~= 'off' and org ~= 'auto' then return { error = 'неверно' } end
    local ov = GlobalState.kvLawPosts or {}
    ov[postId] = org ~= 'auto' and org or nil
    GlobalState.kvLawPosts = ov
    return { ok = true }
end)

lib.callback.register('kavkaz_law:tempPost', function(src, action, data)
    if not leader(src) then return { error = 'нет полномочий' } end
    local list = GlobalState.kvLawTemp or {}
    if action == 'clear' then
        GlobalState.kvLawTemp = {}
        return { ok = true }
    end
    if action ~= 'add' or type(data) ~= 'table' then return { error = 'неверно' } end
    if #list >= Config.MaxTempPosts then return { error = ('временных постов уже %d — снимите старые'):format(#list) } end
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    local pos = pedPos(src)
    if not x or not y or not z or not pos or #(pos - vec3(x, y, z)) > 60.0 then return { error = 'пост ставится рядом с вами' } end
    local org = (data.org == 'fsb' or data.org == 'mixed') and data.org or 'dps'
    list[#list + 1] = { id = ('temp%d_%d'):format(os.time(), math.random(100, 999)), x = x, y = y, z = z, org = org }
    GlobalState.kvLawTemp = list
    return { ok = true }
end)

-- наряды NPC создаёт клиент лидера (он же ими управляет); сервер только проверяет право и пишет в лог
lib.callback.register('kavkaz_law:unit', function(src, kind)
    if not leader(src) then return { error = 'нет полномочий' } end
    if not Config.Units[kind] then return { error = 'нет такого наряда' } end
    pcall(function() exports.kavkaz_admin:Log(src, 'law_unit', nil, Config.Units[kind].label) end)
    return { ok = true }
end)

lib.callback.register('kavkaz_law:isLeader', function(src) return leader(src) end)

-- режим сам возвращается в «обычный», когда истёк срок
CreateThread(function()
    GlobalState.kvLawMode = GlobalState.kvLawMode or { id = 'normal', label = Config.Modes.normal.label, ends = 0 }
    GlobalState.kvLawPosts = GlobalState.kvLawPosts or {}
    GlobalState.kvLawTemp = GlobalState.kvLawTemp or {}
    while true do
        Wait(15000)
        local m = GlobalState.kvLawMode
        if m and m.id ~= 'normal' and m.ends and m.ends > 0 and os.time() >= m.ends then
            broadcastMode('normal', nil)
        end
    end
end)

---------------------------------------------------------------------------
-- выход, смена персонажа, рестарт
---------------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    if Officers[src] then endDuty(src) end
    playerChecked[src] = nil
    animAt[src] = nil
end)

-- смена персонажа без выхода с сервера (qbx)
RegisterNetEvent('qbx_core:server:onLogout', function() local src = source if Officers[src] then endDuty(src) end end)
AddEventHandler('qbx_core:server:playerLoggedOut', function(src) if src and Officers[src] then endDuty(src) end end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src, o in pairs(Officers) do
        deleteCar(o)
        save(o)
        Player(src).state:set('kvLaw', nil, true)
    end
end)

exports('IsOnDuty', function(src, org)
    local o = Officers[src]
    return o ~= nil and (org == nil or o.org == org)
end)
exports('AddReward', function(src, m, xp, reason) reward(src, m, xp, reason or 'задание') end)
exports('GetMode', function() return (GlobalState.kvLawMode or {}).id or 'normal' end)
