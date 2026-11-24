-- онлайн для верхнего правого угла HUD (клиент сам не видит игроков вне зоны прорисовки)
local function update()
    GlobalState.kavkaz_online = #GetPlayers()
end

GlobalState.kavkaz_slots = GetConvarInt('sv_maxclients', 48)

AddEventHandler('playerJoining', update)
AddEventHandler('playerDropped', function() SetTimeout(500, update) end)

CreateThread(function()
    while true do
        update()
        Wait(30000)
    end
end)
