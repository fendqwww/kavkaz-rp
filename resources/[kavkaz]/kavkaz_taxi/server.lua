-- KAVKAZ RP: такси — сервер. смены, заказы, оплата, рейтинг. деньги и проверки только здесь.

local shifts = {}  -- [src] = { net, cid, started, earned, rides, stats = { rides, votes, score_sum } }
local orders = {}  -- [src] = { id, kind, persona, gender, name, special, pickup, dest, pedNet, state, created, boardedAt }
local rate = {}    -- [src] = { last = os.time(), list = { times } }
local nextId = 0

local PLATE_LETTERS = { 'A', 'B', 'E', 'K', 'M', 'H', 'O', 'P', 'C', 'T', 'Y', 'X' }

MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `kavkaz_taxi` (
            `citizenid` VARCHAR(50) NOT NULL,
            `rides` INT NOT NULL DEFAULT 0,
            `votes` INT NOT NULL DEFAULT 0,
            `score_sum` INT NOT NULL DEFAULT 0,
            `earned` INT NOT NULL DEFAULT 0,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end)

---------------------------------------------------------------------------
-- помощники
---------------------------------------------------------------------------

local function notify(src, text, kind)
    exports.qbx_core:Notify(src, text, kind or 'inform', 7000)
end

local function playerPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function toVec(t)
    if type(t) == 'vector3' then return t end
    if type(t) ~= 'table' then return nil end
    local x, y, z = tonumber(t.x), tonumber(t.y), tonumber(t.z)
    if not x or not y or not z then return nil end
    if x ~= x or y ~= y or z ~= z then return nil end -- NaN
    return vector3(x, y, z)
end

local function entityFromNet(net)
    if type(net) ~= 'number' then return nil end
    local ent = NetworkGetEntityFromNetworkId(net)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    return ent
end

local function deleteNet(net)
    local ent = entityFromNet(net)
    if ent then DeleteEntity(ent) end
end

local function randomPlate()
    local l1 = PLATE_LETTERS[math.random(#PLATE_LETTERS)]
    local l2 = PLATE_LETTERS[math.random(#PLATE_LETTERS)]
    return ('%s%s%03d%s'):format(l1, l2, math.random(1, 999), Config.Region)
end

local function rating(st)
    if not st or (st.votes or 0) == 0 then return 5.0 end
    return math.floor(st.score_sum / st.votes * 10 + 0.5) / 10
end

local function loadStats(cid)
    local row = MySQL.single.await('SELECT rides, votes, score_sum, earned FROM kavkaz_taxi WHERE citizenid = ?', { cid })
    return row or { rides = 0, votes = 0, score_sum = 0, earned = 0 }
end

local function saveVote(src, stars, earned, ride)
    local sh = shifts[src]
    if not sh then return end
    stars = math.max(1, math.min(5, math.floor(stars)))
    sh.stats.votes = (sh.stats.votes or 0) + 1
    sh.stats.score_sum = (sh.stats.score_sum or 0) + stars
    if ride then sh.stats.rides = (sh.stats.rides or 0) + 1 end
    MySQL.prepare([[
        INSERT INTO kavkaz_taxi (citizenid, rides, votes, score_sum, earned) VALUES (?, ?, 1, ?, ?)
        ON DUPLICATE KEY UPDATE rides = rides + VALUES(rides), votes = votes + 1,
            score_sum = score_sum + VALUES(score_sum), earned = earned + VALUES(earned)
    ]], { sh.cid, ride and 1 or 0, stars, earned or 0 })
end

local function pickWeighted(night)
    local total, list = 0, {}
    for name, p in pairs(Config.Personas) do
        if not p.night or night then
            total = total + p.weight
            list[#list + 1] = { name = name, w = p.weight }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end) -- одинаковый порядок, pairs его не гарантирует
    local r = math.random() * total
    for _, it in ipairs(list) do
        r = r - it.w
        if r <= 0 then return it.name end
    end
    return 'normal'
end

-- отменить заказ: пассажира (если ещё ждал у дороги) убирает сервер, только когда клиент уже не может (выход, рестарт)
local function dropOrder(src, deletePed)
    local o = orders[src]
    if not o then return end
    if deletePed and o.pedNet then deleteNet(o.pedNet) end
    orders[src] = nil
end

local function endShift(src, silent)
    local sh = shifts[src]
    if not sh then return nil end
    dropOrder(src, true)
    local veh = entityFromNet(sh.net)
    local fine = 0
    local returned = veh ~= nil and #(GetEntityCoords(veh) - Config.Depot.ped.xyz) <= Config.Depot.returnRadius
    if not returned and not silent then
        fine = Config.LostCarFine
        local paid = false
        for _, acc in ipairs({ 'cash', 'bank' }) do
            if not paid and (exports.qbx_core:GetMoney(src, acc) or 0) >= fine then
                paid = exports.qbx_core:RemoveMoney(src, acc, fine, 'Такси: машина не сдана в таксопарк')
            end
        end
        if not paid then fine = 0 end
    end
    if veh then DeleteEntity(veh) end
    shifts[src] = nil
    pcall(function() Player(src).state:set('kvTaxi', nil, true) end) -- игрок мог уже выйти
    local summary = {
        rides = sh.rides, earned = sh.earned, fine = fine,
        minutes = math.floor((os.time() - sh.started) / 60), rating = rating(sh.stats),
    }
    return summary
end

---------------------------------------------------------------------------
-- смена
---------------------------------------------------------------------------

lib.callback.register('kavkaz_taxi:start', function(src, model, spawn)
    if shifts[src] then return { ok = false, msg = 'смена уже идёт' } end
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return { ok = false, msg = 'персонаж не загружен' } end
    local pos = playerPos(src)
    local depot = Config.Depot.ped.xyz
    if not pos or #(pos - depot) > 15.0 then return { ok = false, msg = 'подойдите к диспетчеру таксопарка' } end

    local allowed = false
    for _, m in ipairs(Config.Cars) do if m == model then allowed = true break end end
    if not allowed then return { ok = false, msg = 'нет такой машины' } end

    local at = Config.Depot.carSpawn
    if type(spawn) == 'table' then
        local v = toVec(spawn)
        local h = tonumber(spawn.w)
        if v and h and #(v - depot) <= Config.Depot.spawnRadius then at = vec4(v.x, v.y, v.z, h) end
    end

    local ok, netId, veh = pcall(qbx.spawnVehicle, { model = model, spawnSource = at, warp = GetPlayerPed(src) })
    if not ok or not veh or veh == 0 or not DoesEntityExist(veh) then
        print(('[kavkaz_taxi] машина не создана (%s): %s'):format(src, tostring(netId)))
        return { ok = false, msg = 'машина не выехала, попробуйте ещё раз' }
    end

    local plate = randomPlate()
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleColours(veh, Config.CarColor[1], Config.CarColor[2])
    local ent = Entity(veh)
    ent.state:set('kvPlateIndex', Config.PlateIndex, true)
    ent.state:set('fuel', 100.0, true)
    ent.state:set('owner', player.PlayerData.citizenid, true)
    ent.state:set('kvTaxiCar', src, true)
    local kok, kerr = pcall(function() return exports.qbx_vehiclekeys:GiveKeys(src, veh, true) end)
    if not kok then print(('[kavkaz_taxi] ключи не выданы (%s): %s'):format(src, tostring(kerr))) end

    shifts[src] = {
        net = netId, cid = player.PlayerData.citizenid, started = os.time(), earned = 0, rides = 0,
        stats = loadStats(player.PlayerData.citizenid),
    }
    Player(src).state:set('kvTaxi', true, true)
    return { ok = true, net = netId, plate = plate, rating = rating(shifts[src].stats), rides = shifts[src].stats.rides }
end)

lib.callback.register('kavkaz_taxi:finish', function(src)
    if not shifts[src] then return { ok = false, msg = 'смена не начата' } end
    return { ok = true, summary = endShift(src, false) }
end)

lib.callback.register('kavkaz_taxi:stats', function(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return nil end
    local st = shifts[src] and shifts[src].stats or loadStats(player.PlayerData.citizenid)
    return { rides = st.rides or 0, rating = rating(st), votes = st.votes or 0, earned = st.earned or 0,
        special = (st.rides or 0) >= Config.Special.minRides and rating(st) >= Config.Special.minRating }
end)

---------------------------------------------------------------------------
-- заказы
---------------------------------------------------------------------------

local function rateOk(src)
    local now = os.time()
    local r = rate[src] or { last = 0, list = {} }
    rate[src] = r
    if now - r.last < Config.Rate.minGap then return false end
    local keep = {}
    for _, t in ipairs(r.list) do if now - t < 60 then keep[#keep + 1] = t end end
    r.list = keep
    if #keep >= Config.Rate.perMinute then return false end
    r.last = now
    keep[#keep + 1] = now
    return true
end

lib.callback.register('kavkaz_taxi:newOrder', function(src, hour)
    local sh = shifts[src]
    if not sh then return nil end
    local old = orders[src]
    if old then
        -- клиент «потерял» заказ (вылет, зависание): старый закрываем, если он давно висит
        if os.time() - old.created < Config.OrderTimeout + 60 then return nil end
        dropOrder(src, true)
    end
    if not rateOk(src) then return nil end

    hour = tonumber(hour) or 12
    local night = hour >= 22 or hour < 5
    local gender = math.random() < 0.5 and 'm' or 'f'
    local o = {
        persona = pickWeighted(night), gender = gender,
        name = Config.Names[gender][math.random(#Config.Names[gender])],
        state = 'spawning', created = os.time(),
    }
    nextId = nextId + 1
    o.id = nextId

    local canSpecial = (sh.stats.rides or 0) >= Config.Special.minRides and rating(sh.stats) >= Config.Special.minRating
    if canSpecial and math.random() < Config.Special.chance then
        local i = math.random(#Config.Special.places)
        o.kind, o.special = 'special', i
    elseif math.random() < Config.Call.chance then
        o.kind = 'call'
    else
        o.kind = 'street'
    end
    orders[src] = o
    local sp = o.special and Config.Special.places[o.special]
    return { id = o.id, kind = o.kind, persona = o.persona, gender = o.gender, name = o.name,
        special = sp and { label = sp.label, x = sp.coords.x, y = sp.coords.y, z = sp.coords.z } or nil }
end)

-- клиент поставил пассажира у дороги
lib.callback.register('kavkaz_taxi:ready', function(src, id, pickup, pedNet)
    local o = orders[src]
    if not o or o.id ~= id or o.state ~= 'spawning' then return false end
    local p, pos = toVec(pickup), playerPos(src)
    if not p or not pos or #(p - pos) > 1200.0 then dropOrder(src, false) return false end
    local ped = entityFromNet(pedNet)
    if not ped then dropOrder(src, false) return false end
    o.pickup, o.pedNet, o.state = p, pedNet, 'waiting'
    return true
end)

-- пассажир сел: сервер проверяет, что он в машине смены рядом с игроком, и запоминает адрес
lib.callback.register('kavkaz_taxi:board', function(src, id, dest)
    local o, sh = orders[src], shifts[src]
    if not o or not sh or o.id ~= id or o.state ~= 'waiting' then return { ok = false } end
    local d, pos = toVec(dest), playerPos(src)
    local ped, veh = entityFromNet(o.pedNet), entityFromNet(sh.net)
    if not d or not pos or not ped or not veh then return { ok = false } end
    if GetVehiclePedIsIn(ped, false) ~= veh or #(GetEntityCoords(veh) - pos) > 10.0 then return { ok = false } end

    local from = GetEntityCoords(veh)
    local dist = #(d - from)
    if o.special then
        local sp = Config.Special.places[o.special]
        if #(d - sp.coords) > Config.Special.snap then return { ok = false } end
    elseif dist < Config.Dest.min * 0.6 or dist > Config.Dest.max * 1.3 then
        return { ok = false }
    end
    o.dest, o.from, o.boardedAt, o.state = d, from, os.time(), 'riding'
    return { ok = true }
end)

-- высадка и оплата. stats от клиента влияют только на звёзды и чаевые (с ограничениями), сама поездка — по координатам сервера
lib.callback.register('kavkaz_taxi:dropoff', function(src, id, stats)
    local o, sh = orders[src], shifts[src]
    if not o or not sh or o.id ~= id or o.state ~= 'riding' then return { ok = false } end
    local pos = playerPos(src)
    if not pos or #(pos - o.dest) > 40.0 then return { ok = false, msg = 'до адреса ещё далеко' } end
    local ped = entityFromNet(o.pedNet)
    if ped and #(GetEntityCoords(ped) - pos) > 15.0 then return { ok = false, msg = 'пассажира нет в машине' } end

    local elapsed = os.time() - o.boardedAt
    local straight = #(o.dest - o.from)
    if elapsed < math.max(Config.MinTripTime, straight / Config.MaxAvgSpeed) then
        dropOrder(src, false)
        return { ok = false, msg = 'слишком быстро — поездка не засчитана', cancel = true }
    end

    stats = type(stats) == 'table' and stats or {}
    local crashes = math.max(0, math.min(20, math.floor(tonumber(stats.crashes) or 0)))
    local speeding = math.max(0, math.min(3600, tonumber(stats.speeding) or 0))
    local meterKm = math.max(0, tonumber(stats.meterKm) or 0)

    local straightKm = straight / 1000
    local km = math.max(straightKm, math.min(meterKm, straightKm * Config.Fare.maxDetour + 0.3))
    local minutes = math.min(elapsed / 60, straightKm * 4 + 5)
    local fare = Config.Fare.base + km * Config.Fare.perKm + minutes * Config.Fare.perMin
    if o.kind == 'call' then fare = fare + Config.Fare.callBonus end
    if o.special then fare = fare + Config.Special.places[o.special].bonus end

    local persona = o.persona
    local stars = 5
    stars = stars - math.min(3, crashes) * (persona == 'scared' and 2 or 1)
    if speeding > (persona == 'scared' and 8 or 25) then stars = stars - 1 end
    local expected = straight * Config.Fare.roadFactor / 12.0
    if persona == 'hurry' then
        if elapsed < expected then
            fare = fare * 1.2
            stars = stars + 1
        elseif elapsed > expected * 1.6 then
            stars = stars - 1
        end
    end
    stars = math.max(1, math.min(5, stars))
    fare = math.floor(fare)
    local tip = math.floor(fare * Config.TipMax * math.max(0, stars - 3) / 2)
    if persona == 'drunk' and stars >= 3 then tip = tip + 100 end
    local total = fare + tip
    if persona == 'bigbill' then total = math.ceil(total / 500) * 500 end

    exports.qbx_core:AddMoney(src, 'cash', total, 'Такси: оплата поездки')
    sh.earned = sh.earned + total
    sh.rides = sh.rides + 1
    sh.stats.earned = (sh.stats.earned or 0) + total
    saveVote(src, stars, total, true)
    o.state = 'done'
    orders[src] = nil
    return { ok = true, fare = fare, tip = total - fare, total = total, stars = stars, rating = rating(sh.stats) }
end)

-- отмена. fault = водитель виноват (разбил машину, бросил пассажира, погиб) — оценка 1 звезда
lib.callback.register('kavkaz_taxi:cancel', function(src, id, fault)
    local o = orders[src]
    if not o or o.id ~= id then return false end
    if fault and o.state == 'riding' then saveVote(src, 1, 0, false) end
    orders[src] = nil
    return true
end)

---------------------------------------------------------------------------
-- выход и рестарт
---------------------------------------------------------------------------

local function cleanup(src)
    if shifts[src] then endShift(src, true) end
    dropOrder(src, true)
    rate[src] = nil
end

AddEventHandler('playerDropped', function()
    cleanup(source)
end)

-- смена персонажа без выхода с сервера (события сервера qbx_core, не сетевые — клиент их вызвать не может)
AddEventHandler('qbx_core:server:playerLoggedOut', function(src)
    src = tonumber(src)
    if src then cleanup(src) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src, sh in pairs(shifts) do
        deleteNet(sh.net)
        local o = orders[src]
        if o and o.pedNet then deleteNet(o.pedNet) end
        pcall(function() Player(src).state:set('kvTaxi', nil, true) end) -- игрок мог уже выйти
    end
end)
