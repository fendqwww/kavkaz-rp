-- KAVKAZ RP: русские знаки и щиты, посты ДПС, без американской символики

local RES = GetCurrentResourceName()

---------------------------------------------------------------------------
-- 1. подмена текстур
---------------------------------------------------------------------------
local txdName = 'kavkaz_world'
local txd

-- в память видеокарты грузим только картинки, которые реально подставлены в Config.Textures (у игроков слабые видеокарты)
local loaded = {}
local retex = {}
for _, n in ipairs(Config.RetexImages or {}) do retex[n] = true end
for _, n in ipairs(Config.SignImages or {}) do retex[n] = true end
for _, n in ipairs(Config.Sign2Images or {}) do retex[n] = true end
for _, n in ipairs(Config.UsSignImages or {}) do retex[n] = true end -- американские знаки GTA → ГОСТ (setup/retex/us_signs.py)
local function ensureImage(name)
    if loaded[name] then return true end
    -- 'local/имя' — вывеска, собранная из текстуры игры (images/local, не в git); retex — наша; иначе images/
    local path = retex[name] and ('images/retex/' .. name .. '.png') or ('images/' .. name .. '.png')
    loaded[name] = CreateRuntimeTextureFromImage(txd, name, path) ~= 0
    return loaded[name]
end

CreateThread(function()
    txd = CreateRuntimeTxd(txdName)
    for _, list in ipairs({ Config.Textures, Config.UsSigns or {} }) do
        for _, r in ipairs(list) do
            if ensureImage(r.image) then
                AddReplaceTexture(r.txd, r.txn, txdName, r.image)
            else
                print(('[kavkaz_world] нет картинки %s для %s/%s'):format(r.image, r.txd, r.txn))
            end
        end
    end
end)

-- /kvsign имя — показать нашу картинку на экране на 5 секунд (проверить, что она загрузилась)
RegisterCommand('kvsign', function(_, args)
    local name = args[1] or Config.Images[1]
    if not ensureImage(name) then return print('нет такой картинки: ' .. name) end
    local untilT = GetGameTimer() + 5000
    CreateThread(function()
        while GetGameTimer() < untilT do
            DrawSprite(txdName, name, 0.5, 0.5, 0.5, 0.5, 0.0, 255, 255, 255, 255)
            Wait(0)
        end
    end)
end, false)

---------------------------------------------------------------------------
-- 2. американские флаги
---------------------------------------------------------------------------
local function hideAll(state)
    for _, m in ipairs(Config.HideEverywhere) do
        local model = joaat(m)
        if state then
            CreateModelHideExcludingScriptObjects(0.0, 0.0, 0.0, 10000.0, model, true)
        else
            RemoveModelHide(0.0, 0.0, 0.0, 10000.0, model, false)
        end
    end
end
CreateThread(function() hideAll(true) end)

---------------------------------------------------------------------------
-- 3. посты ДПС (появляются, когда игрок рядом)
---------------------------------------------------------------------------
local spawned = {}

local function at(post, offset)
    local c = post.coords
    local r = math.rad(c.w)
    local cs, sn = math.cos(r), math.sin(r)
    return vec3(c.x + offset.x * cs - offset.y * sn, c.y + offset.x * sn + offset.y * cs, c.z + (offset.z or 0.0))
end

-- земля под точкой. коллизия вдали от игрока ещё не загружена — ждём до 3 с, иначе люди висят или проваливаются
local function ground(p)
    RequestCollisionAtCoord(p.x, p.y, p.z)
    local untilT = GetGameTimer() + 3000
    repeat
        local found, z = GetGroundZFor_3dCoord(p.x, p.y, p.z + 3.0, false)
        if found and math.abs(z - p.z) < 6.0 then return vec3(p.x, p.y, z) end
        Wait(100)
    until GetGameTimer() > untilT
    return p
end

local function load(name)
    local m = joaat(name)
    if not IsModelInCdimage(m) then return nil end
    lib.requestModel(m)
    return m
end

-- пост по дороге: ближайшая полоса, край асфальта, пост за обочиной лицом к дороге (post.auto)
local function placeByRoad(post)
    local c = post.coords
    local untilT = GetGameTimer() + 3000
    while not RequestPathsPreferAccurateBoundingstruct(c.x - 120.0, c.y - 120.0, c.x + 120.0, c.y + 120.0) and GetGameTimer() < untilT do Wait(100) end
    local found, node, heading = GetClosestVehicleNodeWithHeading(c.x, c.y, c.z, 1, 3.0, 0)
    if not found then return nil end
    local ok, edge = GetRoadBoundaryUsingHeading(node.x, node.y, node.z, heading)
    if not ok then return nil end
    local out = vec3(edge.x - node.x, edge.y - node.y, 0.0)
    local len = #out
    if len < 0.5 then return nil end
    out = out / len
    local base = vec3(edge.x, edge.y, edge.z) + out * 8.0
    -- вперёд (+y поста) — к дороге: (-sin w, cos w) = -out
    local w = math.deg(math.atan(out.x, -out.y))
    return vec4(base.x, base.y, edge.z, w), node, out
end

-- предмет не на асфальте: если попал на дорогу — отодвигаем от неё
local function offRoad(pos, out)
    if not out then return pos end
    for _ = 1, 12 do
        if not IsPointOnRoad(pos.x, pos.y, pos.z + 0.5, 0) then return pos end
        pos = pos + out * 1.0
    end
    return pos
end

local function spawnPost(post)
    local list = {}
    local out
    if post.snap then -- место на горе: высоту берём с земли (коллизия под точкой)
        local c = post.coords
        RequestCollisionAtCoord(c.x, c.y, c.z)
        local untilT, gz = GetGameTimer() + 4000, nil
        repeat
            local ok, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + 60.0, false)
            if ok then gz = z else Wait(150) end
        until gz or GetGameTimer() > untilT
        if gz then post = setmetatable({ coords = vec4(c.x, c.y, gz, c.w) }, { __index = post }) end
    end
    if post.auto then
        local coords, node, o = placeByRoad(post)
        if not coords then
            print(('[kavkaz_world] пост %s: дорога рядом не найдена'):format(post.id))
            spawned[post.id] = list
            return
        end
        post = setmetatable({ coords = coords }, { __index = post })
        out = o
        -- машины у поста сбавляют до ~35 км/ч
        list.zone = AddRoadNodeSpeedZone(node.x, node.y, node.z, 45.0, 10.0, false)
    end
    for _, p in ipairs(post.props or {}) do
        local m = load(p.model)
        if m then
            local pos = ground(offRoad(at(post, p.offset), out))
            local o = CreateObject(m, pos.x, pos.y, pos.z, false, false, false)
            SetEntityHeading(o, post.coords.w + (p.heading or 0.0))
            PlaceObjectOnGroundProperly(o)
            FreezeEntityPosition(o, true)
            SetModelAsNoLongerNeeded(m)
            list[#list + 1] = o
        end
    end
    for _, v in ipairs(post.vehicles or {}) do
        local m = load(v.model) or (v.fallback and load(v.fallback))
        if m then
            local pos = ground(offRoad(at(post, v.offset), out))
            local veh = CreateVehicle(m, pos.x, pos.y, pos.z + 0.5, post.coords.w + (v.heading or 0.0), false, false)
            SetVehicleOnGroundProperly(veh)
            SetVehicleDoorsLocked(veh, 2)
            SetEntityInvincible(veh, true)
            FreezeEntityPosition(veh, true)
            SetVehicleNumberPlateText(veh, v.plate or 'A001AA95')
            if v.color then SetVehicleColours(veh, v.color, v.color) end
            SetModelAsNoLongerNeeded(m)
            list[#list + 1] = veh
        end
    end
    for _, pd in ipairs(post.peds or {}) do
        local m = load(pd.model)
        if m then
            local pos = ground(offRoad(at(post, pd.offset), out))
            local ped = CreatePed(4, m, pos.x, pos.y, pos.z, post.coords.w + (pd.heading or 0.0), false, true)
            -- 12.11: раньше замораживали — со сценарием они «скользили», дёргались и уходили в сторону.
            -- теперь стоят сами: не пугаются, не дерутся, не убегают, не падают от толчка
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetPedFleeAttributes(ped, 0, false)
            SetPedCombatAttributes(ped, 17, true)  -- не нападать
            SetPedCanRagdoll(ped, false)
            SetPedCanBeTargetted(ped, false)
            SetPedDiesWhenInjured(ped, false)
            SetPedConfigFlag(ped, 208, true)       -- не уходить с места при столкновении
            SetPedKeepTask(ped, true)
            if pd.scenario then
                TaskStartScenarioInPlace(ped, pd.scenario, 0, true)
            else
                FreezeEntityPosition(ped, true)
            end
            SetModelAsNoLongerNeeded(m)
            list[#list + 1] = ped
        end
    end
    if not spawned[post.id] then -- игрок уехал, пока ждали коллизию
        for _, e in ipairs(list) do if DoesEntityExist(e) then DeleteEntity(e) end end
        if list.zone then RemoveRoadNodeSpeedZone(list.zone) end
        return
    end
    spawned[post.id] = list
end

local function despawnPost(id)
    for _, e in ipairs(spawned[id] or {}) do
        if DoesEntityExist(e) then DeleteEntity(e) end
    end
    if spawned[id] and spawned[id].zone then RemoveRoadNodeSpeedZone(spawned[id].zone) end
    spawned[id] = nil
end

local blips = {}
CreateThread(function()
    -- посты ДПС и «сцены» (места Нагорья в зданиях GTA) устроены одинаково
    local all = {}
    for _, p in ipairs(Config.Posts or {}) do all[#all + 1] = p end
    for _, p in ipairs(Config.Scenes or {}) do all[#all + 1] = p end
    for _, post in ipairs(all) do
        if post.blip then
            local b = AddBlipForCoord(post.coords.x, post.coords.y, post.coords.z)
            SetBlipSprite(b, post.blip.sprite)
            SetBlipColour(b, post.blip.color)
            SetBlipScale(b, 0.7)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(post.label)
            EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
        lib.points.new({
            coords = post.coords.xyz, distance = 150.0,
            onEnter = function()
                if spawned[post.id] then return end
                spawned[post.id] = {}
                CreateThread(function() spawnPost(post) end) -- ждёт коллизию — не в потоке точек
            end,
            onExit = function() despawnPost(post.id) end,
        })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    for id in pairs(spawned) do despawnPost(id) end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    for _, r in ipairs(Config.Textures) do RemoveReplaceTexture(r.txd, r.txn) end
    hideAll(false)
end)

---------------------------------------------------------------------------
-- 5. рейсы на остров «Арзамас» (Config.Transfers)
---------------------------------------------------------------------------
local flying = false

-- земля под точкой: остров качается по требованию — ждём коллизию до 3 минут, игрок стоит замороженный
local function landAt(to, text)
    local ped = cache.ped
    FreezeEntityPosition(ped, true)
    SetEntityCoordsNoOffset(ped, to.x, to.y, to.z + 50.0, false, false, false)
    lib.showTextUI(text .. ' остров подгружается', { position = 'top-center', icon = 'plane' })
    local untilT = GetGameTimer() + 120000
    local z
    while GetGameTimer() < untilT do
        RequestCollisionAtCoord(to.x, to.y, to.z)
        local ok, gz = GetGroundZFor_3dCoord(to.x, to.y, to.z + 300.0, false)
        if ok and HasCollisionLoadedAroundEntity(ped) then z = gz break end
        Wait(250)
    end
    lib.hideTextUI()
    SetEntityCoordsNoOffset(ped, to.x, to.y, (z or to.z) + 0.3, false, false, false)
    SetEntityHeading(ped, to.w or 0.0)
    FreezeEntityPosition(ped, false)
    return z
end

local addPoint

local function fly(t)
    if flying or cache.vehicle then return end
    flying = true
    DoScreenFadeOut(800)
    Wait(900)
    local z = landAt(t.to, t.text or 'Летим…')
    local ok = z ~= nil
    -- обратный рейс стоит там, куда прилетели: высоту узнаём только на месте (с земли)
    for _, u in ipairs(Config.Transfers or {}) do
        if ok and not u.ready and u.at.z == 0.0 and #(vec2(u.at.x, u.at.y) - vec2(t.to.x, t.to.y)) < 5.0 then
            u.at = vec3(u.at.x + 2.5, u.at.y, z + 1.0)
            addPoint(u)
        end
    end
    Wait(300)
    DoScreenFadeIn(900)
    if not ok then lib.notify({ title = t.label, description = 'земля не подгрузилась — если стоишь в воздухе, нажми ещё раз', type = 'error' }) end
    flying = false
end

function addPoint(t)
        t.ready = true
        if t.blip then
            local b = AddBlipForCoord(t.at.x, t.at.y, t.at.z)
            SetBlipSprite(b, t.blip.sprite) SetBlipColour(b, t.blip.color) SetBlipScale(b, 0.8) SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(t.label) EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
        lib.points.new({
            coords = t.at, distance = 3.0,
            onEnter = function() lib.showTextUI('[E] ' .. t.label, { position = 'left-center', icon = 'plane-departure' }) end,
            onExit = function() lib.hideTextUI() end,
            nearby = function()
                DrawMarker(1, t.at.x, t.at.y, t.at.z - 1.0, 0, 0, 0, 0, 0, 0, 1.6, 1.6, 0.4, 47, 191, 138, 120, false, false, 2, false, nil, nil, false)
                if IsControlJustPressed(0, 38) then lib.hideTextUI() CreateThread(function() fly(t) end) end
            end,
        })
end

CreateThread(function()
    for _, t in ipairs(Config.Transfers or {}) do
        if t.at.z ~= 0.0 then addPoint(t) end
    end
end)
