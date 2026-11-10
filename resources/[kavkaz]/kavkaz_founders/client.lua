-- KAVKAZ RP — дома основателей (Норт-Конкер 2044 и 2045): появление дома, вход и выход, гараж, цветущие деревья.

local TREES = { 'prop_tree_jacada_01', 'prop_tree_jacada_02' }
local spawned = {}
local founder = false

local function teleport(c)
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end
    local ped = PlayerPedId()
    RequestCollisionAtCoord(c.x, c.y, c.z)
    SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
    SetEntityHeading(ped, c.w)
    local t = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do Wait(50) end
    Wait(200)
    DoScreenFadeIn(500)
end

-- снаружи: ставим на ближайшую точку, где можно стоять (если координата двери неточная)
local function outside(door)
    local ok, safe = GetSafeCoordForPed(door.x, door.y, door.z, true, 16)
    return ok and vec4(safe.x, safe.y, safe.z, door.w) or door
end

-- место выезда машин: ближайшая дорога у гаража (запоминает сервер, один раз)
local function findGarageRoad()
    local a = Config.Garage.access
    local ok, pos, heading = GetClosestVehicleNodeWithHeading(a.x, a.y, a.z, 1, 3.0, 0)
    if ok and #(pos - a.xyz) < 120.0 then
        TriggerServerEvent('kavkaz_founders:server:garageSpawn', pos.x, pos.y, pos.z + 0.5, heading)
    end
end

-- место выезда из гаража держим свободным: бесхозные машины GTA (припаркованные NPC) убираем.
-- машины игроков (из гаражей, с номером в базе) и машины с людьми не трогаем
local spawnPoint
CreateThread(function()
    while true do
        local wait = 3000
        if founder then
            if not spawnPoint then
                local s = lib.callback.await('kavkaz_founders:garageSpawn', false)
                if s then spawnPoint = vec3(s[1], s[2], s[3]) end
            end
            if spawnPoint and #(GetEntityCoords(PlayerPedId()) - spawnPoint) < 60.0 then
                wait = 1500
                for _, veh in ipairs(GetGamePool('CVehicle')) do
                    if #(GetEntityCoords(veh) - spawnPoint) < 7.0
                        and not Entity(veh).state.vehicleid
                        and IsVehicleSeatFree(veh, -1)
                        and GetVehicleNumberOfPassengers(veh) == 0
                        and not IsEntityAMissionEntity(veh) then
                        NetworkRequestControlOfEntity(veh)
                        SetEntityAsMissionEntity(veh, true, true)
                        DeleteVehicle(veh)
                    end
                end
            end
        end
        Wait(wait)
    end
end)

RegisterNetEvent('kavkaz_founders:client:spawnReset', function() spawnPoint = nil end)

-- метки домов
CreateThread(function()
    for _, f in ipairs(Config.Founders) do
        local b = AddBlipForCoord(f.door.x, f.door.y, f.door.z)
        SetBlipSprite(b, 40)
        SetBlipColour(b, 5)
        SetBlipScale(b, 0.85)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(f.label)
        EndTextCommandSetBlipName(b)
    end
end)

-- вход и выход ([E]) — только для основателей
local text = false
local function hint(show, label)
    if show == text then return end
    text = show
    if show then lib.showTextUI(label) else lib.hideTextUI() end
end

CreateThread(function()
    while true do
        local wait = 1000
        if founder then
            local me = GetEntityCoords(PlayerPedId())
            local near
            for _, f in ipairs(Config.Founders) do
                if #(me - f.door.xyz) < 2.5 then near = { 'in', f } end
                if #(me - f.inside.xyz) < 2.5 then near = { 'out', f } end
            end
            if near then
                wait = 0
                hint(true, near[1] == 'in' and '[E] Войти в дом' or '[E] Выйти на улицу')
                if IsControlJustReleased(0, 38) and not IsPedInAnyVehicle(PlayerPedId(), false) then
                    hint(false)
                    if near[1] == 'in' then teleport(near[2].inside) else teleport(outside(near[2].door)) end
                end
            else
                hint(false)
                wait = 500
            end
        end
        Wait(wait)
    end
end)

-- деревья у входов (цветущие, как сакура): появляются рядом, исчезают вдали
local function treesAround(c)
    local list = {}
    for i = 0, 3 do
        local a = math.rad(i * 90 + 45)
        list[#list + 1] = { model = TREES[i % 2 + 1], x = c.x + math.cos(a) * 9.0, y = c.y + math.sin(a) * 9.0, z = c.z }
    end
    return list
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        for i, f in ipairs(Config.Founders) do
            local near = #(me - f.door.xyz) < 200.0
            if near and not spawned[i] then
                spawned[i] = {}
                for _, t in ipairs(treesAround(f.door)) do
                    local model = joaat(t.model)
                    if IsModelInCdimage(model) then
                        lib.requestModel(model, 5000)
                        local obj = CreateObjectNoOffset(model, t.x, t.y, t.z, false, false, false)
                        PlaceObjectOnGroundProperly(obj)
                        FreezeEntityPosition(obj, true)
                        SetModelAsNoLongerNeeded(model)
                        spawned[i][#spawned[i] + 1] = obj
                    end
                end
            elseif not near and spawned[i] then
                for _, obj in ipairs(spawned[i]) do DeleteObject(obj) end
                spawned[i] = nil
            end
        end
        Wait(2000)
    end
end)

-- основатель появляется у себя дома при каждом входе в персонажа
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    founder = lib.callback.await('kavkaz_founders:isFounder', false) == true
    if not founder or not Config.SpawnAtHome then return end
    local pd = exports.qbx_core:GetPlayerData()
    for _, f in ipairs(Config.Founders) do
        if pd and pd.citizenid == f.citizenid then
            Wait(2500) -- даём qbx_core закончить своё появление
            teleport(f.inside)
            lib.notify({ title = 'Дом', description = 'С возвращением. Выйти — [E] у двери. Гараж — у дома, метка на карте.', type = 'inform' })
            Wait(3000)
            findGarageRoad()
            return
        end
    end
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() or not LocalPlayer.state.isLoggedIn then return end
    founder = lib.callback.await('kavkaz_founders:isFounder', false) == true
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if text then lib.hideTextUI() end
    for _, list in pairs(spawned) do
        for _, obj in ipairs(list) do DeleteObject(obj) end
    end
end)
