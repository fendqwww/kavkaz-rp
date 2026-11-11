-- KAVKAZ RP: пролог «Домой» (docs/vision/23-story-jobs-economy.md, раздел 1).
-- всё в прологе — свои у игрока (не сетевые): самолёт, маршрутка, дядя. другие игроки их не видят.
-- зажать BACKSPACE — пропустить (если сервер разрешил: второй персонаж или админ).

local playing, skip, canSkip, holdSince = false, false, false, nil
local made = {} -- что создали: удалить в конце
local cam

local function ui(msg) SendNUIMessage(msg) end

-- ожидание, которое прерывается пропуском
local function sleep(ms)
    local untilT = GetGameTimer() + ms
    while GetGameTimer() < untilT do
        if skip then return false end
        Wait(0)
    end
    return true
end

local function sub(who, text, ms)
    ui({ action = 'sub', who = who, text = text })
    local ok = sleep(ms)
    ui({ action = 'sub' })
    return ok
end

local function fadeOut(ms)
    DoScreenFadeOut(ms or 800)
    while not IsScreenFadedOut() do Wait(0) end
end

local function fadeIn(ms)
    DoScreenFadeIn(ms or 800)
end

local function load(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    lib.requestModel(hash, 10000)
    return hash
end

local function firstModel(list)
    for _, m in ipairs(list) do
        local h = load(m)
        if h then return h end
    end
end

local function keep(ent) made[#made + 1] = ent return ent end

-- ближайшая дорога к точке: { coords, heading }
local function roadNear(p)
    local ok, pos, heading = GetClosestVehicleNodeWithHeading(p.x, p.y, p.z, 1, 3.0, 0)
    if ok then return pos, heading end
    return vec3(p.x, p.y, p.z), 0.0
end

-- что игрок выбрал в окне ответа
local choicePromise
RegisterNUICallback('choice', function(body, cb)
    cb('ok')
    if choicePromise then choicePromise:resolve(body.id) end
end)

local function ask(list)
    choicePromise = promise.new()
    local opts = {}
    for _, o in ipairs(list) do opts[#opts + 1] = { id = o.id, label = o.label } end
    SetNuiFocus(true, true)
    ui({ action = 'choice', options = opts })
    local id = Citizen.Await(choicePromise)
    SetNuiFocus(false, false)
    ui({ action = 'choice' })
    choicePromise = nil
    return id
end

---------------------------------------------------------------------------
-- сцены
---------------------------------------------------------------------------

local function titles()
    for _, t in ipairs(Config.Titles) do
        ui({ action = 'title', big = t[1], small = t[2] })
        if not sleep(t[3]) then break end
    end
    ui({ action = 'title' })
end

local function landing()
    local L = Config.Landing
    local hash = load(Config.PlaneModel)
    if not hash then return end
    local from, to = L.cam + L.from, L.cam + L.to
    local dir = to - from
    local heading = (math.deg(math.atan(dir.y, dir.x)) - 90.0) % 360.0
    SetFocusPosAndVel(L.cam.x, L.cam.y, L.cam.z, 0.0, 0.0, 0.0)
    local plane = keep(CreateVehicle(hash, from.x, from.y, from.z, heading, false, false))
    SetEntityCollision(plane, false, false)
    SetEntityInvincible(plane, true)
    SetVehicleEngineOn(plane, true, true, false)
    ControlLandingGear(plane, 0)
    SetEntityLodDist(plane, 3000)

    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', L.cam.x, L.cam.y, L.cam.z, 0.0, 0.0, 0.0, 45.0, false, 0)
    PointCamAtEntity(cam, plane, 0.0, 0.0, 0.0, true)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    fadeIn(1500)
    ui({ action = 'title', small = 'Республика Нагорье' })

    local t0 = GetGameTimer()
    local pitch = math.deg(math.atan(dir.z, #dir.xy))
    while not skip do
        local k = (GetGameTimer() - t0) / L.ms
        if k >= 1.0 then break end
        local p = from + dir * k
        SetEntityCoordsNoOffset(plane, p.x, p.y, p.z, false, false, false)
        SetEntityRotation(plane, pitch * 0.6, 0.0, heading, 2, true)
        if k > 0.82 and not IsScreenFadingOut() and not IsScreenFadedOut() then DoScreenFadeOut(1800) end
        Wait(0)
    end
    fadeOut(300)
    ui({ action = 'title' })
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    cam = nil
    ClearFocus()
end

local function meet(van, uncle)
    local ped = cache.ped
    fadeIn(1200)
    StartVehicleHorn(van, 600, joaat('HELDDOWN'), false)
    sleep(800)
    StartVehicleHorn(van, 900, joaat('HELDDOWN'), false)
    sub(Config.Meet[1][1], Config.Meet[1][2], Config.Meet[1][3])
    if skip then return end

    TaskGoToEntity(uncle, ped, 9000, 1.6, 1.5, 0, 0)
    local t = GetGameTimer() + 9000
    while #(GetEntityCoords(uncle) - GetEntityCoords(ped)) > 2.2 and GetGameTimer() < t and not skip do Wait(100) end
    TaskTurnPedToFaceEntity(uncle, ped, 1500)
    TaskTurnPedToFaceEntity(ped, uncle, 1500)
    for i = 2, #Config.Meet do
        if not sub(Config.Meet[i][1], Config.Meet[i][2], Config.Meet[i][3]) then return end
    end

    local id = ask(Config.Tone)
    for _, o in ipairs(Config.Tone) do
        if o.id == id then
            TriggerServerEvent('kavkaz_intro:server:tone', o.id)
            sub('Хамзат', o.reply, 4500)
        end
    end
    if skip then return end
    sub(Config.Board[1], Config.Board[2], Config.Board[3])
end

local function board(van, uncle)
    local ped = cache.ped
    FreezeEntityPosition(ped, false)
    TaskEnterVehicle(uncle, van, 10000, -1, 1.0, 1, 0)
    TaskEnterVehicle(ped, van, 10000, 0, 1.0, 1, 0)
    local t = GetGameTimer() + 10000
    while GetGameTimer() < t and not skip do
        if GetVehiclePedIsIn(ped, false) == van and GetVehiclePedIsIn(uncle, false) == van then break end
        Wait(200)
    end
    if GetVehiclePedIsIn(ped, false) ~= van then SetPedIntoVehicle(ped, van, 0) end
    if GetVehiclePedIsIn(uncle, false) ~= van then SetPedIntoVehicle(uncle, van, -1) end
end

local function ride(van, uncle, part)
    local dest = Config.YardRoad
    TaskVehicleDriveToCoordLongrange(uncle, van, dest.x, dest.y, dest.z, 17.0, 786603, 25.0)
    SetDriverAbility(uncle, 1.0)
    SetPedKeepTask(uncle, true)
    local t0, i = GetGameTimer(), 1
    while not skip do
        local s = (GetGameTimer() - t0) / 1000
        if s >= part.secs then break end
        local line = part.lines[i]
        if line and s >= line[1] then
            ui({ action = 'sub', who = line[2], text = line[3] })
            i = i + 1
        end
        DisableControlAction(0, 75, true) -- не выйти из машины
        DisableControlAction(0, 23, true)
        Wait(0)
    end
    ui({ action = 'sub' })
end

-- перенести маршрутку с дядей и игроком на дорогу у точки p
local function moveVan(van, p)
    local pos, heading = roadNear(p)
    SetEntityCoords(van, pos.x, pos.y, pos.z, false, false, false, false)
    SetEntityHeading(van, heading)
    SetVehicleOnGroundProperly(van)
    SetVehicleForwardSpeed(van, 8.0)
end

local function yard(van, uncle)
    local ped = cache.ped
    local Y = Config.Yard
    moveVan(van, Config.YardRoad)
    SetVehicleForwardSpeed(van, 0.0)
    TaskLeaveVehicle(ped, van, 16)
    TaskLeaveVehicle(uncle, van, 16)
    Wait(300)
    SetEntityCoords(ped, Y.x, Y.y, Y.z - 1.0, false, false, false, false)
    SetEntityHeading(ped, Y.w)
    local o = GetOffsetFromEntityInWorldCoords(ped, 1.2, 0.6, 0.0)
    SetEntityCoords(uncle, o.x, o.y, o.z, false, false, false, false)
    TaskTurnPedToFaceEntity(uncle, ped, 1500)
    fadeIn(1000)
    for _, l in ipairs(Config.YardLines) do
        if not sub(l[1], l[2], l[3]) then return end
    end
end

local function box()
    fadeOut(900)
    local p = promise.new()
    choicePromise = p
    SetNuiFocus(true, true)
    ui({ action = 'box', box = Config.Box })
    Citizen.Await(p)
    choicePromise = nil
    SetNuiFocus(false, false)
    ui({ action = 'box' })
    ui({ action = 'title', big = 'Утро', small = 'Глава 1. «Свой человек»' })
    sleep(3000)
    ui({ action = 'title' })
end

---------------------------------------------------------------------------
-- запуск
---------------------------------------------------------------------------

local function cleanup()
    ui({ action = 'reset' })
    SetNuiFocus(false, false)
    if cam then RenderScriptCams(false, false, 0, true, true) DestroyCam(cam, false) cam = nil end
    ClearFocus()
    local ped = cache.ped
    if IsPedInAnyVehicle(ped, false) then ClearPedTasksImmediately(ped) end -- выйти из маршрутки до её удаления
    for _, e in ipairs(made) do if DoesEntityExist(e) then DeleteEntity(e) end end
    made = {}
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityVisible(ped, true, false)
    DisplayRadar(true)
end

local function play(opts)
    if playing then return end
    playing, skip, canSkip = true, false, opts and opts.skippable or false
    local ped = cache.ped
    ui({ action = 'skip', show = canSkip })

    fadeOut(800)
    DisplayRadar(false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    local A = Config.Arrival
    SetEntityCoords(ped, A.x, A.y, A.z - 1.0, false, false, false, false)
    SetEntityHeading(ped, A.w)

    local ok, err = pcall(function()
        titles()
        if not skip then landing() end

        local van, uncle
        if not skip then
            local vanHash, uncleHash = firstModel(Config.VanModels), load(Config.UncleModel)
            if vanHash and uncleHash then
                local pos, heading = roadNear(GetEntityCoords(ped))
                van = keep(CreateVehicle(vanHash, pos.x, pos.y, pos.z, heading, false, false))
                SetVehicleOnGroundProperly(van)
                SetVehicleColours(van, 89, 89) -- жёлтая маршрутка
                SetVehicleNumberPlateText(van, 'M007KK95')
                SetVehicleEngineOn(van, true, true, false)
                local d = GetOffsetFromEntityInWorldCoords(van, -1.6, 1.2, 0.0)
                uncle = keep(CreatePed(4, uncleHash, d.x, d.y, d.z, heading, false, true))
                SetBlockingOfNonTemporaryEvents(uncle, true)
                SetEntityInvincible(uncle, true)
                SetPedCanBeDraggedOut(uncle, false)
            end
        end

        if van and not skip then meet(van, uncle) end
        if van and not skip then board(van, uncle) end
        if van and not skip then ride(van, uncle, Config.Ride1) end
        if van and not skip then
            fadeOut(1200)
            ui({ action = 'title', small = 'Через час' })
            moveVan(van, Config.CityStart)
            sleep(1500)
            ui({ action = 'title' })
            fadeIn(1200)
            ride(van, uncle, Config.Ride2)
        end
        if van and not skip then fadeOut(1000) yard(van, uncle) end
        if not skip then box() end
    end)
    if not ok then lib.print.error(err) end

    fadeOut(400)
    cleanup()
    local Y = Config.Yard
    SetEntityCoords(cache.ped, Y.x, Y.y, Y.z - 1.0, false, false, false, false)
    SetEntityHeading(cache.ped, Y.w)
    Wait(500)
    fadeIn(1200)
    playing = false
    TriggerServerEvent('kavkaz_intro:server:done', skip)
end

RegisterNetEvent('kavkaz_intro:client:play', function(opts)
    CreateThread(function() play(opts) end)
end)

-- пропуск: держать BACKSPACE 1,5 секунды
lib.addKeybind({
    name = 'kavkaz_intro_skip', description = 'Пролог: пропустить (держать)', defaultKey = 'BACK',
    onPressed = function()
        if not playing or not canSkip then return end
        holdSince = GetGameTimer()
        CreateThread(function()
            while holdSince do
                local k = (GetGameTimer() - holdSince) / 1500
                ui({ action = 'skipProgress', value = math.min(k, 1.0) })
                if k >= 1.0 then
                    skip, holdSince = true, nil
                    if choicePromise then choicePromise:resolve('skip') end
                end
                Wait(50)
            end
            ui({ action = 'skipProgress', value = 0 })
        end)
    end,
    onReleased = function() holdSince = nil end,
})

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and playing then
        cleanup()
        DoScreenFadeIn(0)
    end
end)
