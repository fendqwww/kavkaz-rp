-- KAVKAZ RP: водительские права — клиент. сел за руль без прав — одно предупреждение (ездить можно, это RP: ДПС оштрафует).

local warned = {}

lib.onCache('seat', function(seat)
    if seat ~= -1 then return end
    Wait(300)
    local veh = cache.vehicle
    if not veh or not Config.WarnClasses[GetVehicleClass(veh)] then return end
    if warned[veh] then return end
    local st, untilStr = lib.callback.await('kavkaz_license:status', false)
    if st == 'ok' then return end
    warned[veh] = true
    local text = st == 'banned'
        and ('Ты лишён прав до %s. Если остановит ДПС — штраф и эвакуатор'):format(untilStr or '?')
        or 'У тебя нет водительских прав. Если остановит ДПС — штраф и эвакуатор. Права — в автошколе у Заремы Поворотовны'
    lib.notify({ title = 'Права', description = text, type = 'warning', duration = 9000 })
end)
