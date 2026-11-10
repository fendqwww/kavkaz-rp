-- подсказки команд в чате — в kavkaz_help/config.lua (один список на весь сервер)

-- анимация передачи денег
RegisterNetEvent('kavkaz_rp:client:payAnim', function()
    lib.requestAnimDict('mp_common')
    TaskPlayAnim(cache.ped, 'mp_common', 'givetake1_a', 8.0, -8.0, 1500, 49, 0, false, false, false)
    RemoveAnimDict('mp_common')
end)

-- KAVKAZ: миникарта и пешком. qbx_hud хранит настройки на ПК игрока (KVP), и старое «карта только в машине»
-- перебивает конфиг (overrides qbx_hud config/shared.lua). один раз на ПК сбрасываем настройки HUD к конфигу сервера.
local HUD_RESET = 'kavkaz_hud_reset_v1'
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if GetResourceKvpInt(HUD_RESET) == 1 then return end
    Wait(5000) -- qbx_hud читает свои настройки через 2 с после входа
    TriggerEvent('hud:client:resetStorage')
    SetResourceKvpInt(HUD_RESET, 1)
end)
