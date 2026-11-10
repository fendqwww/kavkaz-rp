-- линия «Порог» (Румиса Халвовна), базар, Иса Медович, Ислам. docs/vision/06-quests.md

local P = Config.Porog
local npcPos = function(id) return Config.Npcs[id].coords.xyz end

local function goTo(src, npcId, text)
    Q.objective(src, { id = 'goto_' .. npcId, text = text, coords = npcPos(npcId), radius = 4.0, onReach = function() end })
end

function Q.setWash(src)
    Q.objective(src, {
        id = 'wash', text = 'Помой руки у рукомойника возле чайханы', coords = Config.Places.sink, radius = 2.0, anim = 'wash',
        onReach = function(s)
            local st = Q.get(s)
            st.washed = true
            Q.save(s, st)
            Q.notify(s, 'руки чистые. возвращайся к Румисе', 'success')
            goTo(s, 'rumisa', 'Вернись к Румисе Халвовне')
        end,
    })
end

local function listText()
    local t = {}
    for _, it in pairs(P.list) do t[#t + 1] = it.label end
    table.sort(t)
    return table.concat(t, ', ')
end

---------------------------------------------------------------------------
-- Румиса Халвовна
---------------------------------------------------------------------------

local function rumisaMenu(src, st, text)
    local opts = {}
    if Q.delivery and Q.delivery.active(src) then
        opts[#opts + 1] = { id = 'job_stop', label = 'Закончить смену доставки' }
    else
        opts[#opts + 1] = { id = 'job_start', label = 'Работа: развозить обеды' }
    end
    if st.isaDay ~= Q.today() and not st.lunch then
        opts[#opts + 1] = { id = 'isa_lunch', label = ('Отнести обед Исе (сегодня, %s)'):format(Q.money(Config.IsaLunch.reward)) }
    end
    opts[#opts + 1] = { id = 'trust', label = 'Как я у вас, Румиса Халвовна?' }
    opts[#opts + 1] = { id = 'bye', label = 'До свидания' }
    return Q.node('rumisa', text or 'Ну что, работать пришёл или чай пить?', opts)
end

Q.handlers.rumisa = function(src, st, choice)
    local name = Q.charName(src)
    -- игроки других линий: у Румисы только работа и ежедневка
    if st.line and st.line ~= 'home' then
        if choice == 'job_start' and Q.delivery then return rumisaMenu(src, st, Q.delivery.start(src)) end
        if choice == 'job_stop' and Q.delivery then return rumisaMenu(src, st, Q.delivery.stop(src)) end
        if choice == 'isa_lunch' and st.isaDay ~= Q.today() then
            st.lunch = true
            goTo(src, 'isa', 'Отнеси обед Исе Медовичу')
            return Q.node('rumisa', 'Отнеси Исе обед. И смотри, чтобы съел!', { { id = 'bye', label = 'Отнесу' } })
        end
        if choice == 'trust' then return rumisaMenu(src, st, ('Посмотрим на тебя… (доверие: %d)'):format(st.trust)) end
        return rumisaMenu(src, st, ('Ты %s? Слышала. Голодный — садись. Работа нужна — тоже есть.'):format(name))
    end
    st.line = st.line or 'home'

    -- шаг 0: знакомство
    if st.porog == 0 then
        if choice == 'wash' then
            st.porog = 1
            Q.setWash(src)
            return Q.node('rumisa', 'Вот и правильно. Рукомойник за углом. Чистые руки — потом разговор.', { { id = 'bye', label = 'Иду' } })
        end
        return Q.node('rumisa', ('Ты новенький? %s, значит. Проходи… Стой! Руки помыл? С улицы — и сразу за стол?'):format(name),
            { { id = 'wash', label = 'Простите, сейчас помою' }, { id = 'bye', label = 'Я потом зайду' } })
    end

    -- шаг 1: помыл руки -> обед, награда, список на базар
    if st.porog == 1 then
        if not st.washed then
            Q.setWash(src)
            return Q.node('rumisa', 'Руки, говорю! Рукомойник за углом.')
        end
        if choice == 'list' then
            st.porog = 2
            st.bag = {}
            goTo(src, 'v_greens', 'Базар: купи ' .. listText())
            return Q.node('rumisa', ('Запомни: %s. Не перепутай — тётя Хеда любит подсунуть не то.'):format(listText()), { { id = 'bye', label = 'Пошёл на базар' } })
        end
        Q.reward(src, P.washReward, 'квест: Руки помыл?')
        Q.trust(src, st, 2)
        return Q.node('rumisa', ('Вот, садись, ешь. Хингалш с тыквой, горячий. Держи %s — на первое время. А теперь помоги мне: сходи на базар.')
            :format(Q.money(P.washReward)), { { id = 'list', label = 'Что купить?' } })
    end

    -- шаг 2: проверка покупок
    if st.porog == 2 then
        local wrong, missing = {}, {}
        for id, it in pairs(P.wrong) do if st.bag[id] then wrong[#wrong + 1] = it.label; st.bag[id] = nil end end
        for id, it in pairs(P.list) do if not st.bag[id] then missing[#missing + 1] = it.label end end
        if #wrong > 0 then
            Q.trust(src, st, -1)
            return Q.node('rumisa', ('Это что? %s? Я такого не просила. Отдай соседям, а мне неси то, что сказала.'):format(table.concat(wrong, ', ')),
                { { id = 'bye', label = 'Понял, исправлю' } })
        end
        if #missing > 0 then
            return Q.node('rumisa', 'Ещё не всё. Нужно: ' .. table.concat(missing, ', ') .. '.')
        end
        if choice == 'take' then
            st.porog, st.bag, st.lunch = 3, {}, true
            Q.trust(src, st, 2)
            goTo(src, 'isa', 'Отнеси обед Исе Медовичу (университет)')
            return Q.node('rumisa', 'Молодец, всё правильно. А теперь отнеси обед Исе Медовичу, в университет. И проследи, чтобы съел! Он у меня совсем худой со своей химией.',
                { { id = 'bye', label = 'Отнесу' } })
        end
        return Q.node('rumisa', 'Так… зелень, тыква, творог, баранина. Всё на месте, свежее. Хорошо выбрал.', { { id = 'take', label = 'Что дальше?' } })
    end

    -- шаг 3: ждём, пока Иса поест
    if st.porog == 3 then
        return Q.node('rumisa', 'Ты ещё здесь? Обед остынет! Иса в университете.')
    end

    -- шаг 4: машина и заказ в Лам-Юрт
    if st.porog == 4 then
        if choice == 'car' then
            local netId = Q.giveCar(src, Config.Cars.rumisa, Config.Places.car, false)
            if not netId then return Q.node('rumisa', 'Машина не заводится… Подожди минуту и спроси ещё раз.') end
            st.porog = 5
            st.carNet = netId
            local deadline = os.time() + P.deliveryMinutes * 60
            Q.objective(src, {
                id = 'lamyurt', text = ('Отвези заказ в Лам-Юрт на машине Румисы (%d мин)'):format(P.deliveryMinutes),
                coords = Config.Places.lamyurt, radius = 8.0, vehNet = netId, deadline = deadline,
                onReach = function(s)
                    local st2 = Q.get(s)
                    if os.time() <= deadline then
                        Q.trust(s, st2, 3)
                        Q.notify(s, 'успел! заказ доставлен', 'success')
                    else
                        Q.trust(s, st2, -1)
                        Q.notify(s, 'опоздал… Румиса это запомнит', 'error')
                    end
                    st2.porog = 6
                    Q.save(s, st2)
                    goTo(s, 'zarema', 'Румиса велела получить права: автошкола у мэрии')
                end,
            })
            return Q.node('rumisa', ('Вот ключи от моей старушки. Отвези заказ в Лам-Юрт, у банка ждут. Даю тебе %d минут — горячее должно быть горячим.')
                :format(P.deliveryMinutes), { { id = 'bye', label = 'Уже еду' } })
        end
        return Q.node('rumisa', 'Иса поел? Ну слава Аллаху. Ты, я смотрю, парень надёжный. Есть дело: заказ в Лам-Юрт, на моей машине.',
            { { id = 'car', label = 'Давайте ключи' }, { id = 'bye', label = 'Чуть позже' } })
    end

    if st.porog == 5 then
        local obj = Q.objectives[src]
        if not obj then
            -- после перезахода: машина пропала — даём ещё раз
            st.porog = 4
            return Q.handlers.rumisa(src, st, nil)
        end
        return Q.node('rumisa', 'Ты почему здесь? Заказ в Лам-Юрт ждёт!')
    end

    if st.porog == 6 then
        return Q.node('rumisa', 'Хорошо съездил. Но без прав больше не пущу за руль! Иди к Зареме Поворотовне в автошколу, у мэрии.')
    end

    -- после линии: работа, ежедневка, доверие
    if choice == 'job_start' and Q.delivery then return rumisaMenu(src, st, Q.delivery.start(src)) end
    if choice == 'job_stop' and Q.delivery then return rumisaMenu(src, st, Q.delivery.stop(src)) end
    if choice == 'isa_lunch' and st.isaDay ~= Q.today() then
        st.lunch = true
        goTo(src, 'isa', 'Отнеси обед Исе Медовичу')
        return Q.node('rumisa', 'Опять он забыл поесть. Отнеси, и смотри, чтобы съел!', { { id = 'bye', label = 'Отнесу' } })
    end
    if choice == 'trust' then
        local t = st.trust
        local word = t >= 30 and 'Ты мне как родной.' or t >= 15 and 'Свой человек.' or t >= 5 and 'Неплохо. Работай дальше.' or 'Посмотрим на тебя…'
        return rumisaMenu(src, st, ('%s (доверие: %d)'):format(word, t))
    end
    return rumisaMenu(src, st)
end

---------------------------------------------------------------------------
-- базар
---------------------------------------------------------------------------

local function vendor(npcId)
    return function(src, st, choice)
        if st.porog ~= 2 then
            return Q.node(npcId, 'Заходи, дорогой! Всё свежее, с гор. (сейчас ничего не нужно)')
        end
        local goods = {}
        for id, it in pairs(P.list) do if it.vendor == npcId then goods[id] = it end end
        for id, it in pairs(P.wrong) do if it.vendor == npcId then goods[id] = it end end

        local msg = 'Что берёшь?'
        if choice and goods[choice] then
            local it = goods[choice]
            if st.bag[choice] then
                msg = 'Это у тебя уже есть.'
            elseif not Q.pay(src, it.price, 'базар: ' .. it.label) then
                msg = 'Денег не хватает, дорогой.'
            else
                st.bag[choice] = true
                msg = ('Держи, %s — лучшее на базаре. Что ещё?'):format(it.label)
            end
        end
        local opts = {}
        for id, it in pairs(goods) do
            if not st.bag[id] then opts[#opts + 1] = { id = id, label = ('%s — %s'):format(it.label, Q.money(it.price)) } end
        end
        table.sort(opts, function(a, b) return a.label < b.label end)
        opts[#opts + 1] = { id = 'bye', label = 'Спасибо, всё' }
        return Q.node(npcId, msg, opts)
    end
end
Q.handlers.v_greens = vendor('v_greens')
Q.handlers.v_dairy = vendor('v_dairy')
Q.handlers.v_meat = vendor('v_meat')

---------------------------------------------------------------------------
-- Иса Медович
---------------------------------------------------------------------------

Q.handlers.isa = function(src, st, choice)
    if st.line == 'study' and (st.ls or 0) >= 1 and st.ls < 99 and not st.lunch then
        return Q.studyIsa(src, st, choice)
    end
    if not st.lunch then
        return Q.node('isa', 'Осторожно, не трогай колбу! Это… просто чай. Зелёный. Очень зелёный. Заходи, когда будет время — покажу опыты.')
    end
    -- обед из линии «Порог»
    if st.porog == 3 then
        if choice == 'press' or choice == 'leave' or choice == 'eat' then
            st.lunch = false
            st.porog = 4
            if choice == 'press' then
                Q.trust(src, st, 2)
                Q.notify(src, 'Иса всё съел. Румиса будет довольна', 'success')
            elseif choice == 'leave' then
                Q.trust(src, st, -1)
                Q.notify(src, 'обед остался на столе рядом с колбами…', 'error')
            else
                Q.trust(src, st, -2)
                Q.notify(src, 'вкусно… но Румиса узнает', 'error')
            end
            Q.objective(src, { id = 'goto_rumisa', text = 'Вернись к Румисе', coords = npcPos('rumisa'), radius = 4.0, onReach = function() end })
            return Q.node('isa', choice == 'press' and 'Ладно-ладно, ем! Передай Румисе спасибо. И что я ем. Особенно что ем.' or 'Угу… потом… реакция идёт…')
        end
        return Q.node('isa', 'Обед? От Румисы? Я сейчас не могу, у меня реакция! Поставь куда-нибудь… только не на горелку.', {
            { id = 'press', label = 'Румиса сказала: пока не съедите — не уйду' },
            { id = 'leave', label = 'Ладно, оставлю здесь' },
            { id = 'eat', label = 'Может, я съем? Никто не узнает' },
        })
    end
    -- ежедневный обед
    st.lunch = false
    st.isaDay = Q.today()
    Q.reward(src, Config.IsaLunch.reward, 'ежедневка: обед для Исы')
    Q.trust(src, st, Config.IsaLunch.trust)
    Q.objective(src, nil)
    return Q.node('isa', ('Опять она меня кормит… Спасибо! Вот, возьми %s за дорогу.'):format(Q.money(Config.IsaLunch.reward)))
end

---------------------------------------------------------------------------
-- Ислам: подсказки новичку
---------------------------------------------------------------------------

Q.handlers.islam = function(src, st, choice)
    -- линия ещё не выбрана — Ислам предлагает начать
    if not st.line and (st.porog or 0) == 0 then
        if choice == 'begin' then
            if not st.startMoney then
                st.startMoney = true
                exports.qbx_core:SetMoney(src, 'cash', Config.StartMoney.cash, 'старт: приехал на родину')
                exports.qbx_core:SetMoney(src, 'bank', Config.StartMoney.bank, 'старт: приехал на родину')
            end
            return Q.startNode(src)
        end
        return Q.node('islam', ('Салам, %s! Только приехал? Расскажи, зачем вернулся — подскажу, с чего начать.'):format(Q.charName(src)),
            { { id = 'begin', label = 'Выбрать, зачем я приехал' }, { id = 'bye', label = 'Потом' } })
    end
    local opts = {}
    for _, t in ipairs(Config.Islam) do opts[#opts + 1] = { id = t.id, label = t.label } end
    opts[#opts + 1] = { id = 'bye', label = 'Спасибо, брат' }
    for _, t in ipairs(Config.Islam) do
        if t.id == choice then return Q.node('islam', t.text, opts) end
    end
    return Q.node('islam', ('Салам, %s! Я Ислам, всех тут знаю. Спрашивай.'):format(Q.charName(src)), opts)
end
