-- NPC, окно диалога, цели на карте. решения принимает сервер.

local peds, cars, open = {}, {}, false

---------------------------------------------------------------------------
-- диалог
---------------------------------------------------------------------------

local currentNpc

local function show(node)
    if not node then
        open, currentNpc = false, nil
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
        return
    end
    currentNpc = node.npc
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'dialog', data = node })
end

local function talk(npcId, choice)
    show(lib.callback.await('kavkaz_quests:talk', false, npcId, choice))
end

RegisterNUICallback('choose', function(body, cb)
    cb('ok')
    if currentNpc then talk(currentNpc, body.id) end
end)

RegisterNUICallback('close', function(_, cb)
    cb('ok')
    show(nil)
end)

---------------------------------------------------------------------------
-- NPC: появляются, когда игрок рядом
---------------------------------------------------------------------------

local function spawn(id, npc)
    local c = npc.coords
    local model = joaat(npc.model)
    lib.requestModel(model)
    -- ставим на землю: если высота в конфиге неточная, NPC не висит в воздухе и не уходит под асфальт
    local found, groundZ = GetGroundZFor_3dCoord(c.x, c.y, c.z + 2.0, false)
    local z = (found and math.abs(groundZ - c.z) < 5.0) and groundZ or (c.z - 1.0)
    local ped = CreatePed(4, model, c.x, c.y, z, c.w, false, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    if npc.scenario then TaskStartScenarioInPlace(ped, npc.scenario, 0, true) end
    SetModelAsNoLongerNeeded(model)
    exports.ox_target:addLocalEntity(ped, {
        { name = 'kavkaz_q_' .. id, icon = 'fa-solid fa-comment', label = 'Поговорить: ' .. npc.name, distance = 2.5, onSelect = function() talk(id) end },
    })
    peds[id] = ped
    -- машина рядом с NPC (маршрутка дяди Хамзата): на ближайшей дороге, только у этого игрока
    if npc.vehicle then
        for _, m in ipairs(npc.vehicle.models) do
            local h = joaat(m)
            if IsModelInCdimage(h) then
                lib.requestModel(h)
                local ok, pos, heading = GetClosestVehicleNodeWithHeading(c.x, c.y, c.z, 1, 3.0, 0)
                if not ok then pos, heading = vec3(c.x + 3.0, c.y, c.z), c.w end
                local veh = CreateVehicle(h, pos.x, pos.y, pos.z, heading, false, false)
                SetVehicleOnGroundProperly(veh)
                if npc.vehicle.color then SetVehicleColours(veh, npc.vehicle.color, npc.vehicle.color) end
                if npc.vehicle.plate then SetVehicleNumberPlateText(veh, npc.vehicle.plate) end
                SetVehicleDoorsLocked(veh, 2)
                SetVehicleIndicatorLights(veh, 0, true) -- аварийка: встал
                SetVehicleIndicatorLights(veh, 1, true)
                FreezeEntityPosition(veh, true)
                SetModelAsNoLongerNeeded(h)
                cars[id] = veh
                break
            end
        end
    end
end

CreateThread(function()
    for id, npc in pairs(Config.Npcs) do
        if npc.blip then
            local b = AddBlipForCoord(npc.coords.x, npc.coords.y, npc.coords.z)
            SetBlipSprite(b, npc.blip.sprite)
            SetBlipColour(b, npc.blip.color)
            SetBlipScale(b, 0.75)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(npc.blip.label)
            EndTextCommandSetBlipName(b)
        end
        lib.points.new({
            coords = npc.coords.xyz, distance = 70.0,
            onEnter = function() if not peds[id] then spawn(id, npc) end end,
            onExit = function()
                if peds[id] then
                    exports.ox_target:removeLocalEntity(peds[id], 'kavkaz_q_' .. id)
                    DeleteEntity(peds[id])
                    peds[id] = nil
                end
                if cars[id] then DeleteEntity(cars[id]) cars[id] = nil end
                if open and currentNpc == id then show(nil) end
            end,
        })
    end
end)

---------------------------------------------------------------------------
-- цели: метка на карте с маршрутом, подсказка сверху, проверка дистанции
---------------------------------------------------------------------------

local obj, objBlip

local function clearObjective()
    obj = nil
    if objBlip then RemoveBlip(objBlip) objBlip = nil end
    lib.hideTextUI()
end

-- действия на месте цели
local ANIMS = {
    wash = { scenario = 'PROP_HUMAN_BUM_BIN', label = 'Моешь руки…' },
    search = { scenario = 'PROP_HUMAN_BUM_BIN', label = 'Ищешь…' },
    sample = { scenario = 'WORLD_HUMAN_GARDENER_PLANT', label = 'Берёшь пробу…' },
    canister = { scenario = 'PROP_HUMAN_PARKING_METER', label = 'Покупаешь канистру и наливаешь бензин…' },
    pour = { scenario = 'PROP_HUMAN_BUM_BIN', label = 'Заливаешь бензин в бак маршрутки…' },
}
local function playAnim(name)
    local a = ANIMS[name]
    if not a then return end
    TaskStartScenarioInPlace(cache.ped, a.scenario, 0, true)
    lib.progressBar({ duration = 4000, label = a.label, canCancel = false, disable = { move = true, car = true, combat = true } })
    ClearPedTasks(cache.ped)
end

RegisterNetEvent('kavkaz_quests:client:objective', function(data)
    clearObjective()
    if not data then return end
    obj = data
    obj.until_ = data.deadline and (GetGameTimer() + data.deadline * 1000) or nil
    objBlip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipSprite(objBlip, 1)
    SetBlipColour(objBlip, 5)
    SetBlipRoute(objBlip, true)
    SetBlipRouteColour(objBlip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(data.text)
    EndTextCommandSetBlipName(objBlip)
    lib.notify({ title = 'Новая цель', description = data.text, type = 'inform', duration = 6000 })

    CreateThread(function()
        local me = data
        local sent = false
        while obj == me do
            local pos = GetEntityCoords(cache.ped)
            local dist = #(pos.xy - me.coords.xy)
            local text = me.text
            if me.until_ then
                local left = math.max(0, math.floor((me.until_ - GetGameTimer()) / 1000))
                text = ('%s · %02d:%02d'):format(me.text, left // 60, left % 60)
            end
            lib.showTextUI(text, { position = 'top-center', icon = 'location-dot' })
            if dist < 40.0 then
                DrawMarker(1, me.coords.x, me.coords.y, me.coords.z - 1.0, 0, 0, 0, 0, 0, 0, me.radius * 2, me.radius * 2, 0.6,
                    61, 147, 216, 120, false, false, 2, false, nil, nil, false)
            end
            if dist <= me.radius and not sent and (not me.drive or cache.vehicle) then
                sent = true
                if me.anim and not cache.vehicle then playAnim(me.anim) end
                TriggerServerEvent('kavkaz_quests:server:reach', me.id)
                SetTimeout(3000, function() sent = false end)
            end
            Wait(dist < 60.0 and 0 or 500)
        end
    end)
end)

-- сервер сам открывает окно (выбор сюжетной линии)
RegisterNetEvent('kavkaz_quests:client:dialog', function(node)
    if IsNuiFocused() then
        -- другое окно открыто: подождать, пока закроют
        CreateThread(function()
            while IsNuiFocused() do Wait(500) end
            show(node)
        end)
        return
    end
    show(node)
end)

-- памятка новичка закрыта (kavkaz_start) -> предложить выбор линии
AddEventHandler('kavkaz_start:client:guideClosed', function()
    TriggerServerEvent('kavkaz_quests:server:begin')
end)

-- после входа: восстановить текущую цель сюжета
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    SetTimeout(5000, function() TriggerServerEvent('kavkaz_quests:server:resume') end)
end)
CreateThread(function()
    Wait(3000)
    if LocalPlayer.state.isLoggedIn then TriggerServerEvent('kavkaz_quests:server:resume') end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, p in pairs(peds) do DeleteEntity(p) end
    for _, v in pairs(cars) do DeleteEntity(v) end
    clearObjective()
    if open then SetNuiFocus(false, false) end
end)

-- KAVKAZ: разговор по [E], когда подошёл к NPC (как в RP-проектах). ox_target (Alt) тоже работает
CreateThread(function()
    local shown
    while true do
        local sleep = 250
        local near
        if not open and not cache.vehicle then
            local pos = GetEntityCoords(cache.ped)
            for id, ped in pairs(peds) do
                if DoesEntityExist(ped) and #(pos - GetEntityCoords(ped)) < 2.2 then near = id break end
            end
        end
        if near then
            sleep = 0
            if shown ~= near then lib.showTextUI(('[E] Поговорить: %s'):format(Config.Npcs[near].name)); shown = near end
            if IsControlJustReleased(0, 38) then
                lib.hideTextUI(); shown = nil
                talk(near)
            end
        elseif shown then
            lib.hideTextUI(); shown = nil
        end
        Wait(sleep)
    end
end)
