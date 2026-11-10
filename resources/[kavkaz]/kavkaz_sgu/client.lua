-- KAVKAZ RP — СГУ «Хазард 7007», клиент: клавиши водителя, звук рядом стоящих машин, стробоскоп, гараж Бислана, проверка ДПС.

local myVeh, myModel = 0, nil
local toneIndex = 1
local active = {}   -- netId -> мелодия (машины рядом с включённым СГУ)
local strobing = {} -- машины со стробоскопом (мигает тот, кто ими управляет)

-- громкость СГУ на этом ПК (меню игрока → настройки), 0–100
local volume = GetResourceKvpInt('volume_set') == 1 and GetResourceKvpInt('volume') or 100
CreateThread(function() Wait(1000) SendNUIMessage({ action = 'volume', value = volume / 100 }) end)
exports('GetVolume', function() return volume end)
exports('SetVolume', function(v)
    volume = math.max(0, math.min(100, math.floor(v)))
    SetResourceKvpInt('volume', volume)
    SetResourceKvpInt('volume_set', 1)
    SendNUIMessage({ action = 'volume', value = volume / 100 })
end)

local function notify(text, kind) lib.notify({ title = 'СГУ', description = text, type = kind or 'inform' }) end
local function model() return myModel and Config.Models[myModel] end

-- громкость и панорама по расстоянию и направлению камеры
local function mix(veh, range)
    local cam = GetFinalRenderedCamCoord()
    local pos = GetEntityCoords(veh)
    local dist = #(pos - cam)
    if dist >= range then return 0.0, 0.0 end
    local vol = (1.0 - dist / range) ^ 2
    if veh == myVeh then vol = math.min(vol, 0.55) end -- в салоне не оглушает
    local rot = GetFinalRenderedCamRot(2)
    local heading = math.rad(rot.z)
    local dir = pos - cam
    local right = vector2(math.cos(heading), math.sin(heading)) -- вправо от взгляда
    local len = math.max(0.001, math.sqrt(dir.x * dir.x + dir.y * dir.y))
    local pan = (dir.x * right.x + dir.y * right.y) / len
    return vol, math.max(-0.85, math.min(0.85, pan))
end

---------------------------------------------------------------------------
-- водитель: кто я и что у меня стоит
---------------------------------------------------------------------------

CreateThread(function()
    local hinted = {}
    while true do
        local veh = cache.vehicle or 0
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) ~= cache.ped then veh = 0 end
        if veh ~= myVeh then
            if myVeh ~= 0 and DoesEntityExist(myVeh) then
                if Entity(myVeh).state.sgu_tone then TriggerServerEvent('kavkaz_sgu:server:tone', VehToNet(myVeh), false) end
                if Entity(myVeh).state.sgu_strobe then TriggerServerEvent('kavkaz_sgu:server:strobe', VehToNet(myVeh), false) end
            end
            myVeh, myModel, toneIndex = veh, nil, 1
            if veh ~= 0 and NetworkGetEntityIsNetworked(veh) then
                myModel = lib.callback.await('kavkaz_sgu:get', false, VehToNet(veh))
                if myModel and not hinted[veh] then
                    hinted[veh] = true
                    local m = Config.Models[myModel]
                    notify(('%s: %s — кряк, %s — мелодия, %s — сменить%s'):format(m.label, Config.Keys.quack, Config.Keys.tone,
                        Config.Keys.next, m.strobe and (', ' .. Config.Keys.strobe .. ' — стробоскоп') or ''))
                end
            end
        end
        Wait(500)
    end
end)

-- сервер сообщил новую модель (купил у Бислана, выдал админ)
RegisterNetEvent('kavkaz_sgu:client:model', function(net, model)
    if myVeh ~= 0 and NetworkGetEntityIsNetworked(myVeh) and VehToNet(myVeh) == net then
        myModel, toneIndex = model, 1
    end
end)

-- панель прибора на экране, пока сидишь за рулём машины с СГУ
CreateThread(function()
    local lastKey
    while true do
        local data
        if myModel and myVeh ~= 0 and not IsPauseMenuActive() and LocalPlayer.state.isLoggedIn then
            local m = Config.Models[myModel]
            local st = Entity(myVeh).state
            local names = {}
            for i, t in ipairs(m.tones) do names[i] = Config.Tones[t] end
            data = { show = true, label = m.label, service = myModel == 'service', tones = names, index = toneIndex,
                on = st.sgu_tone and true or false, strobe = st.sgu_strobe and true or false, canStrobe = m.strobe and true or false,
                keys = Config.Keys }
        else
            data = { show = false }
        end
        local key = json.encode(data)
        if key ~= lastKey then
            lastKey = key
            data.action = 'panel'
            SendNUIMessage(data)
        end
        Wait(150)
    end
end)

local function canUse()
    return myVeh ~= 0 and myModel ~= nil and not IsPauseMenuActive() and not IsNuiFocused()
end

lib.addKeybind({ name = 'kavkaz_sgu_quack', description = 'СГУ: кряк', defaultKey = Config.Keys.quack, onPressed = function()
    if canUse() then
        TriggerServerEvent('kavkaz_sgu:server:quack', VehToNet(myVeh))
        SendNUIMessage({ action = 'flash', which = 'quack' })
    end
end })

lib.addKeybind({ name = 'kavkaz_sgu_tone', description = 'СГУ: мелодия вкл/выкл', defaultKey = Config.Keys.tone, onPressed = function()
    if not canUse() then return end
    local on = Entity(myVeh).state.sgu_tone
    TriggerServerEvent('kavkaz_sgu:server:tone', VehToNet(myVeh), (not on) and model().tones[toneIndex] or false)
end })

lib.addKeybind({ name = 'kavkaz_sgu_next', description = 'СГУ: следующая мелодия', defaultKey = Config.Keys.next, onPressed = function()
    if not canUse() then return end
    local tones = model().tones
    toneIndex = toneIndex % #tones + 1
    SendNUIMessage({ action = 'flash', which = 'next' })
    local tone = tones[toneIndex]
    notify(('мелодия %d/%d: %s'):format(toneIndex, #tones, Config.Tones[tone]))
    if Entity(myVeh).state.sgu_tone then TriggerServerEvent('kavkaz_sgu:server:tone', VehToNet(myVeh), tone) end
end })

lib.addKeybind({ name = 'kavkaz_sgu_strobe', description = 'СГУ: стробоскоп', defaultKey = Config.Keys.strobe, onPressed = function()
    if not canUse() or not model().strobe then return end
    TriggerServerEvent('kavkaz_sgu:server:strobe', VehToNet(myVeh), not Entity(myVeh).state.sgu_strobe)
end })

---------------------------------------------------------------------------
-- звук
---------------------------------------------------------------------------

RegisterNetEvent('kavkaz_sgu:client:quack', function(net)
    if not NetworkDoesEntityExistWithNetworkId(net) then return end
    local veh = NetToVeh(net)
    if veh == 0 then return end
    local vol, pan = mix(veh, Config.Range.quack)
    if vol > 0.01 then SendNUIMessage({ action = 'quack', vol = vol, pan = pan }) end
end)

AddStateBagChangeHandler('sgu_tone', nil, function(bagName, _, value)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 then return end
    local net = NetworkGetNetworkIdFromEntity(entity)
    if value then
        active[net] = value
    elseif active[net] then
        active[net] = nil
        SendNUIMessage({ action = 'stop', id = net })
    end
end)

AddStateBagChangeHandler('sgu_strobe', nil, function(bagName, _, value)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 then return end
    strobing[entity] = value and true or nil
end)

-- громкость мелодий рядом стоящих машин
CreateThread(function()
    while true do
        local any = false
        for net, tone in pairs(active) do
            any = true
            local veh = NetworkDoesEntityExistWithNetworkId(net) and NetToVeh(net) or 0
            if veh == 0 or not DoesEntityExist(veh) then
                active[net] = nil
                SendNUIMessage({ action = 'stop', id = net })
            else
                local vol, pan = mix(veh, Config.Range.loop)
                SendNUIMessage({ action = 'loop', id = net, tone = tone, vol = vol, pan = pan })
            end
        end
        Wait(any and 120 or 500)
    end
end)

-- стробоскоп: фарами мигает тот, кто управляет машиной (так видят все)
CreateThread(function()
    local phase = false
    while true do
        local busy = false
        for veh in pairs(strobing) do
            if DoesEntityExist(veh) and NetworkHasControlOfEntity(veh) then
                busy = true
                SetVehicleLights(veh, phase and 2 or 1)
                SetVehicleFullbeam(veh, phase)
            elseif not DoesEntityExist(veh) then
                strobing[veh] = nil
            end
        end
        if not busy then
            for veh in pairs(strobing) do if DoesEntityExist(veh) and NetworkHasControlOfEntity(veh) then SetVehicleLights(veh, 0) end end
        end
        phase = not phase
        Wait(busy and 110 or 400)
    end
end)
AddStateBagChangeHandler('sgu_strobe', nil, function(bagName, _, value)
    if value then return end
    local entity = GetEntityFromStateBagName(bagName)
    if entity ~= 0 and NetworkHasControlOfEntity(entity) then
        SetVehicleLights(entity, 0)
        SetVehicleFullbeam(entity, false)
    end
end)

-- штатные американские сирены у машин экстренных служб глушим: звук даёт наше служебное СГУ (J)
CreateThread(function()
    while true do
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if GetVehicleClass(veh) == 18 then SetVehicleHasMutedSirens(veh, true) end
        end
        Wait(2000)
    end
end)

---------------------------------------------------------------------------
-- гараж Бислана
---------------------------------------------------------------------------

local function openGarage()
    if myVeh == 0 then return notify('сядь за руль своей машины', 'error') end
    local net = VehToNet(myVeh)
    local info = lib.callback.await('kavkaz_sgu:garageInfo', false, net)
    if not info or info.error then return notify(info and info.error or 'не получилось', 'error') end
    local options = {
        { title = 'Бислан «Крякалка»', description = 'Брат, только ДПС не говори, что от меня. Снимут — штраф и снятие.', readOnly = true, icon = 'user' },
    }
    for _, id in ipairs(Config.ShopOrder) do
        local m = Config.Models[id]
        local names = {}
        for _, t in ipairs(m.tones) do names[#names + 1] = Config.Tones[t] end
        options[#options + 1] = {
            title = ('%s — %s ₽'):format(m.label, lib.math.groupdigits(m.price, ' ')),
            description = (info.current == id and 'стоит на машине · ' or '') .. 'кряк + ' .. table.concat(names, ', ') .. (m.strobe and ' · стробоскоп' or ''),
            icon = 'volume-high',
            disabled = info.current == id,
            onSelect = function()
                local ok = lib.alertDialog({ header = m.label, content = ('Поставить за %s ₽? Деньги — сначала наличные, потом карта.'):format(lib.math.groupdigits(m.price, ' ')),
                    centered = true, cancel = true, labels = { confirm = 'Ставь', cancel = 'Не надо' } })
                if ok ~= 'confirm' then return end
                local done, msg = lib.callback.await('kavkaz_sgu:buy', false, net, id)
                notify(done and ('поставлено: ' .. msg) or msg, done and 'success' or 'error')
                if done then myModel = id toneIndex = 1 end
            end,
        }
    end
    if info.current then
        options[#options + 1] = { title = 'Снять СГУ', description = 'бесплатно', icon = 'xmark', onSelect = function()
            local done, msg = lib.callback.await('kavkaz_sgu:removeOwn', false, net)
            notify(done and 'СГУ снято' or msg, done and 'success' or 'error')
            if done then myModel = nil end
        end }
    end
    lib.registerContext({ id = 'kavkaz_sgu_garage', title = 'Гараж Бислана: СГУ «Хазард 7007»', options = options })
    lib.showContext('kavkaz_sgu_garage')
end

local garageText = false
lib.points.new({
    coords = Config.Garage.coords,
    distance = Config.Garage.radius,
    nearby = function()
        local show = myVeh ~= 0
        if show ~= garageText then
            garageText = show
            if show then lib.showTextUI('[E] Гараж Бислана: СГУ «Хазард 7007»') else lib.hideTextUI() end
        end
        if show and IsControlJustReleased(0, 38) then openGarage() end
    end,
    onExit = function()
        if garageText then garageText = false lib.hideTextUI() end
    end,
})

---------------------------------------------------------------------------
-- ДПС: проверить и изъять (Alt на машине)
---------------------------------------------------------------------------

exports.ox_target:addGlobalVehicle({
    {
        name = 'kavkaz_sgu_check', icon = 'fa-solid fa-bullhorn', label = 'Проверить СГУ', groups = Config.PoliceJobs, distance = 3.0,
        onSelect = function(data)
            local r = lib.callback.await('kavkaz_sgu:check', false, VehToNet(data.entity))
            if not r then return notify('не получилось: подойди ближе и заступи на смену', 'error') end
            if not r.model then return notify(('%s: СГУ не найдено'):format(r.plate), 'success') end
            local ok = lib.alertDialog({ header = 'Найдено СГУ', content = ('%s\nномер %s\n\nИзъять? Штраф выпиши командой /fine ID sgu.'):format(r.label, r.plate),
                centered = true, cancel = true, labels = { confirm = 'Изъять', cancel = 'Оставить' } })
            if ok == 'confirm' then
                local done = lib.callback.await('kavkaz_sgu:seize', false, VehToNet(data.entity))
                notify(done and 'СГУ изъято' or 'не получилось', done and 'success' or 'error')
            end
        end,
    },
})

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    lib.hideTextUI()
end)
