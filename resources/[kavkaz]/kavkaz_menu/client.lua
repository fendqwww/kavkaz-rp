-- KAVKAZ RP — меню игрока (F4 или /menu)

local open = false
local headshot

-- фото в паспорт: снимок лица персонажа (живёт, пока открыто меню)
local function takePhoto()
    if headshot then UnregisterPedheadshot(headshot) headshot = nil end
    local h = RegisterPedheadshot(PlayerPedId())
    local t = GetGameTimer() + 2000
    while not IsPedheadshotReady(h) or not IsPedheadshotValid(h) do
        if GetGameTimer() > t then UnregisterPedheadshot(h) return nil end
        Wait(0)
    end
    headshot = h
    local txd = GetPedheadshotTxdString(h)
    return ('https://nui-img/%s/%s'):format(txd, txd)
end

local function close()
    if not open then return end
    open = false
    if headshot then UnregisterPedheadshot(headshot) headshot = nil end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openMenu(tab)
    if open or not LocalPlayer.state.isLoggedIn or IsPauseMenuActive() then return end
    local data = lib.callback.await('kavkaz_menu:data', false)
    if not data then return end
    data.profile.photo = takePhoto()
    -- настройки хранят сами ресурсы (у каждого своё хранилище на ПК игрока)
    local okH, hints = pcall(function() return exports.kavkaz_hud:GetHints() end)
    local okV, vol = pcall(function() return exports.kavkaz_sgu:GetVolume() end)
    data.settings = { hints = not okH or hints ~= false, sguVolume = okV and vol or 100 }
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', tab = tab or 'profile', data = data })
end

RegisterCommand('menu', function() openMenu() end, false)
lib.addKeybind({ name = 'kavkaz_menu', description = 'Меню игрока', defaultKey = Config.Key, onPressed = function()
    if open then close() elseif not IsNuiFocused() then openMenu() end
end })

RegisterNUICallback('close', function(_, cb) cb('ok'); close() end)

RegisterNUICallback('promo', function(body, cb)
    local ok, msg = lib.callback.await('kavkaz_menu:promo', false, body.code)
    cb({ ok = ok, msg = msg })
end)

RegisterNUICallback('action', function(body, cb)
    cb('ok')
    local a = body.id
    if a == 'help' then close(); ExecuteCommand('help')
    elseif a == 'gps' then close(); ExecuteCommand('gps')
    elseif a == 'gaid' then close(); ExecuteCommand('gaid')
    elseif a == 'report' then
        close()
        local i = lib.inputDialog('Вопрос администрации', { { type = 'textarea', label = 'что случилось', required = true, max = 300 } })
        if i then ExecuteCommand('report ' .. tostring(i[1]):gsub('[\r\n]', ' ')) end
    elseif a == 'hud' then close(); ExecuteCommand('hud')
    elseif a == 'switch' then
        close()
        if lib.alertDialog({ header = 'Сменить персонажа?', content = 'Ты выйдешь в выбор персонажа. Всё сохранится.', centered = true, cancel = true,
            labels = { confirm = 'Сменить', cancel = 'Остаться' } }) == 'confirm' then
            lib.callback.await('kavkaz_menu:switchChar', false)
        end
    end
end)

RegisterNUICallback('setting', function(body, cb)
    cb('ok')
    if body.id == 'hints' and GetResourceState('kavkaz_hud') == 'started' then
        exports.kavkaz_hud:SetHints(body.value == true)
    elseif body.id == 'sguVolume' and GetResourceState('kavkaz_sgu') == 'started' then
        exports.kavkaz_sgu:SetVolume(math.max(0, math.min(100, math.floor(tonumber(body.value) or 100))))
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
