-- luacheck: globals DEATH_STATE_STATE_BAG
-- KAVKAZ: вместо жёлтого текста GTA (qbx.drawText2d) — плашка в kavkaz_hud (событие kavkaz_hud:client:down).
-- логика та же: G — вызвать скорую, E (держать) — в больницу; время лёжа и стоимость — в конфигах qbx_medical / этого ресурса.
local config = require 'config.client'
local sharedConfig = require 'config.shared'
local doctorCount = 0

local function getDoctorCount()
    return lib.callback.await('qbx_ambulancejob:server:getNumDoctors')
end

-- KAVKAZ: шлём в HUD не каждый кадр, а когда что-то поменялось
local lastKey
local function show(data)
    local key = data and ('%s:%s:%s:%s:%s'):format(data.kind, data.time, data.hold or '', data.call or '', data.doctors or '') or 'off'
    if key == lastKey then return end
    lastKey = key
    TriggerEvent('kavkaz_hud:client:down', data)
end

local function displayRespawnText()
    show({
        kind = 'dead',
        time = math.ceil(exports.qbx_medical:GetDeathTime()),
        hold = exports.qbx_medical:GetRespawnHoldTimeDeprecated(),
        cost = sharedConfig.checkInCost,
        doctors = doctorCount,
    })
end

---@param ped number
local function playDeadAnimation(ped)
    if IsInHospitalBed then
        if not IsEntityPlayingAnim(ped, InBedDict, InBedAnim, 3) then
            lib.playAnim(ped, InBedDict, InBedAnim, 1.0, 1.0, -1, 1, 0, false, false, false)
        end
    else
        exports.qbx_medical:PlayDeadAnimation()
    end
end

---@param ped number
local function handleDead(ped)
    if not IsInHospitalBed then
        displayRespawnText()
    else
        show(nil)
    end

    playDeadAnimation(ped)
end

local function handleLastStand()
    local laststandTime = math.ceil(exports.qbx_medical:GetLaststandTime())
    local canCall = laststandTime <= config.laststandTimer and doctorCount > 0
    if canCall and not EmsNotified and IsControlJustPressed(0, 47) then
        TriggerServerEvent('hospital:server:ambulanceAlert', locale('info.civ_down'))
        EmsNotified = true
    end
    show({
        kind = 'down',
        time = laststandTime,
        doctors = doctorCount,
        call = not canCall and 'none' or (EmsNotified and 'sent' or 'can'),
    })
end

local deathStateCfg = require("@qbx_medical.config.shared").deathState
local deathState = LocalPlayer.state[DEATH_STATE_STATE_BAG] or deathStateCfg.ALIVE

local running = false
local function stateLoop()
    if running then return end
    running = true
    doctorCount = getDoctorCount()
    local lastUpdate = GetGameTimer()
    while deathState == deathStateCfg.LAST_STAND or deathState == deathStateCfg.DEAD do
        if deathState == deathStateCfg.LAST_STAND then
            handleLastStand()
        end
        if deathState == deathStateCfg.DEAD then
            handleDead(cache.ped)
        end
        local currentTime = GetGameTimer()
        if (currentTime - lastUpdate) > 60000 then
            doctorCount = getDoctorCount()
            lastUpdate = currentTime
        end
        Wait(0)
    end
    show(nil)
    running = false
end

AddStateBagChangeHandler(DEATH_STATE_STATE_BAG, ('player:%s'):format(cache.serverId), function(_, _, value)
    deathState = value
    if (value == deathStateCfg.LAST_STAND) or (value == deathStateCfg.DEAD) then
        CreateThread(stateLoop)
    end
end)

-- A resource restart does not replay existing state bags.
CreateThread(stateLoop)
