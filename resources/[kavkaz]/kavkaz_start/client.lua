local function showGuide(isFirstTime)
    lib.alertDialog({
        header = Config.WelcomeTitle,
        content = Config.WelcomeText,
        centered = true,
        size = 'lg',
        labels = { confirm = 'Понятно, поехали' },
    })

    if isFirstTime then
        SetNewWaypoint(Config.FirstWaypoint.x, Config.FirstWaypoint.y)
        lib.notify({
            title = 'GPS',
            description = 'Метка на мэрию стоит на карте',
            type = 'inform',
            duration = 8000,
        })
    end
end

-- сервер сам решает, первый ли это вход персонажа
RegisterNetEvent('kavkaz_start:client:welcome', function()
    showGuide(true)
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('kavkaz_start:server:loaded')
end)

RegisterCommand('gaid', function()
    showGuide(false)
end, false)

TriggerEvent('chat:addSuggestion', '/gaid', 'Подсказка для новичка: с чего начать и какие кнопки')
