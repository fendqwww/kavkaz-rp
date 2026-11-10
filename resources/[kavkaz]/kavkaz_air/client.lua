-- KAVKAZ RP — пневмоподвеска, клиент: кнопки водителя, плавная посадка у всех машин рядом, звук пневмы.

local myVeh, hasAir, level = 0, false, 0
local targets = {}  -- машина -> нужная высота (м)
local current = {}  -- машина -> текущая высота (м)

local function notify(text, kind) lib.notify({ title = Config.Label, description = text, type = kind or 'inform' }) end

-- водитель: стоит ли подвеска на моей машине
CreateThread(function()
    while true do
        local veh = cache.vehicle or 0
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) ~= cache.ped then veh = 0 end
        if veh ~= myVeh then
            myVeh, hasAir = veh, false
            if veh ~= 0 and NetworkGetEntityIsNetworked(veh) then
                hasAir = lib.callback.await('kavkaz_air:has', false, VehToNet(veh)) == true
                level = Entity(veh).state.kv_air or 0
                if hasAir then notify(('%s: %s — выше, %s — ниже'):format(Config.Label, Config.Keys.up, Config.Keys.down)) end
            end
        end
        Wait(500)
    end
end)

RegisterNetEvent('kavkaz_air:client:installed', function(net)
    if myVeh ~= 0 and VehToNet(myVeh) == net then hasAir, level = true, 0 end
end)

local function sound(veh, up)
    -- штатные звуки гидравлики лоурайдеров GTA (если банк не загрузился — просто без звука)
    RequestScriptAudioBank('DLC_LOW2/LOWRIDER_HYDRAULICS', false)
    PlaySoundFromEntity(-1, up and 'Hydraulics_Up' or 'Hydraulics_Down', veh, 'Lowrider_Super_Mod_Garage_Sounds', false, 0)
end

local function change(step)
    if myVeh == 0 or not hasAir or IsPauseMenuActive() or IsNuiFocused() then return end
    local new = math.max(Config.Min, math.min(Config.Max, level + step))
    if new == level then return end
    if new > Config.MaxDriveLevel and GetEntitySpeed(myVeh) * 3.6 > Config.MaxDriveSpeed then
        return notify('на ходу ниже нельзя — сбавь скорость', 'error')
    end
    level = new
    TriggerServerEvent('kavkaz_air:server:level', VehToNet(myVeh), level)
end

lib.addKeybind({ name = 'kavkaz_air_up', description = 'Пневмоподвеска: выше', defaultKey = Config.Keys.up, onPressed = function() change(-1) end })
lib.addKeybind({ name = 'kavkaz_air_down', description = 'Пневмоподвеска: ниже', defaultKey = Config.Keys.down, onPressed = function() change(1) end })

-- уровень машины поменялся (у любого игрока рядом) — плавно садим/поднимаем
AddStateBagChangeHandler('kv_air', nil, function(bagName, _, value)
    local veh = GetEntityFromStateBagName(bagName)
    if veh == 0 then return end
    local h = Config.Levels[tonumber(value) or 0] or 0.0
    if targets[veh] and math.abs(targets[veh] - h) > 0.001 then sound(veh, h < targets[veh]) end
    targets[veh] = h
end)

CreateThread(function()
    local lastT = GetGameTimer()
    while true do
        local now = GetGameTimer()
        local dt = (now - lastT) / 1000
        lastT = now
        local moving = false
        for veh, h in pairs(targets) do
            if not DoesEntityExist(veh) then
                targets[veh], current[veh] = nil, nil
            else
                local c = current[veh] or GetVehicleSuspensionHeight(veh)
                if math.abs(c - h) > 0.0005 then
                    moving = true
                    local step = Config.Speed * dt
                    c = c + math.max(-step, math.min(step, h - c))
                end
                current[veh] = c
                SetVehicleSuspensionHeight(veh, c)
            end
        end
        Wait(moving and 0 or 400)
    end
end)

-- машины, которые приехали в зону видимости уже опущенными
CreateThread(function()
    while true do
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if not targets[veh] then
                local lv = Entity(veh).state.kv_air
                if lv and lv ~= 0 then targets[veh] = Config.Levels[lv] or 0.0 end
            end
        end
        Wait(2000)
    end
end)

-- для меню гаража Бислана (kavkaz_sgu)
exports('GarageOption', function(net)
    local info = lib.callback.await('kavkaz_air:info', false, net)
    if not info or info.error then return nil end
    if info.installed then
        return { title = 'Снять пневмоподвеску', description = 'бесплатно', icon = 'arrows-up-down', onSelect = function()
            local ok, msg = lib.callback.await('kavkaz_air:remove', false, net)
            notify(ok and 'пневмоподвеска снята' or msg, ok and 'success' or 'error')
            if ok then hasAir = false end
        end }
    end
    return {
        title = ('%s — %s ₽'):format(Config.Label, lib.math.groupdigits(Config.Price, ' ')),
        description = ('машина опускается и поднимается кнопками %s / %s'):format(Config.Keys.up, Config.Keys.down),
        icon = 'arrows-up-down',
        onSelect = function()
            local a = lib.alertDialog({ header = Config.Label, content = ('Поставить за %s ₽? Сначала наличные, потом карта.'):format(lib.math.groupdigits(Config.Price, ' ')),
                centered = true, cancel = true, labels = { confirm = 'Ставь', cancel = 'Не надо' } })
            if a ~= 'confirm' then return end
            local ok, msg = lib.callback.await('kavkaz_air:buy', false, net)
            notify(ok and ('поставлено. %s — выше, %s — ниже'):format(Config.Keys.up, Config.Keys.down) or msg, ok and 'success' or 'error')
        end,
    }
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for veh in pairs(targets) do if DoesEntityExist(veh) then SetVehicleSuspensionHeight(veh, 0.0) end end
end)
