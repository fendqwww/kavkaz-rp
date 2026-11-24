-- KAVKAZ RP: силовики — посты. появляются, когда игрок рядом (у каждого игрока свои инспекторы-«декорации»),
-- проверяют NPC-машины (заезд в карман, инспектор у окна, отпустить/штраф/задержать) и иногда останавливают игроков.
-- машины NPC — сетевые: проверку ведёт тот игрок, чей клиент владеет машиной, остальным сервер пересылает «анимацию».

local spawned = {}   -- [postId] = { ents = {}, peds = {}, checker, org, pocket, edge, out, dir, ready, busy, nextCheck, zone, ... }
local blips = {}     -- [postId] = blip
local defs = {}      -- [postId] = def (статичные + временные)

local function modeCfg() return Config.Modes[Law.mode()] or Config.Modes.normal end

-- кто стоит на посту сейчас: 'dps' | 'fsb' | 'mixed' | nil
local function staffing(def)
    local ov = (GlobalState.kvLawPosts or {})[def.id]
    if ov == 'off' then return nil end
    if ov then return ov end
    if def.temp then return def.org end
    local m = Law.mode()
    if def.gate then
        if m == 'intercept' then return 'dps' end
        if m == 'kto' then return 'fsb' end
        return nil
    end
    if m == 'normal' then return def.normal and def.org or nil end
    if m == 'kto' then return def.org == 'fsb' and 'fsb' or 'mixed' end
    return def.org
end

local function at(base, heading, off)
    local r = math.rad(heading)
    local cs, sn = math.cos(r), math.sin(r)
    return vector3(base.x + off.x * cs - off.y * sn, base.y + off.x * sn + off.y * cs, base.z + (off.z or 0.0))
end

local function ground(p)
    RequestCollisionAtCoord(p.x, p.y, p.z)
    local untilT = GetGameTimer() + 3000
    repeat
        local found, z = GetGroundZFor_3dCoord(p.x, p.y, p.z + 3.0, false)
        if found and math.abs(z - p.z) < 6.0 then return vector3(p.x, p.y, z) end
        Wait(100)
    until GetGameTimer() > untilT
    return p
end

local function offRoad(pos, out)
    for _ = 1, 12 do
        if not IsPointOnRoad(pos.x, pos.y, pos.z + 0.5, 0) then return pos end
        pos = pos + out * 1.0
    end
    return pos
end

-- место поста у дороги: 8 м за обочиной лицом к дороге; карман для проверки — на асфальте у края, 12 м дальше по ходу
local function place(def)
    local c = def.coords
    local untilT = GetGameTimer() + 3000
    while not RequestPathsPreferAccurateBoundingstruct(c.x - 150.0, c.y - 150.0, c.x + 150.0, c.y + 150.0) and GetGameTimer() < untilT do Wait(100) end
    local found, node, heading = GetClosestVehicleNodeWithHeading(c.x, c.y, c.z, 1, 3.0, 0)
    if not found then return nil end
    if def.shift then -- сдвиг вдоль дороги (КПП у стелы въезда)
        local d = Law.dirOf(heading)
        local p = vector3(node.x, node.y, node.z) + d * def.shift
        local f2, n2, h2 = GetClosestVehicleNodeWithHeading(p.x, p.y, p.z, 1, 3.0, 0)
        if f2 then node, heading = n2, h2 end
    end
    local ok, edge = GetRoadBoundaryUsingHeading(node.x, node.y, node.z, heading)
    if not ok then return nil end
    local out, len = Law.norm2(vector3(edge.x - node.x, edge.y - node.y, 0.0))
    if len < 0.5 then return nil end
    edge = vector3(edge.x, edge.y, edge.z)
    local dir = Law.dirOf(heading)
    local base = edge + out * 8.0
    local w = math.deg(math.atan(out.x, -out.y)) -- лицом к дороге (+Y поста = −out)
    return { base = base, w = w, edge = edge, out = out, dir = dir, node = node,
        pocket = edge - out * 2.3 + dir * 12.0, pocketHeading = heading }
end

local function addBlip(def, org)
    if blips[def.id] then RemoveBlip(blips[def.id]) blips[def.id] = nil end
    if not org then return end
    local c = def.temp and vector3(def.coords.x, def.coords.y, def.coords.z) or def.coords.xyz
    local b = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(b, org == 'fsb' and 487 or 60)
    SetBlipColour(b, org == 'fsb' and 40 or 38)
    SetBlipScale(b, 0.7)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(def.temp and ('Временный пост (%s)'):format(org == 'fsb' and 'ФСБ' or org == 'mixed' and 'ДПС и ФСБ' or 'ДПС') or def.label)
    EndTextCommandSetBlipName(b)
    blips[def.id] = b
end

local function spawnPed(model, pos, heading, scenario, weapon)
    local m = Law.loadModel(model)
    if not m then return nil end
    local ped = CreatePed(4, m, pos.x, pos.y, pos.z, heading, false, true)
    SetModelAsNoLongerNeeded(m)
    if ped == 0 then return nil end
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedCanBeTargetted(ped, false)
    Law.setupOfficer(ped, weapon, 100)
    SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true)
    if scenario then TaskStartScenarioInPlace(ped, scenario, 0, true) end
    return ped
end

local function despawn(id)
    local sp = spawned[id]
    if not sp then return end
    sp.dead = true
    for _, e in ipairs(sp.ents or {}) do
        if DoesEntityExist(e) then
            if IsEntityAPed(e) then pcall(function() exports.ox_target:removeLocalEntity(e) end) end
            DeleteEntity(e)
        end
    end
    if sp.zone then RemoveRoadNodeSpeedZone(sp.zone) end
    spawned[id] = nil
end

local function spawn(def)
    local org = staffing(def)
    local sp = { ents = {}, peds = {}, org = org, def = def }
    spawned[def.id] = sp -- пост без людей (статичный, не в смену): будка и конусы стоят, проверок нет
    local pl = place(def)
    if spawned[def.id] ~= sp then return end -- пока искали дорогу, пост убрали
    if not pl then
        print(('[kavkaz_law] пост %s: дорога рядом не найдена'):format(def.id))
        sp.ready = false
        return
    end
    for k, v in pairs(pl) do sp[k] = v end
    local function put(model, off, h, freeze)
        local m = Law.loadModel(model)
        if not m then return end
        local pos = ground(offRoad(at(pl.base, pl.w, off), pl.out))
        local o = CreateObject(m, pos.x, pos.y, pos.z, false, false, false)
        SetModelAsNoLongerNeeded(m)
        SetEntityHeading(o, pl.w + (h or 0.0))
        PlaceObjectOnGroundProperly(o)
        if freeze ~= false then FreezeEntityPosition(o, true) end
        sp.ents[#sp.ents + 1] = o
    end
    if not def.temp and not def.gate then
        for _, p in ipairs(Config.PostProps) do put(p.model, p.offset, p.heading) end
    end
    if org or not def.gate then
        -- конусы по обочине перед карманом (на асфальте у самого края — машины объезжают)
        for i = 0, 3 do
            local p = pl.edge - pl.out * 0.8 + pl.dir * (2.0 + i * 4.0)
            local m = Law.loadModel(Config.ConeModel)
            if m then
                local g = ground(p)
                local o = CreateObject(m, g.x, g.y, g.z, false, false, false)
                SetModelAsNoLongerNeeded(m)
                PlaceObjectOnGroundProperly(o)
                FreezeEntityPosition(o, true)
                sp.ents[#sp.ents + 1] = o
            end
        end
    end
    if org then
        -- служебная машина у поста (декорация, не на дороге)
        local list = org == 'fsb' and Config.Orgs.fsb.cars or Config.Orgs.dps.cars
        local model = Law.firstModel(list)
        local m = model and Law.loadModel(model)
        if m then
            local pos = ground(offRoad(at(pl.base, pl.w, vec3(-5.0, 6.0, 0.0)), pl.out))
            local veh = CreateVehicle(m, pos.x, pos.y, pos.z + 0.5, pl.w + 70.0, false, false)
            SetModelAsNoLongerNeeded(m)
            SetVehicleOnGroundProperly(veh)
            SetVehicleDoorsLocked(veh, 2)
            SetEntityInvincible(veh, true)
            FreezeEntityPosition(veh, true)
            if org == 'fsb' then SetVehicleColours(veh, 0, 0) end
            SetVehicleNumberPlateText(veh, org == 'fsb' and 'K001EK95' or ('A%04d95'):format(math.random(1000, 9999)))
            SetVehicleNumberPlateTextIndex(veh, org == 'fsb' and 0 or 2)
            SetVehicleSiren(veh, Law.mode() ~= 'normal')
            SetVehicleHasMutedSirens(veh, true)
            sp.ents[#sp.ents + 1] = veh
        end
        -- люди: первый — проверяющий у дороги, остальные — у будки
        local crew = org == 'fsb' and { 'fsb', 'fsb' } or org == 'mixed' and { 'dps', 'fsb', 'fsb' } or { 'dps', 'dps' }
        local spots = { vec3(0.5, 7.0, 0.0), vec3(-4.0, 0.8, 0.0), vec3(-2.0, 3.5, 0.0) }
        local scen = { 'WORLD_HUMAN_COP_IDLES', 'WORLD_HUMAN_CLIPBOARD', 'WORLD_HUMAN_GUARD_STAND' }
        for i, kind in ipairs(crew) do
            local o = Config.Orgs[kind]
            local pos = ground(offRoad(at(pl.base, pl.w, spots[i]), pl.out))
            local ped = spawnPed(o.ped, pos, pl.w + (i == 1 and 0.0 or 270.0), scen[i], kind == 'fsb' and o.weapon or nil)
            if ped then
                sp.ents[#sp.ents + 1] = ped
                sp.peds[#sp.peds + 1] = { ped = ped, home = pos, heading = pl.w + (i == 1 and 0.0 or 270.0), scenario = scen[i], kind = kind }
                if i == 1 then sp.checker = sp.peds[#sp.peds] end
                if Law.addPostTargets then Law.addPostTargets(ped, def, org) end
            end
        end
        if Law.mode() ~= 'normal' or org then
            sp.zone = AddRoadNodeSpeedZone(pl.node.x, pl.node.y, pl.node.z, 45.0, 10.0, false) -- у поста все сбавляют
        end
        local mc = modeCfg()
        sp.nextCheck = GetGameTimer() + math.random(8, 20) * 1000
        sp.checkEvery = mc.check
    end
    sp.ready = true
end

---------------------------------------------------------------------------
-- список постов: статичные + временные (от лидера); пересборка при смене режима/постов
---------------------------------------------------------------------------
local points = {}

local function rebuild()
    local want = {}
    for _, p in ipairs(Config.Posts) do want[p.id] = p end
    for _, t in ipairs(GlobalState.kvLawTemp or {}) do
        want[t.id] = { id = t.id, label = 'Временный пост', coords = vector4(t.x, t.y, t.z, 0.0), org = t.org, temp = true }
    end
    -- убрать пропавшие
    for id, pt in pairs(points) do
        if not want[id] then
            pt:remove()
            points[id] = nil
            despawn(id)
            addBlip({ id = id }, nil)
            defs[id] = nil
        end
    end
    for id, def in pairs(want) do
        defs[id] = def
        local org = staffing(def)
        addBlip(def, org or ((not def.gate and not def.temp) and def.org or nil))
        -- поменялся состав — пересоздать; КПП/временный пост, которого не было, — поставить, если игрок уже рядом
        local sp = spawned[id]
        if sp and sp.org ~= org then
            despawn(id)
            sp = nil
        end
        local c = def.coords
        local near = #(GetEntityCoords(PlayerPedId()) - vector3(c.x, c.y, c.z)) < Config.PostSpawnDistance
        if not sp and near and (org or (not def.gate and not def.temp)) then
            spawned[id] = {}
            CreateThread(function() spawn(def) end)
        end
        if not points[id] then
            local c = def.coords
            points[id] = lib.points.new({
                coords = vector3(c.x, c.y, c.z), distance = Config.PostSpawnDistance,
                onEnter = function()
                    if spawned[id] then return end
                    if not staffing(def) and (def.gate or def.temp) then return end -- пустой КПП/временный — ничего не ставим
                    spawned[id] = {}
                    CreateThread(function() spawn(defs[id] or def) end)
                end,
                onExit = function() despawn(id) end,
            })
        end
    end
end

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end
    rebuild()
end)
AddStateBagChangeHandler('kvLawMode', 'global', function() SetTimeout(200, rebuild) end)
AddStateBagChangeHandler('kvLawPosts', 'global', function() SetTimeout(200, rebuild) end)
AddStateBagChangeHandler('kvLawTemp', 'global', function() SetTimeout(200, rebuild) end)

function Law.postList() return defs, spawned, staffing end

---------------------------------------------------------------------------
-- инспектор поста подходит к машине (у всех игроков рядом — сервер пересылает)
---------------------------------------------------------------------------
local function walkCheck(sp, veh, holdMs)
    local c = sp.checker
    if not c or not DoesEntityExist(c.ped) then return end
    local ped = c.ped
    ClearPedTasks(ped)
    local door = GetOffsetFromEntityInWorldCoords(veh, -1.4, 0.6, 0.0)
    TaskGoStraightToCoord(ped, door.x, door.y, door.z, 1.0, 12000, GetEntityHeading(veh) - 90.0, 0.5)
    local untilT = GetGameTimer() + 12000
    while GetGameTimer() < untilT and DoesEntityExist(ped) and DoesEntityExist(veh) and #(GetEntityCoords(ped) - door) > 1.2 do Wait(200) end
    if not DoesEntityExist(ped) then return end
    if DoesEntityExist(veh) then TaskTurnPedToFaceEntity(ped, veh, 1500) Wait(1500) end
    if not DoesEntityExist(ped) then return end
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    Wait(holdMs)
    if not DoesEntityExist(ped) then return end
    ClearPedTasks(ped)
    TaskGoStraightToCoord(ped, c.home.x, c.home.y, c.home.z, 1.0, 15000, c.heading, 0.5)
    untilT = GetGameTimer() + 15000
    while GetGameTimer() < untilT and DoesEntityExist(ped) and #(GetEntityCoords(ped) - c.home) > 1.0 do Wait(250) end
    if DoesEntityExist(ped) then
        SetEntityHeading(ped, c.heading)
        TaskStartScenarioInPlace(ped, c.scenario, 0, true)
    end
end

RegisterNetEvent('kavkaz_law:client:postAnim', function(postId, netId, holdMs)
    local sp = spawned[postId]
    if not sp or not sp.ready or sp.walking then return end
    sp.walking = true
    CreateThread(function()
        local untilT = GetGameTimer() + 30000
        local veh = 0
        -- ждём, пока машина приедет в карман и встанет
        while GetGameTimer() < untilT do
            if NetworkDoesNetworkIdExist(netId) then veh = NetToVeh(netId) end
            if veh ~= 0 and DoesEntityExist(veh) and GetEntitySpeed(veh) < 0.5 and sp.pocket and #(GetEntityCoords(veh) - sp.pocket) < 30.0 then break end
            Wait(500)
        end
        if veh ~= 0 and DoesEntityExist(veh) and spawned[postId] == sp then walkCheck(sp, veh, holdMs or 12000) end
        sp.walking = false
    end)
end)

---------------------------------------------------------------------------
-- проверка NPC-машины постом (ведёт клиент-владелец машины)
---------------------------------------------------------------------------
local SKIP_CLASS = { [13] = true, [14] = true, [15] = true, [16] = true, [18] = true, [19] = true, [21] = true }

local function candidate(sp)
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) and not IsEntityAMissionEntity(veh) and NetworkHasControlOfEntity(veh) and not SKIP_CLASS[GetVehicleClass(veh)] then
            local driver = GetPedInVehicleSeat(veh, -1)
            if driver ~= 0 and not IsPedAPlayer(driver) and not IsPedDeadOrDying(driver, true) and not Law.hasPlayerInside(veh) then
                local pos = GetEntityCoords(veh)
                local rel = pos - sp.pocket
                local along = rel.x * sp.dir.x + rel.y * sp.dir.y
                if along > -90.0 and along < -25.0 and math.abs(pos.z - sp.pocket.z) < 6.0 then
                    local lateral = (pos.x - sp.edge.x) * sp.out.x + (pos.y - sp.edge.y) * sp.out.y
                    if lateral < 0.5 and lateral > -9.0 then
                        local v = GetEntityVelocity(veh)
                        local speed = #v
                        if speed > 3.0 and speed < 33.0 and (v.x * sp.dir.x + v.y * sp.dir.y) / speed > 0.8 then
                            return veh, driver
                        end
                    end
                end
            end
        end
    end
end

local function runCheck(id, sp, veh, driver)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local hold = math.random(10, 20) * 1000
    TriggerServerEvent('kavkaz_law:server:postAnim', id, netId, hold)
    local ok = Law.pullOver(veh, driver, sp.pocket, 25000)
    if not ok then
        Law.releaseDriver(veh, driver)
        return
    end
    -- ждём инспектора: он подходит, проверяет, уходит
    local untilT = GetGameTimer() + hold + 9000
    while GetGameTimer() < untilT do
        Wait(500)
        if not DoesEntityExist(veh) or not DoesEntityExist(driver) or IsPedDeadOrDying(driver, true) then return end
        if spawned[id] ~= sp then break end -- пост убрали (игрок уехал) — отпускаем
    end
    local m = Law.mode()
    local detainChance = (m == 'intercept' or m == 'kto') and 0.10 or 0.04
    if math.random() < detainChance and spawned[id] == sp and sp.peds[1] and Law.control(driver, 600) then
        -- задержание: водитель выходит и уходит с инспектором за будку, машину потом заберёт эвакуатор
        TaskLeaveVehicle(driver, veh, 256)
        local t = GetGameTimer() + 8000
        while IsPedInAnyVehicle(driver, false) and GetGameTimer() < t do Wait(200) end
        if DoesEntityExist(driver) then
            Law.say(nil, '~b~Пост:~s~ водитель задержан до выяснения', 4000)
            local home = sp.base or GetEntityCoords(driver)
            TaskGoStraightToCoord(driver, home.x, home.y, home.z, 1.0, 15000, 0.0, 0.5)
            Wait(9000)
            if DoesEntityExist(driver) then
                NetworkFadeOutEntity(driver, false, true)
                Wait(1200)
                Law.delete(driver)
            end
        end
        if DoesEntityExist(veh) and Law.control(veh, 600) then
            SetVehicleIndicatorLights(veh, 0, true)
            SetVehicleIndicatorLights(veh, 1, true)
            SetEntityAsNoLongerNeeded(veh)
        end
        return
    end
    Law.releaseDriver(veh, driver)
end

CreateThread(function()
    while true do
        local now = GetGameTimer()
        for id, sp in pairs(spawned) do
            if sp.ready and sp.org and not sp.busy and sp.nextCheck and now >= sp.nextCheck then
                local veh, driver = candidate(sp)
                if veh then
                    sp.busy = true
                    CreateThread(function()
                        local ok, err = pcall(runCheck, id, sp, veh, driver)
                        if not ok then print('[kavkaz_law] проверка поста: ' .. tostring(err)) end
                        sp.busy = false
                        local mc = modeCfg()
                        sp.nextCheck = GetGameTimer() + math.random(mc.check[1], mc.check[2]) * 1000
                    end)
                else
                    sp.nextCheck = now + 2500
                end
            end
        end
        Wait(1000)
    end
end)

---------------------------------------------------------------------------
-- пост останавливает игрока
---------------------------------------------------------------------------
local asked = {}      -- [postId] = true, пока игрок не отъехал дальше 120 м (один раз за проезд)
local lastAsk = 0

local function checkPlayer(id, sp)
    local me = PlayerPedId()
    Law.say('Инспектор', Phrases.postStopPlayer[math.random(#Phrases.postStopPlayer)], 5000)
    PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
    Law.notify(('пост требует остановиться: встаньте у поста в течение %d секунд'):format(Config.PlayerStop.wait), 'warning', 'Пост ДПС')
    local untilT = GetGameTimer() + Config.PlayerStop.wait * 1000
    local stopped = false
    while GetGameTimer() < untilT do
        Wait(300)
        local veh = GetVehiclePedIsIn(me, false)
        if veh == 0 then break end
        if GetEntitySpeed(veh) < 0.5 and #(GetEntityCoords(veh) - sp.pocket) < Config.PlayerStop.stopRadius then
            stopped = true
            break
        end
    end
    if not stopped then
        if lib.callback.await('kavkaz_law:playerIgnored', false, id) then
            Law.notify('вы не остановились по требованию инспектора — штраф придёт (/fines)', 'error', 'Пост ДПС')
        end
        return
    end
    local veh = GetVehiclePedIsIn(me, false)
    if sp.checker and DoesEntityExist(sp.checker.ped) and veh ~= 0 then
        CreateThread(function() walkCheck(sp, veh, 9000) end)
    end
    Wait(4500)
    Law.say('Инспектор', Phrases.postCheckPlayer[math.random(#Phrases.postCheckPlayer)], 4000)
    local done = lib.progressBar({ duration = 6000, label = 'проверка документов', canCancel = false,
        disable = { car = true, move = true, combat = true } })
    local res = lib.callback.await('kavkaz_law:playerStopped', false, id)
    if not res or res.skip then return end
    if not res.license then
        Law.say('Инспектор', Phrases.postPlayerNoLicense[math.random(#Phrases.postPlayerNoLicense)], 5000)
        Law.notify('нет водительского удостоверения: штраф по ст. 12.7 (/fines). права — в автошколе', 'error', 'Пост ДПС')
    else
        Law.say('Инспектор', Phrases.postPlayerOk[math.random(#Phrases.postPlayerOk)], 4000)
    end
    if (res.unpaid or 0) > 0 then
        Law.notify(('у вас неоплаченных штрафов: %d — оплатите, пока не удвоились (/fines)'):format(res.unpaid), 'warning', 'Пост ДПС')
    end
    return done
end

CreateThread(function()
    while true do
        local sleep = 1000
        local me = PlayerPedId()
        local veh = GetVehiclePedIsIn(me, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == me and not Law.duty() and GetVehicleClass(veh) ~= 18 then
            local pos = GetEntityCoords(veh)
            for id, sp in pairs(spawned) do
                if sp.ready and sp.org and sp.pocket then
                    local d = #(pos - sp.pocket)
                    if d > 120.0 then
                        asked[id] = nil
                    elseif d < 90.0 then
                        sleep = 300
                        if not asked[id] and d < Config.PlayerStop.radius + 40.0 then
                            local v = GetEntityVelocity(veh)
                            local speed = #v
                            local rel = pos - sp.pocket
                            local along = rel.x * sp.dir.x + rel.y * sp.dir.y
                            if speed > 2.0 and (v.x * sp.dir.x + v.y * sp.dir.y) / speed > 0.6 and along > -60.0 and along < -10.0 then
                                asked[id] = true
                                if GetGameTimer() - lastAsk > Config.PlayerStop.cooldown * 1000 and math.random() < modeCfg().player then
                                    lastAsk = GetGameTimer()
                                    checkPlayer(id, sp)
                                end
                            end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= Law.RES then return end
    for id in pairs(spawned) do despawn(id) end
    for _, b in pairs(blips) do RemoveBlip(b) end
end)
