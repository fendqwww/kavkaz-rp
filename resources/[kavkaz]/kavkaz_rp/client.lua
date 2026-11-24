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

---------------------------------------------------------------------------
-- автодействия в чат: ремень, двигатель, замок, оружие, бронежилет
---------------------------------------------------------------------------
local GROUPS = {
    [416676503] = 'pistol', [3337201093] = 'smg', [970310034] = 'rifle', [860033945] = 'shotgun',
    [3082541095] = 'sniper', [1159398588] = 'heavy', [2725924767] = 'heavy', [3566412244] = 'melee',
}
local UNARMED = `WEAPON_UNARMED`

local function auto(key) TriggerServerEvent('kavkaz_rp:server:autoMe', key) end

CreateThread(function()
    if not Config.AutoMe then return end
    local lastVeh, belt, engine, lock = 0, nil, nil, nil
    local weapon, armor = UNARMED, nil
    while true do
        Wait(300)
        if LocalPlayer.state.isLoggedIn and not LocalPlayer.state.isDead then
            local ped = cache.ped
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= lastVeh then
                -- сели или вышли: запоминаем текущее, не пишем в чат
                lastVeh = veh
                belt = veh ~= 0 and (LocalPlayer.state.seatbelt or LocalPlayer.state.harness) or nil
                engine = veh ~= 0 and GetIsVehicleEngineRunning(veh) or nil
                lock = veh ~= 0 and GetVehicleDoorLockStatus(veh) or nil
            elseif veh ~= 0 then
                local b = LocalPlayer.state.seatbelt or LocalPlayer.state.harness or false
                if belt ~= nil and b ~= belt then auto(b and 'belt_on' or 'belt_off') end
                belt = b
                if GetPedInVehicleSeat(veh, -1) == ped then
                    local e = GetIsVehicleEngineRunning(veh)
                    if engine ~= nil and e ~= engine then auto(e and 'engine_on' or 'engine_off') end
                    engine = e
                    local l = GetVehicleDoorLockStatus(veh)
                    if lock ~= nil and (l >= 2) ~= (lock >= 2) then auto(l >= 2 and 'lock' or 'unlock') end
                    lock = l
                end
            end

            local w = GetSelectedPedWeapon(ped)
            if w ~= weapon then
                if w == UNARMED then
                    auto('weapon_in')
                elseif weapon == UNARMED then
                    local g = GetWeapontypeGroup(w)
                    if g < 0 then g = g + 4294967296 end -- хэш может прийти со знаком
                    auto('weapon_out:' .. (GROUPS[g] or 'other'))
                end
                weapon = w
            end

            local a = GetPedArmour(ped)
            if armor and a - armor >= 20 then auto('armor') end
            armor = a
        end
    end
end)
