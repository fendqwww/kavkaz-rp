-- KAVKAZ RP — свой HUD вместо qbx_hud (qbx_hud выключен в overrides/kavkaz.cfg).
-- слева снизу: миникарта, рядом здоровье/броня/еда/вода/голос; над картой — сторона света и район;
-- справа снизу: спидометр (км/ч, передача, обороты, топливо, ремень, двигатель, фары, замок);
-- справа сверху: KAVKAZ RP, ID, онлайн, время, наличные и карта.

local visible = false
local userHidden = false
local inVeh = false
local lowFuelWarned = false
local pdata = {}
local last = {}

local function send(action, data)
    data = data or {}
    data.action = action
    SendNUIMessage(data)
end

-- отправить, только если что-то поменялось
local function sendIfChanged(action, data, key)
    if last[action] == key then return end
    last[action] = key
    send(action, data)
end

-- где GTA рисует миникарту (доли экрана), чтобы HUD встал рядом при любом разрешении
local function minimapLayout()
    local pad = math.abs(1.0 - GetSafeZoneSize()) * 0.5 -- отступ «безопасной зоны» из настроек игры
    return {
        left = pad,
        bottom = pad,
        width = 1.0 / (4.0 * GetAspectRatio(false)),
        height = 1.0 / 5.674,
    }
end

local function isLoggedIn()
    return LocalPlayer.state.isLoggedIn == true
end

local function shouldShow()
    return isLoggedIn()
        and not userHidden
        and not LocalPlayer.state.kavkaz_hud_off -- другие наши ресурсы прячут HUD на время катсцен
        and not IsPauseMenuActive()
        and not IsScreenFadedOut()
        and not IsPlayerSwitchInProgress()
end

local function refreshPlayerData()
    local ok, data = pcall(function() return exports.qbx_core:GetPlayerData() end)
    if ok and data then pdata = data end
end

AddEventHandler('QBCore:Player:SetPlayerData', function(data) pdata = data end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshPlayerData()
    last = {}
    send('layout', minimapLayout())
end)

-- всплывашка «+1 500 ₽» / «−300 ₽» (событие шлёт qbx_core при каждом изменении денег)
RegisterNetEvent('hud:client:OnMoneyChange', function(kind, amount, isMinus)
    if kind ~= 'cash' and kind ~= 'bank' then return end
    send('moneyPop', { kind = kind, amount = amount, minus = isMinus and true or false })
end)

local DIRS = { 'С', 'СВ', 'В', 'ЮВ', 'Ю', 'ЮЗ', 'З', 'СЗ' }

local WEEKDAYS = { 'воскресенье', 'понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота' }
local WEATHER = {
    EXTRASUNNY = 'солнечно', CLEAR = 'ясно', CLOUDS = 'облачно', OVERCAST = 'пасмурно', CLEARING = 'проясняется',
    RAIN = 'дождь', THUNDER = 'гроза', FOGGY = 'туман', SMOG = 'дымка', NEUTRAL = 'облачно',
    SNOWLIGHT = 'лёгкий снег', SNOW = 'снег', BLIZZARD = 'метель', XMAS = 'зима', HALLOWEEN = 'туман',
}

-- дата по часам компьютера игрока, день недели — формула Зеллера
local function today()
    local y, mo, d = GetLocalTime()
    local yy, mm = y, mo
    if mm < 3 then mm = mm + 12; yy = yy - 1 end
    local k, j = yy % 100, yy // 100
    local h = (d + (13 * (mm + 1)) // 5 + k + k // 4 + j // 4 + 5 * j) % 7 -- 0 = суббота
    local wd = ({ 7, 1, 2, 3, 4, 5, 6 })[h + 1]                              -- 1 = воскресенье
    return ('%02d.%02d.%d'):format(d, mo, y), WEEKDAYS[wd]
end

local function weatherName()
    local w = GlobalState.weather
    local code = type(w) == 'table' and w.weather or nil
    return code and (WEATHER[code] or code:lower()) or ''
end

-- подсказки клавиш справа (F6 — спрятать/показать, запоминается на ПК игрока)
local HINTS_KVP = 'kavkaz_hud_hints_off'
local hintsOff = GetResourceKvpInt(HINTS_KVP) == 1
local function sendHints()
    send('hints', { show = not hintsOff, list = Config.Hints })
end

local function direction()
    local rot = GetGameplayCamRot(2)
    local deg = (360.0 - rot.z) % 360.0
    return DIRS[math.floor((deg + 22.5) / 45.0) % 8 + 1]
end

local function zoneName(coords)
    local code = GetNameOfZone(coords.x, coords.y, coords.z)
    local label = GetLabelText(code)
    if not label or label == 'NULL' then return '' end
    return label
end

local function gearOf(veh, speed, rpm)
    if not GetIsVehicleEngineRunning(veh) then return 'N' end
    local gear = GetVehicleCurrentGear(veh)
    if gear == 0 then return 'R' end
    if speed < 1.5 and rpm < 0.25 then return 'N' end
    return tostring(gear)
end

local function statusTick(ped)
    local st = LocalPlayer.state
    local maxHp = math.max(1, GetEntityMaxHealth(ped) - 100)
    local hp = math.floor(math.max(0, GetEntityHealth(ped) - 100) / maxHp * 100 + 0.5)
    local oxygen = -1
    if IsPedSwimmingUnderWater(ped) then
        oxygen = math.floor(math.min(100, GetPlayerUnderwaterTimeRemaining(PlayerId()) * 10))
    end
    local prox = st.proximity
    local data = {
        hp = math.min(100, hp),
        armor = GetPedArmour(ped),
        hunger = math.floor(st.hunger or 100),
        thirst = math.floor(st.thirst or 100),
        stress = math.floor(st.stress or 0),
        oxygen = oxygen,
        talking = NetworkIsPlayerTalking(PlayerId()),
        voice = prox and prox.index or 2,
        radio = st.radioChannel or 0,
    }
    local key = table.concat({ data.hp, data.armor, data.hunger, data.thirst, data.stress, data.oxygen,
        tostring(data.talking), data.voice, data.radio }, '|')
    sendIfChanged('status', data, key)
end

local function vehicleTick(ped, veh)
    local class = GetVehicleClass(veh)
    local speed = GetEntitySpeed(veh) * 3.6
    local rpm = GetVehicleCurrentRpm(veh)
    local _, lights, high = GetVehicleLightsState(veh)
    local noFuel = Config.NoFuel[class] == true
    local fuel = noFuel and -1 or math.floor(GetVehicleFuelLevel(veh) + 0.5)
    local st = LocalPlayer.state
    local data = {
        speed = math.floor(speed + 0.5),
        rpm = noFuel and 0 or math.floor(rpm * 100) / 100,
        gear = noFuel and '' or gearOf(veh, speed, rpm),
        fuel = fuel,
        belt = Config.NoBelt[class] and -1 or ((st.seatbelt or st.harness) and 1 or 0),
        engine = noFuel and -1 or (GetVehicleEngineHealth(veh) < 400.0 and 0 or (GetIsVehicleEngineRunning(veh) and 1 or 2)),
        lights = (high == 1 and 2) or (lights == 1 and 1) or 0,
        locked = GetVehicleDoorLockStatus(veh) >= 2,
    }
    local key = table.concat({ data.speed, data.rpm, data.gear, data.fuel, data.belt, data.engine, data.lights, tostring(data.locked) }, '|')
    sendIfChanged('veh', data, key)

    if fuel >= 0 and fuel < Config.LowFuel and GetPedInVehicleSeat(veh, -1) == ped and not lowFuelWarned then
        lowFuelWarned = true
        exports.qbx_core:Notify('Бензин на исходе — заправься на ближайшей АЗС', 'error')
    end
end

-- основной цикл
CreateThread(function()
    while true do
        local show = shouldShow()
        if show ~= visible then
            visible = show
            if show then
                refreshPlayerData()
                last = {}
                send('layout', minimapLayout())
                sendHints()
            end
            send('visible', { show = show })
            DisplayRadar(show)
        end

        local wait = Config.TickFoot
        if visible then
            local ped = PlayerPedId()
            statusTick(ped)

            local veh = GetVehiclePedIsIn(ped, false)
            local showSpeedo = veh ~= 0 and (Config.ShowPassenger or GetPedInVehicleSeat(veh, -1) == ped)
            if showSpeedo then
                if not inVeh then
                    inVeh = true
                    lowFuelWarned = false
                    send('speedo', { show = true })
                end
                vehicleTick(ped, veh)
                wait = Config.TickVehicle
            elseif inVeh then
                inVeh = false
                last.veh = nil
                send('speedo', { show = false })
            end
        end
        Wait(wait)
    end
end)

-- медленный цикл: деньги, ID, онлайн, время, район; миникарта не должна пропадать
CreateThread(function()
    while true do
        if visible then
            local ped = PlayerPedId()
            local money = pdata.money or {}
            local h, m = GetClockHours(), GetClockMinutes()
            local date, weekday = today()
            local info = {
                date = date,
                weekday = weekday,
                weather = weatherName(),
                id = GetPlayerServerId(PlayerId()),
                online = GlobalState.kavkaz_online or #GetActivePlayers(),
                slots = GlobalState.kavkaz_slots or 48,
                time = ('%02d:%02d'):format(h, m),
                cash = money.cash or 0,
                bank = money.bank or 0,
                dir = direction(),
                zone = zoneName(GetEntityCoords(ped)),
            }
            sendIfChanged('info', info, table.concat({ info.id, info.online, info.time, info.cash, info.bank, info.dir, info.zone, info.date, info.weather }, '|'))
            if IsRadarHidden() then DisplayRadar(true) end
            SetRadarBigmapEnabled(false, false)
        end
        Wait(500)
    end
end)

-- каждый кадр прячем стандартные надписи GTA (деньги, название машины, район, улица)
CreateThread(function()
    local list = Config.HideComponents
    while true do
        if visible then
            for i = 1, #list do HideHudComponentThisFrame(list[i]) end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- поменяли разрешение или окно — пересчитать место миникарты
CreateThread(function()
    local lastRes = ''
    while true do
        Wait(2000)
        local x, y = GetActiveScreenResolution()
        local res = x .. 'x' .. y .. ':' .. GetSafeZoneSize()
        if res ~= lastRes then
            lastRes = res
            send('layout', minimapLayout())
        end
    end
end)

lib.addKeybind({
    name = 'kavkaz_hud_hints', description = 'Подсказки клавиш: показать / скрыть', defaultKey = Config.HintsKey,
    onPressed = function()
        hintsOff = not hintsOff
        SetResourceKvpInt(HINTS_KVP, hintsOff and 1 or 0)
        sendHints()
    end,
})

RegisterCommand('hud', function()
    userHidden = not userHidden
    exports.qbx_core:Notify(userHidden and 'Интерфейс скрыт. /hud — вернуть' or 'Интерфейс снова виден', 'inform')
end, false)

-- exports.kavkaz_hud:SetVisible(false) — спрятать HUD из другого ресурса
exports('SetVisible', function(state) userHidden = not state end)

AddEventHandler('onResourceStart', function(name)
    if name ~= GetCurrentResourceName() then return end
    refreshPlayerData()
end)
