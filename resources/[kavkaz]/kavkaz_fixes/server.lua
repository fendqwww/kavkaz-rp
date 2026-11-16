-- qbx_ambulancejob при старте сервера вызывает exports.ox_inventory:RegisterShop раньше,
-- чем ox_inventory успевает его зарегистрировать (гонка при запуске) -> магазин больницы не создаётся.
-- лечим без правки чужого кода: ждём готовности ox_inventory и один раз перезапускаем больницу.
local TARGET = 'qbx_ambulancejob'
local BOOT_WINDOW_MS = 5 * 60 * 1000 -- только сразу после старта сервера, чтобы не дёргать больницу при игроках

local function inventoryReady()
    if GetResourceState('ox_inventory') ~= 'started' then return false end
    return pcall(function() return exports.ox_inventory:Items('water') end)
end

CreateThread(function()
    if GetGameTimer() > BOOT_WINDOW_MS then return end

    local deadline = GetGameTimer() + 120000
    while not inventoryReady() do
        if GetGameTimer() > deadline then
            print('^1[kavkaz_fixes] ox_inventory так и не стал готов, больницу не трогаю^0')
            return
        end
        Wait(1000)
    end
    Wait(3000)

    if GetResourceState(TARGET) ~= 'started' then return end
    print(('^3[kavkaz_fixes] перезапускаю %s после готовности ox_inventory (магазин больницы)^0'):format(TARGET))
    StopResource(TARGET)
    Wait(500)
    StartResource(TARGET)
end)
