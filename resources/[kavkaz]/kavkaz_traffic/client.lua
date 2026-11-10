-- KAVKAZ RP: русский поток. меняем машины NPC на наши модели там, где игрок подмену не увидит,
-- ставим русские номера, убираем американскую полицию и банды из прохожих.
-- трогаем только «ничьи» машины: население GTA (не скриптовые, без игроков внутри), и только те, которыми этот клиент управляет по сети.

local pool = {}       -- { hash, вес } — только модели, которые реально есть на сервере
local total = 0
local ours = {}       -- hash -> true: наши модели не меняем повторно
local plated = {}     -- машины, которым уже поставили номер
local SWAP_POP = { [2] = true, [4] = true, [5] = true } -- население GTA: припаркованные, сценарные, ездящие

local function buildPool()
    pool, total = {}, 0
    for name, weight in pairs(Config.Models) do
        local hash = joaat(name)
        ours[hash] = true
        if IsModelInCdimage(hash) and IsModelAVehicle(hash) then
            pool[#pool + 1] = { hash, weight }
            total = total + weight
        end
    end
end

local function pickModel()
    if total <= 0 then return nil end
    local r = math.random() * total
    for _, it in ipairs(pool) do
        r = r - it[2]
        if r <= 0 then return it[1] end
    end
    return pool[#pool][1]
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
    local model = pickModel()
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
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if done >= Config.PerTick then break end
        if DoesEntityExist(veh) and not IsEntityAMissionEntity(veh) and SWAP_POP[GetEntityPopulationType(veh)] then
            local dist = #(GetEntityCoords(veh) - myPos)
            if dist <= Config.MaxDistance and not hasPlayerInside(veh) then
                local model = GetEntityModel(veh)
                if NetworkHasControlOfEntity(veh) then
                    if not ours[model] and Config.SwapClasses[GetVehicleClass(veh)] and dist >= Config.MinDistance
                        and (dist >= Config.SafeDistance or not IsEntityOnScreen(veh)) then
                        if swap(veh) then done = done + 1 end
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
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, m in ipairs(Config.SuppressVehicles) do SetVehicleModelIsSuppressed(joaat(m), false) end
    for _, m in ipairs(Config.SuppressPeds) do SetPedModelIsSuppressed(joaat(m), false) end
end)
