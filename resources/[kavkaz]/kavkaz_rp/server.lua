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

-- вид строк чата (тема qbx_chat_theme/theme: kavkaz.js и app.css). в шаблоне только наш HTML,
-- всё, что пишет игрок, идёт в args — чат сам экранирует их, так что вставить свой HTML игрок не может.
-- класс kv-<вид> определяет цвет и вкладку: say shout whisper me do try ooc pm radio dep fam gov
local NM = '<b class="nm">{0}</b><i class="id">[{1}]</i>'
local TPL = {
    say     = '<div class="kv kv-say">' .. NM .. ' говорит: {2}</div>',
    shout   = '<div class="kv kv-shout">' .. NM .. ' кричит: {2}</div>',
    whisper = '<div class="kv kv-whisper">' .. NM .. ' {3}: {2}</div>',
    me      = '<div class="kv kv-me">* ' .. NM .. ' {2}</div>',
    ['do']  = '<div class="kv kv-do">{2} <i class="who">(( {0} [{1}] ))</i></div>',
    try_ok  = '<div class="kv kv-try">* ' .. NM .. ' {2} — <b class="ok">удачно</b></div>',
    try_no  = '<div class="kv kv-try">* ' .. NM .. ' {2} — <b class="no">неудачно</b></div>',
    todo    = '<div class="kv kv-me">«{2}», — сказал ' .. NM .. ', {3}</div>',
    ooc     = '<div class="kv kv-ooc">(( ' .. NM .. ': {2} ))</div>',
    pm      = '<div class="kv kv-pm"><b class="tag">{3}</b> ' .. NM .. ': {2}</div>',
    radio   = '<div class="kv kv-radio"><b class="tag">[{3}]</b> ' .. NM .. ': {2}</div>',
    radioOoc= '<div class="kv kv-radio kv-ooc"><b class="tag">[{3}]</b> (( ' .. NM .. ': {2} ))</div>',
    dep     = '<div class="kv kv-dep"><b class="tag">[{3}]</b> ' .. NM .. ': {2}</div>',
    fam     = '<div class="kv kv-fam"><b class="tag">[{3}]</b> ' .. NM .. ': {2}</div>',
    famOoc  = '<div class="kv kv-fam kv-ooc"><b class="tag">[{3}]</b> (( ' .. NM .. ': {2} ))</div>',
    gov     = '<div class="kv kv-gov"><b class="tag">ГОСНОВОСТИ · {0}</b> {2}</div>',
}

-- kind — ключ TPL, args = { имя, ID, текст, доп. }
local function send(target, kind, args)
    TriggerClientEvent('chat:addMessage', target, { template = TPL[kind], args = args })
end

-- всем в радиусе, в том же routing bucket
local function sendNear(src, range, kind, args)
    local pos = GetEntityCoords(GetPlayerPed(src))
    local bucket = GetPlayerRoutingBucket(src)
    for _, id in ipairs(GetPlayers()) do
        local t = tonumber(id)
        if GetPlayerRoutingBucket(t) == bucket and #(GetEntityCoords(GetPlayerPed(t)) - pos) <= range then
            send(t, kind, args)
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
        sendNear(src, Config.Range.say, 'say', { charName(src), src, clean(message) })
    end)
end

chatCommand('s', 'Крикнуть', function(src, a)
    sendNear(src, Config.Range.shout, 'shout', { charName(src), src, a.text .. '!' })
end)

chatCommand('do', 'Описание окружения', function(src, a)
    sendNear(src, Config.Range.action, 'do', { charName(src), src, a.text })
end)

chatCommand('try', 'Попытка', function(src, a)
    local ok = math.random() < 0.5
    sendNear(src, Config.Range.action, ok and 'try_ok' or 'try_no', { charName(src), src, a.text })
end)

chatCommand('todo', 'Фраза*действие', function(src, a)
    local phrase, action = a.text:match('^(.-)%*(.+)$')
    if not phrase or phrase == '' then return notify(src, 'формат: /todo Привет, брат*пожимает руку', 'error') end
    sendNear(src, Config.Range.action, 'todo', { charName(src), src, phrase, action })
end)

chatCommand('b', 'Локальный OOC', function(src, a)
    sendNear(src, Config.Range.ooc, 'ooc', { GetPlayerName(src) or '?', src, a.text })
end)

chatCommand('w', 'Шёпот', function(src, a)
    local t = a.target
    if #(GetEntityCoords(GetPlayerPed(t)) - GetEntityCoords(GetPlayerPed(src))) > Config.Range.whisper then
        return notify(src, 'нужно стоять вплотную', 'error')
    end
    send(t, 'whisper', { charName(src), src, a.text, 'шепчет тебе' })
    send(src, 'whisper', { charName(src), src, a.text, 'шепчет ' .. charName(t) })
    sendNear(src, Config.Range.action, 'me', { charName(src), src, 'что-то шепчет ' .. charName(t) })
end, { { name = 'target', type = 'playerId', help = 'ID' } })

chatCommand('pm', 'Личное OOC-сообщение', function(src, a)
    if a.target == src then return end
    send(a.target, 'pm', { GetPlayerName(src) or '?', src, a.text, 'ЛС от' })
    send(src, 'pm', { GetPlayerName(a.target) or '?', a.target, a.text, 'ЛС для' })
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
        local tag = ('%s · %s'):format(job.label, job.grade.name)
        local who = ooc and (GetPlayerName(src) or '?') or charName(src)
        eachPlayer(function(pd) return pd.job.name == job.name end, function(t)
            send(t, ooc and 'radioOoc' or 'radio', { who, src, a.text, tag })
        end)
    end
end
chatCommand('r', 'Рация организации', radio(false))
chatCommand('rn', 'Рация организации NonRP', radio(true))

chatCommand('d', 'Департамент', function(src, a)
    local job = jobOf(src)
    if not job or not Config.GovJobs[job.name] or not job.onduty then return notify(src, 'только госструктуры на смене', 'error') end
    eachPlayer(function(pd) return Config.GovJobs[pd.job.name] and pd.job.onduty end, function(t)
        send(t, 'dep', { charName(src), src, a.text, 'Департамент · ' .. job.label })
    end)
end)

local function family(ooc)
    return function(src, a)
        local _, gang = jobOf(src)
        if not gang or gang.name == 'none' then return notify(src, 'ты не состоишь в семье или банде', 'error') end
        eachPlayer(function(pd) return pd.gang.name == gang.name end, function(t)
            send(t, ooc and 'famOoc' or 'fam', { ooc and (GetPlayerName(src) or '?') or charName(src), src, a.text, gang.label })
        end)
    end
end
chatCommand('f', 'Чат семьи', family(false))
chatCommand('fn', 'Чат семьи NonRP', family(true))

chatCommand('gov', 'Госновости', function(src, a)
    local job = jobOf(src)
    if not job or not Config.GovJobs[job.name] or not job.isboss then return notify(src, 'только лидеры и замы госструктур', 'error') end
    send(-1, 'gov', { job.label, src, a.text })
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
    sendNear(src, Config.Range.action, 'me', { charName(src), src, 'передал деньги ' .. charName(args.target) })
    print(('[kavkaz_rp] pay %s -> %s: %d'):format(oocName(src), oocName(args.target), amount))
end)

AddEventHandler('playerDropped', function() lastPay[source] = nil end)

-- автодействия: клиент сообщает только ключ события, текст и дальность — здесь
local lastAuto = {}
RegisterNetEvent('kavkaz_rp:server:autoMe', function(key)
    local src = source
    if not Config.AutoMe or type(key) ~= 'string' then return end
    local text = Config.AutoMeText[key]
    if not text or isMuted(src) then return end
    if (lastAuto[src] or 0) + 1200 > GetGameTimer() then return end
    lastAuto[src] = GetGameTimer()
    sendNear(src, Config.Range.action, 'me', { charName(src), src, text })
end)
AddEventHandler('playerDropped', function() lastAuto[source] = nil end)

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
