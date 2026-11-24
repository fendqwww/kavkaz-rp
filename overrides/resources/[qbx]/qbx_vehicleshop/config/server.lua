return {
    commissionRate = 0.1, -- Percent that goes to sales person from a full car sale 10%
    finance = {
        paymentWarning = 10, -- time in minutes that player has to make payment before repo
        paymentInterval = 24, -- time in hours between payment being due
        cronSchedule = '*/10 * * * *', -- cron schedule for finance payment checks ref: https://coxdocs.dev/ox_lib/Modules/Cron/Server#cron-expression
        preventSelling = false, -- prevents players from using /transfervehicle if financed
    },
    saleTimeout = 60000, -- Delay between attempts to sell/gift a vehicle. Prevents abuse
    deleteUnpaidFinancedVehicle = false, -- true to delete unpaid vehicles from database, otherwise it will edit citizenid to hide from db select

    ---@param src number Player Server ID
    ---@param plate string Vehicle Plate
    ---@param vehicle number Vehicle Entity ID
    giveKeys = function(src, plate, vehicle)
        -- KAVKAZ: купленная машина получает номер от kavkaz_plates (транзит «ТР» или сразу на учёт — kavkaz_plates/config.lua),
        -- а не случайный номер qbx. тест-драйв (машина без vehicleid) не трогаем. ключи привязаны к машине, не к номеру.
        if GetResourceState('kavkaz_plates') == 'started' then
            local ok, err = pcall(function() exports.kavkaz_plates:OnShopVehicle(src, vehicle) end)
            if not ok then lib.print.error('kavkaz_plates:OnShopVehicle', err) end
        end
        exports.qbx_vehiclekeys:GiveKeys(src, vehicle)
    end,

    ---@param society string Society name
    ---@param amount number Amount to add
    ---@return boolean
    addSocietyFunds = function(society, amount) -- function to add funds to society
        if GetResourceState('Renewed-Banking'):find('started') then
            return exports['Renewed-Banking']:addAccountMoney(society, amount)
        else
            lib.print.error(('Renewed-Banking is needed for Society Funds and it\'s currently %s'):format(GetResourceState('Renewed-Banking')))
            return false
        end
    end,

    ---@param player any QBX Player object
    ---@param amount number Amount to add
    ---@param reason string? Reason for adding funds
    ---@return boolean
    addPlayerFunds = function(player, account, amount, reason)
        return player.Functions.AddMoney(account, amount, reason)
    end,

    ---@param player any QBX Player object
    ---@param amount number Amount to remove
    ---@param reason string? Reason for removing funds
    removePlayerFunds = function(player, account, amount, reason)
        -- KAVKAZ: редкие машины (limit в kavkaz_cars/cars.lua, например 20 «Геликов» на сервер): деньги не списываем, покупки нет
        if (reason == 'vehicle-bought-in-showroom' or reason == 'vehicle-financed-in-showroom') and GetResourceState('kavkaz_cars') == 'started' then
            local ok, allowed = pcall(function() return exports.kavkaz_cars:CanBuy(player.PlayerData.source) end)
            if ok and allowed == false then return false end
        end
        return player.Functions.RemoveMoney(account, amount, reason)
    end,
}
