-- админ-панель F10 на меню ox_lib. все действия выполняются теми же командами,
-- поэтому права и логи проверяет сервер — панель ничего не делает в обход.

local function clean(text)
    return (tostring(text or ''):gsub('[\r\n]', ' '))
end

local function run(fmt, ...)
    ExecuteCommand(fmt:format(...))
end

local function ask(title, fields)
    return lib.inputDialog(title, fields)
end

local F_REASON = { type = 'input', label = 'причина', required = true }

local openMain, openPlayers, openPlayer, openReports

---------------------------------------------------------------------------
-- игрок
---------------------------------------------------------------------------

local function item(perm, data)
    data.disabled = not Can(perm)
    return data
end

openPlayer = function(p)
    local id = p.id
    lib.registerContext({
        id = 'kavkaz_admin_player',
        title = ('%s [%d]'):format(p.name, id),
        menu = 'kavkaz_admin_players',
        options = {
            { title = p.char or 'персонаж не выбран', description = p.job and ('работа: %s · пинг %d'):format(p.job, p.ping) or ('пинг %d'):format(p.ping), readOnly = true },
            item('check', { title = 'Карточка игрока', icon = 'id-card', onSelect = function()
                ShowCard(lib.callback.await('kavkaz_admin:getCard', false, id))
            end }),
            item('tpto', { title = 'ТП к нему', icon = 'person-walking-arrow-right', onSelect = function() run('goto %d', id) end }),
            item('bring', { title = 'ТП к себе', icon = 'person-walking-arrow-loop-left', onSelect = function() run('bring %d', id) end }),
            item('spec', { title = 'Наблюдать', icon = 'eye', onSelect = function() run('spec %d', id) end }),
            item('revive', { title = 'Вылечить / поднять', icon = 'heart-pulse', onSelect = function() run('arevive %d', id) end }),
            item('heal', { title = 'Вылечить (здоровье 100%)', icon = 'kit-medical', onSelect = function() run('aheal %d', id) end }),
            item('armor', { title = 'Выдать броню', icon = 'shield-halved', onSelect = function()
                local i = ask('Броня', { { type = 'slider', label = 'сколько', min = 0, max = 100, default = 100 } })
                if i then run('aarmor %d %d', id, i[1]) end
            end }),
            item('feed', { title = 'Накормить и напоить', icon = 'utensils', onSelect = function() run('afeed %d', id) end }),
            item('freeze', { title = 'Заморозить / разморозить', icon = 'snowflake', onSelect = function() run('freeze %d', id) end }),
            item('kick', { title = 'Кикнуть', icon = 'door-open', onSelect = function()
                local i = ask('Кик', { F_REASON }) if i then run('kick %d %s', id, clean(i[1])) end
            end }),
            item('mute', { title = 'Мут (чат и голос)', icon = 'microphone-slash', onSelect = function()
                local i = ask('Мут', { { type = 'number', label = 'минут', required = true, min = 1, max = Config.MuteMaxMinutes, default = 30 }, F_REASON })
                if i then run('mute %d %d %s', id, i[1], clean(i[2])) end
            end }),
            item('mute', { title = 'Снять мут', icon = 'microphone', onSelect = function() run('unmute %d', id) end }),
            item('ajail', { title = 'Админ-тюрьма', icon = 'lock', onSelect = function()
                local i = ask('Админ-тюрьма', { { type = 'number', label = 'минут', required = true, min = 1, default = 15 }, F_REASON })
                if i then run('ajail %d %d %s', id, i[1], clean(i[2])) end
            end }),
            item('ajail', { title = 'Выпустить из тюрьмы', icon = 'lock-open', onSelect = function() run('unjail %d', id) end }),
            item('warn', { title = 'Предупреждение', icon = 'triangle-exclamation', onSelect = function()
                local i = ask('Предупреждение', { F_REASON }) if i then run('warn %d %s', id, clean(i[1])) end
            end }),
            item('ban', { title = 'Бан', icon = 'ban', onSelect = function()
                local i = ask('Бан', { { type = 'number', label = 'дней (0 — навсегда, с 5 ур.)', required = true, min = 0, default = 1 }, F_REASON })
                if i then run('ban %d %d %s', id, i[1], clean(i[2])) end
            end }),
            item('disarm', { title = 'Забрать оружие', icon = 'gun', onSelect = function()
                local i = ask('Изъять оружие', { F_REASON }) if i then run('disarm %d %s', id, clean(i[1])) end
            end }),
            item('givemoney', { title = 'Выдать рубли', icon = 'ruble-sign', onSelect = function()
                local i = ask('Выдать рубли', {
                    { type = 'select', label = 'счёт', required = true, default = 'cash', options = { { value = 'cash', label = 'наличные' }, { value = 'bank', label = 'банк' } } },
                    { type = 'number', label = 'сумма, ₽', required = true, min = 1 }, F_REASON })
                if i then run('agivemoney %d %s %d %s', id, i[1], i[2], clean(i[3])) end
            end }),
            item('giveitem', { title = 'Выдать предмет', icon = 'box', onSelect = function()
                local i = ask('Выдать предмет', { { type = 'input', label = 'предмет (например water)', required = true },
                    { type = 'number', label = 'количество', required = true, min = 1, default = 1 }, F_REASON })
                if i then run('agiveitem %d %s %d %s', id, clean(i[1]), i[2], clean(i[3])) end
            end }),
            item('givecar', { title = 'Выдать машину в гараж', icon = 'car', onSelect = function()
                local i = ask('Машина в гараж', { { type = 'input', label = 'модель', required = true }, F_REASON })
                if i then run('agivecar %d %s %s', id, clean(i[1]), clean(i[2])) end
            end }),
            item('sgu', { title = 'СГУ «Хазард 7007»', icon = 'volume-high', description = 'игрок должен сидеть за рулём своей машины', onSelect = function()
                local i = ask('СГУ на машину игрока', { { type = 'select', label = 'модель', required = true, options = {
                    { value = 'mini', label = 'Хазард 7007 Мини' }, { value = 'std', label = 'Хазард 7007' },
                    { value = 'pro', label = 'Хазард 7007 Про' }, { value = 'off', label = 'снять СГУ' } } } })
                if i then run('asgu %d %s', id, i[1]) end
            end }),
            item('setjob', { title = 'Работа и ранг', icon = 'briefcase', onSelect = function()
                local i = ask('Назначить работу', { { type = 'input', label = 'работа (police, ambulance …)', required = true },
                    { type = 'number', label = 'ранг', required = true, min = 0, default = 0 }, F_REASON })
                if i then run('asetjob %d %s %d %s', id, clean(i[1]), i[2], clean(i[3])) end
            end }),
            item('setleader', { title = 'Назначить лидером', icon = 'crown', onSelect = function()
                local i = ask('Лидер организации', { { type = 'input', label = 'работа или банда', required = true }, F_REASON })
                if i then run('setleader %d %s %s', id, clean(i[1]), clean(i[2])) end
            end }),
            item('setadmin', { title = 'Админ-уровень', icon = 'user-shield', onSelect = function()
                local opts = {}
                for lvl = 0, Config.MaxLevel do
                    opts[#opts + 1] = { value = tostring(lvl), label = lvl == 0 and '0 — снять' or ('%d — %s'):format(lvl, Config.Levels[lvl]) }
                end
                local i = ask('Админ-уровень', { { type = 'select', label = 'уровень', required = true, options = opts } })
                if i then run('setadmin %d %s', id, i[1]) end
            end }),
        },
    })
    lib.showContext('kavkaz_admin_player')
end

openPlayers = function(filter)
    local list = lib.callback.await('kavkaz_admin:getPlayers', false)
    if not list then return end
    local options = {
        { title = 'Поиск', icon = 'magnifying-glass', description = filter and ('сейчас: «%s»'):format(filter) or 'по нику, имени или ID', onSelect = function()
            local i = ask('Поиск игрока', { { type = 'input', label = 'ник, имя или ID' } })
            openPlayers(i and i[1] ~= '' and i[1] or nil)
        end },
    }
    local f = filter and filter:lower()
    for _, p in ipairs(list) do
        local hay = ('%d %s %s'):format(p.id, p.name or '', p.char or ''):lower()
        if not f or hay:find(f, 1, true) then
            options[#options + 1] = {
                title = ('[%d] %s'):format(p.id, p.name),
                description = ('%s%s · пинг %d'):format(p.char or 'без персонажа', p.admin > 0 and (' · ' .. Config.Levels[p.admin]) or '', p.ping),
                icon = p.admin > 0 and 'user-shield' or 'user',
                arrow = true,
                onSelect = function() openPlayer(p) end,
            }
        end
    end
    lib.registerContext({ id = 'kavkaz_admin_players', title = ('Игроки онлайн: %d'):format(#list), menu = 'kavkaz_admin_main', options = options })
    lib.showContext('kavkaz_admin_players')
end

---------------------------------------------------------------------------
-- репорты
---------------------------------------------------------------------------

openReports = function()
    local list = lib.callback.await('kavkaz_admin:getReports', false)
    if not list then return end
    local options = {}
    if #list == 0 then options[1] = { title = 'Открытых репортов нет', readOnly = true } end
    for _, r in ipairs(list) do
        options[#options + 1] = {
            title = ('№%d · %s · %d мин назад'):format(r.id, r.from, r.ago),
            description = r.text .. (r.takenBy and ('\nвзял: ' .. r.takenBy) or ''),
            icon = r.takenBy and 'user-check' or 'envelope',
            onSelect = function()
                lib.registerContext({
                    id = 'kavkaz_admin_report', title = ('Репорт №%d'):format(r.id), menu = 'kavkaz_admin_reports',
                    options = {
                        { title = r.text, readOnly = true },
                        { title = 'Принять', icon = 'hand', onSelect = function()
                            local ok, err = lib.callback.await('kavkaz_admin:reportAction', false, r.id, 'take')
                            lib.notify({ description = ok and 'репорт твой' or err, type = ok and 'success' or 'error' })
                        end },
                        { title = 'ТП к игроку', icon = 'person-walking-arrow-right', onSelect = function()
                            lib.callback.await('kavkaz_admin:reportAction', false, r.id, 'take')
                            run('goto %d', r.src)
                        end },
                        { title = 'Карточка игрока', icon = 'id-card', disabled = not Can('check'), onSelect = function()
                            ShowCard(lib.callback.await('kavkaz_admin:getCard', false, r.src))
                        end },
                        { title = 'Закрыть', icon = 'check', onSelect = function()
                            local ok, err = lib.callback.await('kavkaz_admin:reportAction', false, r.id, 'close')
                            lib.notify({ description = ok and 'репорт закрыт' or err, type = ok and 'success' or 'error' })
                        end },
                    },
                })
                lib.showContext('kavkaz_admin_report')
            end,
        }
    end
    lib.registerContext({ id = 'kavkaz_admin_reports', title = 'Репорты', menu = 'kavkaz_admin_main', options = options })
    lib.showContext('kavkaz_admin_reports')
end

---------------------------------------------------------------------------
-- логи и состав
---------------------------------------------------------------------------

local function openLogs(filter)
    local rows = lib.callback.await('kavkaz_admin:getLogs', false, filter)
    if not rows then return end
    local options = {
        { title = 'Поиск', icon = 'magnifying-glass', description = filter and ('сейчас: «%s»'):format(filter) or 'по админу, игроку или действию', onSelect = function()
            local i = ask('Поиск в логах', { { type = 'input', label = 'ник или действие (ban, givemoney …)' } })
            openLogs(i and i[1] ~= '' and i[1] or nil)
        end },
    }
    for _, r in ipairs(rows) do
        options[#options + 1] = {
            title = ('%s · %s · %s'):format(r.t, r.action, r.admin),
            description = ((r.target and ('→ ' .. r.target .. '  ') or '') .. (r.details or '')),
            readOnly = true,
        }
    end
    lib.registerContext({ id = 'kavkaz_admin_logs', title = 'Логи администрации', menu = 'kavkaz_admin_main', options = options })
    lib.showContext('kavkaz_admin_logs')
end

local function openStaff()
    local rows = lib.callback.await('kavkaz_admin:getStaff', false)
    if not rows then return end
    local options = {}
    for _, r in ipairs(rows) do
        options[#options + 1] = {
            title = ('%s — %s'):format(r.name, Config.Levels[r.level] or r.level),
            description = ('на смене всего: %d ч %d мин · закрыто репортов: %d'):format(r.duty_seconds // 3600, (r.duty_seconds % 3600) // 60, r.reports_done),
            readOnly = true,
        }
    end
    if #options == 0 then options[1] = { title = 'в базе пока никого', readOnly = true } end
    lib.registerContext({ id = 'kavkaz_admin_staff', title = 'Состав администрации', menu = 'kavkaz_admin_main', options = options })
    lib.showContext('kavkaz_admin_staff')
end

---------------------------------------------------------------------------
-- команды по уровням (список — kavkaz_help/config.lua), клик — скопировать пример
---------------------------------------------------------------------------

local function openCommands()
    local ok, list = pcall(function() return exports.kavkaz_help:GetAdminCommands() end)
    if not ok or not list then
        return lib.notify({ description = 'список команд недоступен: не запущен kavkaz_help', type = 'error' })
    end
    local my = MyLevel()
    local options, lastLevel = {}, nil
    for _, c in ipairs(list) do
        if c.level ~= lastLevel then
            lastLevel = c.level
            options[#options + 1] = {
                title = ('Уровень %d — %s'):format(c.level, Config.Levels[c.level] or ''),
                readOnly = true,
                icon = c.level <= my and 'unlock' or 'lock',
            }
        end
        local text = c.ex or c.usage
        options[#options + 1] = {
            title = c.key and ('%s · %s'):format(c.key, c.usage) or c.usage,
            description = ('%s\nпример: %s'):format(c.desc or '', text),
            icon = 'copy',
            disabled = c.level > my,
            onSelect = function()
                lib.setClipboard(text)
                lib.notify({ description = ('скопировано: %s'):format(text), type = 'success' })
            end,
        }
    end
    lib.registerContext({ id = 'kavkaz_admin_commands', title = 'Команды (клик — скопировать)', menu = 'kavkaz_admin_main', options = options })
    lib.showContext('kavkaz_admin_commands')
end

---------------------------------------------------------------------------
-- главное меню
---------------------------------------------------------------------------

openMain = function()
    local level = MyLevel()
    if level <= 0 then
        return lib.notify({ description = 'панель доступна только на смене: /alogin', type = 'error' })
    end
    lib.registerContext({
        id = 'kavkaz_admin_main',
        title = ('KAVKAZ · %s'):format(Config.Levels[level]),
        options = {
            { title = 'Игроки', icon = 'users', arrow = true, onSelect = function() openPlayers() end },
            { title = 'Репорты', icon = 'envelope', arrow = true, onSelect = openReports },
            { title = 'Я', icon = 'user-astronaut', arrow = true, onSelect = function()
                lib.registerContext({
                    id = 'kavkaz_admin_self', title = 'Я', menu = 'kavkaz_admin_main',
                    options = {
                        item('noclip', { title = ('Noclip (%s)'):format(Config.Keys.noclip), icon = 'feather', description = Tools.isNoclip() and 'включён' or 'выключен', onSelect = Tools.toggleNoclip }),
                        item('clicktp', { title = ('ТП мышкой (%s)'):format(Config.Keys.clicktp), icon = 'arrow-pointer', onSelect = Tools.toggleClickTp }),
                        item('atpm', { title = 'ТП на метку', icon = 'location-dot', onSelect = function() ExecuteCommand('atpm') end }),
                        item('invis', { title = 'Невидимость', icon = 'ghost', description = Tools.isInvisible() and 'включена' or 'выключена', onSelect = function() ExecuteCommand('invis') end }),
                        item('revive', { title = 'Вылечиться', icon = 'heart-pulse', onSelect = function() ExecuteCommand('arevive') end }),
                        item('armor', { title = 'Броня себе', icon = 'shield-halved', onSelect = function() ExecuteCommand('aarmor') end }),
                        item('feed', { title = 'Наесться', icon = 'utensils', onSelect = function() ExecuteCommand('afeed') end }),
                        { title = 'Сменить PIN', icon = 'key', onSelect = function() ExecuteCommand('apin') end },
                    },
                })
                lib.showContext('kavkaz_admin_self')
            end },
            { title = 'Транспорт', icon = 'car', arrow = true, onSelect = function()
                lib.registerContext({
                    id = 'kavkaz_admin_veh', title = 'Транспорт', menu = 'kavkaz_admin_main',
                    options = {
                        item('aveh', { title = 'Заспавнить машину', icon = 'car-side', onSelect = function()
                            local i = ask('Спавн машины', { { type = 'input', label = 'модель (sultan, priora …)', required = true } })
                            if i then run('aveh %s', clean(i[1])) end
                        end }),
                        item('afix', { title = 'Починить и заправить', icon = 'wrench', onSelect = function() ExecuteCommand('afix') end }),
                        item('aflip', { title = 'Перевернуть', icon = 'rotate', onSelect = function() ExecuteCommand('aflip') end }),
                        item('adv', { title = 'Удалить свою / ближайшие', icon = 'trash', onSelect = function() ExecuteCommand('adv') end }),
                        item('adv', { title = 'Удалить пустые в радиусе', icon = 'trash-can', onSelect = function()
                            local i = ask('Удалить машины', { { type = 'slider', label = 'радиус, м', min = 5, max = 100, default = 20 } })
                            if i then run('adv %d', i[1]) end
                        end }),
                    },
                })
                lib.showContext('kavkaz_admin_veh')
            end },
            item('weather', { title = 'Погода и время', icon = 'cloud-sun', arrow = true, onSelect = function()
                local W = { { 'солнце', 'sun' }, { 'ясно', 'sun' }, { 'облачно', 'cloud' }, { 'пасмурно', 'cloud' }, { 'дождь', 'cloud-rain' },
                    { 'гроза', 'cloud-bolt' }, { 'туман', 'smog' }, { 'снег', 'snowflake' }, { 'метель', 'wind' }, { 'зима', 'tree' } }
                local opts = {}
                for _, w in ipairs(W) do
                    opts[#opts + 1] = { title = w[1], icon = w[2], onSelect = function() run('aweather %s', w[1]) end }
                end
                opts[#opts + 1] = item('time', { title = 'Время суток', icon = 'clock', onSelect = function()
                    local i = ask('Время', { { type = 'slider', label = 'час', min = 0, max = 23, default = 12 } })
                    if i then run('atime %d', i[1]) end
                end })
                lib.registerContext({ id = 'kavkaz_admin_weather', title = 'Погода и время', menu = 'kavkaz_admin_main', options = opts })
                lib.showContext('kavkaz_admin_weather')
            end }),
            item('healall', { title = 'Вылечить всех', icon = 'heart-circle-plus', description = 'поднять, вылечить и накормить весь сервер', onSelect = function()
                if lib.alertDialog({ header = 'Вылечить всех?', content = 'Поднять, вылечить и накормить всех игроков на сервере.', centered = true, cancel = true,
                    labels = { confirm = 'Да', cancel = 'Нет' } }) == 'confirm' then ExecuteCommand('ahealall') end
            end }),
            item('announce', { title = 'Объявление на сервер', icon = 'bullhorn', onSelect = function()
                local i = ask('Объявление', { { type = 'textarea', label = 'текст', required = true, max = 300 } })
                if i then run('announce %s', clean(i[1])) end
            end }),
            item('logs', { title = 'Логи', icon = 'list', arrow = true, onSelect = function() openLogs() end }),
            item('logs', { title = 'Состав и часы смен', icon = 'user-shield', arrow = true, onSelect = openStaff }),
            { title = 'Команды', icon = 'terminal', arrow = true, description = 'все команды по уровням, клик — скопировать', onSelect = openCommands },
            { title = 'Сдать смену', icon = 'right-from-bracket', onSelect = function() ExecuteCommand('alogout') end },
        },
    })
    lib.showContext('kavkaz_admin_main')
end

RegisterCommand('apanel', openMain, false)
lib.addKeybind({ name = 'kavkaz_panel', description = 'Админка: панель', defaultKey = Config.Keys.panel,
    onPressed = function() if MyLevel() > 0 then openMain() end end })
