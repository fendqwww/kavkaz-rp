-- инструменты админа: noclip, телепорт мышкой, ТП на метку и по координатам, спектатор, невидимость, починка.

local noclip, invisible, clickMode, spectating = false, false, false, false

---------------------------------------------------------------------------
-- математика камеры
---------------------------------------------------------------------------

local function rotToDir(rot)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    return vec3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
end

-- луч из камеры через точку экрана (sx, sy в 0..1): куда упёрся — туда и ТП
local function screenToWorld(sx, sy)
    local camPos, camRot = GetFinalRenderedCamCoord(), GetFinalRenderedCamRot(2)
    local fov = GetFinalRenderedCamFov()
    local forward = rotToDir(camRot)
    local rz = math.rad(camRot.z)
    local right = vec3(math.cos(rz), math.sin(rz), 0.0)
    local up = vec3(
        right.y * forward.z - right.z * forward.y,
        right.z * forward.x - right.x * forward.z,
        right.x * forward.y - right.y * forward.x)
    local tanHalf = math.tan(math.rad(fov) / 2)
    local aspect = GetAspectRatio(true)
    local dir = forward + right * ((sx * 2 - 1) * tanHalf * aspect) + up * ((1 - sy * 2) * tanHalf)
    dir = dir / #dir
    local target = camPos + dir * 1500.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(camPos.x, camPos.y, camPos.z, target.x, target.y, target.z, -1, cache.ped, 0)
    local _, hit, coords = GetShapeTestResult(ray)
    return hit == 1 and coords or nil
end

local function teleportTo(x, y, z)
    local entity = (cache.vehicle and cache.seat == -1) and cache.vehicle or cache.ped
    SetEntityCoords(entity, x, y, z, false, false, false, false)
end

-- поиск земли под точкой (для метки на карте)
local function groundZ(x, y)
    for height = 1000.0, 0.0, -25.0 do
        RequestCollisionAtCoord(x, y, height)
        SetEntityCoordsNoOffset(cache.ped, x, y, height, false, false, false)
        Wait(10)
        local found, z = GetGroundZFor_3dCoord(x, y, height, false)
        if found then return z end
    end
    return nil
end

---------------------------------------------------------------------------
-- noclip (F2)
---------------------------------------------------------------------------

local function setNoclip(state)
    noclip = state
    local entity = (cache.vehicle and cache.seat == -1) and cache.vehicle or cache.ped
    if not state then
        SetEntityCollision(entity, true, true)
        FreezeEntityPosition(entity, false)
        SetEntityInvincible(cache.ped, false)
        if not invisible then ResetEntityAlpha(cache.ped) end
        lib.hideTextUI()
        return
    end
    lib.showTextUI('NOCLIP · WASD, Q/E вверх-вниз, SHIFT быстрее, CTRL медленнее', { position = 'top-center' })
    CreateThread(function()
        while noclip do
            entity = (cache.vehicle and cache.seat == -1) and cache.vehicle or cache.ped
            SetEntityCollision(entity, false, false)
            FreezeEntityPosition(entity, true)
            SetEntityInvincible(cache.ped, true)
            SetEntityAlpha(cache.ped, 150, false)

            local speed = Config.NoclipSpeed.normal
            if IsControlPressed(0, 21) then speed = Config.NoclipSpeed.fast
            elseif IsControlPressed(0, 36) then speed = Config.NoclipSpeed.slow end

            local rot = GetGameplayCamRot(2)
            local forward = rotToDir(rot)
            local rz = math.rad(rot.z)
            local right = vec3(math.cos(rz), math.sin(rz), 0.0)
            local move = vec3(0.0, 0.0, 0.0)
            if IsControlPressed(0, 32) then move = move + forward end
            if IsControlPressed(0, 33) then move = move - forward end
            if IsControlPressed(0, 35) then move = move + right end
            if IsControlPressed(0, 34) then move = move - right end
            if IsControlPressed(0, 44) then move = move + vec3(0, 0, 1) end
            if IsControlPressed(0, 38) then move = move - vec3(0, 0, 1) end

            local pos = GetEntityCoords(entity) + move * speed
            SetEntityCoordsNoOffset(entity, pos.x, pos.y, pos.z, true, true, true)
            SetEntityHeading(entity, rot.z)
            DisableControlAction(0, 44, true) DisableControlAction(0, 38, true)
            Wait(0)
        end
    end)
end

-- пока ждём ответа сервера, повторное нажатие игнорируем: иначе два быстрых нажатия
-- оба проходят проверку, пишут в лог «включил» дважды, и второе сразу выключает noclip
local busy = {}
local function guarded(key, fn)
    if busy[key] then return end
    busy[key] = true
    local ok, err = pcall(fn)
    busy[key] = nil
    if not ok then error(err, 0) end
end

local function toggleNoclip()
    guarded('noclip', function()
        if noclip then return setNoclip(false) end
        if not Allowed('noclip', 'включил') or noclip then return end
        setNoclip(true)
    end)
end
RegisterCommand('noclip', toggleNoclip, false)

---------------------------------------------------------------------------
-- телепорт мышкой (F3: появился курсор, ЛКМ — ТП, ПКМ или F3 — выйти)
---------------------------------------------------------------------------

local function toggleClickTp()
    if clickMode then clickMode = false return end
    if not Allowed('clicktp') then return end
    clickMode = true
    lib.showTextUI('ТП мышкой: ЛКМ — перенестись, ПКМ — выйти', { position = 'top-center' })
    CreateThread(function()
        while clickMode do
            SetMouseCursorActiveThisFrame()
            DisableControlAction(0, 1, true) DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
            DisableControlAction(0, 142, true) DisableControlAction(0, 257, true)
            if IsDisabledControlJustPressed(0, 24) then
                local hit = screenToWorld(GetDisabledControlNormal(0, 239), GetDisabledControlNormal(0, 240))
                if hit then teleportTo(hit.x, hit.y, hit.z + 0.5) end
            elseif IsDisabledControlJustPressed(0, 25) then
                clickMode = false
            end
            Wait(0)
        end
        lib.hideTextUI()
    end)
end
RegisterCommand('clicktp', toggleClickTp, false)

---------------------------------------------------------------------------
-- ТП на метку и по координатам
---------------------------------------------------------------------------

RegisterCommand('atpm', function()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return lib.notify({ description = 'поставь метку на карте', type = 'error' }) end
    if not Allowed('atpm') then return end
    local c = GetBlipInfoIdCoord(blip)
    local start = GetEntityCoords(cache.ped)
    DoScreenFadeOut(250) Wait(300)
    FreezeEntityPosition(cache.ped, true)
    local z = groundZ(c.x, c.y)
    FreezeEntityPosition(cache.ped, false)
    if z then teleportTo(c.x, c.y, z + 1.0)
    else
        teleportTo(start.x, start.y, start.z)
        lib.notify({ description = 'не нашёл землю под меткой', type = 'error' })
    end
    DoScreenFadeIn(250)
end, false)

RegisterCommand('tpc', function(_, args)
    local function num(v) return tonumber((tostring(v or ''):gsub(',', ''))) end
    local x, y, z = num(args[1]), num(args[2]), num(args[3])
    if not x or not y or not z then return lib.notify({ description = 'формат: /tpc x y z', type = 'error' }) end
    if not Allowed('tpc', ('%.1f %.1f %.1f'):format(x, y, z)) then return end
    teleportTo(x + 0.0, y + 0.0, z + 0.0)
end, false)

---------------------------------------------------------------------------
-- невидимость
---------------------------------------------------------------------------

local function setInvisible(state)
    invisible = state
    SetEntityVisible(cache.ped, not state, false)
    if not state then ResetEntityAlpha(cache.ped) return end
    CreateThread(function()
        while invisible do
            SetEntityLocallyVisible(cache.ped)
            SetEntityAlpha(cache.ped, 120, false)
            Wait(0)
        end
    end)
end

RegisterCommand('invis', function()
    guarded('invis', function()
        if not invisible and (not Allowed('invis', 'включил') or invisible) then return end
        setInvisible(not invisible)
        lib.notify({ description = invisible and 'ты невидим' or 'ты снова видим', type = 'inform' })
    end)
end, false)

---------------------------------------------------------------------------
-- машина: починить, перевернуть
---------------------------------------------------------------------------

RegisterCommand('afix', function()
    local veh = cache.vehicle or lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
    if not veh then return lib.notify({ description = 'рядом нет машины', type = 'error' }) end
    if not Allowed('afix', GetDisplayNameFromVehicleModel(GetEntityModel(veh))) then return end
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehicleDirtLevel(veh, 0.0)
    Entity(veh).state:set('fuel', 100, true)
    SetVehicleFuelLevel(veh, 100.0)
    lib.notify({ description = 'машина починена и заправлена', type = 'success' })
end, false)

RegisterCommand('aflip', function()
    local veh = cache.vehicle or lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
    if not veh then return lib.notify({ description = 'рядом нет машины', type = 'error' }) end
    if not Allowed('aflip') then return end
    SetVehicleOnGroundProperly(veh)
end, false)

---------------------------------------------------------------------------
-- спектатор
---------------------------------------------------------------------------

local function stopSpec()
    if not spectating then return end
    local back = spectating.back
    spectating = false
    NetworkSetInSpectatorMode(false, cache.ped)
    DoScreenFadeOut(250) Wait(300)
    SetEntityCoords(cache.ped, back.x, back.y, back.z, false, false, false, false)
    FreezeEntityPosition(cache.ped, false)
    SetEntityCollision(cache.ped, true, true)
    if not invisible then SetEntityVisible(cache.ped, true, false) end
    lib.hideTextUI()
    DoScreenFadeIn(250)
end

RegisterNetEvent('kavkaz_admin:client:spec', function(target, coords)
    if not target or spectating then return stopSpec() end
    spectating = { back = GetEntityCoords(cache.ped), target = target }
    DoScreenFadeOut(250) Wait(300)
    SetEntityVisible(cache.ped, false, false)
    SetEntityCollision(cache.ped, false, false)
    FreezeEntityPosition(cache.ped, true)
    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z - 15.0, false, false, false, false)

    local deadline = GetGameTimer() + 5000
    local player = GetPlayerFromServerId(target)
    while player == -1 and GetGameTimer() < deadline do
        Wait(100)
        player = GetPlayerFromServerId(target)
    end
    if player == -1 then
        DoScreenFadeIn(250)
        lib.notify({ description = 'игрок не прогрузился', type = 'error' })
        return stopSpec()
    end
    NetworkSetInSpectatorMode(true, GetPlayerPed(player))
    DoScreenFadeIn(250)
    lib.showTextUI(('Наблюдение за ID %d · BACKSPACE — выйти'):format(target), { position = 'top-center' })

    CreateThread(function()
        while spectating do
            local p = GetPlayerFromServerId(target)
            if p == -1 then stopSpec() break end
            -- держимся под игроком, чтобы он не пропал из зоны прогрузки
            local tpos = GetEntityCoords(GetPlayerPed(p))
            SetEntityCoordsNoOffset(cache.ped, tpos.x, tpos.y, tpos.z - 15.0, false, false, false)
            if IsControlJustPressed(0, 177) then stopSpec() break end
            Wait(0)
        end
    end)
end)

---------------------------------------------------------------------------
-- клавиши и сброс при сдаче смены
---------------------------------------------------------------------------

lib.addKeybind({ name = 'kavkaz_noclip', description = 'Админка: noclip', defaultKey = Config.Keys.noclip,
    onPressed = function() if MyLevel() > 0 then toggleNoclip() end end })
lib.addKeybind({ name = 'kavkaz_clicktp', description = 'Админка: телепорт мышкой', defaultKey = Config.Keys.clicktp,
    onPressed = function() if MyLevel() > 0 then toggleClickTp() end end })

local function resetAll()
    if noclip then setNoclip(false) end
    if invisible then setInvisible(false) end
    clickMode = false
    if spectating then stopSpec() end
end

RegisterNetEvent('kavkaz_admin:client:dutyOff', resetAll)
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then resetAll() lib.hideTextUI() end
end)

-- для панели
Tools = {
    toggleNoclip = toggleNoclip,
    toggleClickTp = toggleClickTp,
    isNoclip = function() return noclip end,
    isInvisible = function() return invisible end,
}
