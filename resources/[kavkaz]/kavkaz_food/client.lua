-- KAVKAZ RP: забегаловки — продавцы, прилавки, метки, меню

local spawned = {} -- id -> { ped = , props = {} }

local function groundZ(c)
    local found, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + 2.0, false)
    if found and math.abs(z - c.z) < 6.0 then return z end
    return c.z - 1.0
end

local function rotate(offset, heading)
    local r = math.rad(heading)
    local cs, sn = math.cos(r), math.sin(r)
    return vec3(offset.x * cs - offset.y * sn, offset.x * sn + offset.y * cs, offset.z)
end

local function openMenu(place)
    local options = {}
    local names = {}
    for item in pairs(place.menu) do names[#names + 1] = item end
    table.sort(names, function(a, b) return place.menu[a] < place.menu[b] end)
    for _, item in ipairs(names) do
        local info = Config.Items[item] or { label = item }
        local price = place.menu[item]
        options[#options + 1] = {
            title = info.label,
            description = (info.desc and (info.desc .. ' · ') or '') .. price .. ' ₽',
            icon = 'utensils',
            onSelect = function()
                local input = lib.inputDialog(info.label .. ' — ' .. price .. ' ₽ за штуку', {
                    { type = 'slider', label = 'Сколько', default = 1, min = 1, max = Config.MaxPerBuy, step = 1 },
                }, { allowCancel = true })
                if not input then return end
                local count = tonumber(input[1]) or 1
                local ok, msg = lib.callback.await('kavkaz_food:buy', false, place.id, item, count)
                lib.notify({
                    title = place.label,
                    description = msg or (ok and 'приятного аппетита' or 'не получилось'),
                    type = ok and 'success' or 'error',
                })
            end,
        }
    end
    lib.registerContext({ id = 'kavkaz_food_' .. place.id, title = place.label, options = options })
    lib.showContext('kavkaz_food_' .. place.id)
end

local function spawn(place)
    local c = place.seller.coords
    local z = groundZ(c)
    local data = { props = {} }

    local model = joaat(place.seller.model)
    if IsModelInCdimage(model) then
        lib.requestModel(model)
        local ped = CreatePed(4, model, c.x, c.y, z, c.w, false, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
        SetModelAsNoLongerNeeded(model)
        exports.ox_target:addLocalEntity(ped, {
            { name = 'kavkaz_food_' .. place.id, icon = 'fa-solid fa-utensils', label = 'Меню: ' .. place.label, distance = 2.5,
              onSelect = function() openMenu(place) end },
        })
        data.ped = ped
    end

    for _, p in ipairs(place.props or {}) do
        local pm = joaat(p.model)
        if IsModelInCdimage(pm) then
            lib.requestModel(pm)
            local o = rotate(p.offset, c.w)
            local obj = CreateObject(pm, c.x + o.x, c.y + o.y, z + o.z, false, false, false)
            SetEntityHeading(obj, c.w + (p.heading or 0.0))
            PlaceObjectOnGroundProperly(obj)
            FreezeEntityPosition(obj, true)
            SetModelAsNoLongerNeeded(pm)
            data.props[#data.props + 1] = obj
        end
    end
    spawned[place.id] = data
end

local function despawn(id)
    local d = spawned[id]
    if not d then return end
    if d.ped then
        exports.ox_target:removeLocalEntity(d.ped, 'kavkaz_food_' .. id)
        DeleteEntity(d.ped)
    end
    for _, o in ipairs(d.props) do DeleteEntity(o) end
    spawned[id] = nil
end

local blips = {}
CreateThread(function()
    for _, place in ipairs(Config.Places) do
        local c = place.seller.coords
        if place.blip then
            local b = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(b, place.blip.sprite)
            SetBlipColour(b, place.blip.color)
            SetBlipScale(b, 0.7)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(place.label)
            EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
        lib.points.new({
            coords = c.xyz, distance = 80.0,
            onEnter = function() if not spawned[place.id] then spawn(place) end end,
            onExit = function() despawn(place.id) end,
        })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(spawned) do despawn(id) end
    for _, b in ipairs(blips) do RemoveBlip(b) end
end)
