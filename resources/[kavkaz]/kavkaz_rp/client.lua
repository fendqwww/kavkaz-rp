-- подсказки команд в чате — в kavkaz_help/config.lua (один список на весь сервер)

-- анимация передачи денег
RegisterNetEvent('kavkaz_rp:client:payAnim', function()
    lib.requestAnimDict('mp_common')
    TaskPlayAnim(cache.ped, 'mp_common', 'givetake1_a', 8.0, -8.0, 1500, 49, 0, false, false, false)
    RemoveAnimDict('mp_common')
end)

-- HUD и миникарта — kavkaz_hud (qbx_hud выключен в kavkaz.cfg)
