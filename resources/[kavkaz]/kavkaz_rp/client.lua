-- подсказки команд в чате — в kavkaz_help/config.lua (один список на весь сервер)

-- анимация передачи денег
RegisterNetEvent('kavkaz_rp:client:payAnim', function()
    lib.requestAnimDict('mp_common')
    TaskPlayAnim(cache.ped, 'mp_common', 'givetake1_a', 8.0, -8.0, 1500, 49, 0, false, false, false)
    RemoveAnimDict('mp_common')
end)

-- HUD и миникарта — kavkaz_hud (qbx_hud выключен в kavkaz.cfg)

-- первая помощь: любой игрок с аптечкой может поднять упавшего (не только врач). Alt на человеке
exports.ox_target:addGlobalPlayer({
    {
        name = 'kavkaz_firstaid', icon = 'fa-solid fa-kit-medical', label = 'Оказать первую помощь', distance = 2.0,
        items = 'firstaid',
        canInteract = function(entity)
            local id = NetworkGetPlayerIndexFromPed(entity)
            return id ~= -1 and Player(GetPlayerServerId(id)).state.isDead == true
        end,
        onSelect = function(data)
            local target = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
            lib.requestAnimDict('mini@cpr@char_a@cpr_str')
            if lib.progressCircle({
                duration = 10000, position = 'bottom', label = 'Оказываешь первую помощь…', canCancel = true,
                disable = { move = true, car = true, combat = true },
                anim = { dict = 'mini@cpr@char_a@cpr_str', clip = 'cpr_pumpchest' },
            }) then
                TriggerServerEvent('kavkaz_rp:server:firstAid', target)
            end
        end,
    },
})
