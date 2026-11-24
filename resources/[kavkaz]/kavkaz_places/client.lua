-- KAVKAZ RP: места города — NPC, метки, меню. деньги и проверки — server.lua

local RES = GetCurrentResourceName()
local spawned = {}  -- key -> ped
local homes = {}    -- ped -> vec4 (куда вернуться после работы у машины)
local gen = {}      -- key -> номер попытки появления (старый поток загрузки не создаёт второго NPC)
local blips = {}
local busy = false

local function notify(title, text, kind)
    lib.notify({ title = title, description = text, type = kind or 'inform', duration = 6000 })
end

local function money(n)
    return (tostring(math.floor(n)):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')) .. ' ₽'
end

---------------------------------------------------------------------------
-- NPC
---------------------------------------------------------------------------
-- пол под точкой (в точках бывает и уровень пола, и высота «по пояс» из /mypos) — ищем землю сверху вниз
local function groundZ(c)
    RequestCollisionAtCoord(c.x, c.y, c.z)
    local untilT = GetGameTimer() + 2000
    repeat
        local ok, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
        if ok and math.abs(z - c.z) < 3.0 then return z end
        Wait(100)
    until GetGameTimer() > untilT
    return c.z - 1.0
end

-- вызывать из отдельного потока: ждёт модель и коллизию
local function spawnPed(key, model, coords, frozen, options)
    if spawned[key] ~= nil then return end
    spawned[key] = false -- место занято, пока грузим модель
    gen[key] = (gen[key] or 0) + 1
    local my = gen[key]
    local m = joaat(model)
    if not IsModelInCdimage(m) then
        print(('[kavkaz_places] нет модели %s (%s)'):format(model, key))
        spawned[key] = nil
        return
    end
    lib.requestModel(m, 10000)
    local z = groundZ(coords)
    if spawned[key] ~= false or gen[key] ~= my then SetModelAsNoLongerNeeded(m) return end -- игрок ушёл, пока грузили
    local ped = CreatePed(4, m, coords.x, coords.y, z, coords.w, false, true)
    SetModelAsNoLongerNeeded(m)
    if ped == 0 then spawned[key] = nil return end
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCanRagdoll(ped, false)
    SetPedDiesWhenInjured(ped, false)
    SetPedConfigFlag(ped, 208, true)
    SetPedKeepTask(ped, true)
    if frozen then FreezeEntityPosition(ped, true) end
    homes[ped] = coords
    spawned[key] = ped
    if options then exports.ox_target:addLocalEntity(ped, options) end
end

local function despawnPed(key)
    local ped = spawned[key]
    spawned[key] = nil
    gen[key] = (gen[key] or 0) + 1
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        exports.ox_target:removeLocalEntity(ped)
        homes[ped] = nil
        DeleteEntity(ped)
    end
end

-- работник подходит к машине, делает сценарий; возвращает функцию «закончить»
local function workerAt(ped, veh, scenario)
    if not ped or ped == 0 or not DoesEntityExist(ped) or not DoesEntityExist(veh) then return function() end end
    local p = GetOffsetFromEntityInWorldCoords(veh, -1.6, 0.6, 0.0)
    ClearPedTasks(ped)
    TaskGoStraightToCoord(ped, p.x, p.y, p.z, 1.0, 8000, GetEntityHeading(veh) - 90.0, 0.5)
    local stop = false
    CreateThread(function()
        local untilT = GetGameTimer() + 8000
        while not stop and GetGameTimer() < untilT and DoesEntityExist(ped) and #(GetEntityCoords(ped) - p) > 1.2 do Wait(200) end
        if not stop and DoesEntityExist(ped) then TaskStartScenarioInPlace(ped, scenario, 0, true) end
    end)
    return function()
        stop = true
        if not DoesEntityExist(ped) then return end
        ClearPedTasks(ped)
        local home = homes[ped]
        if home then TaskGoStraightToCoord(ped, home.x, home.y, home.z, 1.0, 10000, home.w, 0.5) end
    end
end

---------------------------------------------------------------------------
-- машина игрока у места
---------------------------------------------------------------------------
local function myVehicle(place)
    local me = PlayerPedId()
    local veh = GetVehiclePedIsIn(me, false)
    if veh == 0 then return nil, 'подъезжай на машине и оставайся за рулём' end
    if GetPedInVehicleSeat(veh, -1) ~= me then return nil, 'сядь за руль' end
    local c = place.ped.coords
    if #(GetEntityCoords(veh) - vec3(c.x, c.y, c.z)) > place.radius then return nil, 'подъезжай ближе к мастеру' end
    if not NetworkGetEntityIsNetworked(veh) then return nil, 'с этой машиной не работаем' end
    return veh
end

local function burstTyres(veh)
    local n = 0
    for _, w in ipairs({ 0, 1, 2, 3, 4, 5, 45, 47 }) do
        if IsVehicleTyreBurst(veh, w, false) then n = n + 1 end
    end
    return n
end

local function progress(label, time)
    return lib.progressCircle({
        duration = time, label = label, position = 'bottom', useWhileDead = false, canCancel = true,
        disable = { move = true, car = true, combat = true },
    })
end

---------------------------------------------------------------------------
-- услуги
---------------------------------------------------------------------------
local function doDetail(place, pkg)
    if busy then return end
    local veh, err = myVehicle(place)
    if not veh then return notify(place.label, err, 'error') end
    busy = true
    local done = workerAt(spawned[place.id], veh, 'WORLD_HUMAN_MAID_CLEAN')
    local ok = progress(pkg.label .. '…', pkg.time)
    done()
    if not ok then busy = false return notify(place.label, 'отменено, денег не взяли', 'inform') end
    veh = myVehicle(place)
    if not veh then busy = false return notify(place.label, 'машина уехала — услугу не оказали', 'error') end
    local paid, msg, body = lib.callback.await('kavkaz_places:detail', false, place.id, pkg.id, VehToNet(veh))
    busy = false
    if not paid then return notify(place.label, msg, 'error') end
    SetVehicleDirtLevel(veh, 0.0)
    WashDecalsFromVehicle(veh, 1.0)
    if body then
        SetVehicleDeformationFixed(veh)
        SetVehicleBodyHealth(veh, 1000.0)
    end
    notify(place.label, msg, 'success')
end

local function openDetailing(place)
    local options = {}
    for _, pkg in ipairs(Config.Detailing) do
        options[#options + 1] = {
            title = ('%s — %s'):format(pkg.label, money(pkg.price)),
            description = pkg.desc,
            icon = 'spray-can-sparkles',
            onSelect = function() doDetail(place, pkg) end,
        }
    end
    lib.registerContext({ id = 'kavkaz_places_detail', title = place.label, options = options })
    lib.showContext('kavkaz_places_detail')
end

local function doRepair(place)
    if busy then return end
    local veh, err = myVehicle(place)
    if not veh then return notify(place.label, err, 'error') end
    local tyres = burstTyres(veh)
    local ok, price = lib.callback.await('kavkaz_places:repairQuote', false, place.id, VehToNet(veh), tyres)
    if not ok then return notify(place.label, price, 'error') end
    if price <= 0 then return notify(place.label, 'машина в порядке, чинить нечего', 'inform') end
    local text = ('Двигатель, кузов%s — %s. Чиним?'):format(tyres > 0 and (', колёса (' .. tyres .. ')') or '', money(price))
    if lib.alertDialog({ header = place.label, content = text, centered = true, cancel = true, labels = { confirm = 'Чинить', cancel = 'Не надо' } }) ~= 'confirm' then return end
    busy = true
    local done = workerAt(spawned[place.id], veh, 'WORLD_HUMAN_WELDING')
    local finished = progress('Ремонт…', Config.Repair.time)
    done()
    if not finished then busy = false return notify(place.label, 'отменено, денег не взяли', 'inform') end
    veh = myVehicle(place)
    if not veh then busy = false return notify(place.label, 'машина уехала — ремонт не сделан', 'error') end
    local paid, msg = lib.callback.await('kavkaz_places:repair', false, place.id, VehToNet(veh), burstTyres(veh))
    busy = false
    if not paid then return notify(place.label, msg, 'error') end
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    for _, w in ipairs({ 0, 1, 2, 3, 4, 5, 45, 47 }) do SetVehicleTyreFixed(veh, w) end
    notify(place.label, msg, 'success')
end

local function openStore(place)
    local store = Config.Stores[place.store]
    if not store then return end
    local options = {}
    for _, it in ipairs(store.items) do
        options[#options + 1] = {
            title = ('%s — %s'):format(it.label, money(it.price)),
            icon = 'prescription-bottle-medical',
            onSelect = function()
                local input = lib.inputDialog(it.label, {
                    { type = 'number', label = 'Сколько', default = 1, min = 1, max = Config.MaxPerBuy, required = true },
                })
                if not input then return end
                local ok, msg = lib.callback.await('kavkaz_places:buy', false, place.id, it.name, input[1])
                notify(store.title, msg, ok and 'success' or 'error')
            end,
        }
    end
    lib.registerContext({ id = 'kavkaz_places_store', title = store.title, options = options })
    lib.showContext('kavkaz_places_store')
end

local function openPost(place)
    lib.registerContext({
        id = 'kavkaz_places_post', title = place.label,
        options = {
            { title = 'Оплатить штрафы', description = 'список неоплаченных штрафов', icon = 'file-invoice',
              onSelect = function() ExecuteCommand('fines') end },
            { title = 'Перевести деньги', description = ('с карты на карту, комиссия %d%%'):format(math.floor(Config.Post.fee * 100)), icon = 'money-bill-transfer',
              onSelect = function()
                  local input = lib.inputDialog('Перевод', {
                      { type = 'number', label = 'ID получателя', min = 1, required = true },
                      { type = 'number', label = 'Сумма, ₽', min = Config.Post.min, max = Config.Post.max, required = true },
                  })
                  if not input then return end
                  local ok, msg = lib.callback.await('kavkaz_places:transfer', false, place.id, input[1], input[2])
                  notify(place.label, msg, ok and 'success' or 'error')
              end },
        },
    })
    lib.showContext('kavkaz_places_post')
end

local OPEN = {
    detailing = { label = 'Детейлинг', icon = 'fa-solid fa-spray-can-sparkles', fn = openDetailing },
    repair    = { label = 'Ремонт и шиномонтаж', icon = 'fa-solid fa-wrench', fn = doRepair },
    store     = { label = 'Купить', icon = 'fa-solid fa-prescription-bottle-medical', fn = openStore },
    post      = { label = 'Почта', icon = 'fa-solid fa-envelope', fn = openPost },
}

---------------------------------------------------------------------------
-- точки
---------------------------------------------------------------------------
CreateThread(function()
    for i, c in ipairs(Config.Clerks) do
        local key = ('clerk_%s_%d'):format(c.shop, c.id)
        lib.points.new({
            coords = c.coords.xyz, distance = Config.SpawnDistance,
            onEnter = function()
                CreateThread(function()
                    spawnPed(key, c.model, c.coords, true, {
                        { name = 'kavkaz_places_shop', label = 'Магазин', icon = 'fa-solid fa-basket-shopping', distance = 2.5,
                          onSelect = function() exports.ox_inventory:openInventory('shop', { type = c.shop, id = c.id }) end },
                    })
                end)
            end,
            onExit = function() despawnPed(key) end,
        })
        if i % 10 == 0 then Wait(0) end
    end

    for _, place in ipairs(Config.Places) do
        local c = place.ped.coords
        local open = OPEN[place.kind]
        if open then
            if place.blip then
                local b = AddBlipForCoord(c.x, c.y, c.z)
                SetBlipSprite(b, place.blip.sprite)
                SetBlipColour(b, place.blip.color)
                SetBlipScale(b, 0.7)
                SetBlipAsShortRange(b, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(Config.BlipLabels[place.kind] or place.label)
                EndTextCommandSetBlipName(b)
                blips[#blips + 1] = b
            end
            local vehicleKind = place.kind == 'detailing' or place.kind == 'repair'
            lib.points.new({
                coords = c.xyz, distance = Config.SpawnDistance,
                onEnter = function()
                    -- работник ходит к машине — не замораживаем; продавец стоит на месте
                    CreateThread(function()
                        spawnPed(place.id, place.ped.model, c, not vehicleKind, {
                            { name = 'kavkaz_places_' .. place.kind, label = open.label, icon = open.icon,
                              distance = vehicleKind and 6.0 or 2.5,
                              onSelect = function() open.fn(place) end },
                        })
                    end)
                end,
                onExit = function() despawnPed(place.id) end,
            })
        end
    end
end)

-- детейлинг и ремонт без выхода из машины: подсказка и клавиша E, когда за рулём рядом с мастером
CreateThread(function()
    local shown
    while true do
        local sleep = 1000
        local me = PlayerPedId()
        local veh = GetVehiclePedIsIn(me, false)
        local near
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == me then
            local pos = GetEntityCoords(veh)
            for _, place in ipairs(Config.Places) do
                if (place.kind == 'detailing' or place.kind == 'repair') then
                    local c = place.ped.coords
                    local d = #(pos - vec3(c.x, c.y, c.z))
                    if d < 40.0 then sleep = 250 end
                    if d <= place.radius then near = place break end
                end
            end
        end
        if near and not busy and GetEntitySpeed(veh) < 1.0 then
            sleep = 0
            if shown ~= near.id then
                lib.showTextUI(('[E] %s — %s'):format(OPEN[near.kind].label, near.label))
                shown = near.id
            end
            if IsControlJustReleased(0, 38) then
                lib.hideTextUI()
                shown = nil
                OPEN[near.kind].fn(near)
            end
        elseif shown then
            lib.hideTextUI()
            shown = nil
        end
        Wait(sleep)
    end
end)

-- полировка: пока не истекла, машина под игроком не пачкается
CreateThread(function()
    while true do
        Wait(15000)
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        if veh ~= 0 and NetworkHasControlOfEntity(veh) then
            local untilT = Entity(veh).state.kvPolishUntil
            if untilT and GetCloudTimeAsInt() < untilT and GetVehicleDirtLevel(veh) > 0.0 then
                SetVehicleDirtLevel(veh, 0.0)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    for key in pairs(spawned) do despawnPed(key) end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    lib.hideTextUI()
end)
