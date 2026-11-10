-- RP-чаты и /pay. вся логика на сервере: дистанцию, организацию и деньги проверяем здесь.

local lastPay = {}

local function notify(src, text, kind)
    exports.qbx_core:Notify(src, text, kind or 'inform', 5000)
end

local function isMuted(src)
    local ok, muted = pcall(function() return exports.kavkaz_admin:IsMuted(src) end)
    return ok and muted
end

-- имя персонажа для IC, «Ник [ID]» для OOC
local function charName(src)
    local p = exports.qbx_core:GetPlayer(src)
    if not p then return GetPlayerName(src) or '?' end
    local ci = p.PlayerData.charinfo
    return ('%s %s'):format(ci.firstname, ci.lastname)
end

local function oocName(src)
    return ('%s [%d]'):format(GetPlayerName(src) or '?', src)
end

local function send(target, color, prefix, text)
    TriggerClientEvent('chat:addMessage', target, { color = color, multiline = true, args = { prefix, text } })
end

-- всем в радиусе, в том же routing bucket
local function sendNear(src, range, color, prefix, text)
    local pos = GetEntityCoords(GetPlayerPed(src))
    local bucket = GetPlayerRoutingBucket(src)
    for _, id in ipairs(GetPlayers()) do
        local t = tonumber(id)
        if GetPlayerRoutingBucket(t) == bucket and #(GetEntityCoords(GetPlayerPed(t)) - pos) <= range then
            send(t, color, prefix, text)
        end
    end
end

local function clean(text)
    return (tostring(text or ''):gsub('[\r\n]', ' '):sub(1, 300))
end

-- обёртка: команда, текст обязателен, мут блокирует
local function chatCommand(name, help, fn, extraParams)
    local params = extraParams or {}
    params[#params + 1] = { name = 'text', type = 'longString', help = 'текст' }
    lib.addCommand(name, { help = help, params = params }, function(src, args)
        if src == 0 then return end
        if isMuted(src) then return notify(src, 'у тебя мут', 'error') end
        args.text = clean(args.text)
        if args.text == '' then return end
        fn(src, args)
    end)
end

---------------------------------------------------------------------------
-- рядом
---------------------------------------------------------------------------

if Config.LocalChat then
    AddEventHandler('chatMessage', function(src, _, message)
        CancelEvent()
        if message:sub(1, 1) == '/' or isMuted(src) then return end
        sendNear(src, Config.Range.say, Config.Colors.say, charName(src) .. ' говорит', clean(message))
    end)
end

chatCommand('s', 'Крикнуть', function(src, a)
    sendNear(src, Config.Range.shout, Config.Colors.shout, charName(src) .. ' кричит', a.text .. '!')
end)

chatCommand('do', 'Описание окружения', function(src, a)
    sendNear(src, Config.Range.action, Config.Colors['do'], '*', ('%s (( %s ))'):format(a.text, charName(src)))
end)

chatCommand('try', 'Попытка', function(src, a)
    local ok = math.random() < 0.5
    sendNear(src, Config.Range.action, Config.Colors.try, '*', ('%s %s — %s'):format(charName(src), a.text, ok and 'удачно' or 'неудачно'))
end)

chatCommand('todo', 'Фраза*действие', function(src, a)
    local phrase, action = a.text:match('^(.-)%*(.+)$')
    if not phrase or phrase == '' then return notify(src, 'формат: /todo Привет, брат*пожимает руку', 'error') end
    sendNear(src, Config.Range.action, Config.Colors.me, '*', ('«%s», — сказал %s, %s'):format(phrase, charName(src), action))
end)

chatCommand('b', 'Локальный OOC', function(src, a)
    sendNear(src, Config.Range.ooc, Config.Colors.ooc, '(( ' .. oocName(src), a.text .. ' ))')
end)

chatCommand('w', 'Шёпот', function(src, a)
    local t = a.target
    if #(GetEntityCoords(GetPlayerPed(t)) - GetEntityCoords(GetPlayerPed(src))) > Config.Range.whisper then
        return notify(src, 'нужно стоять вплотную', 'error')
    end
    send(t, Config.Colors.whisper, charName(src) .. ' шепчет', a.text)
    send(src, Config.Colors.whisper, 'ты шепчешь ' .. charName(t), a.text)
    sendNear(src, Config.Range.action, Config.Colors.me, '*', charName(src) .. ' что-то шепчет ' .. charName(t))
end, { { name = 'target', type = 'playerId', help = 'ID' } })

chatCommand('pm', 'Личное OOC-сообщение', function(src, a)
    if a.target == src then return end
    send(a.target, Config.Colors.pm, 'ЛС от ' .. oocName(src), a.text)
    send(src, Config.Colors.pm, 'ЛС для ' .. oocName(a.target), a.text)
end, { { name = 'target', type = 'playerId', help = 'ID' } })

---------------------------------------------------------------------------
-- рации
---------------------------------------------------------------------------

local function eachPlayer(filter, fn)
    for _, id in ipairs(GetPlayers()) do
        local t = tonumber(id)
        local p = exports.qbx_core:GetPlayer(t)
        if p and filter(p.PlayerData) then fn(t) end
    end
end

local function jobOf(src)
    local p = exports.qbx_core:GetPlayer(src)
    return p and p.PlayerData.job, p and p.PlayerData.gang
end

local function radio(ooc)
    return function(src, a)
        local job = jobOf(src)
        if not job or job.name == 'unemployed' then return notify(src, 'ты не состоишь в организации', 'error') end
        if Config.GovJobs[job.name] and not job.onduty then return notify(src, 'рация работает на смене', 'error') end
        local prefix = ('[%s] %s %s'):format(job.label, job.grade.name, ooc and oocName(src) or charName(src))
        eachPlayer(function(pd) return pd.job.name == job.name end, function(t)
            send(t, ooc and Config.Colors.radioOoc or Config.Colors.radio, prefix, ooc and ('(( ' .. a.text .. ' ))') or a.text)
        end)
    end
end
chatCommand('r', 'Рация организации', radio(false))
chatCommand('rn', 'Рация организации NonRP', radio(true))

chatCommand('d', 'Департамент', function(src, a)
    local job = jobOf(src)
    if not job or not Config.GovJobs[job.name] or not job.onduty then return notify(src, 'только госструктуры на смене', 'error') end
    eachPlayer(function(pd) return Config.GovJobs[pd.job.name] and pd.job.onduty end, function(t)
        send(t, Config.Colors.dep, ('[Департамент] %s | %s'):format(job.label, charName(src)), a.text)
    end)
end)

local function family(ooc)
    return function(src, a)
        local _, gang = jobOf(src)
        if not gang or gang.name == 'none' then return notify(src, 'ты не состоишь в семье или банде', 'error') end
        eachPlayer(function(pd) return pd.gang.name == gang.name end, function(t)
            send(t, Config.Colors.fam, ('[%s] %s'):format(gang.label, ooc and oocName(src) or charName(src)), ooc and ('(( ' .. a.text .. ' ))') or a.text)
        end)
    end
end
chatCommand('f', 'Чат семьи', family(false))
chatCommand('fn', 'Чат семьи NonRP', family(true))

chatCommand('gov', 'Госновости', function(src, a)
    local job = jobOf(src)
    if not job or not Config.GovJobs[job.name] or not job.isboss then return notify(src, 'только лидеры и замы госструктур', 'error') end
    send(-1, Config.Colors.gov, ('ГОСНОВОСТИ | %s'):format(job.label), a.text)
end)

---------------------------------------------------------------------------
-- /pay ID сумма — наличные из рук в руки
---------------------------------------------------------------------------

lib.addCommand('pay', {
    help = 'Передать наличные игроку рядом',
    params = {
        { name = 'target', type = 'playerId', help = 'ID' },
        { name = 'amount', type = 'number', help = 'сумма в ₽' },
    },
}, function(src, args)
    if src == 0 or args.target == src then return end
    local now = os.time()
    if lastPay[src] and now - lastPay[src] < Config.Pay.cooldown then return notify(src, 'не так быстро', 'error') end
    lastPay[src] = now

    local amount = math.floor(args.amount)
    if amount < 1 or amount > Config.Pay.max then return notify(src, 'неверная сумма', 'error') end
    if #(GetEntityCoords(GetPlayerPed(args.target)) - GetEntityCoords(GetPlayerPed(src))) > Config.Pay.distance then
        return notify(src, 'подойди ближе', 'error')
    end
    if not exports.qbx_core:GetPlayer(args.target) then return notify(src, 'игрок не загружен', 'error') end
    if (exports.qbx_core:GetMoney(src, 'cash') or 0) < amount then return notify(src, 'не хватает наличных', 'error') end
    if not exports.qbx_core:RemoveMoney(src, 'cash', amount, 'pay: игроку ' .. args.target) then return end
    exports.qbx_core:AddMoney(args.target, 'cash', amount, 'pay: от игрока ' .. src)

    local sum = tostring(amount):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '') .. ' ₽'
    TriggerClientEvent('kavkaz_rp:client:payAnim', src)
    notify(src, ('ты передал %s'):format(sum), 'success')
    notify(args.target, ('%s передал тебе %s'):format(charName(src), sum), 'success')
    sendNear(src, Config.Range.action, Config.Colors.me, '*', ('%s передал деньги %s'):format(charName(src), charName(args.target)))
    print(('[kavkaz_rp] pay %s -> %s: %d'):format(oocName(src), oocName(args.target), amount))
end)

AddEventHandler('playerDropped', function() lastPay[source] = nil end)

-- первая помощь от игрока: проверяем расстояние, что человек упал, и списываем аптечку
local lastAid = {}
RegisterNetEvent('kavkaz_rp:server:firstAid', function(target)
    local src = source
    target = tonumber(target)
    if not target or target == src or not GetPlayerName(target) then return end
    if (lastAid[src] or 0) + 8000 > GetGameTimer() then return end
    lastAid[src] = GetGameTimer()
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target))) > 4.0 then return end
    if not Player(target).state.isDead then return end
    if not exports.ox_inventory:RemoveItem(src, 'firstaid', 1) then
        return exports.qbx_core:Notify(src, 'Нужна аптечка', 'error')
    end
    exports.qbx_medical:Revive(target)
    exports.qbx_core:Notify(src, 'Ты поднял человека. Пусть всё же доедет до больницы', 'success')
    exports.qbx_core:Notify(target, 'Тебе оказали первую помощь', 'success')
end)
AddEventHandler('playerDropped', function() lastAid[source] = nil end)
