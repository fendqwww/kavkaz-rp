-- названия районов, метки, входы в здания, скрытие объектов

-- русские названия зон: заменяем тексты, которые GTA показывает на карте и в HUD
CreateThread(function()
    for code, name in pairs(Config.Zones) do
        AddTextEntry(code, name)
    end
end)

-- метки
local blips = {}
CreateThread(function()
    for _, b in ipairs(Config.Blips) do
        local blip = AddBlipForCoord(b.coords.x, b.coords.y, b.coords.z)
        SetBlipSprite(blip, b.sprite or 1)
        SetBlipColour(blip, b.color or 0)
        SetBlipScale(blip, b.scale or 0.75)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(b.label)
        EndTextCommandSetBlipName(blip)
        blips[#blips + 1] = blip
    end
end)

-- скрытие стандартных объектов
local function applyHides()
    for _, h in ipairs(Config.Hide) do
        local model = type(h.model) == 'string' and joaat(h.model) or h.model
        CreateModelHideExcludingScriptObjects(h.coords.x, h.coords.y, h.coords.z, h.radius or 5.0, model, true)
    end
end
CreateThread(applyHides)

-- входы в здания
local function teleport(to)
    DoScreenFadeOut(300)
    Wait(350)
    RequestCollisionAtCoord(to.x, to.y, to.z)
    SetEntityCoords(cache.ped, to.x, to.y, to.z - 1.0, false, false, false, false)
    SetEntityHeading(cache.ped, to.w)
    local deadline = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(cache.ped) and GetGameTimer() < deadline do Wait(50) end
    DoScreenFadeIn(400)
end

local function use(e, toInside)
    if e.jobs then
        local ok, err = lib.callback.await('kavkaz_map:canEnter', false, e.id)
        if not ok then return lib.notify({ description = err or 'вход только для сотрудников', type = 'error' }) end
    end
    teleport(toInside and e.inside or e.outside)
end

CreateThread(function()
    for _, e in ipairs(Config.Entrances) do
        exports.ox_target:addSphereZone({
            coords = e.outside.xyz, radius = 1.6, debug = false,
            options = { { name = 'kavkaz_in_' .. e.id, icon = 'fa-solid fa-door-open', label = e.label, onSelect = function() use(e, true) end } },
        })
        exports.ox_target:addSphereZone({
            coords = e.inside.xyz, radius = 1.6, debug = false,
            options = { { name = 'kavkaz_out_' .. e.id, icon = 'fa-solid fa-door-closed', label = 'Выйти на улицу', onSelect = function() teleport(e.outside) end } },
        })
    end
end)

-- /mypos — текущие координаты (для конфига и для Claude): печатает и копирует в буфер обмена
RegisterCommand('mypos', function()
    local c, h = GetEntityCoords(cache.ped), GetEntityHeading(cache.ped)
    local text = ('vec4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, c.z, h)
    lib.setClipboard(text)
    print(text)
    lib.notify({ title = 'Координаты скопированы', description = text .. '\nзона: ' .. GetNameOfZone(c.x, c.y, c.z), type = 'inform', duration = 8000 })
end, false)
TriggerEvent('chat:addSuggestion', '/mypos', 'Скопировать свои координаты (для конфига карты)')

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    for _, h in ipairs(Config.Hide) do
        local model = type(h.model) == 'string' and joaat(h.model) or h.model
        RemoveModelHide(h.coords.x, h.coords.y, h.coords.z, h.radius or 5.0, model, false)
    end
end)
