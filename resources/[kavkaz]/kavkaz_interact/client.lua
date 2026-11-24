-- KAVKAZ RP — меню взаимодействия (радиальное, как у крупных RP-проектов).
-- клавиша G: короткое нажатие за рулём машины с СГУ — кряк, удержание — меню.
-- навёл мышь на пункт и отпустил G — выполнить. Esc или правая кнопка — закрыть.
-- ремень, замок и зажигание вызывают штатные действия Qbox (те же, что на B, L и клавише двигателя).

local open = false
local held = false
local pressAt, pressId = 0, 0
local ctxKind, ctxVeh = 'foot', 0
local handsUp = false

local NO_BELT = { [8] = true, [13] = true, [14] = true, [15] = true, [16] = true, [21] = true }
local HANDS = { dict = 'missminuteman_1ig_2', clip = 'handsup_base' }

local function notify(text, kind) lib.notify({ description = text, type = kind or 'inform' }) end

---------------------------------------------------------------------------
-- что перед игроком
---------------------------------------------------------------------------
local function context()
    local veh = cache.vehicle
    if veh and veh ~= 0 then
        return cache.seat == -1 and 'driver' or 'passenger', veh
    end
    local near = lib.getClosestVehicle(GetEntityCoords(cache.ped), Config.ReachVehicle, false)
    if near and near ~= 0 then return 'outside', near end
    return 'foot', 0
end

local function doorOpen(veh, i) return GetVehicleDoorAngleRatio(veh, i) > 0.1 end

-- включено ли сейчас (пункт помечается точкой)
local function isOn(id, veh)
    if id == 'hands' then
        handsUp = handsUp and IsEntityPlayingAnim(cache.ped, HANDS.dict, HANDS.clip, 3)
        return handsUp
    end
    if veh == 0 or not DoesEntityExist(veh) then return false end
    if id == 'hood' then return doorOpen(veh, 4) end
    if id == 'trunk' then return doorOpen(veh, 5) end
    if id == 'belt' then return (LocalPlayer.state.seatbelt or LocalPlayer.state.harness) and true or false end
    if id == 'lock' then return GetVehicleDoorLockStatus(veh) >= 2 end
    if id == 'engine' then return GetIsVehicleEngineRunning(veh) end
    if id == 'lights' then
        local _, on, high = GetVehicleLightsState(veh)
        return on == 1 or high == 1
    end
    return false
end

local function available(id, veh)
    if id == 'hood' then return GetIsDoorValid(veh, 4) end
    if id == 'trunk' then return GetIsDoorValid(veh, 5) end
    if id == 'belt' then return not NO_BELT[GetVehicleClass(veh)] end
    if id == 'doors' then return GetIsDoorValid(veh, 0) or GetIsDoorValid(veh, 1) end
    return true
end

local function build(list, veh)
    local items = {}
    for _, it in ipairs(list) do
        if veh == 0 or available(it.id, veh) then
            local on = isOn(it.id, veh)
            local icon = it.icon
            if it.id == 'lock' then icon = on and 'lock' or 'lock-open' end
            items[#items + 1] = { id = it.id, label = it.label, icon = icon, on = on, sub = it.sub or false }
        end
    end
    return items
end

local function rootItems()
    if ctxKind == 'foot' then return build(Config.Foot, 0) end
    return build(Config.Vehicle[ctxKind], ctxVeh)
end

local function doorItems()
    local items = {}
    for _, d in ipairs(Config.Doors) do
        if GetIsDoorValid(ctxVeh, d.door) then
            items[#items + 1] = { id = d.id, label = d.label, icon = d.icon, on = doorOpen(ctxVeh, d.door) }
        end
    end
    items[#items + 1] = { id = 'back', label = 'Назад', icon = 'back' }
    return items
end

---------------------------------------------------------------------------
-- открыть / закрыть
---------------------------------------------------------------------------
local BLOCK = { 1, 2, 3, 4, 5, 6, 24, 25, 37, 68, 69, 70, 91, 92, 106, 114, 140, 141, 142, 199, 200, 257, 263, 264, 322 }

local function blockControls()
    for i = 1, #BLOCK do DisableControlAction(0, BLOCK[i], true) end
end

local function closeMenu()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
    -- ещё мгновение не даём «выстрелить» клику, которым выбрали пункт
    CreateThread(function()
        local untilT = GetGameTimer() + 250
        while GetGameTimer() < untilT do blockControls() Wait(0) end
    end)
end

local function openMenu()
    if open or IsPauseMenuActive() or IsNuiFocused() then return end
    if not LocalPlayer.state.isLoggedIn or LocalPlayer.state.isDead then return end
    ctxKind, ctxVeh = context()
    local items = rootItems()
    if #items == 0 then return end
    open = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true) -- игра продолжает слышать клавиши: можно ехать и отпустить G
    SetCursorLocation(0.5, 0.5)
    SendNUIMessage({ action = 'open', items = items, hold = held, key = Config.Key })
    CreateThread(function()
        while open do
            blockControls()
            -- контекст пропал (вышел из машины, машина уехала) — закрываем
            if ctxVeh ~= 0 and not DoesEntityExist(ctxVeh) then closeMenu() end
            Wait(0)
        end
    end)
end

---------------------------------------------------------------------------
-- действия
---------------------------------------------------------------------------
local function control(veh)
    if not NetworkGetEntityIsNetworked(veh) or NetworkHasControlOfEntity(veh) then return true end
    NetworkRequestControlOfEntity(veh)
    local untilT = GetGameTimer() + 600
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < untilT do Wait(10) end
    return NetworkHasControlOfEntity(veh)
end

local function toggleDoor(veh, idx)
    if not DoesEntityExist(veh) or not GetIsDoorValid(veh, idx) then return notify('у этой машины такого нет', 'error') end
    if cache.vehicle ~= veh and GetVehicleDoorLockStatus(veh) >= 2 then return notify('машина закрыта на ключ', 'error') end
    if not control(veh) then return notify('не получилось, попробуй ещё раз', 'error') end
    if doorOpen(veh, idx) then SetVehicleDoorShut(veh, idx, false) else SetVehicleDoorOpen(veh, idx, false, false) end
end

-- нажать штатную клавишу Qbox (ремень, замок, двигатель): те же проверки и анимации, что у клавиши
local function press(name)
    ExecuteCommand('+' .. name)
    Wait(60)
    ExecuteCommand('-' .. name)
end

local ACTIONS = {
    hood = function(veh) toggleDoor(veh, 4) end,
    trunk = function(veh) toggleDoor(veh, 5) end,
    belt = function() press('toggleseatbelt') end,
    lock = function() press('togglelocks') end,
    engine = function() press('toggleengine') end,
    lights = function(veh)
        if not DoesEntityExist(veh) then return end
        local on = isOn('lights', veh)
        SetVehicleLights(veh, on and 1 or 2)
        notify(on and 'фары выключены' or 'фары включены')
    end,
    seatout = function(veh)
        if LocalPlayer.state.seatbelt or LocalPlayer.state.harness then return notify('сначала отстегни ремень', 'error') end
        TaskLeaveVehicle(cache.ped, veh, 0)
    end,
    hands = function()
        handsUp = not isOn('hands', 0)
        if handsUp then
            lib.requestAnimDict(HANDS.dict)
            TaskPlayAnim(cache.ped, HANDS.dict, HANDS.clip, 4.0, 4.0, -1, 49, 0, false, false, false)
            RemoveAnimDict(HANDS.dict)
        else
            StopAnimTask(cache.ped, HANDS.dict, HANDS.clip, 4.0)
        end
    end,
    passport = function() ExecuteCommand('menu') end,
    gps = function() ExecuteCommand('gps') end,
    help = function() ExecuteCommand('help') end,
}

RegisterNUICallback('select', function(data, cb)
    cb(1)
    local id = data and data.id
    if not open or type(id) ~= 'string' then return end
    if id == 'doors' then return SendNUIMessage({ action = 'open', items = doorItems(), hold = false, key = Config.Key }) end
    if id == 'back' then return SendNUIMessage({ action = 'open', items = rootItems(), hold = false, key = Config.Key }) end
    local veh = ctxVeh
    closeMenu()
    local door = id:match('^d(%d)$')
    if door then return toggleDoor(veh, tonumber(door)) end
    local fn = ACTIONS[id]
    if fn then fn(veh) end
end)

RegisterNUICallback('close', function(_, cb)
    cb(1)
    closeMenu()
end)

---------------------------------------------------------------------------
-- клавиша
---------------------------------------------------------------------------
local function quick()
    -- короткое нажатие: кряк СГУ, если я за рулём и оно стоит
    if cache.vehicle and cache.seat == -1 and GetResourceState('kavkaz_sgu') == 'started' then
        pcall(function() exports.kavkaz_sgu:Quack() end)
    end
end

lib.addKeybind({
    name = 'kavkaz_interact',
    description = 'Меню взаимодействия (удерживать). Коротко за рулём — кряк СГУ',
    defaultKey = Config.Key,
    onPressed = function()
        if open or IsNuiFocused() then return end
        pressId = pressId + 1
        local my = pressId
        pressAt = GetGameTimer()
        held = true
        SetTimeout(Config.HoldMs, function()
            if held and my == pressId then openMenu() end
        end)
    end,
    onReleased = function()
        local was = held
        held = false
        if open then
            SendNUIMessage({ action = 'release' }) -- выбрать наведённый пункт или закрыть
            return
        end
        if was and GetGameTimer() - pressAt < Config.HoldMs then quick() end
    end,
})

-- кто владеет клавишей кряка (kavkaz_sgu спрашивает, чтобы не крякать дважды)
exports('IsOpen', function() return open end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if open then SetNuiFocus(false, false) SetNuiFocusKeepInput(false) end
end)
