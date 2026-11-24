-- KAVKAZ RP: такси — клиент. пассажиров создаёт сам игрок-таксист (он же их владелец в OneSync: задачи NPC работают
-- только у владельца), сервер выдаёт заказы, проверяет посадку/высадку и платит.

local shift = nil     -- { net, plate, gen, lostWarned }
local order = nil     -- текущий заказ, см. requestOrder
local paused = false
local nextOrderAt = 0
local gen = 0
local depotPed, depotBlip
local textShown = nil

local function now() return GetGameTimer() end

local function notify(text, kind, title)
    lib.notify({ title = title or 'Такси', description = text, type = kind or 'inform', duration = 7000 })
end

-- субтитры внизу экрана (шрифт GTA умеет кириллицу); длинную строку режем на куски, у GTA лимит на один кусок
local function say(text, ms)
    if not text or text == '' then return end
    BeginTextCommandPrint('STRING')
    local len = utf8.len(text)
    if not len then
        AddTextComponentSubstringPlayerName(text)
    else
        local i = 1
        while i <= len do
            local a = utf8.offset(text, i)
            local b = utf8.offset(text, math.min(i + 40, len + 1)) or (#text + 1)
            AddTextComponentSubstringPlayerName(text:sub(a, b - 1))
            i = i + 40
        end
    end
    EndTextCommandPrint(ms or 6000, true)
end

local function speak(o, line)
    if line and o then say(('%s: %s'):format(o.name, line)) end
end

local function fmtDist(m)
    if m < 1000 then return ('%d м'):format(math.floor(m)) end
    return ('%.1f км'):format(m / 1000)
end

local function starsText(n)
    n = math.max(0, math.min(5, n or 0))
    return string.rep('★', n) .. string.rep('☆', 5 - n)
end

local function meter(text)
    if text == textShown then return end
    if text then
        lib.showTextUI(text, { position = 'right-center', icon = 'taxi' })
    elseif textShown then
        lib.hideTextUI()
    end
    textShown = text
end

local function removeBlip(b)
    if b and DoesBlipExist(b) then RemoveBlip(b) end
end

local function control(ent)
    if ent and DoesEntityExist(ent) and not NetworkHasControlOfEntity(ent) then NetworkRequestControlOfEntity(ent) end
end

local function streetLabel(c)
    local ok, s = pcall(function() return exports.kavkaz_map:streetAt(c) end)
    if not ok or not s or s == '' then
        local h = GetStreetNameAtCoord(c.x, c.y, c.z)
        s = h and h ~= 0 and GetStreetNameFromHashKey(h) or ''
    end
    local zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    if zone and zone ~= '' and zone ~= 'NULL' then
        if s ~= '' then return s .. ', ' .. zone end
        return zone
    end
    return s ~= '' and s or 'адрес на карте'
end

local function taxiVeh()
    if not shift or not NetworkDoesNetworkIdExist(shift.net) then return nil end
    local veh = NetToVeh(shift.net)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    return veh
end

local function isDriver(veh)
    local ped = PlayerPedId()
    return veh ~= nil and GetVehiclePedIsIn(ped, false) == veh and GetPedInVehicleSeat(veh, -1) == ped
end

local function loadModel(name)
    local hash = joaat(name)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local t = now() + 5000
    while not HasModelLoaded(hash) do
        if now() > t then return nil end
        Wait(50)
    end
    return hash
end

local function hail(ped)
    if not ped or not DoesEntityExist(ped) then return end
    control(ped)
    if not HasAnimDictLoaded('taxi_hail') then pcall(lib.requestAnimDict, 'taxi_hail', 3000) end
    if HasAnimDictLoaded('taxi_hail') then
        TaskPlayAnim(ped, 'taxi_hail', 'hail_taxi', 4.0, -4.0, -1, 49, 0.0, false, false, false)
    else
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    end
end

-- отпустить пассажира: вылезти (если сидит), пойти по своим делам, дальше им управляет игра
local function releasePed(ped)
    if not ped or not DoesEntityExist(ped) then return end
    CreateThread(function()
        control(ped)
        SetBlockingOfNonTemporaryEvents(ped, false)
        SetPedKeepTask(ped, false)
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and not IsEntityDead(ped) then
            TaskLeaveVehicle(ped, veh, GetEntitySpeed(veh) > 1.0 and 16 or 0)
            local t = now() + 8000
            while DoesEntityExist(ped) and IsPedInAnyVehicle(ped, false) and now() < t do Wait(250) end
        end
        if not DoesEntityExist(ped) then return end
        if not IsEntityDead(ped) then
            ClearPedSecondaryTask(ped)
            TaskWanderStandard(ped, 10.0, 10)
        end
        SetPedAsNoLongerNeeded(ped)
    end)
end

local function freeSeat(veh)
    local max = GetVehicleMaxNumberOfPassengers(veh)
    for _, s in ipairs({ 2, 1, 0 }) do
        if s < max and IsVehicleSeatFree(veh, s) then return s end
    end
    return nil
end

local function loadNodes(x, y)
    local t = now() + 1500
    while not AreNodesLoadedForArea(x - 60.0, y - 60.0, x + 60.0, y + 60.0) and now() < t do
        RequestPathNodesInAreaThisFrame(x - 60.0, y - 60.0, x + 60.0, y + 60.0)
        Wait(0)
    end
end

---------------------------------------------------------------------------
-- заказ: место посадки и адрес
---------------------------------------------------------------------------

-- тротуар у дороги впереди игрока на расстоянии minD..maxD
local function findPickup(minD, maxD)
    local me = PlayerPedId()
    local pc = GetEntityCoords(me)
    local heading = GetEntityHeading(me)
    for _ = 1, 16 do
        local ang = math.rad(heading + math.random(-80, 80))
        local d = minD + math.random() * (maxD - minD)
        local tx, ty = pc.x - math.sin(ang) * d, pc.y + math.cos(ang) * d
        local found, node = GetClosestVehicleNode(tx, ty, pc.z, 1, 3.0, 0)
        if found and node and #(node - pc) >= minD * 0.6 then
            for _, flags in ipairs({ 13, 12 }) do -- 1 только тротуар + 4 не в помещении + 8 не в воде; запасной — без тротуара
                local ok, safe = GetSafeCoordForPed(node.x, node.y, node.z, true, flags)
                if ok and safe then
                    local dn = #(vector2(safe.x, safe.y) - vector2(node.x, node.y))
                    if dn >= 2.0 and dn <= 22.0 and math.abs(safe.z - node.z) < 4.0 and #(safe - pc) >= minD * 0.5 then
                        return safe, node
                    end
                end
            end
        end
        Wait(0)
    end
    return nil
end

local function chooseDest(o, from)
    if o.special then
        local s = vector3(o.special.x, o.special.y, o.special.z)
        loadNodes(s.x, s.y)
        local ok, node = GetClosestVehicleNode(s.x, s.y, s.z, 0, 3.0, 0)
        if ok and node and #(node - s) <= Config.Special.snap then return node end
        return s
    end
    for _ = 1, 12 do
        local ang = math.random() * 2.0 * math.pi
        local d = Config.Dest.min + math.random() * (Config.Dest.max - Config.Dest.min)
        local x, y = from.x + math.cos(ang) * d, from.y + math.sin(ang) * d
        loadNodes(x, y)
        local ok, node = GetClosestVehicleNode(x, y, from.z, 0, 1.0, 0)
        if ok and node then
            local dist = #(node - from)
            if dist >= Config.Dest.min * 0.7 and dist <= Config.Dest.max * 1.2
                and #(vector2(node.x, node.y) - vector2(x, y)) < 300.0 then
                return node
            end
        end
    end
    return nil
end

local function finishOrder(o)
    removeBlip(o.blip)
    removeBlip(o.destBlip)
    o.blip, o.destBlip = nil, nil
    meter(nil)
    if o.ped then releasePed(o.ped) end
    if order == o then order = nil end
    nextOrderAt = now() + math.random(Config.NextOrder[1], Config.NextOrder[2]) * 1000
end

-- отмена: fault = виноват водитель (оценка 1 звезда)
local function cancelOrder(o, text, fault, line)
    if order ~= o then return end
    order = nil
    if line and o.ped and DoesEntityExist(o.ped) and not IsEntityDead(o.ped) then speak(o, line) end
    lib.callback.await('kavkaz_taxi:cancel', false, o.id, fault == true)
    finishOrder(o)
    if text then notify(text, fault and 'error' or 'inform') end
end

local function spawnPassenger(o)
    local minD, maxD = Config.Street.minDist, Config.Street.maxDist
    if o.kind ~= 'street' then minD, maxD = Config.Call.minDist, Config.Call.maxDist end
    local pos, node = findPickup(minD, maxD)
    if not pos then pos, node = findPickup(80.0, 150.0) end
    if not pos then return false end

    local list = Config.PedModels[o.gender] or Config.PedModels.m
    local hash = loadModel(list[math.random(#list)]) or loadModel(list[1])
    if not hash then return false end
    local heading = GetHeadingFromVector_2d(node.x - pos.x, node.y - pos.y)
    local ped = CreatePed(4, hash, pos.x, pos.y, pos.z, heading, true, true)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return false end
    local t = now() + 3000
    while not NetworkGetEntityIsNetworked(ped) and now() < t do Wait(50) end
    if not NetworkGetEntityIsNetworked(ped) then
        DeleteEntity(ped)
        return false
    end
    local net = PedToNet(ped)
    SetNetworkIdCanMigrate(net, false) -- задачи пассажиру даём только мы
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedKeepTask(ped, true)
    o.ped, o.pedNet, o.pickup = ped, net, pos
    hail(ped)

    if not lib.callback.await('kavkaz_taxi:ready', false, o.id, { x = pos.x, y = pos.y, z = pos.z }, net) then
        if DoesEntityExist(ped) then DeleteEntity(ped) end
        o.ped = nil
        return false
    end
    if order ~= o then -- смену закрыли, пока ждали сервер
        if DoesEntityExist(ped) then DeleteEntity(ped) end
        return false
    end

    o.blip = AddBlipForEntity(ped)
    SetBlipSprite(o.blip, 280)
    SetBlipColour(o.blip, 5)
    SetBlipRoute(o.blip, true)
    SetBlipRouteColour(o.blip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Клиент такси')
    EndTextCommandSetBlipName(o.blip)

    o.stage, o.stageAt = 'waiting', now()
    local where = ('%s (%s)'):format(streetLabel(pos), fmtDist(#(pos - GetEntityCoords(PlayerPedId()))))
    if o.kind == 'street' then
        notify(Phrases.dispatch.street[math.random(#Phrases.dispatch.street)]:format(where))
    else
        PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
        local list2 = o.kind == 'special' and Phrases.dispatch.special or Phrases.dispatch.call
        if o.kind == 'special' then where = ('%s → %s'):format(where, o.special.label) end
        notify(list2[math.random(#list2)]:format(where), 'inform', 'Диспетчер')
    end
    return true
end

local function requestOrder()
    local data = lib.callback.await('kavkaz_taxi:newOrder', false, GetClockHours())
    if not data then
        nextOrderAt = now() + 8000
        return
    end
    if not shift then
        lib.callback.await('kavkaz_taxi:cancel', false, data.id, false)
        return
    end
    local o = {
        id = data.id, kind = data.kind, persona = data.persona, gender = data.gender, name = data.name,
        special = data.special, stage = 'spawning', created = now(),
    }
    order = o
    if not spawnPassenger(o) then
        if order == o then order = nil end
        lib.callback.await('kavkaz_taxi:cancel', false, o.id, false)
        nextOrderAt = now() + 5000
    end
end

---------------------------------------------------------------------------
-- этапы заказа
---------------------------------------------------------------------------

local function startRide(o, veh)
    o.stage = 'starting'
    local dest = chooseDest(o, GetEntityCoords(veh))
    if order ~= o then return end
    if not dest then
        return cancelOrder(o, 'клиент не смог объяснить адрес и вышел', false, Phrases.pick(o.persona, 'cancel'))
    end
    -- сервер узнаёт, что пассажир сел, с небольшой задержкой — до трёх попыток
    local res
    for try = 1, 3 do
        res = lib.callback.await('kavkaz_taxi:board', false, o.id, { x = dest.x, y = dest.y, z = dest.z })
        if order ~= o then return end
        if res and res.ok then break end
        if try < 3 then Wait(700) end
        if order ~= o then return end
    end
    if not res or not res.ok then
        return cancelOrder(o, 'клиент передумал ехать', false, Phrases.pick(o.persona, 'cancel'))
    end
    o.dest = dest
    removeBlip(o.blip)
    o.blip = nil
    o.destBlip = AddBlipForCoord(dest.x, dest.y, dest.z)
    SetBlipColour(o.destBlip, 5)
    SetBlipRoute(o.destBlip, true)
    SetBlipRouteColour(o.destBlip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Адрес пассажира')
    EndTextCommandSetBlipName(o.destBlip)

    local label = o.special and o.special.label or streetLabel(dest)
    local line = Phrases.pick(o.persona, 'address') or '%s.'
    speak(o, line:format(label))
    o.stats = { crashes = 0, speeding = 0.0, meterKm = 0.0 }
    o.lastPos = GetEntityCoords(veh)
    o.lastBody = GetVehicleBodyHealth(veh)
    o.lastKmh = GetEntitySpeed(veh) * 3.6
    o.startedAt, o.lastTickAt = now(), now()
    o.chatterAt = now() + math.random(25, 45) * 1000
    o.stage = 'riding'
end

local function tickWaiting(o, veh)
    local ped = o.ped
    if not ped or not DoesEntityExist(ped) or IsEntityDead(ped) then
        return cancelOrder(o, 'клиент пропал — заказ снят')
    end
    if now() - o.created > Config.OrderTimeout * 1000 then
        return cancelOrder(o, 'клиент не дождался и ушёл')
    end
    if now() > (o.hailAt or 0) then
        o.hailAt = now() + 3000
        if not IsEntityPlayingAnim(ped, 'taxi_hail', 'hail_taxi', 3) then hail(ped) end
    end
    if not veh or not isDriver(veh) then return end
    if #(GetEntityCoords(veh) - GetEntityCoords(ped)) > 9.0 or GetEntitySpeed(veh) > 1.5 then return end

    if GetVehicleDoorLockStatus(veh) >= 2 then
        if now() > (o.lockWarnAt or 0) then
            o.lockWarnAt = now() + 8000
            notify('двери заблокированы — откройте, чтобы клиент сел')
        end
        return
    end
    local seat = freeSeat(veh)
    if not seat then
        if now() > (o.lockWarnAt or 0) then
            o.lockWarnAt = now() + 8000
            notify('в машине нет свободного места для клиента', 'error')
        end
        return
    end
    control(ped)
    ClearPedTasks(ped)
    TaskEnterVehicle(ped, veh, Config.BoardTimeout * 1000, seat, 1.0, 1, 0)
    o.stage, o.stageAt, o.seat = 'boarding', now(), seat
    if not o.greeted then
        o.greeted = true
        speak(o, Phrases.pick(o.persona, 'hello'))
    end
end

local function tickBoarding(o, veh)
    local ped = o.ped
    if not ped or not DoesEntityExist(ped) or IsEntityDead(ped) then
        return cancelOrder(o, 'клиент пропал — заказ снят')
    end
    if not veh then return cancelOrder(o, 'машина смены недоступна') end
    if IsPedInVehicle(ped, veh, false) then return startRide(o, veh) end
    if not isDriver(veh) or GetEntitySpeed(veh) > 3.0 or #(GetEntityCoords(veh) - GetEntityCoords(ped)) > 15.0 then
        control(ped)
        ClearPedTasks(ped)
        hail(ped)
        o.stage = 'waiting'
        return
    end
    if now() - o.stageAt > Config.BoardTimeout * 1000 then
        control(ped)
        local seat = (o.seat and IsVehicleSeatFree(veh, o.seat)) and o.seat or freeSeat(veh)
        if not seat then return cancelOrder(o, 'клиенту некуда сесть — заказ снят') end
        SetPedIntoVehicle(ped, veh, seat)
        o.stageAt = now() -- если и так не сел — ещё одна попытка через BoardTimeout
    end
end

local function tickRiding(o, veh)
    local ped, me = o.ped, PlayerPedId()
    if not ped or not DoesEntityExist(ped) then return cancelOrder(o, 'пассажир пропал') end
    if IsEntityDead(ped) then return cancelOrder(o, 'пассажир погиб — поездка сорвана', true) end
    if not veh or IsEntityDead(veh) or not IsVehicleDriveable(veh, false) then
        return cancelOrder(o, 'машина разбита — поездка сорвана', true, Phrases.pick(o.persona, 'cancel'))
    end
    if IsEntityDead(me) or LocalPlayer.state.isDead then return cancelOrder(o, 'поездка сорвана', true) end
    if not IsPedInVehicle(ped, veh, false) then return cancelOrder(o, 'пассажир вышел из машины') end

    if not isDriver(veh) then
        o.outSince = o.outSince or now()
        if not o.warnedOut and now() - o.outSince > 5000 then
            o.warnedOut = true
            speak(o, Phrases.pick(o.persona, 'driverLeft'))
        end
        if now() - o.outSince > Config.LeaveCarGrace * 1000 then
            return cancelOrder(o, 'вы бросили пассажира — поездка сорвана', true, Phrases.pick(o.persona, 'cancel'))
        end
        o.lastPos = GetEntityCoords(veh)
        o.lastTickAt = now()
        return
    end
    o.outSince, o.warnedOut = nil, false

    local t = now()
    local dt = math.min(1.0, (t - (o.lastTickAt or t)) / 1000)
    o.lastTickAt = t
    local vp = GetEntityCoords(veh)
    local step = #(vp - o.lastPos)
    if step < 80.0 then o.stats.meterKm = o.stats.meterKm + step / 1000 end
    o.lastPos = vp
    local kmh = GetEntitySpeed(veh) * 3.6

    -- авария: кузов просел или резкая потеря скорости (так не тормозят)
    local body = GetVehicleBodyHealth(veh)
    local decel = (o.lastKmh - kmh) / math.max(dt, 0.25) -- км/ч в секунду; тормоза дают ~35, удар — больше 100
    local hit = (o.lastBody - body) > 10.0 or decel > 110.0
    o.lastBody, o.lastKmh = body, kmh
    if hit and t - (o.lastCrashAt or 0) > 2500 then
        o.lastCrashAt = t
        o.stats.crashes = o.stats.crashes + 1
        speak(o, Phrases.pick(o.persona, 'crash'))
    end

    local limit = o.persona == 'scared' and Config.SpeedLimit.scared or Config.SpeedLimit.normal
    if kmh > limit then
        o.stats.speeding = o.stats.speeding + dt
        if t - (o.lastSpeedLineAt or 0) > 15000 then
            o.lastSpeedLineAt = t
            speak(o, Phrases.pick(o.persona, 'speed'))
        end
    end

    if o.persona == 'hurry' then
        if kmh < 25 then o.slowSince = o.slowSince or t else o.slowSince = nil end
        if o.slowSince and t - o.slowSince > 12000 and t - (o.lastSlowLineAt or 0) > 20000 then
            o.lastSlowLineAt = t
            speak(o, Phrases.pick('hurry', 'slow'))
        end
    end

    if o.persona ~= 'silent' and t > o.chatterAt then
        o.chatterAt = t + (o.persona == 'talker' and math.random(30, 55) or math.random(60, 110)) * 1000
        if o.persona == 'talker' or math.random() < 0.5 then speak(o, Phrases.pick(o.persona, 'chatter')) end
    end

    local left = #(vp - o.dest)
    if t > (o.meterAt or 0) then
        o.meterAt = t + 1000
        local fare = Config.Fare.base + o.stats.meterKm * Config.Fare.perKm + (t - o.startedAt) / 60000 * Config.Fare.perMin
        meter(('Счётчик: %d ₽  ·  %.1f км  ·  до адреса %s'):format(math.floor(fare), o.stats.meterKm, fmtDist(left)))
    end

    if left < 60.0 and not o.arriveSaid then
        o.arriveSaid = true
        speak(o, Phrases.pick(o.persona, 'arrive'))
    end
    if left < 25.0 and GetEntitySpeed(veh) < 1.0 and t > (o.payRetryAt or 0) then
        o.stage = 'paying'
        local res = lib.callback.await('kavkaz_taxi:dropoff', false, o.id, o.stats)
        if order ~= o then return end
        if not res or not res.ok then
            if res and res.cancel then
                order = nil
                finishOrder(o)
                return notify(res.msg or 'поездка не засчитана', 'error')
            end
            o.stage, o.payRetryAt = 'riding', now() + 3000
            if res and res.msg then notify(res.msg) end
            return
        end
        speak(o, Phrases.pick(o.persona, res.stars >= 4 and 'payGood' or 'payBad'))
        notify(('%d ₽ наличными (чаевые %d ₽) · %s · ваш рейтинг %.1f'):format(res.total, res.tip, starsText(res.stars), res.rating),
            'success', 'Поездка оплачена')
        order = nil
        finishOrder(o)
    end
end

local function tick()
    local veh = taxiVeh()
    if veh and not shift.lostWarned and (IsEntityDead(veh) or not IsVehicleDriveable(veh, false)) then
        shift.lostWarned = true
        paused = true
        notify(('машина смены разбита — закройте смену у диспетчера (штраф %d ₽)'):format(Config.LostCarFine), 'error')
    end
    local o = order
    if not o then
        if paused or now() < nextOrderAt then return end
        if veh and isDriver(veh) and not IsEntityDead(PlayerPedId()) then requestOrder() end
        return
    end
    if o.stage == 'waiting' then
        tickWaiting(o, veh)
    elseif o.stage == 'boarding' then
        tickBoarding(o, veh)
    elseif o.stage == 'riding' then
        tickRiding(o, veh)
    end
end

local function shiftLoop(g)
    CreateThread(function()
        while shift and shift.gen == g do
            local ok, err = pcall(tick)
            if not ok then
                print('[kavkaz_taxi] ошибка: ' .. tostring(err))
                Wait(1000)
            end
            Wait(250)
        end
    end)
end

-- стрелка над головой клиента, пока он ждёт
CreateThread(function()
    while true do
        local o = order
        if o and o.stage == 'waiting' and o.ped and DoesEntityExist(o.ped) then
            local pc = GetEntityCoords(o.ped)
            if #(pc - GetEntityCoords(PlayerPedId())) < 90.0 then
                DrawMarker(2, pc.x, pc.y, pc.z + 1.25, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.35, 0.35, 0.35,
                    255, 200, 0, 210, true, true, 2, false, nil, nil, false)
                Wait(0)
            else
                Wait(300)
            end
        else
            Wait(500)
        end
    end
end)

---------------------------------------------------------------------------
-- смена
---------------------------------------------------------------------------

local function clearLocal(deletePed)
    local o = order
    order = nil
    if o then
        removeBlip(o.blip)
        removeBlip(o.destBlip)
        if o.ped and DoesEntityExist(o.ped) then
            if deletePed then DeleteEntity(o.ped) else releasePed(o.ped) end
        end
    end
    meter(nil)
    shift = nil
    paused = false
end

local function chooseCarModel()
    for _, m in ipairs(Config.Cars) do
        local h = joaat(m)
        if IsModelInCdimage(h) and IsModelAVehicle(h) then return m end
    end
    return nil
end

-- свободная полоса рядом с таксопарком (правый ряд)
local function findSpawn()
    local d = Config.Depot.ped
    for n = 1, 20 do
        local ok, pos, heading = GetNthClosestVehicleNodeWithHeading(d.x, d.y, d.z, n, 0, 3.0, 0.0)
        if ok and pos then
            local h = math.rad(heading)
            local p = vector3(pos.x + math.cos(h) * 2.0, pos.y + math.sin(h) * 2.0, pos.z)
            if #(p - d.xyz) <= Config.Depot.spawnRadius and not IsAnyVehicleNearPoint(p.x, p.y, p.z, 4.0) then
                return { x = p.x, y = p.y, z = p.z, w = heading }
            end
        end
    end
    return nil
end

local function startShift()
    if shift then return notify('смена уже идёт') end
    local model = chooseCarModel()
    if not model then return notify('машина такси не найдена на сервере', 'error') end
    local res = lib.callback.await('kavkaz_taxi:start', false, model, findSpawn())
    if not res or not res.ok then return notify(res and res.msg or 'не получилось начать смену', 'error') end
    gen = gen + 1
    shift = { net = res.net, plate = res.plate, gen = gen }
    paused, nextOrderAt = false, now() + 4000
    notify(('Смена началась, рейтинг %.1f. Клиенты голосуют у тротуара рядом с вами — подъезжайте и останавливайтесь. Меню: /taxi')
        :format(res.rating or 5.0), 'success')
    shiftLoop(gen)
end

local function finishShift()
    if not shift then return notify('смена не начата') end
    if #(GetEntityCoords(PlayerPedId()) - Config.Depot.ped.xyz) > Config.Depot.returnRadius then
        local veh = taxiVeh()
        local carHome = veh and #(GetEntityCoords(veh) - Config.Depot.ped.xyz) <= Config.Depot.returnRadius
        if not carHome then
            local ok = lib.alertDialog({
                header = 'Закрыть смену здесь?',
                content = ('Машина не в таксопарке — штраф %d ₽. Чтобы без штрафа, пригоните её к диспетчеру.'):format(Config.LostCarFine),
                centered = true, cancel = true,
                labels = { confirm = 'Закрыть со штрафом', cancel = 'Отмена' },
            })
            if ok ~= 'confirm' then return end
        end
    end
    local res = lib.callback.await('kavkaz_taxi:finish', false)
    clearLocal(false)
    if res and res.ok and res.summary then
        local s = res.summary
        lib.alertDialog({
            header = 'Смена закрыта',
            content = ('Поездок: **%d**  \nЗаработано: **%d ₽**  \nНа смене: %d мин  \nРейтинг: **%.1f**%s'):format(
                s.rides, s.earned, s.minutes, s.rating, s.fine > 0 and ('  \nШтраф за машину: %d ₽'):format(s.fine) or ''),
            centered = true,
        })
    end
end

local function showStats()
    local s = lib.callback.await('kavkaz_taxi:stats', false)
    if not s then return end
    lib.alertDialog({
        header = 'Рейтинг таксиста',
        content = ('Рейтинг: **%.1f** (%d оценок)  \nПоездок всего: %d  \nЗаработано всего: %d ₽  \n%s'):format(
            s.rating, s.votes, s.rides, s.earned,
            s.special and 'Доступны дальние заказы: аэропорт и межгород.'
            or ('Дальние заказы (аэропорт, межгород) — от %d поездок и рейтинга %.1f.'):format(Config.Special.minRides, Config.Special.minRating)),
        centered = true,
    })
end

local function cancelCurrent()
    local o = order
    if not o then return notify('заказа нет') end
    if o.stage == 'riding' then
        local ok = lib.alertDialog({
            header = 'Высадить пассажира?', content = 'Поездка не будет оплачена, клиент поставит 1 звезду.',
            centered = true, cancel = true, labels = { confirm = 'Высадить', cancel = 'Везти дальше' },
        })
        if ok ~= 'confirm' or order ~= o or o.stage ~= 'riding' then return end
        cancelOrder(o, 'пассажир высажен без оплаты', true, Phrases.pick(o.persona, 'cancel'))
    elseif o.stage == 'waiting' or o.stage == 'boarding' then
        cancelOrder(o, 'заказ отменён')
    end
end

RegisterCommand('taxi', function()
    if not shift then
        return notify(('смена такси начинается у диспетчера: %s (метка на карте)'):format(Config.Depot.label))
    end
    lib.registerContext({
        id = 'kavkaz_taxi_menu',
        title = 'Такси · ' .. (shift.plate or ''),
        options = {
            {
                title = paused and 'Выйти на линию' or 'Перерыв (новых заказов не будет)',
                icon = paused and 'play' or 'pause',
                onSelect = function()
                    paused = not paused
                    if not paused then nextOrderAt = now() + 2000 end
                    notify(paused and 'перерыв: новых заказов не будет' or 'на линии: ждите клиентов')
                end,
            },
            { title = 'Отменить текущий заказ', icon = 'xmark', disabled = order == nil, onSelect = cancelCurrent },
            { title = 'Маршрут в таксопарк', icon = 'route', onSelect = function()
                SetNewWaypoint(Config.Depot.ped.x, Config.Depot.ped.y)
            end },
            { title = 'Мой рейтинг', icon = 'star', onSelect = showStats },
            { title = 'Закончить смену', icon = 'flag-checkered', onSelect = finishShift },
        },
    })
    lib.showContext('kavkaz_taxi_menu')
end, false)

---------------------------------------------------------------------------
-- диспетчер в таксопарке
---------------------------------------------------------------------------

local function spawnDepotPed()
    if depotPed then return end
    local c = Config.Depot.ped
    local hash = loadModel(Config.Depot.pedModel)
    if not hash or depotPed then return end
    local ped = CreatePed(4, hash, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return end
    depotPed = ped
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    exports.ox_target:addLocalEntity(ped, {
        { name = 'kavkaz_taxi_start', icon = 'fa-solid fa-taxi', label = 'Начать смену таксиста', distance = 2.5,
          canInteract = function() return shift == nil end, onSelect = startShift },
        { name = 'kavkaz_taxi_finish', icon = 'fa-solid fa-flag-checkered', label = 'Закончить смену', distance = 2.5,
          canInteract = function() return shift ~= nil end, onSelect = finishShift },
        { name = 'kavkaz_taxi_stats', icon = 'fa-solid fa-star', label = 'Мой рейтинг таксиста', distance = 2.5,
          onSelect = showStats },
    })
end

local function removeDepotPed()
    if not depotPed then return end
    exports.ox_target:removeLocalEntity(depotPed, { 'kavkaz_taxi_start', 'kavkaz_taxi_finish', 'kavkaz_taxi_stats' })
    if DoesEntityExist(depotPed) then DeleteEntity(depotPed) end
    depotPed = nil
end

CreateThread(function()
    local c = Config.Depot.ped
    depotBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(depotBlip, Config.Depot.blip.sprite)
    SetBlipColour(depotBlip, Config.Depot.blip.color)
    SetBlipScale(depotBlip, Config.Depot.blip.scale)
    SetBlipAsShortRange(depotBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Depot.label)
    EndTextCommandSetBlipName(depotBlip)
end)

lib.points.new({
    coords = Config.Depot.ped.xyz,
    distance = 60.0,
    onEnter = spawnDepotPed,
    onExit = removeDepotPed,
})

---------------------------------------------------------------------------
-- выход персонажа, рестарт ресурса
---------------------------------------------------------------------------

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    clearLocal(true)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearLocal(true)
    removeDepotPed()
    removeBlip(depotBlip)
end)
