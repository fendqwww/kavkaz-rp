-- автошкола Заремы Поворотовны: теория (6 вопросов) -> вождение по маршруту -> права (предмет driver_license).
-- финал линии «Порог» тоже здесь.

local S = Config.School
local theory = {} -- src -> { i, ok }

local function hasLicense(src)
    local ok, count = pcall(function() return exports.ox_inventory:Search(src, 'count', 'driver_license') end)
    return ok and (count or 0) > 0
end

local function giveLicense(src)
    local meta
    pcall(function() meta = exports.qbx_idcard:GetMetaLicense(src, { 'driver_license' }) end)
    if type(meta) ~= 'table' then
        local p = exports.qbx_core:GetPlayer(src)
        local ci = p and p.PlayerData.charinfo or {}
        meta = { cardtype = 'driver_license', citizenid = p and p.PlayerData.citizenid, firstname = ci.firstname, lastname = ci.lastname, birthdate = ci.birthdate }
    end
    exports.ox_inventory:AddItem(src, 'driver_license', 1, meta)
    local p = exports.qbx_core:GetPlayer(src)
    if p then
        local lic = p.PlayerData.metadata.licences or {}
        lic.driver = true
        p.Functions.SetMetaData('licences', lic)
    end
end

local function question(i)
    local q = S.questions[i]
    local opts = {}
    for n, a in ipairs(q.a) do opts[#opts + 1] = { id = 'ans_' .. n, label = a } end
    return Q.node('zarema', ('Вопрос %d из %d. %s'):format(i, #S.questions, q.q), opts)
end

local function practice(src, st)
    if not Q.pay(src, S.practiceFee, 'автошкола: вождение') then
        return Q.node('zarema', ('Вождение стоит %s. Приходи, когда будут деньги.'):format(Q.money(S.practiceFee)))
    end
    local netId = Q.giveCar(src, Config.Cars.school, S.car, true)
    if not netId then
        Q.reward(src, S.practiceFee, 'автошкола: возврат')
        return Q.node('zarema', 'Учебная машина занята. Подожди минуту.')
    end
    local deadline = os.time() + S.minutes * 60
    local function step(i)
        Q.objective(src, {
            id = 'school_' .. i, text = ('Вождение: точка %d из %d'):format(i, #S.route), coords = S.route[i], radius = 6.0,
            vehNet = netId, deadline = deadline,
            onReach = function(s)
                if os.time() > deadline then
                    Q.removeCar(s, netId)
                    return Q.notify(s, 'не уложился во время. экзамен не сдан, приходи ещё', 'error')
                end
                if i < #S.route then return step(i + 1) end
                Q.removeCar(s, netId)
                giveLicense(s)
                Q.notify(s, 'экзамен сдан! права категории B — в инвентаре', 'success')
                Q.storyCheck(s)
            end,
        })
    end
    step(1)
    return Q.node('zarema', ('Садись. Едем по точкам на карте, %d минут. Правила соблюдай — я всё вижу.'):format(S.minutes), { { id = 'bye', label = 'Поехали' } })
end

Q.handlers.zarema = function(src, st, choice)
    -- теория
    local t = theory[src]
    if choice == 'theory' then
        theory[src] = { i = 1, ok = 0 }
        return question(1)
    end
    if t and choice and choice:sub(1, 4) == 'ans_' then
        local n = tonumber(choice:sub(5))
        if n == S.questions[t.i].ok then t.ok = t.ok + 1 end
        if t.i < #S.questions then
            t.i = t.i + 1
            return question(t.i)
        end
        theory[src] = nil
        if t.ok >= S.pass then
            st.theory = true
            return Q.node('zarema', ('Теория сдана: %d из %d. Теперь вождение.'):format(t.ok, #S.questions),
                { { id = 'practice', label = ('Сдать вождение (%s)'):format(Q.money(S.practiceFee)) }, { id = 'bye', label = 'Позже' } })
        end
        return Q.node('zarema', ('%d из %d. Мало. Почитай правила и приходи снова.'):format(t.ok, #S.questions),
            { { id = 'theory', label = 'Попробовать ещё раз' }, { id = 'bye', label = 'Позже' } })
    end

    if choice == 'practice' then
        if not st.theory then return Q.node('zarema', 'Сначала теория.') end
        if hasLicense(src) then return Q.node('zarema', 'У тебя уже есть права.') end
        return practice(src, st)
    end

    if hasLicense(src) then
        return Q.node('zarema', 'Права у тебя есть. Езди аккуратно, Нагорск маленький — все друг друга знают.')
    end
    local opts = {}
    if not st.theory then opts[#opts + 1] = { id = 'theory', label = 'Сдать теорию (бесплатно)' } end
    if st.theory then opts[#opts + 1] = { id = 'practice', label = ('Сдать вождение (%s)'):format(Q.money(S.practiceFee)) } end
    opts[#opts + 1] = { id = 'bye', label = 'До свидания' }
    return Q.node('zarema', 'Автошкола Заремы Поворотовны. Права категории B: теория и вождение.', opts)
end

AddEventHandler('playerDropped', function() theory[source] = nil end)
