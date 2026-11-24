-- KAVKAZ RP: силовики — наряды NPC. лидер вызывает наряд к себе или спецгруппу на метку; в «Перехват»/КТО по улицам
-- катаются NPC-патрули. машины и люди сетевые (их видят все), управляет ими клиент того, кто вызвал.

local units = {}    -- { kind, veh, peds = {}, blip, mode = 'drive'|'follow'|'guard'|'leave', target }
local patrols = {}  -- { veh, peds = {} }

local function countUnits(alpha)
    local n = 0
    for _, u in ipairs(units) do
        if (u.kind == 'alpha') == alpha and u.mode ~= 'leave' then n = n + 1 end
    end
    return n
end

-- точка на дороге на расстоянии [minD, maxD] от target, по возможности вне экрана
local function spawnNode(target, minD, maxD)
    local fallback
    for n = 20, 220, 8 do
        local ok, pos = GetNthClosestVehicleNode(target.x, target.y, target.z, n, 0, 3.0, 0.0)
        if ok then
            local d = #(pos - target)
            if d >= minD and d <= maxD then
                if not IsSphereVisible(pos.x, pos.y, pos.z, 4.0) then return pos end
                fallback = fallback or pos
            end
            if d > maxD then break end
        end
    end
    return fallback
end

local function headingAt(pos)
    local ok, _, h = GetClosestVehicleNodeWithHeading(pos.x, pos.y, pos.z, 1, 3.0, 0)
    return ok and h or 0.0
end

local function makeCrew(veh, def, count)
    local m = Law.loadModel(def.ped)
    local peds = {}
    if not m then return peds end
    for i = 1, count do
        local seat = i - 2 -- -1 водитель, 0 рядом, 1/2 сзади
        if seat > GetVehicleMaxNumberOfPassengers(veh) - 1 then break end
        local ped = CreatePedInsideVehicle(veh, 6, m, seat, true, false)
        if ped ~= 0 then
            SetEntityAsMissionEntity(ped, true, true)
            Law.setupOfficer(ped, def.weapon, def.armour)
            SetBlockingOfNonTemporaryEvents(ped, true)
            if def.helmet then SetPedPropIndex(ped, 0, 0, 0, true) end
            peds[#peds + 1] = ped
        end
    end
    SetModelAsNoLongerNeeded(m)
    return peds
end

local function makeCar(def, pos, heading)
    local name = Law.firstModel(def.cars)
    local m = name and Law.loadModel(name)
    if not m then return nil end
    local veh = CreateVehicle(m, pos.x, pos.y, pos.z + 0.5, heading, true, false)
    SetModelAsNoLongerNeeded(m)
    if veh == 0 then return nil end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    if def.color then SetVehicleColours(veh, def.color, def.color) end
    if def.plateIndex then SetVehicleNumberPlateTextIndex(veh, def.plateIndex) end
    SetVehicleNumberPlateText(veh, ('A%04d95'):format(math.random(1000, 9999)))
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleSiren(veh, true)
    Entity(veh).state:set('fuel', 100.0, true)
    return veh
end

local function removeUnit(u)
    if u.blip and DoesBlipExist(u.blip) then RemoveBlip(u.blip) end
    for _, p in ipairs(u.peds) do
        if DoesEntityExist(p) then pcall(function() exports.ox_target:removeLocalEntity(p) end) end
        Law.delete(p)
    end
    Law.delete(u.veh)
end

local function dismiss(u)
    if u.mode == 'leave' then return end
    u.mode = 'leave'
    if u.blip and DoesBlipExist(u.blip) then RemoveBlip(u.blip) u.blip = nil end
    CreateThread(function()
        if DoesEntityExist(u.veh) then
            for i, p in ipairs(u.peds) do
                if DoesEntityExist(p) and not IsPedInVehicle(p, u.veh, false) and Law.control(p, 500) then
                    ClearPedTasks(p)
                    TaskEnterVehicle(p, u.veh, 15000, i - 2, 1.5, 1, 0)
                end
            end
            local t = GetGameTimer() + 15000
            local all
            repeat
                Wait(500)
                all = true
                for _, p in ipairs(u.peds) do
                    if DoesEntityExist(p) and not IsPedInVehicle(p, u.veh, false) then all = false end
                end
            until all or GetGameTimer() > t
            local driver = GetPedInVehicleSeat(u.veh, -1)
            if driver ~= 0 and Law.control(driver, 500) then
                SetVehicleSiren(u.veh, false)
                TaskVehicleDriveWander(driver, u.veh, 16.0, 786603)
            end
            -- уехали из вида — убираем
            local t2 = GetGameTimer() + 60000
            while GetGameTimer() < t2 and DoesEntityExist(u.veh) and #(GetEntityCoords(u.veh) - GetEntityCoords(PlayerPedId())) < 150.0 do Wait(1000) end
        end
        removeUnit(u)
        for i, x in ipairs(units) do if x == u then table.remove(units, i) break end end
    end)
end

local function order(u, what)
    local me = PlayerPedId()
    for i, p in ipairs(u.peds) do
        if DoesEntityExist(p) and Law.control(p, 500) then
            ClearPedTasks(p)
            if IsPedInAnyVehicle(p, false) then TaskLeaveVehicle(p, GetVehiclePedIsIn(p, false), 0) end
            if what == 'follow' then
                local ox = (i % 2 == 0) and 1.2 or -1.2
                TaskFollowToOffsetOfEntity(p, me, ox, -1.5 - i * 0.6, 0.0, 2.0, -1, 1.5, true)
            elseif what == 'guard' then
                TaskGuardCurrentPosition(p, 12.0, 12.0, true)
            end
        end
    end
    u.mode = what
end

local function addUnitTargets(u)
    local opts = {
        { name = 'kvlaw_u_follow', icon = 'fa-solid fa-person-walking-arrow-right', label = 'Наряд: за мной', distance = 3.0,
          canInteract = function() return u.mode ~= 'leave' end, onSelect = function() order(u, 'follow') Law.say('Наряд', 'Есть, за вами.', 2500) end },
        { name = 'kvlaw_u_guard', icon = 'fa-solid fa-shield-halved', label = 'Наряд: охранять здесь', distance = 3.0,
          canInteract = function() return u.mode ~= 'leave' end, onSelect = function() order(u, 'guard') Law.say('Наряд', 'Есть, занимаем позиции.', 2500) end },
        { name = 'kvlaw_u_free', icon = 'fa-solid fa-flag-checkered', label = 'Наряд: свободны', distance = 3.0,
          canInteract = function() return u.mode ~= 'leave' end, onSelect = function() dismiss(u) Law.say('Наряд', 'Понял, убываем.', 2500) end },
    }
    for _, p in ipairs(u.peds) do exports.ox_target:addLocalEntity(p, opts) end
end

-- вызвать наряд/спецгруппу к точке (к себе — target = позиция игрока)
function Law.callUnit(kind, target, toMe)
    local def = Config.Units[kind]
    if not def then return end
    if kind == 'alpha' then
        if countUnits(true) >= 1 then Law.notify('спецгруппа уже работает — отзовите её («все свободны»)', 'error') return end
    elseif countUnits(false) >= Config.MaxUnits then
        Law.notify(('нарядов уже %d — отпустите кого-нибудь'):format(Config.MaxUnits), 'error') return
    end
    local ok = lib.callback.await('kavkaz_law:unit', false, kind)
    if not ok or ok.error then Law.notify(ok and ok.error or 'нет ответа', 'error') return end
    local pos = spawnNode(target, Config.UnitSpawnMin, Config.UnitSpawnMax)
    if not pos then Law.notify('рядом нет дороги — наряд не проедет', 'error') return end
    local veh = makeCar(def, pos, headingAt(pos))
    if not veh then Law.notify('машина наряда не загрузилась', 'error') return end
    local peds = makeCrew(veh, def, def.count)
    if #peds == 0 then Law.delete(veh) Law.notify('люди наряда не загрузились', 'error') return end
    local u = { kind = kind, veh = veh, peds = peds, mode = 'drive', target = target, toMe = toMe }
    units[#units + 1] = u
    u.blip = AddBlipForEntity(veh)
    SetBlipSprite(u.blip, kind == 'alpha' and 487 or 56)
    SetBlipColour(u.blip, kind == 'dps' and 38 or 40)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(def.label)
    EndTextCommandSetBlipName(u.blip)
    Law.notify(('%s выехал%s'):format(def.label, kind == 'alpha' and 'а' or ''), 'success', 'Дежурная часть')
    CreateThread(function()
        local driver = peds[1]
        local function go()
            local t = u.toMe and GetEntityCoords(PlayerPedId()) or u.target
            TaskVehicleDriveToCoordLongrange(driver, veh, t.x, t.y, t.z, kind == 'alpha' and 30.0 or 26.0, 786468, 15.0)
            SetPedKeepTask(driver, true)
            return t
        end
        local t = go()
        local started, lastGo, slowFor = GetGameTimer(), GetGameTimer(), 0
        while u.mode == 'drive' do
            Wait(1000)
            if not DoesEntityExist(veh) or not DoesEntityExist(driver) or IsPedDeadOrDying(driver, true) then dismiss(u) return end
            local d = #(GetEntityCoords(veh) - t)
            if d < 25.0 then break end
            slowFor = GetEntitySpeed(veh) < 1.0 and slowFor + 1 or 0
            if GetGameTimer() - lastGo > 8000 and Law.control(driver, 300) then lastGo = GetGameTimer() t = go() end
            if slowFor > 20 or GetGameTimer() - started > 150000 then
                -- застрял: переставим ближе по дороге (за пределами видимости, если получится)
                local p2 = spawnNode(t, 40.0, 90.0)
                if p2 and Law.control(veh, 500) then
                    SetEntityCoords(veh, p2.x, p2.y, p2.z + 0.5, false, false, false, false)
                    SetEntityHeading(veh, headingAt(p2))
                    SetVehicleOnGroundProperly(veh)
                end
                slowFor, started = 0, GetGameTimer()
            end
        end
        if u.mode ~= 'drive' then return end
        if Law.control(veh, 500) then
            TaskVehicleTempAction(driver, veh, 27, 3000)
            SetVehicleHasMutedSirens(veh, true)
        end
        Wait(2500)
        if kind == 'alpha' then
            -- спецгруппа: выходят и занимают позиции вокруг метки
            for i, p in ipairs(peds) do
                if DoesEntityExist(p) and Law.control(p, 500) then
                    local a = (i / #peds) * math.pi * 2
                    local dest = u.target + vector3(math.cos(a) * 7.0, math.sin(a) * 7.0, 0.0)
                    TaskLeaveVehicle(p, veh, 0)
                    SetTimeout(1500, function()
                        if DoesEntityExist(p) then
                            TaskGoToCoordAnyMeans(p, dest.x, dest.y, dest.z, 2.0, 0, false, 786603, 0.0)
                            SetTimeout(9000, function() if DoesEntityExist(p) and u.mode ~= 'leave' then TaskGuardCurrentPosition(p, 15.0, 15.0, true) end end)
                        end
                    end)
                end
            end
            u.mode = 'guard'
            Law.notify('спецгруппа на месте, позиции заняты', 'success', 'Спецгруппа')
        else
            order(u, 'follow')
            Law.say('Наряд', ('%s на месте. Какие указания?'):format(Law.ucfirst(def.label)), 3500)
        end
        for _, p in ipairs(peds) do SetBlockingOfNonTemporaryEvents(p, false) end
        addUnitTargets(u)
    end)
end

function Law.dismissAll()
    local n = 0
    for _, u in ipairs(units) do if u.mode ~= 'leave' then dismiss(u) n = n + 1 end end
    Law.notify(n > 0 and ('отпущено нарядов: %d'):format(n) or 'нарядов нет', 'inform', 'Дежурная часть')
end

---------------------------------------------------------------------------
-- патрули в усиленных режимах (Config.Modes[...].patrols на каждого игрока)
---------------------------------------------------------------------------
local function removePatrol(p)
    for _, ped in ipairs(p.peds) do Law.delete(ped) end
    Law.delete(p.veh)
end

CreateThread(function()
    while true do
        Wait(5000)
        local want = (Config.Modes[Law.mode()] or Config.Modes.normal).patrols or 0
        if not LocalPlayer.state.isLoggedIn then want = 0 end
        local myPos = GetEntityCoords(PlayerPedId())
        for i = #patrols, 1, -1 do
            local p = patrols[i]
            local gone = not DoesEntityExist(p.veh) or #(GetEntityCoords(p.veh) - myPos) > 450.0
            if gone or #patrols > want then
                removePatrol(p)
                table.remove(patrols, i)
            end
        end
        if #patrols < want then
            local pos = spawnNode(myPos, 180.0, 320.0)
            if pos then
                local kind = (Law.mode() == 'kto' and #patrols % 2 == 1) and 'fsb' or 'dps'
                local def = Config.Units[kind]
                local veh = makeCar(def, pos, headingAt(pos))
                if veh then
                    SetVehicleHasMutedSirens(veh, true) -- только маячки, без воя
                    local peds = makeCrew(veh, def, 2)
                    if #peds > 0 then
                        TaskVehicleDriveWander(peds[1], veh, 14.0, 786603)
                        SetPedKeepTask(peds[1], true)
                        patrols[#patrols + 1] = { veh = veh, peds = peds }
                    else
                        Law.delete(veh)
                    end
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= Law.RES then return end
    for _, u in ipairs(units) do removeUnit(u) end
    for _, p in ipairs(patrols) do removePatrol(p) end
end)
