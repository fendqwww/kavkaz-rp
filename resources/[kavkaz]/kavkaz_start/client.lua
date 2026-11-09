local guideOpen = false

local function openGuide(isFirstTime)
    if guideOpen then return end
    guideOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', first = isFirstTime })

    if isFirstTime then
        SetNewWaypoint(Config.FirstWaypoint.x, Config.FirstWaypoint.y)
    end
end

RegisterNUICallback('close', function(_, cb)
    guideOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- ждём, пока игрок реально в игре: экран не затемнён, редактор внешности и другие окна закрыты.
-- так приветствие не перекрывает выбор квартиры и создание внешности.
local function waitUntilFree()
    local freeSince
    local deadline = GetGameTimer() + 15 * 60 * 1000
    while GetGameTimer() < deadline do
        local free = IsScreenFadedIn() and not IsNuiFocused() and not IsPauseMenuActive()
            and not IsPlayerSwitchInProgress() and not GetIsLoadingScreenActive()
        if free then
            freeSince = freeSince or GetGameTimer()
            if GetGameTimer() - freeSince >= 3000 then return true end
        else
            freeSince = nil
        end
        Wait(500)
    end
    return false
end

-- сервер сам решает, первый ли это вход персонажа (флаг в metadata)
RegisterNetEvent('kavkaz_start:client:welcome', function()
    openGuide(true)
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    CreateThread(function()
        if waitUntilFree() then
            TriggerServerEvent('kavkaz_start:server:loaded')
        end
    end)
end)

RegisterCommand('gaid', function()
    openGuide(false)
end, false)

TriggerEvent('chat:addSuggestion', '/gaid', 'Памятка новичка: с чего начать и какие кнопки')

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and guideOpen then
        SetNuiFocus(false, false)
    end
end)
