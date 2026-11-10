-- KAVKAZ RP — усадьбы основателей: метки и цветущие деревья вокруг домов (как сакура).

local TREES = { 'prop_tree_jacada_01', 'prop_tree_jacada_02' }
local spawned = {}

local function treesAround(c)
    local list = {}
    for i = 0, 7 do
        local a = math.rad(i * 45 + 20)
        local r = (i % 2 == 0) and 13.0 or 16.0
        list[#list + 1] = { model = TREES[i % 2 + 1], x = c.x + math.cos(a) * r, y = c.y + math.sin(a) * r, z = c.z }
    end
    return list
end

CreateThread(function()
    for i, f in ipairs(Config.Founders) do
        local b = AddBlipForCoord(f.house.x, f.house.y, f.house.z)
        SetBlipSprite(b, 40)
        SetBlipColour(b, 5)
        SetBlipScale(b, 0.85)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Усадьба основателя')
        EndTextCommandSetBlipName(b)
    end

    while true do
        local me = GetEntityCoords(PlayerPedId())
        for i, f in ipairs(Config.Founders) do
            local near = #(me - f.house.xyz) < 250.0
            if near and not spawned[i] then
                spawned[i] = {}
                for _, t in ipairs(treesAround(f.house)) do
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

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, list in pairs(spawned) do
        for _, obj in ipairs(list) do DeleteObject(obj) end
    end
end)

-- основатели появляются у своей усадьбы при каждом входе в персонажа
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    local pd = exports.qbx_core:GetPlayerData()
    local home
    for _, f in ipairs(Config.Founders) do
        if pd and pd.citizenid == f.citizenid then home = f.house end
    end
    if not home or not Config.SpawnAtHome then return end
    Wait(2500) -- даём qbx_core закончить своё появление
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end
    local ped = PlayerPedId()
    RequestCollisionAtCoord(home.x, home.y, home.z)
    SetEntityCoords(ped, home.x, home.y, home.z + 1.0, false, false, false, false)
    local t = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do Wait(50) end
    -- ближайшая точка, где можно стоять (двор у дома), а не внутри стен
    local ok, safe = GetSafeCoordForPed(home.x, home.y, home.z, true, 16)
    if ok then SetEntityCoords(ped, safe.x, safe.y, safe.z, false, false, false, false) end
    SetEntityHeading(ped, home.w)
    Wait(300)
    DoScreenFadeIn(600)
    lib.notify({ title = 'Усадьба', description = 'С возвращением домой. Гараж — у въезда с дороги (метка на карте).', type = 'inform' })
end)
