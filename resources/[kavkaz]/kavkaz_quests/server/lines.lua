-- старт игрока: 50 000 ₽, выбор сюжетной линии, прокат скутера у Заура.
-- линии: home (Румиса, «Порог» в porog.lua), work (Бислан, сторож Висхан, капитан Адам), study (Иса, доктор Мадина).
-- все три заканчиваются у Заремы в автошколе (Q.lineFinale). шаг линий work/study — st.ls.

local npcPos = function(id) return Config.Npcs[id].coords.xyz end
local function goTo(src, npcId, text)
    Q.objective(src, { id = 'goto_' .. npcId, text = text, coords = npcPos(npcId), radius = 4.0, onReach = function() end })
end

---------------------------------------------------------------------------
-- выбор линии
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
    for _, id in ipairs({ 'home', 'work', 'study' }) do
        local l = Config.Lines[id]
        opts[#opts + 1] = { id = 'line_' .. id, label = ('%s — %s'):format(l.label, l.text) }
    end
    local list, sum = budgetText()
    return {
        npc = 'start', name = 'Республика Нагорье',
        text = ('%s, ты вернулся на родину. В кармане %s. На первые два дня нужно примерно %s: %s. Остальное — твой запас. Зачем ты приехал?')
            :format(Q.charName(src), Q.money(Config.StartMoney.cash + Config.StartMoney.bank), Q.money(sum), list),
        options = opts,
    }
end

Q.handlers.start = function(src, st, choice)
    if st.line then return nil end
    local id = choice and choice:match('^line_(%a+)$')
    if not id or not Config.Lines[id] then return Q.startNode(src) end
    st.line = id
    st.ls = (id ~= 'home') and 0 or nil
    Q.notify(src, ('линия «%s». первым делом — скутер у Заура, он рядом'):format(Config.Lines[id].label), 'success')
    goTo(src, 'zaur', 'Арендуй скутер у Заура')
    return nil
end

-- стартовые деньги — один раз на персонажа
local function giveStartMoney(src, st)
    if st.startMoney then return end
    st.startMoney = true
    exports.qbx_core:SetMoney(src, 'cash', Config.StartMoney.cash, 'старт: приехал на родину')
    exports.qbx_core:SetMoney(src, 'bank', Config.StartMoney.bank, 'старт: приехал на родину')
end

-- после памятки (или по просьбе Ислама): если линия не выбрана — показать выбор
RegisterNetEvent('kavkaz_quests:server:begin', function()
    local src = source
    local st = Q.get(src)
    if not st or st.line then return end
    -- старые персонажи, которые начали «Порог» до появления линий, остаются в линии home
    if st.porog and st.porog > 0 then
        st.line = 'home'
        return Q.save(src, st)
    end
    giveStartMoney(src, st)
    Q.save(src, st)
    TriggerClientEvent('kavkaz_quests:client:dialog', src, Q.startNode(src))
end)

---------------------------------------------------------------------------
-- Заур: прокат скутеров
---------------------------------------------------------------------------

local function nextAfterRent(src, st)
    if st.afterRent then return end
    st.afterRent = true
    if st.line == 'home' then goTo(src, 'rumisa', 'Чайхана «У Румисы»: тебя ждут в Старом городе')
    elseif st.line == 'work' then st.ls = 1 goTo(src, 'bislan', 'Гараж Бислана в промзоне: там нужны руки')
    elseif st.line == 'study' then st.ls = 1 goTo(src, 'isa', 'Университет: Иса Медович ждёт нового студента') end
end

Q.handlers.zaur = function(src, st, choice)
    local now = os.time()
    local active = (st.rent or 0) > now
    local R = Config.Rent

    if choice == 'rent' or choice == 'extend' then
        if not Q.pay(src, R.price, 'прокат скутера') then return Q.node('zaur', 'Брат, денег не хватает.') end
        st.rent = math.max(st.rent or 0, now) + R.hours * 3600
        if choice == 'rent' then
            local netId = Q.giveCar(src, Config.Cars.scooter, Config.Places.scooter, false)
            st.scooterNet = netId
        end
        nextAfterRent(src, st)
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
        local hours = math.ceil((st.rent - now) / 3600)
        opts[#opts + 1] = { id = 'take', label = ('Забрать мой скутер (аренда ещё %d ч)'):format(hours) }
        opts[#opts + 1] = { id = 'extend', label = ('Продлить на сутки — %s'):format(Q.money(R.price)) }
        opts[#opts + 1] = { id = 'return', label = 'Вернуть скутер' }
    else
        opts[#opts + 1] = { id = 'rent', label = ('Арендовать скутер на сутки — %s'):format(Q.money(R.price)) }
    end
    opts[#opts + 1] = { id = 'bye', label = 'До свидания' }
    return Q.node('zaur', 'Скутеры! Дёшево, быстро, по пробкам — лучше любой Камри. Сутки — полторы тысячи.', opts)
end

---------------------------------------------------------------------------
-- линия «На заработки»: Бислан -> свалка -> тест-драйв -> капитан Адам -> автошкола
---------------------------------------------------------------------------

local W = Config.Work

Q.handlers.bislan = function(src, st, choice)
    if st.line ~= 'work' or (st.ls or 0) < 1 then
        return Q.node('bislan', 'Брат, тебе Хазард? Только ДПС не говори, что от меня. (заходи позже — будет работа)')
    end
    if st.ls == 1 then
        if choice == 'scrap' then
            st.ls = 2
            goTo(src, 'guard', 'Свалка: договорись со сторожем Висханом')
            return Q.node('bislan', ('Езжай на свалку к Висхану, скажи — от Бислана. Возьми генератор и два поршня. Он попросит %s — не торгуйся, свой человек.'):format(Q.money(W.scrapCost)))
        end
        return Q.node('bislan', 'Новенький? Руки откуда растут? Ладно, проверим. Мне запчасти нужны со свалки, а сам не успеваю — у меня тут «Приора» без глушителя.',
            { { id = 'scrap', label = 'Съезжу за запчастями' }, { id = 'bye', label = 'Потом' } })
    end
    if st.ls == 2 then return Q.node('bislan', 'Ты ещё не был на свалке? Висхан ждёт.') end
    if st.ls == 3 then
        if choice == 'test' then
            local netId = Q.giveCar(src, Config.Cars.client, vec4(735.0, -1080.0, 22.0, 270.0), false)
            if not netId then return Q.node('bislan', 'Машина не заводится, подожди минуту.') end
            st.ls = 4
            local deadline = os.time() + W.testMinutes * 60
            Q.objective(src, {
                id = 'test_out', text = 'Тест-драйв: доедь до пирса Дель-Перро', coords = Config.Places.testdrive, radius = 10.0, vehNet = netId, deadline = deadline,
                onReach = function(s)
                    Q.objective(s, {
                        id = 'test_back', text = 'Тест-драйв: верни машину Бислану', coords = npcPos('bislan'), radius = 10.0, vehNet = netId, deadline = deadline,
                        onReach = function(s2)
                            local st2 = Q.get(s2)
                            Q.removeCar(s2, netId)
                            if os.time() <= deadline then
                                Q.reward(s2, W.testReward, 'линия «На заработки»: тест-драйв')
                                Q.notify(s2, 'машина в порядке, Бислан доволен', 'success')
                            else
                                Q.notify(s2, 'долго катался… клиент уже звонил. Бислан не заплатил', 'error')
                            end
                            st2.ls = 5
                            Q.save(s2, st2)
                            goTo(s2, 'adam', 'Отвези пирожки капитану Адаму (ГУ МВД)')
                        end,
                    })
                end,
            })
            return Q.node('bislan', ('Клиент говорит — стучит. Прокатись до пирса и обратно, послушай. %d минут, не гоняй!'):format(W.testMinutes))
        end
        Q.reward(src, W.scrapReward, 'линия «На заработки»: запчасти')
        return Q.node('bislan', ('О, генератор как новый! Держи %s. Слушай, ещё дело есть.'):format(Q.money(W.scrapReward)),
            { { id = 'test', label = 'Какое?' } })
    end
    if st.ls == 4 then
        if not Q.objectives[src] then st.ls = 3 return Q.handlers.bislan(src, st, nil) end
        return Q.node('bislan', 'Ты чего тут? Машину на тест-драйв, до пирса и обратно!')
    end
    if st.ls == 5 then return Q.node('bislan', 'Отвези пирожки Адаму, говорю. Он хоть и «Тауметр», но человек хороший. Когда сытый.') end
    return Q.node('bislan', 'Будет работа — позову. Права получил? Молодец.')
end

Q.handlers.guard = function(src, st, choice)
    if st.line ~= 'work' or st.ls ~= 2 then return Q.node('guard', 'Чего надо? Свалка закрыта. Для чужих.') end
    if st.scrapPaid then return Q.node('guard', 'Ищи там, в куче у забора.') end
    if choice == 'pay' then
        if not Q.pay(src, W.scrapCost, 'свалка: запчасти для Бислана') then return Q.node('guard', 'Без денег — без запчастей.') end
        st.scrapPaid = true
        Q.objective(src, {
            id = 'scrap', text = 'Найди генератор и поршни в куче у забора', coords = Config.Places.scrap, radius = 3.0, anim = 'search',
            onReach = function(s)
                local st2 = Q.get(s)
                st2.ls, st2.scrapPaid = 3, nil
                Q.save(s, st2)
                Q.notify(s, 'запчасти у тебя. вези Бислану', 'success')
                goTo(s, 'bislan', 'Отвези запчасти Бислану')
            end,
        })
        return Q.node('guard', 'Вон куча у забора. Генератор синий, поршни в ящике. Бислану привет.')
    end
    return Q.node('guard', 'От Бислана? Ну… генератор и поршни есть. Только бесплатно не бывает.',
        { { id = 'pay', label = ('Заплатить %s'):format(Q.money(W.scrapCost)) }, { id = 'bye', label = 'Потом' } })
end

Q.handlers.adam = function(src, st, choice)
    if st.line ~= 'work' or st.ls ~= 5 then
        return Q.node('adam', 'Тонировка? Номер? Документы? …А, ты пешком. Ладно, иди.')
    end
    if choice == 'right' or choice == 'wrong' then
        st.ls = 6
        Q.reward(src, W.adamReward, 'линия «На заработки»: пирожки для Адама')
        goTo(src, 'zarema', 'Получи права: автошкола у мэрии')
        if choice == 'right' then
            return Q.node('adam', 'Правильно. Видишь, не все у Бислана безнадёжные. Запомни: номер — в МРЭО, штрафы — /fines, тонировку «в ноль» сниму прямо на месте. И без прав за руль не садись — иди к Зареме.')
        end
        return Q.node('adam', 'Неправильно! «В ноль» — штраф и снятие на месте. Учись, пока я добрый. Номер — в МРЭО, штрафы — /fines. И к Зареме за правами, бегом.')
    end
    return Q.node('adam', 'Пирожки? От Бислана? …Подкупить решил? Шучу. Раз пришёл — вопрос: тонировка передних стёкол «в ноль», это как?',
        { { id = 'right', label = 'Нарушение: штраф и снятие плёнки' }, { id = 'wrong', label = 'Нормально, если красиво' } })
end

---------------------------------------------------------------------------
-- линия «На учёбу»: Иса -> пробы воды -> доктор Мадина -> травы -> опыт -> автошкола
---------------------------------------------------------------------------

local S = Config.Study

local function chain(src, points, label, anim, idPrefix, onDone)
    local function step(i)
        Q.objective(src, {
            id = idPrefix .. i, text = ('%s %d из %d'):format(label, i, #points), coords = points[i], radius = 6.0, anim = anim,
            onReach = function(s) if i < #points then step(i + 1) else onDone(s) end end,
        })
    end
    step(1)
end

function Q.studyIsa(src, st, choice)
    if st.ls == 1 then
        if choice == 'water' then
            st.ls = 2
            chain(src, Config.Places.water, 'Проба воды', 'sample', 'water_', function(s)
                local st2 = Q.get(s)
                st2.ls = 3
                Q.save(s, st2)
                goTo(s, 'isa', 'Отвези пробы Исе Медовичу')
            end)
            return Q.node('isa', 'Первое задание студента — полевое! Пробы воды: пляж, каналы, озеро в Миррор-парке. Пробирки в сумке. Не пей из них.')
        end
        return Q.node('isa', 'Новый студент! Прекрасно. Я Иса Медович. Химия — это просто, если не взрывается. А если взрывается — это уже физика. Начнём?',
            { { id = 'water', label = 'Начнём' }, { id = 'bye', label = 'Позже' } })
    end
    if st.ls == 2 then return Q.node('isa', 'Пробы ещё не все. Три пробирки — три места.') end
    if st.ls == 3 then
        if choice == 'madina' then
            st.ls = 4
            goTo(src, 'madina', 'Отвези мазь доктору Мадине (больница)')
            return Q.node('isa', 'Отвези доктору Мадине мою мазь. На мёде! Всё на свете лечится мёдом. Почти всё.')
        end
        Q.reward(src, S.waterReward, 'линия «На учёбу»: пробы воды')
        return Q.node('isa', ('Вода чистая! Кроме каналов — там… жизнь. Держи %s стипендии. Есть поручение.'):format(Q.money(S.waterReward)),
            { { id = 'madina', label = 'Какое?' } })
    end
    if st.ls == 4 then return Q.node('isa', 'Мазь — доктору Мадине, в больницу.') end
    if st.ls == 5 then return Q.node('isa', 'Травы нужны с холмов у обсерватории. Три пучка.') end
    if st.ls == 6 then
        local right = choice == 'mix_ok'
        if choice and choice:sub(1, 4) == 'mix_' then
            if not right then
                return Q.node('isa', 'ПФФ! …Фиолетовый дым. Ничего, бывает. Брови отрастут. Ещё раз: в каком порядке?',
                    { { id = 'mix_a', label = 'Травы → мёд → вода' }, { id = 'mix_ok', label = 'Вода → травы → мёд' }, { id = 'mix_b', label = 'Мёд → вода → травы' } })
            end
            st.ls = 7
            Q.reward(src, S.herbsReward, 'линия «На учёбу»: мазь')
            goTo(src, 'zarema', 'Получи права: автошкола у мэрии')
            return Q.node('isa', ('Идеально! Мазь как у меня в молодости. Держи %s. И вот что: студенту нужны права, приборы возить. Иди к Зареме Поворотовне.'):format(Q.money(S.herbsReward)))
        end
        return Q.node('isa', 'Травы! Теперь опыт. В каком порядке смешиваем для мази?',
            { { id = 'mix_a', label = 'Травы → мёд → вода' }, { id = 'mix_ok', label = 'Вода → травы → мёд' }, { id = 'mix_b', label = 'Мёд → вода → травы' } })
    end
    if st.ls == 7 then return Q.node('isa', 'Права, права! Зарема Поворотовна ждёт.') end
    return Q.node('isa', 'Заходи на опыты. Только не трогай зелёную колбу.')
end

Q.handlers.madina = function(src, st, choice)
    if st.line ~= 'study' or (st.ls ~= 4) then
        return Q.node('madina', 'Здравствуйте. Если плохо — проходите в приёмный покой. Если хорошо — тем более приходите на медосмотр.')
    end
    if choice == 'herbs' then
        st.ls = 5
        chain(src, Config.Places.herbs, 'Пучок трав', 'search', 'herbs_', function(s)
            local st2 = Q.get(s)
            st2.ls = 6
            Q.save(s, st2)
            goTo(s, 'isa', 'Отвези травы Исе Медовичу')
        end)
        return Q.node('madina', 'Чабрец, зверобой и мята растут на холмах у обсерватории. Соберите три пучка для Исы — мазь нужна больнице.')
    end
    Q.reward(src, S.madinaReward, 'линия «На учёбу»: мазь для больницы')
    return Q.node('madina', ('Опять мёд? Иса неисправим. Но мазь работает, это правда. Спасибо — %s. Передайте ему: нужно больше, и травы свежие.'):format(Q.money(S.madinaReward)),
        { { id = 'herbs', label = 'Где взять травы?' } })
end

---------------------------------------------------------------------------
-- финал любой линии у Заремы
---------------------------------------------------------------------------

function Q.lineReady(st)
    return (st.line == 'home' and st.porog == 6) or (st.line == 'work' and st.ls == 6) or (st.line == 'study' and st.ls == 7)
end

function Q.lineFinale(src, st)
    local L = Config.Lines[st.line]
    st.title = L.title
    st.lineDone = true
    if st.line == 'home' then st.porog = 7 Q.trust(src, st, 10) else st.ls = 99 end
    Q.reward(src, L.final, 'сюжет: ' .. L.label)
    Q.objective(src, nil)
    Q.notify(src, ('линия «%s» пройдена: %s, титул «%s». дальше — права и своя жизнь'):format(L.label, Q.money(L.final), L.title), 'success')
end
