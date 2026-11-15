-- KAVKAZ RP: нарды — сервер. кости, ходы и деньги только здесь; клиент присылает лишь «шашку с позиции X на кость Y».

local R = Nardy
local games, inGame, invites = {}, {}, {}
local nextId = 0

local function charName(src)
    local p = exports.qbx_core:GetPlayer(src)
    if p and p.PlayerData.charinfo then
        return ('%s %s'):format(p.PlayerData.charinfo.firstname or '', p.PlayerData.charinfo.lastname or '')
    end
    return GetPlayerName(src) or ('Игрок ' .. src)
end

local function notify(src, text, kind)
    TriggerClientEvent('ox_lib:notify', src, { title = 'Нарды', description = text, type = kind or 'inform' })
end

local function near(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if pa == 0 or pb == 0 then return false end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= Config.Distance
end

local function cash(src)
    local p = exports.qbx_core:GetPlayer(src)
    return p and p.PlayerData.money and p.PlayerData.money.cash or 0
end

local function rub(n)
    local s = tostring(math.floor(n)):reverse():gsub('(%d%d%d)', '%1 '):reverse()
    return (s:gsub('^ ', '')) .. ' ₽'
end

-- состояние партии для одного игрока (его цвет, его законные ходы)
local function send(g)
    local s = g.state
    local board = {}
    for a = 1, 24 do board[a] = { s.pts[a].c, s.pts[a].n } end
    for color = 1, 2 do
        local src = g.p[color]
        TriggerClientEvent('kavkaz_nardy:state', src, {
            color = color,
            board = board,
            off = { s.off[1], s.off[2] },
            turn = s.turn,
            dice = s.dice,
            rolled = g.rolled,
            legal = (s.turn == color) and R.legal(s) or {},
            names = { g.names[1], g.names[2] },
            stake = g.stake,
            left = math.max(0, g.deadline - os.time()),
            turnTime = Config.TurnTime,
        })
    end
end

local function cleanup(g)
    games[g.id] = nil
    for color = 1, 2 do inGame[g.p[color]] = nil end
end

local function finish(g, winner, reason)
    if g.over then return end
    g.over = true
    local s = g.state
    local loser = 3 - winner
    local mars = s.off[loser] == 0 and reason == 'win'
    local pot = g.stake * 2
    if pot > 0 then
        exports.qbx_core:AddMoney(g.p[winner], 'cash', pot, 'нарды: выигрыш')
    end
    for color = 1, 2 do
        if GetPlayerName(g.p[color]) then
            TriggerClientEvent('kavkaz_nardy:finish', g.p[color], {
                win = color == winner, winner = g.names[winner], reason = reason, pot = pot, mars = mars,
            })
        end
    end
    cleanup(g)
end

-- новый ход: бросаем кости; если ходить нечем — передаём ход дальше
local function startTurn(g)
    local s = g.state
    local a, b = R.roll(s, math.random)
    g.rolled = { a, b }
    g.deadline = os.time() + Config.TurnTime
    send(g)
    if R.turnOver(s) then
        local id = g.id
        SetTimeout(1800, function()
            local cur = games[id]
            if not cur or cur.over then return end
            notify(cur.p[s.turn], ('Выпало %d и %d — ходить нечем, ход переходит'):format(a, b))
            R.nextTurn(s)
            startTurn(cur)
        end)
    end
end

local function start(white, black, stake)
    nextId = nextId + 1
    local g = {
        id = nextId, p = { white, black }, names = { charName(white), charName(black) },
        stake = stake, state = R.new(), deadline = 0,
    }
    games[g.id] = g
    inGame[white], inGame[black] = g.id, g.id
    startTurn(g)
end

local function invite(src, target, stake)
    target, stake = tonumber(target), math.floor(tonumber(stake) or 0)
    if not target or target == src or not GetPlayerName(target) then return notify(src, 'Игрока с таким номером нет рядом', 'error') end
    if stake < 0 or stake > Config.MaxStake then return notify(src, 'Ставка от 0 до ' .. rub(Config.MaxStake), 'error') end
    if inGame[src] then return notify(src, 'Ты уже играешь. Вернуться к доске: /nardy', 'error') end
    if inGame[target] then return notify(src, 'Этот игрок уже за доской', 'error') end
    if not near(src, target) then return notify(src, 'Подойди ближе к сопернику', 'error') end
    if stake > 0 and cash(src) < stake then return notify(src, 'Не хватает наличных на ставку', 'error') end
    invites[target] = { from = src, stake = stake, t = os.time() }
    TriggerClientEvent('kavkaz_nardy:invited', target, src, charName(src), stake)
    notify(src, ('Предложил сыграть %s, ждём ответа'):format(stake > 0 and ('на ' .. rub(stake)) or 'без ставки'))
end

RegisterNetEvent('kavkaz_nardy:invite', function(target, stake) invite(source, target, stake) end)

RegisterNetEvent('kavkaz_nardy:answer', function(accept)
    local src = source
    local inv = invites[src]
    invites[src] = nil
    if not inv then return end
    local from = inv.from
    if not GetPlayerName(from) then return notify(src, 'Соперник ушёл', 'error') end
    if not accept then return notify(from, charName(src) .. ' отказался играть') end
    if os.time() - inv.t > Config.InviteTime then return notify(src, 'Приглашение устарело', 'error') end
    if inGame[src] or inGame[from] then return notify(src, 'Кто-то из вас уже играет', 'error') end
    if not near(src, from) then
        notify(src, 'Соперник отошёл', 'error')
        return notify(from, 'Отошёл слишком далеко — партия не началась', 'error')
    end
    local stake = inv.stake
    if stake > 0 then
        if not exports.qbx_core:RemoveMoney(from, 'cash', stake, 'нарды: ставка') then
            notify(src, 'У соперника не хватило наличных', 'error')
            return notify(from, 'Не хватает наличных на ставку', 'error')
        end
        if not exports.qbx_core:RemoveMoney(src, 'cash', stake, 'нарды: ставка') then
            exports.qbx_core:AddMoney(from, 'cash', stake, 'нарды: возврат ставки')
            notify(from, 'У соперника не хватило наличных', 'error')
            return notify(src, 'Не хватает наличных на ставку', 'error')
        end
    end
    -- кто ходит первым (белыми) — жребий
    if math.random(2) == 1 then start(from, src, stake) else start(src, from, stake) end
end)

RegisterNetEvent('kavkaz_nardy:move', function(from, die)
    local src = source
    local g = games[inGame[src] or -1]
    if not g or g.over then return end
    local s = g.state
    if g.p[s.turn] ~= src then return end
    from, die = tonumber(from), tonumber(die)
    if not from or not die or not R.move(s, from, die) then return send(g) end
    local w = R.winner(s)
    if w then return finish(g, w, 'win') end
    if R.turnOver(s) then
        R.nextTurn(s)
        return startTurn(g)
    end
    send(g)
end)

RegisterNetEvent('kavkaz_nardy:surrender', function()
    local src = source
    local g = games[inGame[src] or -1]
    if not g then return end
    finish(g, g.p[1] == src and 2 or 1, 'surrender')
end)

-- /nardy ID ставка — пригласить; /nardy — вернуться к своей доске
RegisterCommand('nardy', function(src, args)
    if src == 0 then return end
    if not args[1] then
        local g = games[inGame[src] or -1]
        if g then return send(g) end
        return notify(src, 'Пригласить: /nardy ID ставка (0 — без ставки) или ALT на игрока', 'inform')
    end
    invite(src, args[1], args[2] or 0)
end, false)

AddEventHandler('playerDropped', function()
    local src = source
    invites[src] = nil
    local g = games[inGame[src] or -1]
    if g then finish(g, g.p[1] == src and 2 or 1, 'left') end
end)

-- кто долго не ходит — проигрывает (иначе ставка зависнет)
CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for _, g in pairs(games) do
            if not g.over and g.deadline > 0 and now > g.deadline then
                finish(g, 3 - g.state.turn, 'timeout')
            end
        end
    end
end)
