-- KAVKAZ RP: нарды — клиент. окно доски, приглашение через ALT на игрока, автодействия в чат.

local open, lastTurnRoll = false, nil

local function rub(n)
    local s = tostring(math.floor(n)):reverse():gsub('(%d%d%d)', '%1 '):reverse()
    return (s:gsub('^ ', '')) .. ' ₽'
end

local function autoMe(key)
    if GetResourceState('kavkaz_rp') == 'started' then TriggerServerEvent('kavkaz_rp:server:autoMe', key) end
end

local function show(state)
    if not open then
        open = true
        SetNuiFocus(true, true)
        autoMe('nardy_start')
    end
    SendNUIMessage({ action = 'state', data = state })
end

local function hide()
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
end

local function askStake(target)
    local input = lib.inputDialog('Нарды', {
        { type = 'number', label = 'Ставка наличными, ₽', description = '0 — играть на интерес. Победитель забирает обе ставки.',
          default = 0, min = 0, max = Config.MaxStake, step = 500 },
    })
    if not input then return end
    TriggerServerEvent('kavkaz_nardy:invite', target, tonumber(input[1]) or 0)
end

-- ALT на игрока рядом → «Сыграть в нарды»
CreateThread(function()
    exports.ox_target:addGlobalPlayer({
        {
            name = 'kavkaz_nardy_invite',
            icon = 'fa-solid fa-dice',
            label = 'Сыграть в нарды',
            distance = Config.Distance,
            onSelect = function(data)
                local idx = NetworkGetPlayerIndexFromPed(data.entity)
                if idx == -1 then return end
                askStake(GetPlayerServerId(idx))
            end,
        },
    })
end)

RegisterNetEvent('kavkaz_nardy:invited', function(from, name, stake)
    local what = stake > 0 and ('на ' .. rub(stake) .. ' наличными') or 'на интерес, без ставки'
    local answer = lib.alertDialog({
        header = 'Нарды',
        content = ('%s [%d] предлагает сыграть в длинные нарды %s.'):format(name, from, what),
        centered = true,
        cancel = true,
        labels = { confirm = 'Сыграть', cancel = 'Отказаться' },
    })
    TriggerServerEvent('kavkaz_nardy:answer', answer == 'confirm')
end)

RegisterNetEvent('kavkaz_nardy:state', function(state)
    -- свой новый бросок — в чат «бросил кости»
    if state.turn == state.color and state.rolled then
        local full = (state.rolled[1] == state.rolled[2]) and 4 or 2
        local key = table.concat(state.rolled, ':') .. ':' .. state.off[1] .. ':' .. state.off[2] .. ':' .. GetGameTimer() // 5000
        if #state.dice == full and key ~= lastTurnRoll then
            lastTurnRoll = key
            autoMe('nardy_roll')
        end
    end
    show(state)
end)

RegisterNetEvent('kavkaz_nardy:finish', function(res)
    SendNUIMessage({ action = 'finish', data = res })
    lastTurnRoll = nil
    SetTimeout(5000, function() if open then hide() end end)
end)

RegisterNUICallback('move', function(data, cb)
    TriggerServerEvent('kavkaz_nardy:move', data.from, data.die)
    cb(1)
end)

RegisterNUICallback('close', function(_, cb)
    hide()
    lib.notify({ title = 'Нарды', description = 'Доска свёрнута, партия идёт. Вернуться: /nardy', type = 'inform' })
    cb(1)
end)

RegisterNUICallback('surrender', function(_, cb)
    TriggerServerEvent('kavkaz_nardy:surrender')
    cb(1)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
