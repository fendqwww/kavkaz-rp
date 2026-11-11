-- KAVKAZ RP: американские объекты прячем по всей карте, на их местах вокруг игрока ставим наши (не сетевые, свои у каждого)

local cells, spawned = {}, {}
local function cellKey(x, y) return math.floor(x / Config.Cell) .. ':' .. math.floor(y / Config.Cell) end

-- что ставить вместо модели: { model, yaw }
local function pick(model, i)
    local r = Config.Replace[model]
    if r then
        if not r.with then return nil end
        return r.with[(i % #r.with) + 1], r.yaw or 0.0
    end
    for _, pat in ipairs(Config.SmallPalm) do
        if model:find(pat) then return Config.PalmBushes[(i % #Config.PalmBushes) + 1], 0.0 end
    end
    if model:find(Config.PalmPattern) then
        return Config.PalmTrees[(i % #Config.PalmTrees) + 1], 0.0
    end
end

-- спрятать все американские модели из списка мест
CreateThread(function()
    local hidden = {}
    for i, e in ipairs(ReplaceData) do
        if not hidden[e[1]] then
            hidden[e[1]] = true
            CreateModelHideExcludingScriptObjects(0.0, 0.0, 0.0, 10000.0, joaat(e[1]), true)
        end
        local with, yaw = pick(e[1], i)
        if with then
            local k = cellKey(e[2], e[3])
            cells[k] = cells[k] or {}
            cells[k][#cells[k] + 1] = { with, e[2], e[3], e[4], (e[5] + yaw) % 360.0 }
        end
    end
end)

local function spawnCell(k)
    local list, objs = cells[k], {}
    for _, o in ipairs(list or {}) do
        local hash = joaat(o[1])
        if IsModelInCdimage(hash) then
            lib.requestModel(hash, 3000)
            local ob = CreateObjectNoOffset(hash, o[2], o[3], o[4], false, false, false)
            SetEntityHeading(ob, o[5])
            FreezeEntityPosition(ob, true)
            SetModelAsNoLongerNeeded(hash)
            objs[#objs + 1] = ob
        end
    end
    spawned[k] = objs
end

local function clearCell(k)
    for _, ob in ipairs(spawned[k] or {}) do if DoesEntityExist(ob) then DeleteEntity(ob) end end
    spawned[k] = nil
end

CreateThread(function()
    Wait(3000)
    while true do
        local p = GetEntityCoords(cache.ped)
        local cx, cy = math.floor(p.x / Config.Cell), math.floor(p.y / Config.Cell)
        local want = {}
        local r = math.ceil(Config.Radius / Config.Cell)
        for dx = -r, r do
            for dy = -r, r do
                local k = (cx + dx) .. ':' .. (cy + dy)
                if cells[k] then want[k] = true end
            end
        end
        for k in pairs(want) do if not spawned[k] then spawnCell(k) end end
        for k in pairs(spawned) do if not want[k] then clearCell(k) end end
        Wait(1500)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for k in pairs(spawned) do clearCell(k) end
end)
