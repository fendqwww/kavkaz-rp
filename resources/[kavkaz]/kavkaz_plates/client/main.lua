-- окно МРЭО (NPC + ox_target + NUI), подтверждения сделок, пробивка номера для ДПС.

local office = Config.Office

-- русские номера на всех машинах: фоны GTA plate01…05 (vehshare) -> наши (html/tex, setup/retex/plate_textures.py).
-- символы рисует GTA, фон — наш: белый Россия, чёрный военный, синий полиция, жёлтый такси, белый без флага
CreateThread(function()
    local txd = CreateRuntimeTxd('kavkaz_plates_tex')
    CreateRuntimeTextureFromImage(txd, 'flat_n', 'html/tex/flat_n.png')
    for i = 1, 5 do
        local name = ('plate0%d'):format(i)
        CreateRuntimeTextureFromImage(txd, name, ('html/tex/%s.png'):format(name))
        AddReplaceTexture('vehshare', name, 'kavkaz_plates_tex', name)
        AddReplaceTexture('vehshare', name .. '_n', 'kavkaz_plates_tex', 'flat_n') -- без выдавленного «San Andreas»
    end
end)
local ped, blip, isOpen = nil, nil, false

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    send('close')
end

local function open()
    local data = lib.callback.await('kavkaz_plates:getData', false)
    if not data then return lib.notify({ description = 'подойди к окну МРЭО', type = 'error' }) end
    isOpen = true
    SetNuiFocus(true, true)
    send('open', data)
end

RegisterNUICallback('close', function(_, cb) close() cb('ok') end)

-- действия окна: ответ { ok = текст, data = новые данные } или { error = текст }
RegisterNUICallback('action', function(body, cb)
    local name, a = body.name, body.args or {}
    local res
    if name == 'buyRandom' then res = lib.callback.await('kavkaz_plates:buyRandom', false, a.vehicleId, a.region, a.style)
    elseif name == 'setFrame' then res = lib.callback.await('kavkaz_plates:setFrame', false, a.plate, a.frame)
    elseif name == 'pickChoice' then res = lib.callback.await('kavkaz_plates:pickChoice', false, a.index, a.vehicleId)
    elseif name == 'attach' then res = lib.callback.await('kavkaz_plates:attach', false, a.plate, a.vehicleId)
    elseif name == 'detach' then res = lib.callback.await('kavkaz_plates:detach', false, a.vehicleId)
    elseif name == 'sell' then res = lib.callback.await('kavkaz_plates:sell', false, a.plate, a.target, a.price)
    elseif name == 'choices' then
        local list = lib.callback.await('kavkaz_plates:getChoices', false, a.region)
        res = list and { list = list } or { error = 'подойди к окну МРЭО' }
    end
    cb(res or { error = 'неизвестное действие' })
end)

---------------------------------------------------------------------------
-- подтверждения (сервер спрашивает покупателя / водителя)
---------------------------------------------------------------------------

local function money(v) return lib.math.groupdigits(v, ' ') .. ' ₽' end

local function confirm(header, content)
    local done = false
    SetTimeout(30000, function() if not done then lib.closeAlertDialog() end end) -- 30 секунд на ответ
    local answer = lib.alertDialog({ header = header, content = content, centered = true, cancel = true,
        labels = { confirm = 'Согласен', cancel = 'Отказаться' } })
    done = true
    return answer == 'confirm'
end

lib.callback.register('kavkaz_plates:confirmBuy', function(d)
    if isOpen then close() end
    return confirm('Покупка номера', ('**%s** продаёт тебе номер **%s** за **%s**.\n\nДеньги спишутся с наличных или карты.')
        :format(d.seller, d.pretty, money(d.price)))
end)

lib.callback.register('kavkaz_plates:confirmIssue', function(d)
    return confirm('Регистрация номера', ('Инспектор **%s** ставит твою машину на учёт.\n\nГоспошлина: **%s**. Номер — случайный, регион 95.')
        :format(d.officer, money(d.price)))
end)

---------------------------------------------------------------------------
-- пробивка номера (ДПС / полиция)
---------------------------------------------------------------------------

local STATUS = {
    ok = '✅ на учёте',
    transit = '🟡 транзит: машина не зарегистрирована в МРЭО',
    other_car = '🚨 номер от другой машины',
    stolen_plate = '🚨 номер числится снятым — подделка или чужой номер',
    unknown = '🚨 номер не найден в базе (липовый или угнанная машина NPC)',
    service = '🔵 служебная машина организации',
}

-- какая статья kavkaz_fines подходит к результату пробивки (инспектор всё равно решает сам)
local STATUS_ARTICLE = { other_car = 'fake', stolen_plate = 'fake' }

local function driverServerId(vehicle)
    local ped = GetPedInVehicleSeat(vehicle, -1)
    if ped == 0 or not IsPedAPlayer(ped) then return nil end
    return GetPlayerServerId(NetworkGetPlayerIndexFromPed(ped))
end

local function checkVehicle(vehicle)
    local res = lib.callback.await('kavkaz_plates:check', false, NetworkGetNetworkIdFromEntity(vehicle))
    if not res then return lib.notify({ description = 'база недоступна: нужна служебная смена', type = 'error' }) end
    local lines = { ('Номер: **%s**'):format(res.pretty or res.plate), STATUS[res.status] or res.status }
    if res.owner then lines[#lines + 1] = 'Владелец: **' .. res.owner .. '**' end
    if res.fines and res.fines > 0 then lines[#lines + 1] = ('⚠ неоплаченных штрафов у владельца: **%d**'):format(res.fines) end
    if res.frameText then lines[#lines + 1] = ('Рамка: «%s»'):format(res.frameText) end
    if res.model then lines[#lines + 1] = 'Машина по базе: ' .. res.model end
    if res.registeredModel then lines[#lines + 1] = ('Номер выдан на: %s, а перед тобой — %s'):format(res.registeredModel,
        GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))) end

    -- тонировка: тауметр пока не предмет, замер встроен в пробивку (Config.Tint)
    local tint = Config.Tint[GetVehicleWindowTint(vehicle)] or { label = 'неизвестно' }
    lines[#lines + 1] = ('Тонировка: %s%s'):format(tint.label, tint.article and ' — **нарушение**' or '')

    local article = tint.article or STATUS_ARTICLE[res.status]
    local driver = article and driverServerId(vehicle)
    if not driver then
        return lib.alertDialog({ header = 'База ГИБДД', content = table.concat(lines, '  \n'), centered = true })
    end
    lines[#lines + 1] = '\nВыписать штраф водителю?'
    local answer = lib.alertDialog({ header = 'База ГИБДД', content = table.concat(lines, '  \n'), centered = true, cancel = true,
        labels = { confirm = 'Выписать штраф', cancel = 'Закрыть' } })
    if answer == 'confirm' then ExecuteCommand(('fine %d %s'):format(driver, article)) end
end

local policeGroups = {}
for job, grade in pairs(Config.PoliceJobs) do policeGroups[job] = grade end

exports.ox_target:addGlobalVehicle({
    {
        name = 'kavkaz_plates_check',
        icon = 'fa-solid fa-magnifying-glass',
        label = 'Пробить номер по базе',
        groups = policeGroups,
        distance = 4.0,
        onSelect = function(data) checkVehicle(data.entity) end,
    },
})

RegisterCommand('checkplate', function()
    local vehicle = cache.vehicle or lib.getClosestVehicle(GetEntityCoords(cache.ped), 6.0, false)
    if not vehicle then return lib.notify({ description = 'рядом нет машины', type = 'error' }) end
    checkVehicle(vehicle)
end, false)
-- подсказки в чате — в kavkaz_help/config.lua

---------------------------------------------------------------------------
-- NPC и метка
---------------------------------------------------------------------------

local function spawnPed()
    local c = office.ped.coords
    lib.requestModel(office.ped.model)
    ped = CreatePed(4, joaat(office.ped.model), c.x, c.y, c.z - 1.0, c.w, false, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    SetModelAsNoLongerNeeded(joaat(office.ped.model))
    exports.ox_target:addLocalEntity(ped, {
        { name = 'kavkaz_plates_office', icon = 'fa-solid fa-id-card', label = 'Окно МРЭО: номера', distance = 2.5, onSelect = open },
    })
end

CreateThread(function()
    local c = office.ped.coords
    blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, office.blip.sprite)
    SetBlipColour(blip, office.blip.color)
    SetBlipScale(blip, office.blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(office.label)
    EndTextCommandSetBlipName(blip)
end)

-- NPC появляется, только когда игрок рядом
lib.points.new({
    coords = office.ped.coords.xyz,
    distance = 60.0,
    onEnter = function() if not ped then spawnPed() end end,
    onExit = function()
        if ped then
            exports.ox_target:removeLocalEntity(ped, 'kavkaz_plates_office')
            DeleteEntity(ped)
            ped = nil
        end
        close()
    end,
})

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if ped then DeleteEntity(ped) end
    if isOpen then SetNuiFocus(false, false) end
end)
