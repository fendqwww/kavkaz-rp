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

local function ground(p)
    local found, z = GetGroundZFor_3dCoord(p.x, p.y, p.z + 3.0, false)
    if found and math.abs(z - p.z) < 6.0 then return vec3(p.x, p.y, z) end
    return p
end

local function load(name)
    local m = joaat(name)
    if not IsModelInCdimage(m) then return nil end
    lib.requestModel(m)
    return m
end

local function spawnPost(post)
    local list = {}
    for _, p in ipairs(post.props or {}) do
        local m = load(p.model)
        if m then
            local pos = ground(at(post, p.offset))
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
            local pos = ground(at(post, v.offset))
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
            local pos = ground(at(post, pd.offset))
            local ped = CreatePed(4, m, pos.x, pos.y, pos.z, post.coords.w + (pd.heading or 0.0), false, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            FreezeEntityPosition(ped, true)
            if pd.scenario then TaskStartScenarioInPlace(ped, pd.scenario, 0, true) end
            SetModelAsNoLongerNeeded(m)
            list[#list + 1] = ped
        end
    end
    spawned[post.id] = list
end

local function despawnPost(id)
    for _, e in ipairs(spawned[id] or {}) do
        if DoesEntityExist(e) then DeleteEntity(e) end
    end
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
            onEnter = function() if not spawned[post.id] then spawnPost(post) end end,
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
