-- движок сюжетных линий (story.lua): старт с 50 000 ₽, выбор линии, прокат скутера, шаги, выбор роли.
-- состояние: st.line ('law' | 'business' | 'crime'), st.step (номер шага), st.rep (репутация линии),
-- st.afterRent (скутер взят), st.jobCount (заказы на шаге job), st.quiz (вопрос/верные), st.lineDone, st.career, st.title

local npcPos = function(id) return Config.Npcs[id].coords.xyz end
local LINES = { 'law', 'business', 'crime' }
local TALKABLE = { talk = true, pay = true, quiz = true, drive = true, final = true }

local function hasLicense(src)
    local ok, count = pcall(function() return exports.ox_inventory:Search(src, 'count', 'driver_license') end)
    return ok and (count or 0) > 0
end

function Q.current(st)
    local L = st.line and Story[st.line]
    return L and not st.lineDone and L.steps[st.step or 1] or nil
end

local function goTo(src, npcId, text)
    Q.objective(src, { id = 'goto_' .. npcId, text = text, coords = npcPos(npcId), radius = 4.0, onReach = function() end })
end

---------------------------------------------------------------------------
-- цель текущего шага
---------------------------------------------------------------------------

local advance

local function points(src, list, text, anim, onDone, vehNet, deadline)
    local function step(i)
        Q.objective(src, {
            id = ('pt_%d_%d'):format(i, math.random(1, 1e6)), text = #list > 1 and ('%s · %d из %d'):format(text, i, #list) or text,
            coords = list[i], radius = vehNet and 10.0 or 4.0, anim = anim, vehNet = vehNet, deadline = deadline,
            onReach = function(s) if i < #list then step(i + 1) else onDone(s) end end,
        })
    end
    step(1)
end

function Q.storyObjective(src, st)
    local s = Q.current(st)
    if not s then return Q.objective(src, nil) end
    local who = s.npc and Config.Npcs[s.npc] and Config.Npcs[s.npc].name
    if TALKABLE[s.type] then return goTo(src, s.npc, s.goal or ('Иди к: ' .. who)) end
    if s.type == 'go' then
        return Q.objective(src, { id = 'go_' .. st.step, text = s.text, coords = s.coords, radius = 4.0, anim = s.anim,
            onReach = function(p) advance(p, Q.get(p)) end })
    end
    if s.type == 'points' then
        return points(src, s.points, s.text, s.anim, function(p) advance(p, Q.get(p)) end)
    end
    if s.type == 'job' then
        return goTo(src, 'rumisa', ('%s · сделано %d из %d'):format(s.text, st.jobCount or 0, s.count))
    end
    if s.type == 'license' then
        if hasLicense(src) then return advance(src, st) end
        return goTo(src, 'zarema', s.text)
    end
end

-- следующий шаг: награда, сохранение, новая цель
advance = function(src, st, extraRep, noReward)
    local s = Q.current(st)
    if not s then return end
    if not noReward and s.reward and s.reward > 0 then Q.reward(src, s.reward, ('сюжет «%s», шаг %d'):format(Story[st.line].label, st.step)) end
    st.rep = (st.rep or 0) + (s.rep or 0) + (extraRep or 0)
    st.step = (st.step or 1) + 1
    st.jobCount, st.quiz = nil, nil
    Q.save(src, st)
    local nxt = Q.current(st)
    if nxt then Q.notify(src, ('сюжет: шаг %d из %d'):format(st.step, #Story[st.line].steps), 'inform') end
    Q.storyObjective(src, st)
end
Q.advance = advance

-- права получены в автошколе / заказ доставлен — проверить шаг
function Q.storyCheck(src)
    local st = Q.get(src)
    local s = st and Q.current(st)
    if s and s.type == 'license' and hasLicense(src) then advance(src, st) end
end

function Q.storyJob(src)
    local st = Q.get(src)
    local s = st and Q.current(st)
    if not s or s.type ~= 'job' then return end
    st.jobCount = (st.jobCount or 0) + 1
    if st.jobCount >= s.count then
        Q.notify(src, 'задание по работе выполнено — смена закрыта, дальше по сюжету', 'success')
        advance(src, st)
        if Q.delivery and Q.delivery.active(src) then Q.delivery.stop(src) end
        return
    end
    Q.save(src, st)
    Q.notify(src, ('сюжет: заказов %d из %d'):format(st.jobCount, s.count), 'inform')
end

---------------------------------------------------------------------------
-- разговор по шагу. возвращает узел диалога или nil (у этого NPC сейчас нет шага)
---------------------------------------------------------------------------

local function bye(label) return { { id = 'bye', label = label or 'Понял' } } end

function Q.storyTalk(src, st, npcId, choice)
    local s = Q.current(st)
    if not s or s.npc ~= npcId or not TALKABLE[s.type] then return nil end

    if s.type == 'talk' then
        if s.options then
            local n = choice and tonumber(choice:match('^opt_(%d+)$'))
            local o = n and s.options[n]
            if o then
                advance(src, st, o.rep)
                return Q.node(npcId, o.reply, bye())
            end
            local opts = {}
            for i, opt in ipairs(s.options) do opts[#opts + 1] = { id = 'opt_' .. i, label = opt.label } end
            return Q.node(npcId, s.text, opts)
        end
        if choice == 'ok' then
            advance(src, st)
            return nil
        end
        return Q.node(npcId, s.text, { { id = 'ok', label = 'Понял' } })
    end

    if s.type == 'pay' then
        if choice == 'pay' then
            if not Q.pay(src, s.amount, ('сюжет: %s'):format(Config.Npcs[npcId].name)) then
                return Q.node(npcId, ('Нужно %s. Приходи, когда будут деньги.'):format(Q.money(s.amount)))
            end
            advance(src, st)
            return Q.node(npcId, 'Договорились.', bye())
        end
        return Q.node(npcId, s.text, { { id = 'pay', label = ('Заплатить %s'):format(Q.money(s.amount)) }, { id = 'bye', label = 'Потом' } })
    end

    if s.type == 'quiz' then
        local q = st.quiz
        if choice == 'start' or not q then
            if choice ~= 'start' then return Q.node(npcId, s.text, { { id = 'start', label = 'Давайте' }, { id = 'bye', label = 'Потом' } }) end
            st.quiz = { i = 1, ok = 0 }
            q = st.quiz
        elseif choice and choice:match('^ans_%d+$') then
            if tonumber(choice:sub(5)) == s.questions[q.i].ok then q.ok = q.ok + 1 end
            if q.i >= #s.questions then
                local okCount = q.ok
                st.quiz = nil
                if okCount >= s.pass then
                    advance(src, st, okCount - s.pass)
                    return Q.node(npcId, ('%d из %d. Годится.'):format(okCount, #s.questions), bye())
                end
                return Q.node(npcId, ('%d из %d. Мало. Подумай и приходи ещё.'):format(okCount, #s.questions),
                    { { id = 'start', label = 'Ещё раз' }, { id = 'bye', label = 'Потом' } })
            end
            q.i = q.i + 1
        end
        local item = s.questions[q.i]
        local opts = {}
        for i, a in ipairs(item.a) do opts[#opts + 1] = { id = 'ans_' .. i, label = a } end
        return Q.node(npcId, ('Вопрос %d из %d. %s'):format(q.i, #s.questions, item.q), opts)
    end

    if s.type == 'drive' then
        if choice == 'go' then
            local netId = Q.giveCar(src, s.car, s.spawn, false)
            if not netId then return Q.node(npcId, 'Машина не заводится. Подожди минуту и спроси ещё.') end
            local deadline = os.time() + s.minutes * 60
            local stepNow = st.step
            local list = {}
            for _, p in ipairs(s.points) do list[#list + 1] = p end
            if s.back then list[#list + 1] = npcPos(npcId) end
            st.driving = stepNow
            points(src, list, s.goal or 'Поездка', nil, function(p)
                local st2 = Q.get(p)
                Q.removeCar(p, netId)
                st2.driving = nil
                if st2.step ~= stepNow then return end
                if os.time() <= deadline then
                    Q.notify(p, 'успел вовремя', 'success')
                    advance(p, st2)
                else
                    -- опоздал: шаг засчитан, но без денег и с минусом к репутации
                    Q.notify(p, 'опоздал… денег за это не будет', 'error')
                    advance(p, st2, -1, true)
                end
            end, netId, deadline)
            return Q.node(npcId, ('Ключи твои. %d минут — время пошло.'):format(s.minutes), bye('Поехали'))
        end
        if st.driving == st.step and Q.objectives[src] then return Q.node(npcId, 'Ты почему здесь? Время идёт!') end
        return Q.node(npcId, s.text, { { id = 'go', label = 'Давай ключи' }, { id = 'bye', label = 'Потом' } })
    end

    if s.type == 'final' then
        local pick
        for _, c in ipairs(s.careers) do if choice == 'car_' .. c.id then pick = c end end
        if pick then
            if pick.locked then return Q.node(npcId, 'Это пока закрыто. Выбери другое.', nil) end
            local L = Story[st.line]
            st.career, st.title, st.lineDone = pick.id, L.title, true
            Q.reward(src, L.final, ('сюжет «%s»: финал'):format(L.label))
            local jobSet = false
            if pick.job and exports.qbx_core:GetJob(pick.job) then
                local ok = pcall(function() exports.qbx_core:SetJob(src, pick.job, pick.grade or 0) end)
                jobSet = ok
            end
            Q.objective(src, nil)
            Q.save(src, st)
            Q.notify(src, ('сюжет пройден: %s, титул «%s»%s'):format(Q.money(L.final), L.title,
                jobSet and ('. ты принят: ' .. pick.label) or ''), 'success')
            return Q.node(npcId, jobSet and 'Добро пожаловать. Завтра — первая смена. Не подведи.' or 'Решение принято. Удачи — и заходи, если что.', bye('Спасибо'))
        end
        local opts = {}
        for _, c in ipairs(s.careers) do opts[#opts + 1] = { id = 'car_' .. c.id, label = c.label .. (c.locked and ' (закрыто)' or '') } end
        return Q.node(npcId, ('%s (репутация: %d)'):format(s.text, st.rep or 0), opts)
    end
end

---------------------------------------------------------------------------
-- старт: 50 000 ₽ и выбор линии
---------------------------------------------------------------------------

local function budgetText()
    local t, sum = {}, 0
    for _, b in ipairs(Config.Budget) do
        t[#t + 1] = ('%s — %s'):format(b[1], Q.money(b[2]))
        sum = sum + b[2]
    end
    return table.concat(t, '; '), sum
end

function Q.startNode(src)
    local opts = {}
    for _, id in ipairs(LINES) do opts[#opts + 1] = { id = 'line_' .. id, label = Story[id].label .. ' — ' .. Story[id].intro } end
    local list, sum = budgetText()
    return {
        npc = 'start', name = 'Республика Нагорье',
        text = ('%s, ты вернулся на родину. В кармане %s. На первые два дня нужно примерно %s (%s), остальное — запас. Какой дорогой пойдёшь?')
            :format(Q.charName(src), Q.money(Config.StartMoney.cash + Config.StartMoney.bank), Q.money(sum), list),
        options = opts,
    }
end

function Q.giveStartMoney(src, st)
    if st.startMoney then return end
    st.startMoney = true
    exports.qbx_core:SetMoney(src, 'cash', Config.StartMoney.cash, 'старт: приехал на родину')
    exports.qbx_core:SetMoney(src, 'bank', Config.StartMoney.bank, 'старт: приехал на родину')
end

-- старые линии (home/work/study из прошлой версии) начинаем заново по новой схеме
local function migrate(st)
    if st.line and not Story[st.line] then st.line, st.step, st.lineDone = nil, nil, nil end
end

Q.handlers.start = function(src, st, choice)
    migrate(st)
    if st.line then return nil end
    local id = choice and choice:match('^line_(%a+)$')
    if not id or not Story[id] then return Q.startNode(src) end
    st.line, st.step, st.rep = id, 1, 0
    Q.notify(src, ('линия «%s». первым делом — скутер у Заура, он рядом'):format(Story[id].label), 'success')
    if st.afterRent then Q.storyObjective(src, st) else goTo(src, 'zaur', 'Арендуй скутер у Заура') end
    return nil
end

RegisterNetEvent('kavkaz_quests:server:begin', function()
    local src = source
    local st = Q.get(src)
    if not st then return end
    migrate(st)
    if st.line then return Q.save(src, st) end
    Q.giveStartMoney(src, st)
    Q.save(src, st)
    TriggerClientEvent('kavkaz_quests:client:dialog', src, Q.startNode(src))
end)

-- после перезахода: вернуть цель
function Q.storyResume(src)
    local st = Q.get(src)
    if not st then return end
    migrate(st)
    if not st.line or st.lineDone then return end
    if not st.afterRent then return goTo(src, 'zaur', 'Арендуй скутер у Заура') end
    st.driving, st.quiz = nil, nil
    Q.save(src, st)
    Q.storyObjective(src, st)
end

---------------------------------------------------------------------------
-- Заур: прокат скутеров (первый шаг любой линии)
---------------------------------------------------------------------------

Q.handlers.zaur = function(src, st, choice)
    local now = os.time()
    local active = (st.rent or 0) > now
    local R = Config.Rent

    if choice == 'rent' or choice == 'extend' then
        if not Q.pay(src, R.price, 'прокат скутера') then return Q.node('zaur', 'Брат, денег не хватает.') end
        st.rent = math.max(st.rent or 0, now) + R.hours * 3600
        if choice == 'rent' then st.scooterNet = Q.giveCar(src, Config.Cars.scooter, Config.Places.scooter, false) end
        if not st.afterRent then
            st.afterRent = true
            if st.line then Q.storyObjective(src, st) end
        end
        return Q.node('zaur', choice == 'rent' and 'Держи ключи, скутер вон стоит. Шлем не забудь, ДПС любит придраться.' or 'Продлил. Катайся.')
    end
    if choice == 'take' and active then
        local veh = st.scooterNet and NetworkGetEntityFromNetworkId(st.scooterNet)
        if veh and veh ~= 0 and DoesEntityExist(veh) then return Q.node('zaur', 'Так он у тебя уже есть.') end
        st.scooterNet = Q.giveCar(src, Config.Cars.scooter, Config.Places.scooter, false)
        return Q.node('zaur', 'Держи. Аренда ещё действует.')
    end
    if choice == 'return' and active then
        Q.removeCar(src, st.scooterNet)
        st.scooterNet, st.rent = nil, 0
        return Q.node('zaur', 'Принял. Приходи ещё.')
    end

    local opts = {}
    if active then
        opts[#opts + 1] = { id = 'take', label = ('Забрать мой скутер (аренда ещё %d ч)'):format(math.ceil((st.rent - now) / 3600)) }
        opts[#opts + 1] = { id = 'extend', label = ('Продлить на сутки — %s'):format(Q.money(R.price)) }
        opts[#opts + 1] = { id = 'return', label = 'Вернуть скутер' }
    else
        opts[#opts + 1] = { id = 'rent', label = ('Арендовать скутер на сутки — %s'):format(Q.money(R.price)) }
    end
    opts[#opts + 1] = { id = 'bye', label = 'До свидания' }
    return Q.node('zaur', 'Скутеры! Дёшево, быстро, по пробкам — лучше любой Камри. Сутки — полторы тысячи.', opts)
end
