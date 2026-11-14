-- KAVKAZ RP: русский поток. меняем машины NPC на наши модели там, где игрок подмену не увидит,
-- ставим русские номера, убираем американскую полицию и банды из прохожих.
-- трогаем только «ничьи» машины: население GTA (не скриптовые, без игроков внутри), и только те, которыми этот клиент управляет по сети.

local pool = {}       -- { hash, вес } — только модели, которые реально есть на сервере
local total = 0
local ours = {}       -- hash -> true: наши модели не меняем повторно
local plated = {}     -- машины, которым уже поставили номер
local SWAP_POP = { [2] = true, [4] = true, [5] = true } -- население GTA: припаркованные, сценарные, ездящие

local classPools = {} -- класс GTA -> { pool, total } (фургоны -> Газель, автобусы -> ЛиАЗ)

local function makePool(models)
    local p, t = {}, 0
    for name, weight in pairs(models) do
        local hash = joaat(name)
        ours[hash] = true
        if IsModelInCdimage(hash) and IsModelAVehicle(hash) then
            p[#p + 1] = { hash, weight }
            t = t + weight
        end
    end
    return p, t
end

local function buildPool()
    pool, total = makePool(Config.Models)
    for cls, models in pairs(Config.ClassModels or {}) do
        local p, t = makePool(models)
        if t > 0 then classPools[cls] = { p, t } end
    end
end

local function pickFrom(p, t)
    if t <= 0 then return nil end
    local r = math.random() * t
    for _, it in ipairs(p) do
        r = r - it[2]
        if r <= 0 then return it[1] end
    end
    return p[#p][1]
end

-- 11.11: у игроков медленный интернет. раньше трафик сразу просил все ~20 моделей — они качались разом (~300 МБ),
-- забивали канал, машина из гаража не грузилась, игроков выкидывало по таймауту. теперь:
--   новые (ещё не скачанные) модели — строго по одной и только после своих машин (kavkaz_cars, state kvCarsCached)
--   или через Config.DownloadDelay после входа; пока качается — в поток ставим уже скачанные.
local ready = {}               -- hash -> true: модель уже на диске (хоть раз загрузилась)
local loading, loadingSince    -- модель, которая сейчас качается
local loggedAt = GetGameTimer()

local function isReady(hash)
    if ready[hash] then return true end
    if HasModelLoaded(hash) then ready[hash] = true return true end
    return false
end

local function canDownload()
    if loading then
        if HasModelLoaded(loading) or GetGameTimer() - loadingSince > 180000 then
            if HasModelLoaded(loading) then ready[loading] = true end
            loading = nil
        else
            return false
        end
    end
    return LocalPlayer.state.kvCarsCached or GetGameTimer() - loggedAt > Config.DownloadDelay
end

-- сколько машин каждой нашей модели сейчас рядом (считает tick) — чтобы не было пяти одинаковых Приор подряд
local nearCount = {}

-- из пула: модели, которые уже скачаны и которых рядом ещё мало (с весами)
local function pickReady(p)
    local list, t = {}, 0
    for _, it in ipairs(p) do
        if isReady(it[1]) and (nearCount[it[1]] or 0) < Config.MaxSame then list[#list + 1] = it; t = t + it[2] end
    end
    return pickFrom(list, t)
end

local function pickModel(cls)
    local cp = cls and classPools[cls]
    local p, t = pool, total
    if cp then p, t = cp[1], cp[2] end
    local want = pickFrom(p, t)
    if not want then return nil end
    if isReady(want) and (nearCount[want] or 0) < Config.MaxSame then return want end
    if isReady(want) then return pickReady(p) end
    -- выбранная модель ещё не скачана: начать её качать (если сейчас ничего не качается), а пока взять скачанную
    if canDownload() then
        loading, loadingSince = want, GetGameTimer()
        RequestModel(want)
    end
    return pickReady(p)
end

local regions, regionTotal = {}, 0
for code, w in pairs(Config.Regions) do regions[#regions + 1] = { code, w }; regionTotal = regionTotal + w end

local function randomPlate()
    local L = Config.PlateLetters
    local function letter() local i = math.random(#L); return L:sub(i, i) end
    local r = math.random() * regionTotal
    local region = regions[1][1]
    for _, it in ipairs(regions) do r = r - it[2]; if r <= 0 then region = it[1]; break end end
    -- обычный номер: без «красивых» сочетаний (их выдают только в МРЭО и на аукционе)
    local n
    repeat n = math.random(11, 989) until not (n % 111 == 0 or n < 10)
    return ('%s%03d%s%s%s'):format(letter(), n, letter(), letter(), region)
end

local function setPlate(veh)
    if plated[veh] then return end
    plated[veh] = true
    SetVehicleNumberPlateText(veh, randomPlate())
    SetVehicleNumberPlateTextIndex(veh, 0)
end

local function hasPlayerInside(veh)
    for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 and IsPedAPlayer(ped) then return true end
    end
    return false
end

local function swap(veh)
    local model = pickModel(GetVehicleClass(veh))
    if not model then return false end
    if not HasModelLoaded(model) then
        RequestModel(model)
        return false -- догрузится, поменяем на следующей проверке
    end
    local driver = GetPedInVehicleSeat(veh, -1)
    local driverModel = driver ~= 0 and GetEntityModel(driver) or nil
    local coords, heading = GetEntityCoords(veh), GetEntityHeading(veh)
    local speed = GetEntitySpeed(veh)
    local moving = driver ~= 0 and not IsPedAPlayer(driver)

    -- удаляем старую машину и водителя
    if driver ~= 0 and not IsPedAPlayer(driver) then
        SetEntityAsMissionEntity(driver, true, true)
        DeleteEntity(driver)
    end
    SetEntityAsMissionEntity(veh, true, true)
    DeleteEntity(veh)

    local nv = CreateVehicle(model, coords.x, coords.y, coords.z, heading, true, false)
    SetModelAsNoLongerNeeded(model) -- в памяти держится, пока такие машины рядом (важно для слабых видеокарт)
    if nv == 0 then return false end
    nearCount[model] = (nearCount[model] or 0) + 1
    SetVehicleOnGroundProperly(nv)
    SetVehicleNumberPlateText(nv, randomPlate())
    SetVehicleNumberPlateTextIndex(nv, 0)
    plated[nv] = true
    SetVehicleColours(nv, math.random(0, 160), math.random(0, 160))
    SetVehicleDirtLevel(nv, math.random() * 6.0)

    if moving and driverModel and IsModelInCdimage(driverModel) then
        RequestModel(driverModel)
        local t = GetGameTimer() + 500
        while not HasModelLoaded(driverModel) and GetGameTimer() < t do Wait(0) end
        if HasModelLoaded(driverModel) then
            local ped = CreatePedInsideVehicle(nv, 26, driverModel, -1, true, false)
            if ped ~= 0 then
                SetVehicleEngineOn(nv, true, true, false)
                SetVehicleForwardSpeed(nv, speed)
                TaskVehicleDriveWander(ped, nv, math.max(12.0, speed), 786603) -- обычная езда по правилам
                SetPedKeepTask(ped, true)
                SetEntityAsNoLongerNeeded(ped)
            end
            SetModelAsNoLongerNeeded(driverModel)
        end
    end
    SetEntityAsNoLongerNeeded(nv)
    return true
end

local function tick()
    local me = PlayerPedId()
    local myPos = GetEntityCoords(me)
    local done = 0
    local pool_ = GetGamePool('CVehicle')
    nearCount = {}
    for _, veh in ipairs(pool_) do
        local m = GetEntityModel(veh)
        if ours[m] and #(GetEntityCoords(veh) - myPos) <= Config.MaxDistance then nearCount[m] = (nearCount[m] or 0) + 1 end
    end
    for _, veh in ipairs(pool_) do
        if done >= Config.PerTick then break end
        if DoesEntityExist(veh) and not IsEntityAMissionEntity(veh) and SWAP_POP[GetEntityPopulationType(veh)] then
            local dist = #(GetEntityCoords(veh) - myPos)
            if dist <= Config.MaxDistance and not hasPlayerInside(veh) then
                local model = GetEntityModel(veh)
                if NetworkHasControlOfEntity(veh) then
                    if not ours[model] and (Config.SwapClasses[GetVehicleClass(veh)] or classPools[GetVehicleClass(veh)]) and dist >= Config.MinDistance
                        and (dist >= Config.SafeDistance or not IsEntityOnScreen(veh)) then
                        if swap(veh) then done = done + 1 end -- swap сам ставит модель, учёт обновится на следующей проверке
                    else
                        setPlate(veh)
                    end
                end
            end
        end
    end
    -- чистим память о машинах, которых уже нет
    for veh in pairs(plated) do
        if not DoesEntityExist(veh) then plated[veh] = nil end
    end
end

CreateThread(function()
    for _, m in ipairs(Config.SuppressVehicles) do SetVehicleModelIsSuppressed(joaat(m), true) end
    for _, m in ipairs(Config.SuppressPeds) do SetPedModelIsSuppressed(joaat(m), true) end
    -- 12.11: за городом сценарные бандиты (байкеры, деревенщины, сектанты) стреляли в игроков. теперь нейтральны
    for _, g in ipairs(Config.CalmGroups or {}) do
        SetRelationshipBetweenGroups(1, joaat(g), `PLAYER`)
        SetRelationshipBetweenGroups(1, `PLAYER`, joaat(g))
    end
    buildPool()
    while true do
        Wait(Config.Interval)
        if LocalPlayer.state.isLoggedIn then
            local ok, err = pcall(tick)
            if not ok then print('[kavkaz_traffic] ' .. tostring(err)) end
        end
    end
end)

-- подавление моделей не сбрасывается само: снимаем, если ресурс выключили
AddEventHandler('QBCore:Client:OnPlayerLoaded', function() loggedAt = GetGameTimer() end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, m in ipairs(Config.SuppressVehicles) do SetVehicleModelIsSuppressed(joaat(m), false) end
    for _, m in ipairs(Config.SuppressPeds) do SetPedModelIsSuppressed(joaat(m), false) end
end)
