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
    if not Config.PalmsToTrees then return nil end -- 15.11: пальмы просто убираем, деревья расставим отдельно
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
    local all = {}
    for _, e in ipairs(ReplaceData) do all[#all + 1] = e end
    for _, e in ipairs(Config.TrafficLights and LightsData or {}) do all[#all + 1] = e end
    for i, e in ipairs(all) do
        if not hidden[e[1]] then
            hidden[e[1]] = true
            CreateModelHideExcludingScriptObjects(0.0, 0.0, 0.0, 10000.0, joaat(e[1]), true)
        end
        local with, yaw = pick(e[1], i)
        if with then
            local k = cellKey(e[2], e[3])
            cells[k] = cells[k] or {}
            -- деревья вместо пальм встают на землю под собой (пальма стояла в кадке или утопленной — берёза висела/тонула)
            cells[k][#cells[k] + 1] = { with, e[2], e[3], e[4], (e[5] + yaw) % 360.0, snap = not Config.Replace[e[1]] }
        end
    end
    -- готовые расстановки (Map Editor): { хэш, x, y, z, rx, ry, rz } — поворот целиком, а не только курс
    for _, e in ipairs(Config.Placements and RublevkaData or {}) do
        local k = cellKey(e[2], e[3])
        cells[k] = cells[k] or {}
        cells[k][#cells[k] + 1] = { e[1], e[2], e[3], e[4], e[7], e[5], e[6] }
    end
    for _, h in ipairs(Config.Placements and RublevkaHide or {}) do
        CreateModelHide(h[2], h[3], h[4], 3.0, h[1], true)
    end
    -- русские кварталы (setup/maps/make_rublocks.py): { модель, x, y, курс } — высоту берём с земли на месте
    for _, e in ipairs(Config.RuBlocks and RuBlocksData or {}) do
        local k = cellKey(e[2], e[3])
        cells[k] = cells[k] or {}
        cells[k][#cells[k] + 1] = { e[1], e[2], e[3], false, e[4] }
    end
    -- 13.11: на видео основателя пальмы в городе остались — общий вызов на всю карту срабатывает не всегда.
    -- повторяем скрытие кругом 450 м вокруг игрока каждые 100 м пути (старый круг снимаем)
    local models = {}
    for name in pairs(hidden) do models[#models + 1] = joaat(name) end
    local last
    while true do
        local p = GetEntityCoords(cache.ped)
        if not last or #(p - last) > 100.0 then
            for _, h in ipairs(models) do
                if last then RemoveModelHide(last.x, last.y, last.z, 450.0, h, false) end
                CreateModelHideExcludingScriptObjects(p.x, p.y, p.z, 450.0, h, true)
            end
            last = p
        end
        Wait(3000)
    end
end)

-- высота дома по земле: углы и центр. склон больше Config.MaxSlope — место пропускаем (дом не висит и не тонет).
-- nil — коллизия ещё не загрузилась (далеко), попробуем позже; false — место не подходит
local function groundFor(hash, x, y, yaw)
    local mn, mx = GetModelDimensions(hash)
    local r = math.rad(yaw)
    local cs, sn = math.cos(r), math.sin(r)
    local zs = {}
    for _, c in ipairs({ { 0, 0 }, { mn.x, mn.y }, { mx.x, mn.y }, { mn.x, mx.y }, { mx.x, mx.y } }) do
        local px, py = x + c[1] * cs - c[2] * sn, y + c[1] * sn + c[2] * cs
        RequestCollisionAtCoord(px, py, 100.0)
        local ok, z = GetGroundZFor_3dCoord(px, py, 1000.0, false)
        if not ok then return nil end
        if IsPointOnRoad(px, py, z + 0.5, 0) then return false end -- угол на дороге: трафик врезался бы
        zs[#zs + 1] = z
    end
    -- ближайшая полоса не ближе 6 м от стены (по самой длинной стороне дома)
    local found, node = GetClosestVehicleNode(x, y, zs[1], 1, 3.0, 0)
    if found and #(vec2(node.x, node.y) - vec2(x, y)) < math.max(mx.x - mn.x, mx.y - mn.y) / 2 + 6.0 then return false end
    -- земля сильно выше/ниже улицы — это крыша чужого здания или обрыв: не ставим
    if found and math.abs(zs[1] - node.z) > 6.0 then return false end
    local lo, hi = math.huge, -math.huge
    for _, z in ipairs(zs) do lo, hi = math.min(lo, z), math.max(hi, z) end
    if hi - lo > (Config.MaxSlope or 2.0) then return false end
    local wet, wz = GetWaterHeight(x, y, hi + 20.0)
    if wet and wz > lo - 1.0 then return false end -- берег озера: не в воду
    return lo - 0.15
end

-- 15.11: двор у жилого дома (Config.Yards). по одной длинной стороне — лавочки и стол, по другой — машины, у торца — баки.
-- всё ставится только вместе с домом и только на землю рядом с ним: не на дорогу, не у самой полосы, не на крышу/в обрыв
local function pickOf(list, seed) return list[(seed % #list) + 1] end

local function nearLane(x, y, z, d)
    local found, node = GetClosestVehicleNode(x, y, z, 1, 3.0, 0)
    return found and #(vec2(node.x, node.y) - vec2(x, y)) < d
end

local function yardGround(x, y, baseZ, laneGap)
    local ok, gz = GetGroundZFor_3dCoord(x, y, baseZ + 4.0, false)
    if not ok or math.abs(gz - baseZ) > 2.5 then return nil end
    if IsPointOnRoad(x, y, gz + 0.5, 0) or nearLane(x, y, gz, laneGap) then return nil end
    return gz
end

local function loadModel(hash)
    if not IsModelInCdimage(hash) then return false end
    local ok = pcall(lib.requestModel, hash, 5000)
    return ok and HasModelLoaded(hash)
end

local function spawnYard(name, x, y, z, yaw)
    local Y = Config.Yards
    if not Y or not Y.houses[name] then return nil end
    local out = {}
    local mn, mx = GetModelDimensions(joaat(name))
    local r = math.rad(yaw)
    local cs, sn = math.cos(r), math.sin(r)
    local alongX = (mx.x - mn.x) >= (mx.y - mn.y) -- длинная ось модели
    local hl = (alongX and (mx.x - mn.x) or (mx.y - mn.y)) / 2
    local hs = (alongX and (mx.y - mn.y) or (mx.x - mn.x)) / 2
    local cx, cy = (mx.x + mn.x) / 2, (mx.y + mn.y) / 2 -- центр модели бывает не в нуле
    local function world(l, s) -- (вдоль, поперёк) дома -> мир
        local lx, ly
        if alongX then lx, ly = cx + l, cy + s else lx, ly = cx + s, cy + l end
        return x + lx * cs - ly * sn, y + lx * sn + ly * cs
    end
    local head = alongX and yaw or yaw + 90.0
    local seed = math.floor(math.abs(x) * 7 + math.abs(y) * 13)
    local function put(model, l, s, h)
        local hash = joaat(model)
        local px, py = world(l, s)
        local gz = yardGround(px, py, z, 4.0)
        if not gz or not loadModel(hash) then return end
        local e = CreateObjectNoOffset(hash, px, py, gz, false, false, false)
        SetEntityHeading(e, h)
        PlaceObjectOnGroundProperly(e)
        FreezeEntityPosition(e, true)
        SetModelAsNoLongerNeeded(hash)
        out[#out + 1] = e
    end
    put(pickOf(Y.benches, seed), -hl * 0.35, hs + 3.0, head + 180.0)
    put(pickOf(Y.benches, seed + 1), hl * 0.35, hs + 3.0, head + 180.0)
    put(pickOf(Y.extra, seed), 0.0, hs + 5.0, head)
    put(pickOf(Y.bins, seed), hl + 3.0, hs * 0.5, head + 90.0)
    put(pickOf(Y.bins, seed + 1), hl + 3.0, hs * 0.5 - 2.2, head + 90.0)
    local nCars = hl > 12.0 and 3 or 2
    for i = 1, nCars do
        local hash = joaat(pickOf(Y.cars, seed + i))
        local px, py = world((i - (nCars + 1) / 2) * 6.0, -(hs + 4.5))
        local gz = yardGround(px, py, z, 6.0)
        if gz and loadModel(hash) then
            local v = CreateVehicle(hash, px, py, gz + 0.3, head + ((seed + i) % 2 == 0 and 0.0 or 180.0), false, false)
            if v ~= 0 then
                SetVehicleOnGroundProperly(v)
                SetVehicleDoorsLocked(v, 2)
                local c = pickOf(Y.carColors, seed + i * 3)
                SetVehicleColours(v, c, c)
                SetVehicleDirtLevel(v, ((seed + i) % 10) * 1.0)
                SetEntityInvincible(v, true)
                FreezeEntityPosition(v, true)
                out[#out + 1] = v
            end
            SetModelAsNoLongerNeeded(hash)
        end
    end
    return out
end

local skip = {} -- места русских кварталов, где земля оказалась неровной
local function spawnOne(o)
    local hash = type(o[1]) == 'number' and o[1] or joaat(o[1])
    if not IsModelInCdimage(hash) or skip[o] then return true end
    lib.requestModel(hash, 3000)
    local z = o[4]
    if o.snap then
        local ok, gz = GetGroundZFor_3dCoord(o[2], o[3], z + 2.0, false)
        if not ok then SetModelAsNoLongerNeeded(hash) return false end -- земля ещё не загрузилась
        if math.abs(gz - z) < 3.0 then z = gz end
        if IsPointOnRoad(o[2], o[3], z + 0.5, 0) then skip[o] = true SetModelAsNoLongerNeeded(hash) return true end
    end
    if z == false then
        z = groundFor(hash, o[2], o[3], o[5])
        if z == nil then SetModelAsNoLongerNeeded(hash) return false end -- позже
        if z == false then skip[o] = true SetModelAsNoLongerNeeded(hash) return true end
    end
    local ob = CreateObjectNoOffset(hash, o[2], o[3], z, false, false, false)
    if o[6] then SetEntityRotation(ob, o[6], o[7], o[5], 2, true) else SetEntityHeading(ob, o[5]) end
    FreezeEntityPosition(ob, true)
    SetModelAsNoLongerNeeded(hash)
    -- дом русского квартала (высота считалась по земле) — сразу двор вокруг него
    local yard = o[4] == false and type(o[1]) == 'string' and spawnYard(o[1], o[2], o[3], z, o[5]) or nil
    return true, ob, yard
end

local function spawnCell(k)
    local objs, wait = {}, {}
    for _, o in ipairs(cells[k] or {}) do
        local done, ob, yard = spawnOne(o)
        if ob then objs[#objs + 1] = ob elseif not done then wait[#wait + 1] = o end
        for _, e in ipairs(yard or {}) do objs[#objs + 1] = e end
    end
    spawned[k] = objs
    spawned[k].wait = wait
end

-- дома, под которыми земля ещё не загрузилась, — пробуем снова, пока игрок рядом
local function retryCell(k)
    local objs = spawned[k]
    if not objs.wait or #objs.wait == 0 then return end
    local still = {}
    for _, o in ipairs(objs.wait) do
        local done, ob, yard = spawnOne(o)
        if ob then objs[#objs + 1] = ob elseif not done then still[#still + 1] = o end
        for _, e in ipairs(yard or {}) do objs[#objs + 1] = e end
    end
    objs.wait = still
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
        for k in pairs(want) do if not spawned[k] then spawnCell(k) else retryCell(k) end end
        for k in pairs(spawned) do if not want[k] then clearCell(k) end end
        Wait(1500)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for k in pairs(spawned) do clearCell(k) end
end)
