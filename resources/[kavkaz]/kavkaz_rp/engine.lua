-- KAVKAZ RP: двигатель заводится кнопкой, а не сам при посадке (docs/vision/20-plan-polish.md, п. 5).
-- рука тянется к замку, стартёр крутит (звук стартёра GTA), обороты подскакивают и падают до холостых.
-- старые машины (ВАЗ, Газель, УАЗ) и побитый двигатель иногда заводятся не с первого раза.
-- ключи проверяет qbx_vehiclekeys: без ключей он сам глушит двигатель, мы только пишем, почему не завелось.

local E = Config.Engine
local NO_AUTOSTART = 429 -- флаг педа: не заводить двигатель самому при посадке и нажатии газа
local busy, hint = false, false
local started = {} -- машины, которые за эту посадку уже заводились (первый запуск «на холодную» тяжелее)

local function showHint(on)
    if on == hint then return end
    hint = on
    if on then lib.showTextUI(('[%s] — завести двигатель'):format(E.Key), { position = 'left-center' })
    else lib.hideTextUI() end
end

-- шанс, что не заведётся с этой попытки
local function failChance(veh)
    local chance = 0.0
    if E.OldCars[GetEntityArchetypeName(veh)] then
        chance = started[veh] and E.OldRetry or E.OldCold
    end
    local hp = GetVehicleEngineHealth(veh)
    if hp < 300.0 then chance = math.max(chance, 0.6)
    elseif hp < 600.0 then chance = math.max(chance, 0.25) end
    return chance
end

-- подскок оборотов после запуска («перегазовка»)
local function blip(veh)
    CreateThread(function()
        for i = 1, 12 do
            if not DoesEntityExist(veh) or not GetIsVehicleEngineRunning(veh) then return end
            SetVehicleCurrentRpm(veh, 0.55 - i * 0.03)
            Wait(40)
        end
    end)
end

local function crank(veh)
    -- рука к замку зажигания
    local anim = E.Anim
    if GetVehicleClass(veh) == 8 then anim = E.AnimBike end
    lib.playAnim(cache.ped, anim.dict, anim.clip, 8.0, 8.0, -1, 48, 0)
    Wait(anim.delay)
    if cache.vehicle ~= veh or cache.seat ~= -1 then return end

    -- стартёр GTA крутит, пока двигатель заводится «не мгновенно»
    SetVehicleEngineOn(veh, true, false, true)

    if math.random() < failChance(veh) then
        Wait(E.CrankMs)
        SetVehicleEngineOn(veh, false, true, true)
        started[veh] = true
        lib.notify({ description = 'Не завелась. Попробуй ещё раз.', type = 'inform' })
        return
    end

    Wait(E.CrankMs)
    started[veh] = true
    if GetIsVehicleEngineRunning(veh) then
        blip(veh)
    elseif not exports.qbx_vehiclekeys:HasKeys(veh) then
        lib.notify({ description = 'Нет ключей от этой машины', type = 'error' })
    end
end

local function toggle()
    local veh = cache.vehicle
    if busy or not veh or cache.seat ~= -1 then return end
    if GetVehicleClass(veh) == 13 then return end -- велосипед
    busy = true
    if GetIsVehicleEngineRunning(veh) then
        lib.playAnim(cache.ped, E.Anim.dict, E.Anim.clip, 8.0, 8.0, -1, 48, 0)
        Wait(E.Anim.delay)
        if cache.vehicle == veh then SetVehicleEngineOn(veh, false, false, true) end
    else
        crank(veh)
    end
    Wait(600)
    busy = false
end

lib.addKeybind({ name = 'kavkaz_engine', description = 'Машина: завести / заглушить двигатель', defaultKey = E.Key, onPressed = toggle })

-- за рулём: не даём GTA заводить самой, подсказываем кнопку, пока двигатель заглушён
lib.onCache('seat', function(seat)
    SetPedConfigFlag(cache.ped, NO_AUTOSTART, true)
    if seat ~= -1 then showHint(false) return end
    CreateThread(function()
        Wait(0)
        local veh = cache.vehicle
        while veh and cache.vehicle == veh and cache.seat == -1 do
            showHint(GetVehicleClass(veh) ~= 13 and not GetIsVehicleEngineRunning(veh))
            Wait(250)
        end
        showHint(false)
        if veh then started[veh] = nil end
    end)
end)

lib.onCache('ped', function(ped) SetPedConfigFlag(ped, NO_AUTOSTART, true) end)
CreateThread(function() SetPedConfigFlag(PlayerPedId(), NO_AUTOSTART, true) end)
