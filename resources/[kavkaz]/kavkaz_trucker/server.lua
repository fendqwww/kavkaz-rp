-- KAVKAZ RP: дальнобой, сервер. деньги, опыт, проверки расстояний и все машины рейса — только здесь.
-- тягач и прицеп создаёт сервер (OneSync), режим «не удалять без игрока» — удаляем сами: сдача, отмена, выход, рестарт ресурса.

local jobs = {}      -- src -> рейс
local trucks = {}    -- src -> { net, used }
local offers = {}    -- src -> { at, list }
local lastCall = {}  -- src -> { ключ -> время }
local stats = {}     -- citizenid -> { xp, trips, km, earned }
local nextId = 0

local DEPOT = { id = 'depot', label = Config.Depot.label, coords = Config.Depot.truckSpawn.xyz }

---------------------------------------------------------------------------
-- мелочи
---------------------------------------------------------------------------
local function notify(src, text, kind)
    pcall(function() exports.qbx_core:Notify(src, text, kind or 'inform', 8000) end)
end

local function citizen(src)
    local p = exports.qbx_core:GetPlayer(src)
    return p and p.PlayerData and p.PlayerData.citizenid or nil
end

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped)
end

local function flat(a, b)
    return #(vec2(a.x, a.y) - vec2(b.x, b.y))
end

local function ent(net)
    if not net then return nil end
    local e = NetworkGetEntityFromNetworkId(net)
    if e and e ~= 0 and DoesEntityExist(e) then return e end
    return nil
end

local function delNet(net)
    local e = ent(net)
    if e then DeleteEntity(e) end
end

local function throttle(src, key, ms)
    local now = GetGameTimer()
    lastCall[src] = lastCall[src] or {}
    local last = lastCall[src][key]
    if last and now - last < ms then return false end
    lastCall[src][key] = now
    return true
end

local function money(n)
    local s = tostring(math.floor(n + 0.5))
    local out = s:reverse():gsub('(%d%d%d)', '%1 '):reverse()
    return (out:gsub('^ ', ''))
end

local function where(id)
    if id == 'depot' then return DEPOT end
    for _, p in ipairs(Config.Points) do
        if p.id == id then return p end
    end
    return nil
end

local function segDist(p, a, b)
    local dx, dy = b.x - a.x, b.y - a.y
    local len2 = dx * dx + dy * dy
    local t = 0.0
    if len2 > 0 then t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2 end
    t = math.max(0.0, math.min(1.0, t))
    local cx, cy = a.x + t * dx, a.y + t * dy
    return math.sqrt((p.x - cx) ^ 2 + (p.y - cy) ^ 2)
end

local function isNight()
    local t = GlobalState.currentTime
    local h = type(t) == 'table' and tonumber(t.hour) or nil
    return h ~= nil and (h >= 22 or h < 6)
end

-- спросить клиента с таймаутом (ответа может не быть: игрок вышел, клиент завис)
local function askClient(src, name, timeoutMs, ...)
    local p = promise.new()
    local done = false
    lib.callback(name, src, function(res)
        if done then return end
        done = true
        p:resolve(res)
    end, ...)
    SetTimeout(timeoutMs, function()
        if done then return end
        done = true
        p:resolve(nil)
    end)
    return Citizen.Await(p)
end

---------------------------------------------------------------------------
-- деньги
---------------------------------------------------------------------------
local function give(src, amount, reason)
    if amount <= 0 then return end
    exports.qbx_core:AddMoney(src, 'bank', amount, reason)
end

-- услуга: списать всё сразу с карты или наличными, иначе отказать
local function chargeExact(src, amount, reason)
    for _, acc in ipairs({ 'bank', 'cash' }) do
        if (exports.qbx_core:GetMoney(src, acc) or 0) >= amount then
            if exports.qbx_core:RemoveMoney(src, acc, amount, reason) then return true end
        end
    end
    return false
end

-- штраф: сколько есть (сначала карта, потом наличные), возвращает списанное
local function fine(src, amount, reason)
    if amount <= 0 then return 0 end
    if chargeExact(src, amount, reason) then return amount end
    local took = 0
    for _, acc in ipairs({ 'bank', 'cash' }) do
        local have = math.floor(exports.qbx_core:GetMoney(src, acc) or 0)
        local part = math.min(have, amount - took)
        if part > 0 and exports.qbx_core:RemoveMoney(src, acc, part, reason) then took = took + part end
    end
    return took
end

---------------------------------------------------------------------------
-- опыт водителя (таблица kavkaz_trucker, схема — sql/2026-11-16_kavkaz_trucker.sql)
---------------------------------------------------------------------------
CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS kavkaz_trucker (
        citizenid VARCHAR(50) NOT NULL PRIMARY KEY,
        xp INT NOT NULL DEFAULT 0,
        trips INT NOT NULL DEFAULT 0,
        km DECIMAL(10,1) NOT NULL DEFAULT 0,
        earned BIGINT NOT NULL DEFAULT 0,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )]])
end)

local function loadStats(cid)
    if stats[cid] then return stats[cid] end
    local row = MySQL.single.await('SELECT xp, trips, km, earned FROM kavkaz_trucker WHERE citizenid = ?', { cid })
    local s = { xp = 0, trips = 0, km = 0.0, earned = 0 }
    if row then
        s.xp, s.trips, s.km, s.earned = tonumber(row.xp) or 0, tonumber(row.trips) or 0, tonumber(row.km) or 0.0, tonumber(row.earned) or 0
    end
    stats[cid] = s
    return s
end

local function saveStats(cid, s)
    MySQL.insert.await('INSERT INTO kavkaz_trucker (citizenid, xp, trips, km, earned) VALUES (?, ?, ?, ?, ?) '
        .. 'ON DUPLICATE KEY UPDATE xp = VALUES(xp), trips = VALUES(trips), km = VALUES(km), earned = VALUES(earned)',
        { cid, s.xp, s.trips, s.km, s.earned })
end

local function levelOf(xp)
    local lvl = 1
    for i, l in ipairs(Config.Levels) do
        if xp >= l.xp then lvl = i end
    end
    return lvl
end

local function levelMul(lvl)
    return 1.0 + Config.LevelPay * (lvl - 1) + (Config.Levels[lvl].payBonus or 0.0)
end

---------------------------------------------------------------------------
-- машины
---------------------------------------------------------------------------
local function truckModel()
    local ok, car = pcall(function() return exports.kavkaz_cars:GetCar(Config.Truck) end)
    if ok and car and car.current then return car.current end
    return Config.TruckFallback
end

local function plateText()
    return ('TR%06d'):format(math.random(0, 999999))
end

local function setupTruck(src, veh)
    SetEntityOrphanMode(veh, 2)
    SetVehicleNumberPlateText(veh, plateText())
    Entity(veh).state:set('fuel', 100.0, true)
    local cid = citizen(src)
    if cid then Entity(veh).state:set('owner', cid, true) end
    local ok, err = pcall(function() return exports.qbx_vehiclekeys:GiveKeys(src, veh, true) end)
    if not ok then print(('[kavkaz_trucker] ключи не выданы (%s): %s'):format(src, tostring(err))) end
end

local function spawnTruck(src, at)
    local ped = GetPlayerPed(src)
    local ok, netId, veh = pcall(qbx.spawnVehicle, { model = truckModel(), spawnSource = at, warp = ped })
    if not ok or not netId or not veh or veh == 0 then
        print(('[kavkaz_trucker] тягач не создан (%s): %s'):format(src, tostring(netId)))
        return nil
    end
    setupTruck(src, veh)
    trucks[src] = { net = netId, used = os.time() }
    return netId
end

local function spawnTrailer(model, c)
    local veh = CreateVehicleServerSetter(joaat(model), 'trailer', c.x, c.y, c.z, c.w)
    local t = GetGameTimer()
    while not veh or veh == 0 or not DoesEntityExist(veh) do
        if GetGameTimer() - t > 4000 then return nil end
        Wait(50)
    end
    SetEntityOrphanMode(veh, 2)
    pcall(SetVehicleNumberPlateText, veh, plateText())
    return veh, NetworkGetNetworkIdFromEntity(veh)
end

-- свой тягач у базы — тот же, иначе новый
local function ensureTruck(src)
    local t = trucks[src]
    local veh = t and ent(t.net)
    if veh and #(GetEntityCoords(veh) - DEPOT.coords) <= Config.Depot.reuseTruck then
        t.used = os.time()
        return t.net
    end
    if t then delNet(t.net); trucks[src] = nil end
    return spawnTruck(src, Config.Depot.truckSpawn)
end

---------------------------------------------------------------------------
-- рейсы
---------------------------------------------------------------------------
local function cargoPay(cargoKey, km, lmul, night, contraband)
    local c = Config.Cargo[cargoKey]
    local v = (c.base + km * c.perKm) * lmul
    if night then v = v * Config.NightMul end
    if c.urgent then v = v * 1.25 end
    if contraband then v = v * Config.Contraband.payMul end
    return v
end

local function deadlineFor(cargoKey, km)
    local c = Config.Cargo[cargoKey]
    local sec = km * 1000.0 / Config.AvgSpeed + 180
    if c.perishable then sec = sec * 0.85 end
    if c.urgent then sec = sec * 0.7 end
    return math.floor(sec)
end

local function roadKm(a, b)
    return #(a - b) * Config.RoadFactor / 1000.0
end

local function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

local function makeOffers(src, cid)
    local s = loadStats(cid)
    local lvl = levelOf(s.xp)
    local maxKm = Config.Levels[lvl].maxKm
    local night = isNight()
    local lmul = levelMul(lvl)
    local cand = {}
    for key, cargo in pairs(Config.Cargo) do
        if lvl >= cargo.minLevel then
            for _, p in ipairs(Config.Points) do
                if p.tags[cargo.to] then
                    local km = roadKm(DEPOT.coords, p.coords)
                    if km >= 1.0 and km <= maxKm then cand[#cand + 1] = { cargo = key, from = 'depot', to = p.id, km = km } end
                end
            end
        end
    end
    shuffle(cand)
    local list, usedTo = {}, {}
    for _, c in ipairs(cand) do
        if #list >= 4 then break end
        if not usedTo[c.to] then usedTo[c.to] = true; list[#list + 1] = c end
    end
    -- обратный рейс: забрать на точке и привезти в порт (с 2-го уровня)
    if lvl >= 2 then
        local back = {}
        for _, p in ipairs(Config.Points) do
            if p.tags.build then
                local km = roadKm(p.coords, DEPOT.coords)
                if km <= maxKm then back[#back + 1] = { cargo = 'build', from = p.id, to = 'depot', km = km } end
            end
        end
        if #back > 0 then list[#list + 1] = back[math.random(1, #back)] end
    end
    -- «левый» груз
    if lvl >= Config.Contraband.minLevel and #cand > 0 and math.random() < Config.Contraband.chance then
        local c = cand[math.random(1, #cand)]
        list[#list + 1] = { cargo = c.cargo, from = 'depot', to = c.to, km = c.km, contraband = true }
    end
    for _, o in ipairs(list) do
        nextId = nextId + 1
        o.id = ('%d_%d'):format(src, nextId)
        o.deadline = deadlineFor(o.cargo, o.km)
        o.estimate = math.floor(cargoPay(o.cargo, o.km, lmul, night, o.contraband) / 10 + 0.5) * 10
        o.night = night
    end
    offers[src] = { at = os.time(), list = list }
    return list, lvl, s
end

local function pickPosts(fromC, toC, contraband)
    local res = {}
    for i, post in ipairs(Config.Posts) do
        if segDist(post.coords, fromC, toC) <= Config.PostCheck.nearRoute then
            local chance = contraband and Config.PostCheck.contrabandChance or Config.PostCheck.chance
            if math.random() < chance then res[i] = 'pending' end
        end
    end
    return res
end

-- что видит клиент
local function sendJob(src)
    local job = jobs[src]
    if not job then
        TriggerClientEvent('kavkaz_trucker:client:job', src, nil)
        return
    end
    local from, to = where(job.from), where(job.to)
    local checks = {}
    for i, state in pairs(job.checks) do
        if state == 'pending' then checks[#checks + 1] = { i = i, coords = Config.Posts[i].coords, label = Config.Posts[i].label } end
    end
    local left = job.deadline
    if job.loadedAt then left = job.deadline - (os.time() - job.loadedAt) end
    TriggerClientEvent('kavkaz_trucker:client:job', src, {
        id = job.id, cargo = job.cargo, cargoLabel = job.contraband and Config.Contraband.label or Config.Cargo[job.cargo].label,
        from = { label = from.label, coords = from.coords }, to = { label = to.label, coords = to.coords },
        km = job.km, stage = job.stage, deadlineLeft = left, timerRunning = job.loadedAt ~= nil,
        truckNet = trucks[src] and trucks[src].net or nil, trailerNet = job.trailerNet,
        checks = checks, breakdown = job.breakdown, contraband = job.contraband, estimate = job.estimate,
    })
end

local function endJob(src, keepTruck)
    local job = jobs[src]
    if job then delNet(job.trailerNet) end
    jobs[src] = nil
    if not keepTruck and trucks[src] then delNet(trucks[src].net); trucks[src] = nil end
    if GetPlayerName(src) then sendJob(src) end
end

local function placeTrailer(src, job)
    local from = where(job.from)
    local spot = askClient(src, 'kavkaz_trucker:roadSpot', 8000, from.coords)
    if type(spot) ~= 'vector4' or flat(spot, from.coords) > 160.0 then return false end
    local veh, net = spawnTrailer(job.trailerModel, spot)
    if not veh then return false end
    Entity(veh).state:set('kvTrucker', src, true)
    job.trailerNet, job.loadedAt, job.stage = net, os.time(), 'haul'
    return true
end

---------------------------------------------------------------------------
-- обращения клиента
---------------------------------------------------------------------------
local function nearDepot(src, extra)
    local pc = pedCoords(src)
    return pc ~= nil and #(pc - Config.Depot.ped.coords.xyz) <= Config.Depot.talk + (extra or 4.0)
end

lib.callback.register('kavkaz_trucker:offers', function(src)
    if not nearDepot(src) then return nil end
    local cid = citizen(src)
    if not cid then return nil end
    local list, lvl, s
    local cache = offers[src]
    if cache and os.time() - cache.at <= Config.OffersTtl then
        list = cache.list
        s = loadStats(cid)
        lvl = levelOf(s.xp)
    else
        list, lvl, s = makeOffers(src, cid)
    end
    local out = {}
    for _, o in ipairs(list) do
        local c = Config.Cargo[o.cargo]
        out[#out + 1] = {
            id = o.id, cargoLabel = o.contraband and Config.Contraband.label or c.label, note = o.contraband and 'без документов: на посту ДПС могут найти' or c.note,
            from = where(o.from).label, to = where(o.to).label, km = o.km, estimate = o.estimate,
            minutes = math.ceil(o.deadline / 60), contraband = o.contraband, night = o.night, remote = o.from ~= 'depot',
        }
    end
    local nextL = Config.Levels[lvl + 1]
    return {
        list = out, level = lvl, levelLabel = Config.Levels[lvl].label, xp = s.xp, nextXp = nextL and nextL.xp or nil,
        trips = s.trips, km = s.km, hasJob = jobs[src] ~= nil,
    }
end)

lib.callback.register('kavkaz_trucker:accept', function(src, offerId)
    if not throttle(src, 'accept', 3000) then return false, 'подожди пару секунд' end
    if jobs[src] then return false, 'у тебя уже есть рейс' end
    if not nearDepot(src) then return false, 'подойди к диспетчеру' end
    local cid = citizen(src)
    if not cid then return false, 'персонаж не загружен' end
    local cache = offers[src]
    if not cache or os.time() - cache.at > Config.OffersTtl then return false, 'список устарел — открой рейсы заново' end
    local offer
    for _, o in ipairs(cache.list) do
        if o.id == offerId then offer = o end
    end
    if not offer then return false, 'этот рейс уже не актуален' end
    local from, to = where(offer.from), where(offer.to)
    if not from or not to then return false, 'точка рейса не найдена' end
    local lvl = levelOf(loadStats(cid).xp)
    if lvl < Config.Cargo[offer.cargo].minLevel then return false, 'рано: нужен уровень выше' end

    local truckNet = ensureTruck(src)
    if not truckNet then return false, 'тягач не выдался — попробуй ещё раз' end
    offers[src] = nil
    local trailers = Config.Cargo[offer.cargo].trailers
    local job = {
        id = offer.id, cid = cid, cargo = offer.cargo, from = offer.from, to = offer.to, km = offer.km,
        deadline = offer.deadline, estimate = offer.estimate, contraband = offer.contraband, night = offer.night,
        lmul = levelMul(lvl), trailerModel = trailers[math.random(1, #trailers)],
        stage = 'pickup', createdAt = os.time(), checks = pickPosts(from.coords, to.coords, offer.contraband),
    }
    if math.random() < Config.Breakdown.chance then
        local kinds = Config.Breakdown.kinds
        job.breakdown = { kind = kinds[math.random(1, #kinds)], at = 0.3 + math.random() * 0.4 }
    end
    jobs[src] = job
    if offer.from == 'depot' and not placeTrailer(src, job) then
        jobs[src] = nil
        return false, 'не нашлось места для прицепа — попробуй ещё раз'
    end
    sendJob(src)
    return true
end)

-- приехал на дальнюю погрузку
lib.callback.register('kavkaz_trucker:arrived', function(src)
    local job = jobs[src]
    if not job or job.stage ~= 'pickup' then return false end
    if not throttle(src, 'arrived', 4000) then return false end
    local pc = pedCoords(src)
    if not pc or flat(pc, where(job.from).coords) > 200.0 then return false end
    if not placeTrailer(src, job) then return false end
    sendJob(src)
    return true
end)

lib.callback.register('kavkaz_trucker:where', function(src)
    local job = jobs[src]
    local trailer = job and ent(job.trailerNet)
    if not trailer then return nil end
    return GetEntityCoords(trailer)
end)

lib.callback.register('kavkaz_trucker:deliver', function(src)
    local job = jobs[src]
    if not job or job.stage ~= 'haul' then return false, 'нет активного рейса' end
    if not throttle(src, 'deliver', 3000) then return false, 'подожди' end
    local trailer = ent(job.trailerNet)
    if not trailer then return false, 'прицеп не найден' end
    local to, from = where(job.to), where(job.from)
    local tc = GetEntityCoords(trailer)
    if flat(tc, to.coords) > Config.UnloadRadius + 5.0 then return false, 'прицеп не в зоне разгрузки' end
    local pc = pedCoords(src)
    if not pc or #(pc - tc) > 60.0 then return false, 'подойди ближе к прицепу' end
    local elapsed = os.time() - (job.loadedAt or os.time())
    if elapsed < #(from.coords - to.coords) / Config.MinSpeed then
        print(('[kavkaz_trucker] %s доставил слишком быстро: %d с на %.1f км'):format(GetPlayerName(src), elapsed, job.km))
        return false, 'груз так быстро не довезти'
    end

    -- целость: здоровье кузова прицепа (если сервер его не знает — считаем целым)
    local okBh, bh = pcall(GetVehicleBodyHealth, trailer)
    local integrity = 1.0
    if okBh and type(bh) == 'number' and bh > 0 and bh <= 1000 then integrity = bh / 1000.0 end
    local cargo = Config.Cargo[job.cargo]
    local base = cargoPay(job.cargo, job.km, job.lmul, job.night, job.contraband)
    local lines = { ('%s, %.1f км: %s ₽'):format(job.contraband and 'попутный груз' or cargo.label, job.km, money(base)) }
    local total = base
    if elapsed <= job.deadline then
        total = total + base * Config.OnTimeBonus
        lines[#lines + 1] = ('в срок: +%d %%'):format(math.floor(Config.OnTimeBonus * 100))
    else
        local pen = cargo.perishable and 0.5 or Config.LatePenalty
        total = total - base * pen
        lines[#lines + 1] = ('опоздание: −%d %%'):format(math.floor(pen * 100))
    end
    local k = 0.5 + 0.5 * integrity
    if cargo.fragile and integrity < 0.6 then k = k * 0.5 end
    if k < 0.999 then lines[#lines + 1] = ('груз помят (%d %%): ×%.2f'):format(math.floor(integrity * 100), k) end
    total = math.max(0, math.floor(total * k / 10 + 0.5) * 10)

    DeleteEntity(trailer)
    jobs[src] = nil
    if trucks[src] then trucks[src].used = os.time() end

    local s = loadStats(job.cid)
    local before = levelOf(s.xp)
    local xp = math.floor(job.km * (cargo.xp or 1.0) * 10 + 0.5)
    if elapsed <= job.deadline then xp = math.floor(xp * 1.1 + 0.5) end
    s.xp, s.trips, s.km, s.earned = s.xp + xp, s.trips + 1, s.km + job.km, s.earned + total
    saveStats(job.cid, s)
    give(src, total, ('Дальнобой: %s → %s'):format(from.label, to.label))
    if job.contraband then TriggerEvent('kavkaz_trucker:server:contraband', src, 'delivered', { cargo = job.cargo, to = job.to }) end
    sendJob(src)
    local after = levelOf(s.xp)
    if after > before then
        notify(src, ('Новый уровень: %s. Открыты рейсы дальше и дороже.'):format(Config.Levels[after].label), 'success')
    end
    lines[#lines + 1] = ('итого на карту: %s ₽ · опыт +%d'):format(money(total), xp)
    return true, lines
end)

-- пост ДПС: остановился
lib.callback.register('kavkaz_trucker:postStop', function(src, idx)
    local job = jobs[src]
    idx = tonumber(idx)
    if not job or job.stage ~= 'haul' or not idx or job.checks[idx] ~= 'pending' then return nil end
    local pc = pedCoords(src)
    if not pc or flat(pc, Config.Posts[idx].coords) > Config.PostCheck.radius + 60.0 then return nil end
    job.checks[idx] = 'done'
    local cargo = Config.Cargo[job.cargo]
    if job.contraband and math.random() < Config.Contraband.foundChance then
        local took = fine(src, Config.Contraband.fine, 'Штраф ДПС: груз без документов')
        TriggerEvent('kavkaz_trucker:server:contraband', src, 'found', { cargo = job.cargo, post = idx })
        endJob(src, true)
        return { result = 'found', fine = took }
    end
    if cargo.overweight and math.random() < cargo.overweight then
        local took = fine(src, Config.PostCheck.overweightFine, 'Штраф ДПС: перевес')
        return { result = 'overweight', fine = took }
    end
    return { result = 'ok' }
end)

-- пост ДПС: проехал мимо
lib.callback.register('kavkaz_trucker:postIgnored', function(src, idx)
    local job = jobs[src]
    idx = tonumber(idx)
    if not job or not idx or job.checks[idx] ~= 'pending' then return nil end
    local pc = pedCoords(src)
    if not pc or flat(pc, Config.Posts[idx].coords) > 800.0 then return nil end
    job.checks[idx] = 'done'
    local amount = Config.PostCheck.ignoreFine + (job.contraband and Config.Contraband.ignoreFine or 0)
    local took = fine(src, amount, 'Штраф ДПС: неподчинение требованию остановиться')
    if job.contraband then TriggerEvent('kavkaz_trucker:server:contraband', src, 'ignored', { cargo = job.cargo, post = idx }) end
    return { fine = took }
end)

-- прицеп уничтожен (сообщает клиент: ему это только в минус)
lib.callback.register('kavkaz_trucker:trailerLost', function(src)
    local job = jobs[src]
    if not job or job.stage ~= 'haul' then return false end
    local amount = job.cargo == 'fuel' and Config.DestroyedFine.fuel or Config.DestroyedFine.default
    local took = fine(src, amount, 'Дальнобой: груз уничтожен')
    endJob(src, true)
    notify(src, ('Груз уничтожен. Рейс сорван, удержано %s ₽.'):format(money(took)), 'error')
    return true
end)

lib.callback.register('kavkaz_trucker:crane', function(src)
    local job = jobs[src]
    local trailer = job and ent(job.trailerNet)
    if not trailer then return false, 'прицеп не найден' end
    if not throttle(src, 'crane', 5000) then return false, 'подожди' end
    local pc = pedCoords(src)
    local c = GetEntityCoords(trailer)
    if not pc or #(pc - c) > 25.0 then return false, 'подойди к прицепу' end
    if not chargeExact(src, Config.CranePrice, 'Дальнобой: кран') then return false, 'не хватает денег на кран' end
    local ok, err = pcall(function()
        SetEntityRotation(trailer, 0.0, 0.0, GetEntityHeading(trailer), 2, true)
        SetEntityCoords(trailer, c.x, c.y, c.z + 1.0, false, false, false, false)
    end)
    if not ok then
        print('[kavkaz_trucker] кран: ' .. tostring(err))
        give(src, Config.CranePrice, 'Дальнобой: возврат за кран')
        return false, 'кран не смог — деньги вернули'
    end
    return true
end)

lib.callback.register('kavkaz_trucker:evac', function(src)
    if not jobs[src] then return false, 'эвакуация — только в рейсе' end
    if not throttle(src, 'evac', 15000) then return false, 'эвакуатор уже в пути' end
    local pc = pedCoords(src)
    if not pc then return false end
    local spot = askClient(src, 'kavkaz_trucker:roadSpot', 8000, pc)
    if type(spot) ~= 'vector4' or flat(spot, pc) > 150.0 then return false, 'рядом нет дороги' end
    if not chargeExact(src, Config.EvacPrice, 'Дальнобой: новый тягач') then return false, 'не хватает денег' end
    if trucks[src] then delNet(trucks[src].net); trucks[src] = nil end
    if not spawnTruck(src, spot) then
        give(src, Config.EvacPrice, 'Дальнобой: возврат за эвакуацию')
        return false, 'тягач не выдался, деньги вернули'
    end
    sendJob(src)
    return true
end)

lib.callback.register('kavkaz_trucker:cancel', function(src)
    local job = jobs[src]
    if not job then return false, 'рейса нет' end
    local amount = job.stage == 'haul' and Config.CancelFine or 0
    local took = fine(src, amount, 'Дальнобой: отмена рейса')
    endJob(src, true)
    return true, took
end)

lib.callback.register('kavkaz_trucker:returnTruck', function(src)
    if jobs[src] then return false, 'сначала закончи или отмени рейс' end
    local t = trucks[src]
    local veh = t and ent(t.net)
    if not veh then trucks[src] = nil; return false, 'тягача нет' end
    if #(GetEntityCoords(veh) - DEPOT.coords) > Config.Depot.reuseTruck then return false, 'пригони тягач на базу' end
    DeleteEntity(veh)
    trucks[src] = nil
    return true
end)

---------------------------------------------------------------------------
-- уборка
---------------------------------------------------------------------------
local function cleanup(src)
    if jobs[src] then delNet(jobs[src].trailerNet) end
    if trucks[src] then delNet(trucks[src].net) end
    jobs[src], trucks[src], offers[src], lastCall[src] = nil, nil, nil, nil
end

AddEventHandler('playerDropped', function()
    cleanup(source)
end)

AddEventHandler('qbx_core:server:playerLoggedOut', function(src)
    src = src or source
    if src then cleanup(src) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(jobs) do delNet(jobs[src].trailerNet) end
    for src in pairs(trucks) do delNet(trucks[src].net) end
end)

-- брошенные рейсы и тягачи
CreateThread(function()
    while true do
        Wait(10000)
        local now = os.time()
        for src, job in pairs(jobs) do
            if not GetPlayerName(src) then
                cleanup(src)
            elseif job.stage == 'pickup' then
                if now - job.createdAt > 30 * 60 then
                    endJob(src, true)
                    notify(src, 'Рейс снят: ты не доехал до погрузки за 30 минут.', 'error')
                end
            else
                local trailer = ent(job.trailerNet)
                local truck = trucks[src] and ent(trucks[src].net)
                local pc = pedCoords(src)
                if not trailer then
                    endJob(src, true)
                    notify(src, 'Прицеп пропал — рейс снят без штрафа.', 'error')
                elseif pc then
                    local far = #(pc - GetEntityCoords(trailer)) > 400.0 and (not truck or #(pc - GetEntityCoords(truck)) > 400.0)
                    if far then
                        job.farSince = job.farSince or now
                        if now - job.farSince > Config.AbandonMinutes * 60 then
                            local took = fine(src, Config.CancelFine, 'Дальнобой: брошенный рейс')
                            endJob(src, true)
                            notify(src, ('Рейс брошен и снят, удержано %s ₽.'):format(money(took)), 'error')
                        end
                    else
                        job.farSince = nil
                    end
                end
            end
        end
        for src, t in pairs(trucks) do
            if not jobs[src] then
                local veh = ent(t.net)
                local pc = pedCoords(src)
                if not veh then
                    trucks[src] = nil
                elseif now - t.used > Config.TruckIdleMinutes * 60 and (not pc or #(pc - GetEntityCoords(veh)) > 200.0) then
                    DeleteEntity(veh)
                    trucks[src] = nil
                end
            end
        end
    end
end)
