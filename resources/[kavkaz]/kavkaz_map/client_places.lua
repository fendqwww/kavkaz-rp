-- KAVKAZ RP: навигатор (F5 / /gps), метки мест, русские названия чужих меток, объекты карты (мечеть).

local placeBlips = {}

local function addBlip(p)
    local b = AddBlipForCoord(p.coords.x, p.coords.y, p.coords.z)
    SetBlipSprite(b, p.sprite or 1)
    SetBlipColour(b, p.color or 0)
    SetBlipScale(b, 0.8)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(p.label)
    EndTextCommandSetBlipName(b)
    placeBlips[#placeBlips + 1] = b
end

CreateThread(function()
    for _, p in ipairs(Config.Places) do
        if p.blip then addBlip(p) end
    end
end)

---------------------------------------------------------------------------
-- метки других ресурсов: русские названия и наши цвета
---------------------------------------------------------------------------

local done = {}

local function isOurs(b)
    for _, mine in ipairs(placeBlips) do if mine == b then return true end end
    return false
end

local function nearAny(pos, list)
    if not list then return false end
    for _, c in ipairs(list) do
        if #(pos - c) < 40.0 then return true end
    end
    return false
end

local function normalize()
    for sprite, rule in pairs(Config.BlipRules) do
        local b = GetFirstBlipInfoId(sprite)
        while DoesBlipExist(b) do
            if not done[b] and not isOurs(b) then
                done[b] = true
                local pos = GetBlipInfoIdCoord(b)
                if not nearAny(pos, rule.keepNear) then
                    if rule.hide then
                        SetBlipDisplay(b, 0)
                    else
                        BeginTextCommandSetBlipName('STRING')
                        AddTextComponentSubstringPlayerName(rule[1])
                        EndTextCommandSetBlipName(b)
                        if rule[2] then SetBlipColour(b, rule[2]) end
                        SetBlipAsShortRange(b, true)
                    end
                end
            end
            b = GetNextBlipInfoId(sprite)
        end
    end
end

CreateThread(function()
    Wait(5000)
    while true do
        normalize()
        Wait(10000) -- ресурсы добавляют метки после входа и при смене работы
    end
end)

---------------------------------------------------------------------------
-- навигатор
---------------------------------------------------------------------------

local function dist(c)
    local d = #(GetEntityCoords(cache.ped) - vec3(c.x, c.y, c.z))
    if d < 1000 then return ('%d м'):format(math.floor(d / 10 + 0.5) * 10) end
    return ('%.1f км'):format(d / 1000)
end

local function setRoute(label, c)
    SetNewWaypoint(c.x, c.y)
    lib.notify({ title = 'Навигатор', description = ('%s — %s. Метка на карте, едь по линии.'):format(label, dist(c)), type = 'success' })
end

local function nearestBlip(sprite)
    local me = GetEntityCoords(cache.ped)
    local best, bestD
    local b = GetFirstBlipInfoId(sprite)
    while DoesBlipExist(b) do
        if GetBlipInfoIdDisplay(b) ~= 0 then
            local p = GetBlipInfoIdCoord(b)
            local d = #(me - p)
            if not bestD or d < bestD then best, bestD = p, d end
        end
        b = GetNextBlipInfoId(sprite)
    end
    return best
end

local openNav

local function openCategory(cat)
    local options = {}
    if cat.id == 'near' then
        for _, n in ipairs(Config.Nearest) do
            local p = nearestBlip(n.sprite)
            options[#options + 1] = {
                title = n.label, description = p and ('ближайшее — ' .. dist(p)) or 'рядом не найдено',
                disabled = p == nil, icon = 'location-dot',
                onSelect = function() setRoute(n.label, p) end,
            }
        end
    else
        local list = {}
        for _, p in ipairs(Config.Places) do
            if p.cat == cat.id then list[#list + 1] = p end
        end
        if cat.id ~= 'start' then
            local me = GetEntityCoords(cache.ped)
            table.sort(list, function(a, b) return #(me - a.coords) < #(me - b.coords) end)
        end
        for i, p in ipairs(list) do
            options[#options + 1] = {
                title = (cat.id == 'start' and (i .. '. ') or '') .. p.label,
                description = (p.desc and (p.desc .. ' · ') or '') .. dist(p.coords),
                icon = 'location-dot',
                onSelect = function() setRoute(p.label, p.coords) end,
            }
        end
    end
    lib.registerContext({ id = 'kavkaz_nav_cat', title = cat.label, menu = 'kavkaz_nav', options = options })
    lib.showContext('kavkaz_nav_cat')
end

openNav = function()
    local options = {}
    if IsWaypointActive() then
        options[#options + 1] = { title = 'Убрать метку', icon = 'xmark', onSelect = function() SetWaypointOff() end }
    end
    for _, cat in ipairs(Config.NavCategories) do
        options[#options + 1] = { title = cat.label, description = cat.desc, icon = cat.icon, arrow = true, onSelect = function() openCategory(cat) end }
    end
    lib.registerContext({ id = 'kavkaz_nav', title = 'Навигатор', options = options })
    lib.showContext('kavkaz_nav')
end

RegisterCommand('gps', function() openNav() end, false)
lib.addKeybind({ name = 'kavkaz_nav', description = 'Навигатор: куда идти', defaultKey = Config.NavKey, onPressed = function()
    if LocalPlayer.state.isLoggedIn and not IsNuiFocused() then openNav() end
end })

---------------------------------------------------------------------------
-- объекты карты (data/*.json): появляются рядом, исчезают вдали — бережём слабые ПК
---------------------------------------------------------------------------

local MAPS = { 'data/mosque.json' }
local loaded = {}

local function spawnSet(set)
    local list = {}
    for _, o in ipairs(set.objects) do
        local model = o[1]
        if IsModelInCdimage(model) then
            lib.requestModel(model, 5000)
            local obj = CreateObjectNoOffset(model, o[2], o[3], o[4], false, false, false)
            SetEntityRotation(obj, o[5], o[6], o[7], 2, true)
            FreezeEntityPosition(obj, true)
            SetModelAsNoLongerNeeded(model)
            list[#list + 1] = obj
        end
    end
    return list
end

CreateThread(function()
    local sets = {}
    for _, path in ipairs(MAPS) do
        local raw = LoadResourceFile(GetCurrentResourceName(), path)
        local ok, data = pcall(json.decode, raw or '')
        if ok and data then
            data.center = vec3(data.center[1], data.center[2], data.center[3])
            sets[#sets + 1] = data
        end
    end
    while true do
        local me = GetEntityCoords(cache.ped)
        for i, set in ipairs(sets) do
            local near = #(me - set.center) < set.radius
            if near and not loaded[i] then
                loaded[i] = spawnSet(set)
            elseif not near and loaded[i] then
                for _, obj in ipairs(loaded[i]) do DeleteObject(obj) end
                loaded[i] = nil
            end
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(placeBlips) do RemoveBlip(b) end
    for _, list in pairs(loaded) do
        for _, obj in ipairs(list) do DeleteObject(obj) end
    end
end)
