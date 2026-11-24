-- KAVKAZ RP: силовики — смена, служебная машина, пульт лидера, объявления режимов

local function startOrEnd(org)
    local r = lib.callback.await('kavkaz_law:duty', false, org)
    if not r then return end
    if r.error then Law.notify(r.error, 'error') return end
    if r.started then
        local o = Config.Orgs[r.org]
        Law.notify(('вы на смене: %s, %s.\n%s — остановить машину (в машине — впереди, пешком — на которую смотрите), ALT у двери — проверка%s')
            :format(o.full, o.ranks[r.rank], Config.ActionKey, r.leader and ('. %s — пульт лидера'):format(Config.PanelKey) or ''), 'success', o.label)
    end
    -- конец смены: итог приходит событием kavkaz_law:client:dutyEnded
end

RegisterNetEvent('kavkaz_law:client:dutyEnded', function(summary)
    if summary then
        CreateThread(function() lib.alertDialog({ header = 'Итог смены', content = summary, centered = true, cancel = false }) end)
    end
end)

local function headingAt(pos)
    local ok, _, h = GetClosestVehicleNodeWithHeading(pos.x, pos.y, pos.z, 1, 3.0, 0)
    return ok and h or 0.0
end

local carBusy = false
local function requestCar()
    local d = Law.duty()
    if not d or carBusy then return end
    carBusy = true
    local org = Config.Orgs[d.org]
    local model = Law.firstModel(org.cars)
    if not model then carBusy = false Law.notify('служебных машин нет на сервере', 'error') return end
    local p = GetEntityCoords(PlayerPedId())
    local spot
    for n = 1, 14 do
        local ok, pos = GetNthClosestVehicleNode(p.x, p.y, p.z, n, 0, 3.0, 0.0)
        if ok and #(pos - p) < 70.0 and not IsAnyVehicleNearPoint(pos.x, pos.y, pos.z, 3.5) then spot = pos break end
    end
    if not spot then carBusy = false Law.notify('рядом нет свободного места у дороги', 'error') return end
    local r = lib.callback.await('kavkaz_law:car', false, model, spot.x, spot.y, spot.z, headingAt(spot))
    if not r or r.error then carBusy = false Law.notify(r and r.error or 'нет ответа', 'error') return end
    local untilT = GetGameTimer() + 8000
    while not NetworkDoesNetworkIdExist(r.netId) and GetGameTimer() < untilT do Wait(100) end
    local veh = NetworkDoesNetworkIdExist(r.netId) and NetToVeh(r.netId) or 0
    if veh ~= 0 and Law.control(veh, 1500) then
        if r.color then SetVehicleColours(veh, r.color, r.color) end
        SetVehicleNumberPlateTextIndex(veh, r.plateIndex or 0)
        SetVehicleDirtLevel(veh, 0.0)
        SetVehicleEngineOn(veh, false, true, false)
    end
    if veh ~= 0 then
        local b = AddBlipForEntity(veh)
        SetBlipSprite(b, 56)
        SetBlipColour(b, 38)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Служебная машина')
        EndTextCommandSetBlipName(b)
        SetTimeout(60000, function() if DoesBlipExist(b) then RemoveBlip(b) end end)
    end
    Law.notify(('служебная машина подана, госномер %s'):format(r.plate or ''), 'success')
    carBusy = false
end

-- опции смены у NPC поста и у отдела
local function dutyOptions(orgs)
    local opts = {}
    for _, org in ipairs(orgs) do
        local o = Config.Orgs[org]
        opts[#opts + 1] = { name = 'kvlaw_duty_' .. org, icon = 'fa-solid fa-id-badge', label = ('Заступить на смену (%s)'):format(o.label), distance = 2.5,
            canInteract = function() return not Law.duty() end, onSelect = function() startOrEnd(org) end }
    end
    opts[#opts + 1] = { name = 'kvlaw_duty_end', icon = 'fa-solid fa-right-from-bracket', label = 'Закончить смену', distance = 2.5,
        canInteract = function() return Law.duty() ~= nil end, onSelect = function() startOrEnd(Law.org()) end }
    opts[#opts + 1] = { name = 'kvlaw_duty_car', icon = 'fa-solid fa-car', label = 'Служебная машина', distance = 2.5,
        canInteract = function() return Law.duty() ~= nil end, onSelect = requestCar }
    opts[#opts + 1] = { name = 'kvlaw_duty_panel', icon = 'fa-solid fa-sliders', label = 'Пульт лидера', distance = 2.5,
        canInteract = function() local d = Law.duty() return d and d.leader end, onSelect = function() Law.panel() end }
    return opts
end

function Law.addPostTargets(ped, def, org)
    local orgs = (org == 'fsb') and { 'fsb' } or (org == 'mixed') and { 'dps', 'fsb' } or { 'dps' }
    exports.ox_target:addLocalEntity(ped, dutyOptions(orgs))
end

local zones = {}
CreateThread(function()
    for id, o in pairs(Config.Orgs) do
        zones[#zones + 1] = exports.ox_target:addSphereZone({
            coords = o.station.xyz, radius = 2.2, debug = Config.Debug, options = dutyOptions({ id }),
        })
        local b = AddBlipForCoord(o.station.x, o.station.y, o.station.z)
        SetBlipSprite(b, id == 'fsb' and 487 or 60)
        SetBlipColour(b, id == 'fsb' and 40 or 38)
        SetBlipScale(b, 0.8)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(o.stationLabel)
        EndTextCommandSetBlipName(b)
    end
end)

---------------------------------------------------------------------------
-- пульт лидера
---------------------------------------------------------------------------
local function waypoint()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return nil end
    local c = GetBlipInfoIdCoord(blip)
    local untilT = GetGameTimer() + 4000
    while not RequestPathsPreferAccurateBoundingstruct(c.x - 100.0, c.y - 100.0, c.x + 100.0, c.y + 100.0) and GetGameTimer() < untilT do Wait(100) end
    local ok, node = GetClosestVehicleNode(c.x, c.y, 50.0, 0, 3.0, 0.0)
    if ok then return node end
    return nil
end

local function call(name, ...)
    local r = lib.callback.await(name, false, ...)
    if not r then Law.notify('нет ответа сервера', 'error') return false end
    if r.error then Law.notify(r.error, 'error') return false end
    return true
end

local function postsMenu()
    local defs, _, staffing = Law.postList()
    local options = {}
    local ids = {}
    for id in pairs(defs) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local def = defs[id]
        if not def.temp then
            local org = staffing(def)
            local now = org == 'fsb' and 'ФСБ' or org == 'mixed' and 'ДПС + ФСБ' or org == 'dps' and 'ДПС' or 'пусто'
            local function set(v) return function() if call('kavkaz_law:post', id, v) then Law.notify(('%s: %s'):format(def.label, v == 'off' and 'снят' or v == 'auto' and 'по режиму' or 'выставлен'), 'success') end end end
            lib.registerContext({ id = 'kvlaw_post_' .. id, title = def.label, menu = 'kvlaw_posts', options = {
                { title = 'ДПС', icon = 'car', onSelect = set('dps') },
                { title = 'ФСБ', icon = 'user-secret', onSelect = set('fsb') },
                { title = 'ДПС и ФСБ', icon = 'users', onSelect = set('mixed') },
                { title = 'Снять пост', icon = 'ban', onSelect = set('off') },
                { title = 'Как в режиме города', icon = 'rotate', onSelect = set('auto') },
            } })
            options[#options + 1] = { title = def.label, description = 'сейчас: ' .. now, icon = def.gate and 'road-barrier' or 'building-shield', menu = 'kvlaw_post_' .. id }
        end
    end
    lib.registerContext({ id = 'kvlaw_posts', title = 'Посты', menu = 'kvlaw_panel', options = options })
    lib.showContext('kvlaw_posts')
end

function Law.panel()
    if not lib.callback.await('kavkaz_law:isLeader', false) then
        Law.notify(('пульт — у лидеров: %s и выше'):format(Config.Orgs.dps.ranks[Config.LeaderRank]:lower()), 'error')
        return
    end
    local m = GlobalState.kvLawMode or {}
    local modes = {}
    for _, id in ipairs({ 'normal', 'enhanced', 'intercept', 'kto' }) do
        local c = Config.Modes[id]
        modes[#modes + 1] = { title = Law.ucfirst(c.label), description = c.minutes > 0 and ('на %d минут'):format(c.minutes) or 'без срока',
            icon = id == m.id and 'circle-check' or 'circle', disabled = id == m.id,
            onSelect = function() if call('kavkaz_law:mode', id) then Law.notify('режим объявлен', 'success') end end }
    end
    lib.registerContext({ id = 'kvlaw_modes', title = 'Режим в городе', menu = 'kvlaw_panel', options = modes })
    local function tempPost(org)
        return function()
            local p = GetEntityCoords(PlayerPedId())
            if call('kavkaz_law:tempPost', 'add', { x = p.x, y = p.y, z = p.z, org = org }) then Law.notify('временный пост выставлен — встанет у ближайшей дороги', 'success') end
        end
    end
    lib.registerContext({ id = 'kvlaw_temp', title = 'Поставить пост здесь', menu = 'kvlaw_panel', options = {
        { title = 'Пост ДПС', icon = 'car', onSelect = tempPost('dps') },
        { title = 'Пост ФСБ', icon = 'user-secret', onSelect = tempPost('fsb') },
        { title = 'Совместный пост', icon = 'users', onSelect = tempPost('mixed') },
        { title = 'Снять все временные посты', icon = 'trash', onSelect = function() if call('kavkaz_law:tempPost', 'clear') then Law.notify('временные посты сняты', 'success') end end },
    } })
    lib.registerContext({ id = 'kvlaw_panel', title = 'Пульт лидера', options = {
        { title = 'Режим в городе', description = 'сейчас: ' .. (m.label or 'обычный режим'), icon = 'tower-broadcast', menu = 'kvlaw_modes' },
        { title = 'Посты', description = 'кто где стоит', icon = 'building-shield', onSelect = postsMenu },
        { title = 'Поставить пост здесь', icon = 'road-barrier', menu = 'kvlaw_temp' },
        { title = 'Наряд ДПС ко мне', icon = 'car-on', onSelect = function() Law.callUnit('dps', GetEntityCoords(PlayerPedId()), true) end },
        { title = 'Опергруппа ФСБ ко мне', icon = 'user-secret', onSelect = function() Law.callUnit('fsb', GetEntityCoords(PlayerPedId()), true) end },
        { title = 'Спецгруппа на метку', description = 'поставьте метку на карте', icon = 'crosshairs', onSelect = function()
            local t = waypoint()
            if not t then Law.notify('поставьте метку на карте (у дороги)', 'error') return end
            Law.callUnit('alpha', t, false)
        end },
        { title = 'Все наряды — свободны', icon = 'flag-checkered', onSelect = function() Law.dismissAll() end },
    } })
    lib.showContext('kvlaw_panel')
end

---------------------------------------------------------------------------
-- объявления режимов (всем игрокам)
---------------------------------------------------------------------------
local lastMode = nil
AddStateBagChangeHandler('kvLawMode', 'global', function(_, _, value)
    if type(value) ~= 'table' then return end
    if lastMode == nil then lastMode = value.id return end -- первое значение при входе — без объявления
    if value.id == lastMode then return end
    lastMode = value.id
    local c = Config.Modes[value.id]
    if not c then return end
    PlaySoundFrontend(-1, 'Event_Message_Purple', 'GTAO_FM_Events_Soundset', true)
    if value.id == 'normal' then
        lib.notify({ title = 'Нагорье', description = 'режим отменён, город живёт в обычном режиме', type = 'inform', duration = 9000 })
    else
        lib.notify({ title = Law.ucfirst(c.label), description = c.text .. (value.by and ('\n— %s'):format(value.by) or ''), type = 'warning', duration = 12000 })
    end
end)
CreateThread(function()
    Wait(2000)
    lastMode = (GlobalState.kvLawMode or {}).id or 'normal'
end)

---------------------------------------------------------------------------
-- клавиши и команды
---------------------------------------------------------------------------
lib.addKeybind({ name = 'kavkaz_law_action', description = 'ДПС/ФСБ: требовать остановиться / сдать задержанного', defaultKey = Config.ActionKey,
    onPressed = function() if Law.duty() then Law.actionKey() end end })
lib.addKeybind({ name = 'kavkaz_law_panel', description = 'ДПС/ФСБ: пульт лидера', defaultKey = Config.PanelKey,
    onPressed = function() Law.panel() end })

RegisterCommand('pult', function() Law.panel() end, false)
RegisterCommand('smena', function()
    local d = Law.duty()
    if d then startOrEnd(d.org) return end
    lib.registerContext({ id = 'kvlaw_smena', title = 'Смена', options = {
        { title = 'Заступить в ДПС', icon = 'car', onSelect = function() startOrEnd('dps') end },
        { title = 'Заступить в ФСБ', icon = 'user-secret', onSelect = function() startOrEnd('fsb') end },
    } })
    lib.showContext('kvlaw_smena')
end, false)
TriggerEvent('chat:addSuggestion', '/smena', 'заступить на смену ДПС/ФСБ или закончить (в отделе или на посту)')
TriggerEvent('chat:addSuggestion', '/pult', 'пульт лидера: режимы города, посты, наряды, спецгруппа')

AddEventHandler('onResourceStop', function(res)
    if res ~= Law.RES then return end
    for _, z in ipairs(zones) do pcall(function() exports.ox_target:removeZone(z) end) end
end)
