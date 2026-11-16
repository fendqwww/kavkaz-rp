-- страховка: если по какой-то причине qbx_core не закрыл экран загрузки, закрываем его сами через 90 секунд
CreateThread(function()
    Wait(90000)
    if GetIsLoadingScreenActive() then
        ShutdownLoadingScreen()
    end
    ShutdownLoadingScreenNui()
end)
