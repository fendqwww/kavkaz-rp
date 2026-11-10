-- команды админов: перемещение, помощь игрокам, транспорт, выдача, мир, админ-чат.
-- имена не пересекаются с командами qbx_core / qbx_medical (tp, tpm, car, dv, givemoney, setjob, revive, aheal …).

local function cmd(name, perm, help, params, fn)
    lib.addCommand(name, { help = help, params = params }, function(src, args, raw)
        if not Admin.can(src, perm) then return end
        fn(src, args, raw)
    end)
end

local P_TARGET = { name = 'target', type = 'playerId', help = 'ID игрока' }
local P_TARGET_OPT = { name = 'target', type = 'playerId', help = 'ID игрока (по умолчанию ты)', optional = true }
local P_REASON = { name = 'reason', type = 'longString', help = 'причина' }

local function noConsole(src)
    if src == 0 then print('[kavkaz_admin] эта команда только из игры') return true end
    return false
end

---------------------------------------------------------------------------
-- перемещение
---------------------------------------------------------------------------

local function teleportPed(src, coords)
    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    local entity = (veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped) and veh or ped
    SetEntityCoords(entity, coords.x, coords.y, coords.z, false, false, false, false)
end

cmd('goto', 'tpto', 'Телепорт к игроку', { P_TARGET }, function(src, args)
    if noConsole(src) then return end
    local pos = GetEntityCoords(GetPlayerPed(args.target))
    SetPlayerRoutingBucket(src, GetPlayerRoutingBucket(args.target))
    teleportPed(src, pos + vec3(1.0, 1.0, 0.0))
    Admin.log(src, 'goto', args.target)
end)

cmd('bring', 'bring', 'Телепорт игрока к себе', { P_TARGET }, function(src, args)
    if noConsole(src) then return end
    if exports.kavkaz_admin:IsJailed(args.target) then return Admin.notify(src, 'игрок в админ-тюрьме', 'error') end
    local pos = GetEntityCoords(GetPlayerPed(src))
    SetPlayerRoutingBucket(args.target, GetPlayerRoutingBucket(src))
    teleportPed(args.target, pos + vec3(1.0, 0.0, 0.0))
    Admin.notify(args.target, 'тебя телепортировал администратор', 'inform')
    Admin.log(src, 'bring', args.target)
end)

cmd('spec', 'spec', 'Наблюдать за игроком (повторно — выйти)', { P_TARGET_OPT }, function(src, args)
    if noConsole(src) then return end
    local target = args.target
    if not target or target == src then
        TriggerClientEvent('kavkaz_admin:client:spec', src, nil)
        return
    end
    TriggerClientEvent('kavkaz_admin:client:spec', src, target, GetEntityCoords(GetPlayerPed(target)))
    Admin.log(src, 'spec', target)
end)

-- клиентские действия (noclip, ТП на метку, клик-ТП, невидимость, починка): клиент спрашивает разрешение,
-- сервер проверяет смену и уровень и пишет лог
local CLIENT_ACTIONS = { noclip = true, clicktp = true, atpm = true, tpc = true, invis = true, afix = true, aflip = true }
lib.callback.register('kavkaz_admin:allowed', function(src, action, details)
    if not CLIENT_ACTIONS[action] then return false end
    if not Admin.can(src, action) then return false end
    if action ~= 'clicktp' and action ~= 'atpm' then Admin.log(src, action, nil, details) end
    return true
end)

---------------------------------------------------------------------------
-- помощь игрокам
---------------------------------------------------------------------------

cmd('arevive', 'revive', 'Поднять и вылечить игрока', { P_TARGET_OPT }, function(src, args)
    local target = args.target or src
    if target == 0 then return end
    exports.qbx_medical:Revive(target)
    exports.qbx_medical:Heal(target)
    Admin.notify(target, 'администратор вылечил тебя', 'success')
    Admin.log(src, 'revive', target)
end)

cmd('freeze', 'freeze', 'Заморозить / разморозить игрока', { P_TARGET }, function(src, args)
    local st = Player(args.target).state
    local frozen = not st.kavkazFrozen
    st:set('kavkazFrozen', frozen, true)
    FreezeEntityPosition(GetPlayerPed(args.target), frozen)
    TriggerClientEvent('kavkaz_admin:client:freeze', args.target, frozen)
    Admin.notify(src, frozen and 'игрок заморожен' or 'игрок разморожен', 'inform')
    Admin.notify(args.target, frozen and 'администратор заморозил тебя' or 'ты разморожен', 'inform')
    Admin.log(src, frozen and 'freeze' or 'unfreeze', args.target)
end)

cmd('disarm', 'disarm', 'Забрать всё оружие у игрока', { P_TARGET, P_REASON }, function(src, args)
    if not Admin.canTouch(src, args.target) then return end
    local removed = {}
    for _, item in pairs(exports.ox_inventory:GetInventoryItems(args.target) or {}) do
        if item.name:find('^WEAPON_') then
            exports.ox_inventory:RemoveItem(args.target, item.name, item.count, nil, item.slot)
            removed[#removed + 1] = item.name
        end
    end
    RemoveAllPedWeapons(GetPlayerPed(args.target), true)
    Admin.notify(src, ('изъято: %d'):format(#removed), 'success')
    Admin.notify(args.target, 'администратор изъял у тебя оружие: ' .. args.reason, 'error')
    Admin.log(src, 'disarm', args.target, ('%s; %s'):format(args.reason, table.concat(removed, ', ')))
end)

---------------------------------------------------------------------------
-- карточка игрока
---------------------------------------------------------------------------

function Admin.card(target)
    local license = Admin.license(target)
    local player = exports.qbx_core:GetPlayer(target)
    local card = {
        id = target,
        name = GetPlayerName(target),
        ping = GetPlayerPing(target),
        level = Admin.getLevel(target),
        onDuty = Admin.duty[target] ~= nil,
        ids = Admin.ids(target),
        warns = MySQL.scalar.await('SELECT COUNT(*) FROM kavkaz_warns WHERE license = ? AND active = 1', { license }) or 0,
        bans = MySQL.scalar.await('SELECT COUNT(*) FROM kavkaz_bans WHERE license = ?', { license }) or 0,
        jailed = exports.kavkaz_admin:IsJailed(target),
        muted = exports.kavkaz_admin:IsMuted(target),
    }
    if player then
        local pd = player.PlayerData
        card.char = ('%s %s'):format(pd.charinfo.firstname, pd.charinfo.lastname)
        card.citizenid = pd.citizenid
        card.cash = pd.money.cash or 0
        card.bank = pd.money.bank or 0
        card.job = ('%s (%s)'):format(pd.job.label or pd.job.name, pd.job.grade and pd.job.grade.name or '-')
        card.gang = ('%s (%s)'):format(pd.gang.label or pd.gang.name, pd.gang.grade and pd.gang.grade.name or '-')
        card.vehicles = MySQL.scalar.await('SELECT COUNT(*) FROM player_vehicles WHERE citizenid = ?', { pd.citizenid }) or 0
    end
    -- другие онлайн-игроки с тем же IP — подсказка на мульти-аккаунт
    local ip = GetPlayerEndpoint(target)
    ip = ip and ip:match('^[^:]+')
    card.sameIp = {}
    if ip and ip ~= '127.0.0.1' then
        for _, id in ipairs(GetPlayers()) do
            local other = tonumber(id)
            local oip = GetPlayerEndpoint(other)
            if other ~= target and oip and oip:match('^[^:]+') == ip then
                card.sameIp[#card.sameIp + 1] = Admin.label(other)
            end
        end
    end
    return card
end

cmd('check', 'check', 'Карточка игрока', { P_TARGET }, function(src, args)
    local card = Admin.card(args.target)
    if src == 0 then return print(json.encode(card, { indent = true })) end
    TriggerClientEvent('kavkaz_admin:client:card', src, card)
    Admin.log(src, 'check', args.target)
end)

---------------------------------------------------------------------------
-- транспорт
---------------------------------------------------------------------------

cmd('aveh', 'aveh', 'Заспавнить машину', { { name = 'model', type = 'string', help = 'модель, например sultan' } }, function(src, args)
    if noConsole(src) then return end
    local ped = GetPlayerPed(src)
    local old = GetVehiclePedIsIn(ped, false)
    if old ~= 0 then DeleteEntity(old) end
    -- имя из автопарка (kv_camry80) -> модель, которая сейчас ездит (заглушка GTA или настоящая)
    local model = args.model:lower()
    local car = GetResourceState('kavkaz_cars') == 'started' and exports.kavkaz_cars:GetCar(model) or nil
    if car then model = car.current end
    local ok, netId, vehicle = pcall(qbx.spawnVehicle, { model = model, spawnSource = ped, warp = true, bucket = GetPlayerRoutingBucket(src) })
    if not ok or not vehicle or vehicle == 0 then
        return Admin.notify(src, 'не удалось: проверь название модели', 'error')
    end
    pcall(function() exports.qbx_vehiclekeys:GiveKeys(src, vehicle) end)
    Admin.log(src, 'aveh', nil, args.model)
end)

cmd('adv', 'adv', 'Удалить машину (в которой сидишь или пустые в радиусе)', {
    { name = 'radius', type = 'number', help = 'радиус в метрах (до 100)', optional = true },
}, function(src, args)
    if noConsole(src) then return end
    local ped = GetPlayerPed(src)
    local current = GetVehiclePedIsIn(ped, false)
    if current ~= 0 and not args.radius then
        DeleteEntity(current)
        Admin.log(src, 'adv', nil, 'своя машина')
        return
    end
    local radius = math.min(args.radius or 5.0, 100.0)
    local pos, count = GetEntityCoords(ped), 0
    for _, veh in ipairs(GetAllVehicles()) do
        if #(GetEntityCoords(veh) - pos) <= radius then
            local occupied = false
            for seat = -1, 6 do
                local p = GetPedInVehicleSeat(veh, seat)
                if p ~= 0 and IsPedAPlayer(p) then occupied = true break end
            end
            if not occupied then DeleteEntity(veh) count = count + 1 end
        end
    end
    Admin.notify(src, ('удалено машин: %d'):format(count), 'success')
    Admin.log(src, 'adv', nil, ('радиус %d м, удалено %d'):format(radius, count))
end)

---------------------------------------------------------------------------
-- выдача (всё с причиной и в лог)
---------------------------------------------------------------------------

local MONEY_TYPES = { cash = true, bank = true }
local pending, pendingId = {}, 0 -- крупные выдачи ждут второго админа

local function doMoney(src, p)
    if not GetPlayerName(p.target) then return false, 'игрок вышел' end
    local ok
    if p.set then
        ok = exports.qbx_core:SetMoney(p.target, p.account, p.amount, 'admin: ' .. p.reason)
    else
        ok = exports.qbx_core:AddMoney(p.target, p.account, p.amount, 'admin: ' .. p.reason)
    end
    if not ok then return false, 'qbx_core отклонил операцию' end
    Admin.log(src, p.set and 'setmoney' or 'givemoney', p.target,
        ('%s %s ₽ (%s): %s%s'):format(p.set and '=' or '+', p.amount, p.account, p.reason,
            p.confirmedBy and (' | подтвердил ' .. p.confirmedBy) or ''))
    Admin.notify(p.target, p.set and ('администратор установил тебе %s ₽ (%s)'):format(p.amount, p.account)
        or ('администратор выдал тебе %s ₽ (%s)'):format(p.amount, p.account), 'inform')
    return true
end

local function moneyCommand(set)
    return function(src, args)
        local account = args.account:lower()
        if not MONEY_TYPES[account] then return Admin.notify(src, 'счёт: cash или bank', 'error') end
        local amount = math.floor(args.amount)
        if amount < 0 or (not set and amount == 0) then return Admin.notify(src, 'неверная сумма', 'error') end
        local p = { by = src, target = args.target, account = account, amount = amount, reason = args.reason, set = set }

        if src ~= 0 and amount > Config.MoneyConfirmLimit then
            pendingId = pendingId + 1
            p.created = os.time()
            pending[pendingId] = p
            Admin.log(src, 'money_request', args.target, ('%s ₽ (%s), заявка №%d: %s'):format(amount, account, pendingId, args.reason))
            Admin.broadcast(('%s просит %s %s ₽ (%s) игроку %s. причина: %s. подтвердить: /aconfirm %d')
                :format(Admin.label(src), set and 'установить' or 'выдать', amount, account, Admin.label(args.target), args.reason, pendingId), 5)
            return Admin.notify(src, ('больше %d ₽ — нужна подпись второго админа 5+. заявка №%d'):format(Config.MoneyConfirmLimit, pendingId), 'inform')
        end
        local ok, err = doMoney(src, p)
        Admin.notify(src, ok and 'готово' or err, ok and 'success' or 'error')
    end
end

local MONEY_PARAMS = {
    P_TARGET,
    { name = 'account', type = 'string', help = 'cash или bank' },
    { name = 'amount', type = 'number', help = 'сумма в ₽' },
    P_REASON,
}
cmd('agivemoney', 'givemoney', 'Выдать рубли (с логом)', MONEY_PARAMS, moneyCommand(false))
cmd('asetmoney', 'setmoney', 'Установить сумму (с логом)', MONEY_PARAMS, moneyCommand(true))

cmd('aconfirm', 'givemoney', 'Подтвердить крупную выдачу денег', { { name = 'id', type = 'number', help = 'номер заявки' } }, function(src, args)
    local p = pending[math.floor(args.id)]
    if not p then return Admin.notify(src, 'заявка не найдена', 'error') end
    if p.by == src then return Admin.notify(src, 'свою заявку подтверждает другой админ', 'error') end
    if os.time() - p.created > 600 then
        pending[math.floor(args.id)] = nil
        return Admin.notify(src, 'заявка устарела (10 мин)', 'error')
    end
    pending[math.floor(args.id)] = nil
    p.confirmedBy = Admin.label(src)
    local ok, err = doMoney(p.by, p)
    Admin.notify(src, ok and 'подтверждено и выдано' or err, ok and 'success' or 'error')
    if ok and GetPlayerName(p.by) then Admin.notify(p.by, ('заявку подтвердил %s'):format(p.confirmedBy), 'success') end
end)

cmd('agiveitem', 'giveitem', 'Выдать предмет', {
    P_TARGET,
    { name = 'item', type = 'string', help = 'название предмета, например water' },
    { name = 'count', type = 'number', help = 'количество' },
    P_REASON,
}, function(src, args)
    local count = math.floor(args.count)
    if count < 1 or count > 1000 then return Admin.notify(src, 'количество от 1 до 1000', 'error') end
    if not exports.ox_inventory:Items(args.item) then return Admin.notify(src, 'такого предмета нет', 'error') end
    if not exports.ox_inventory:CanCarryItem(args.target, args.item, count) then
        return Admin.notify(src, 'у игрока нет места в инвентаре', 'error')
    end
    local ok = exports.ox_inventory:AddItem(args.target, args.item, count)
    if not ok then return Admin.notify(src, 'не удалось выдать', 'error') end
    Admin.notify(src, 'выдано', 'success')
    Admin.log(src, 'giveitem', args.target, ('%s x%d: %s'):format(args.item, count, args.reason))
end)

cmd('agivecar', 'givecar', 'Выдать машину в гараж', {
    P_TARGET,
    { name = 'model', type = 'string', help = 'модель' },
    P_REASON,
}, function(src, args)
    local player = exports.qbx_core:GetPlayer(args.target)
    if not player then return Admin.notify(src, 'игрок ещё не выбрал персонажа', 'error') end
    local model = args.model:lower()
    -- машина из автопарка (kavkaz_cars/cars.lua): можно писать имя спавна kv_camry80 — выдастся текущая модель (заглушка или настоящая)
    local car = GetResourceState('kavkaz_cars') == 'started' and exports.kavkaz_cars:GetCar(model) or nil
    if car then model = car.current end
    local known = exports.qbx_core:GetVehiclesByName()
    if known and not known[model] then return Admin.notify(src, 'модели нет в списке машин сервера (kavkaz_cars/cars.lua или qbx_core)', 'error') end
    local id, err = exports.qbx_vehicles:CreatePlayerVehicle({ model = model, citizenid = player.PlayerData.citizenid, garage = Config.GiveCarGarage })
    if not id then return Admin.notify(src, 'не удалось: ' .. (err and err.message or '?'), 'error') end
    -- номер от kavkaz_plates (транзит или сразу на учёт), а не случайный qbx
    if GetResourceState('kavkaz_plates') == 'started' then pcall(function() exports.kavkaz_plates:AssignNew(id, 'admin') end) end
    Admin.notify(src, 'машина в гараже игрока', 'success')
    Admin.notify(args.target, ('тебе выдана машина %s — она в гараже'):format(model), 'success')
    Admin.log(src, 'givecar', args.target, ('%s (id %s): %s'):format(model, id, args.reason))
end)

local function groupCommand(kind)
    return function(src, args)
        local name = args.name:lower()
        local group = kind == 'job' and exports.qbx_core:GetJob(name) or exports.qbx_core:GetGang(name)
        if not group then return Admin.notify(src, kind == 'job' and 'такой работы нет' or 'такой банды нет', 'error') end
        local grade = math.floor(args.grade or 0)
        if not group.grades[grade] then return Admin.notify(src, 'такого ранга нет', 'error') end
        local ok, err
        if kind == 'job' then ok, err = exports.qbx_core:SetJob(args.target, name, grade)
        else ok, err = exports.qbx_core:SetGang(args.target, name, grade) end
        if ok == false then return Admin.notify(src, 'ошибка: ' .. tostring(err and err.message or err), 'error') end
        Admin.notify(src, 'готово', 'success')
        Admin.notify(args.target, ('тебе назначено: %s, ранг «%s»'):format(group.label, group.grades[grade].name), 'inform')
        Admin.log(src, 'set' .. kind, args.target, ('%s %d: %s'):format(name, grade, args.reason))
    end
end

local function groupParams(what)
    return { P_TARGET, { name = 'name', type = 'string', help = what }, { name = 'grade', type = 'number', help = 'ранг' }, P_REASON }
end
cmd('asetjob', 'setjob', 'Назначить работу', groupParams('работа, например police'), groupCommand('job'))
cmd('asetgang', 'setgang', 'Назначить банду', groupParams('банда'), groupCommand('gang'))

-- лидер = старший (boss) ранг организации
cmd('setleader', 'setleader', 'Назначить лидера организации', {
    P_TARGET, { name = 'name', type = 'string', help = 'работа или банда' }, P_REASON,
}, function(src, args)
    local name = args.name:lower()
    local isJob = exports.qbx_core:GetJob(name) ~= nil
    local group = isJob and exports.qbx_core:GetJob(name) or exports.qbx_core:GetGang(name)
    if not group then return Admin.notify(src, 'организация не найдена', 'error') end
    local top
    for grade, data in pairs(group.grades) do
        if data.isboss and (not top or grade > top) then top = grade end
    end
    if not top then return Admin.notify(src, 'у организации нет ранга лидера (isboss)', 'error') end
    groupCommand(isJob and 'job' or 'gang')(src, { target = args.target, name = name, grade = top, reason = 'лидер: ' .. args.reason })
end)

---------------------------------------------------------------------------
-- мир и связь
---------------------------------------------------------------------------

cmd('announce', 'announce', 'Объявление на весь сервер', { { name = 'text', type = 'longString', help = 'текст' } }, function(src, args)
    TriggerClientEvent('kavkaz_admin:client:announce', -1, args.text)
    Admin.log(src, 'announce', nil, args.text)
end)

cmd('a', 'adminchat', 'Админ-чат', { { name = 'text', type = 'longString', help = 'сообщение' } }, function(src, args)
    local who = src == 0 and 'консоль' or ('%s %s'):format(Admin.levelName(Admin.dutyLevel(src)), Admin.label(src))
    for _, id in ipairs(Admin.onDutyList(1)) do
        TriggerClientEvent('chat:addMessage', id, { color = { 255, 200, 60 }, args = { 'А-ЧАТ | ' .. who, args.text } })
    end
    print(('[a-chat] %s: %s'):format(who, args.text))
end)

cmd('admins', 'admins', 'Кто из админов на смене', nil, function(src)
    local lines = {}
    for id, d in pairs(Admin.duty) do
        lines[#lines + 1] = ('%s — %s, %d мин'):format(Admin.label(id), Admin.levelName(d.level), (os.time() - d.since) // 60)
    end
    local text = #lines > 0 and table.concat(lines, '\n') or 'никого'
    if src == 0 then return print(text) end
    Admin.chat(src, 'на смене:\n' .. text)
end)
