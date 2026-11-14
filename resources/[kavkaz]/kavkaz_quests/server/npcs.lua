-- постоянные NPC вне сюжета: Румиса (работа, ежедневка, доверие), Иса (ежедневный обед), Ислам (подсказки, старт),
-- продавцы базара и все остальные — обычная реплика (idle из конфига).

local function goTo(src, npcId, text)
    local c = Config.Npcs[npcId].coords.xyz
    Q.objective(src, { id = 'goto_' .. npcId, text = text, coords = c, radius = 4.0, onReach = function() end })
end

local function rumisaMenu(src, st, text)
    local opts = {}
    if Q.delivery and Q.delivery.active(src) then
        opts[#opts + 1] = { id = 'job_stop', label = 'Закончить смену доставки' }
    else
        opts[#opts + 1] = { id = 'job_start', label = ('Работа: развозить обеды (%s за заказ)'):format(Q.money(Config.Delivery.pay)) }
    end
    if st.isaDay ~= Q.today() and not st.lunch then
        opts[#opts + 1] = { id = 'isa_lunch', label = ('Отнести обед Исе (раз в день, %s)'):format(Q.money(Config.IsaLunch.reward)) }
    end
    if not st.starterCar then
        opts[#opts + 1] = { id = 'starter_car', label = 'Румиса Халвовна, мне бы машину…' }
    end
    opts[#opts + 1] = { id = 'trust', label = 'Как я у вас, Румиса Халвовна?' }
    opts[#opts + 1] = { id = 'bye', label = 'До свидания' }
    return Q.node('rumisa', text or 'Ну что, работать пришёл или чай пить?', opts)
end

local function hasLicense(src)
    local ok, count = pcall(function() return exports.ox_inventory:Search(src, 'count', 'driver_license') end)
    return ok and (count or 0) > 0
end

-- старая «Семёрка» Румисы — первая машина новичка (Config.StarterCar)
local function starterCar(src, st)
    local cfg = Config.StarterCar
    if st.starterCar then return rumisaMenu(src, st, 'Семёрку я тебе уже отдала. Береги её!') end
    if not hasLicense(src) then
        return rumisaMenu(src, st, 'Машину? А права у тебя есть? Сначала к Зареме Поворотовне в автошколу, потом поговорим.')
    end
    if (st.trust or 0) < cfg.trust then
        return rumisaMenu(src, st, ('Машину не каждому доверю. Поработай у меня, помоги Исе — тогда посмотрим. (доверие %d из %d)'):format(st.trust or 0, cfg.trust))
    end
    if GetResourceState('kavkaz_cars') ~= 'started' then return rumisaMenu(src, st, 'Ключи куда-то задевала… Приходи попозже.') end
    st.starterCar = true -- сразу, чтобы двойное нажатие не выдало две машины
    Q.save(src, st)
    local id, err = exports.kavkaz_cars:GiveCar(src, cfg.car, { garage = cfg.garage, reason = 'quest_rumisa' })
    if not id then
        print(('[kavkaz_quests] Семёрка не выдана %s: %s'):format(GetPlayerName(src) or src, tostring(err)))
        st.starterCar = nil
        Q.save(src, st)
        return rumisaMenu(src, st, 'Ключи куда-то задевала… Приходи попозже.')
    end
    Q.notify(src, '«Семёрка» Румисы в гараже у мотеля. номер оформи в МРЭО ГИБДД у мэрии', 'success')
    return Q.node('rumisa', 'Вот, держи ключи от моей старой Семёрки. Муж на ней ещё на базар ездил. Не гоняй, номер в МРЭО оформи — и чтобы без тонировки «в ноль»!',
        { { id = 'bye', label = 'Спасибо, Румиса Халвовна!' } })
end

Q.handlers.rumisa = function(src, st, choice)
    if choice == 'job_start' and Q.delivery then return rumisaMenu(src, st, Q.delivery.start(src)) end
    if choice == 'job_stop' and Q.delivery then return rumisaMenu(src, st, Q.delivery.stop(src)) end
    if choice == 'isa_lunch' and st.isaDay ~= Q.today() then
        st.lunch = true
        goTo(src, 'isa', 'Отнеси обед Исе Медовичу')
        return Q.node('rumisa', 'Опять он забыл поесть. Отнеси, и смотри, чтобы съел!', { { id = 'bye', label = 'Отнесу' } })
    end
    if choice == 'starter_car' then return starterCar(src, st) end
    if choice == 'trust' then
        local t = st.trust or 0
        local word = t >= 30 and 'Ты мне как родной.' or t >= 15 and 'Свой человек.' or t >= 5 and 'Неплохо. Работай дальше.' or 'Посмотрим на тебя…'
        return rumisaMenu(src, st, ('%s (доверие: %d)'):format(word, t))
    end
    return rumisaMenu(src, st)
end

Q.handlers.isa = function(src, st, choice)
    if not st.lunch then
        return Q.node('isa', 'Осторожно, не трогай колбу! Это… просто чай. Зелёный. Очень зелёный.')
    end
    st.lunch = false
    st.isaDay = Q.today()
    Q.reward(src, Config.IsaLunch.reward, 'ежедневка: обед для Исы')
    Q.trust(src, st, Config.IsaLunch.trust)
    Q.objective(src, nil)
    Q.storyResume(src)
    return Q.node('isa', ('Опять она меня кормит… Спасибо! Вот, возьми %s за дорогу.'):format(Q.money(Config.IsaLunch.reward)))
end

Q.handlers.islam = function(src, st, choice)
    if not st.line then
        if not st.homeDone then
            -- ещё не был у дяди: сюжет начинается с него (Story.home)
            if choice == 'begin' then
                Q.startHome(src, st)
                return Q.node('islam', 'Дядя Хамзат тебя ищет, весь двор уже знает. Метку поставил — иди.', { { id = 'bye', label = 'Спасибо' } })
            end
            return Q.node('islam', ('Салам, %s! Ты же внук Шамсудина? Тебя дядя Хамзат ищет.'):format(Q.charName(src)),
                { { id = 'begin', label = 'Где он?' }, { id = 'bye', label = 'Потом' } })
        end
        if choice == 'begin' then
            Q.giveStartMoney(src, st)
            return Q.startNode(src)
        end
        return Q.node('islam', ('Салам, %s! Кого из книжки деда навестишь следующим? Подскажу, с чего начать.'):format(Q.charName(src)),
            { { id = 'begin', label = 'Выбрать, к кому идти' }, { id = 'bye', label = 'Потом' } })
    end
    local opts = {}
    for _, t in ipairs(Config.Islam) do opts[#opts + 1] = { id = t.id, label = t.label } end
    opts[#opts + 1] = { id = 'bye', label = 'Спасибо, брат' }
    for _, t in ipairs(Config.Islam) do
        if t.id == choice then return Q.node('islam', t.text, opts) end
    end
    return Q.node('islam', ('Салам, %s! Я Ислам, всех тут знаю. Спрашивай.'):format(Q.charName(src)), opts)
end

-- все остальные: обычная реплика
setmetatable(Q.handlers, { __index = function(_, npcId)
    local npc = Config.Npcs[npcId]
    if not npc then return nil end
    return function() return Q.node(npcId, npc.idle or 'Здравствуй.') end
end })
