-- /fine — выписать штраф (полиция, ДПС), /fines — мои штрафы и оплата

local function money(n) return lib.math.groupdigits(n, ' ') .. ' ₽' end

RegisterCommand('fine', function(_, args)
    local articles = lib.callback.await('kavkaz_fines:canFine', false)
    if not articles then return lib.notify({ description = 'штрафы выписывают сотрудники на смене', type = 'error' }) end
    local target = tonumber(args[1])
    if not target then
        local player = lib.getClosestPlayer(GetEntityCoords(cache.ped), 6.0, false)
        target = player and GetPlayerServerId(player)
    end
    if not target then return lib.notify({ description = 'рядом нет нарушителя. /fine ID', type = 'error' }) end
    local opts, preset = {}, nil
    for _, a in ipairs(articles) do
        opts[#opts + 1] = { value = a.id, label = ('%s — %s'):format(a.label, money(a.amount)) }
        if a.id == args[2] then preset = a.id end -- /fine ID статья: статью подставляет пробивка номера (kavkaz_plates)
    end
    local input = lib.inputDialog(('Штраф игроку ID %d'):format(target), {
        { type = 'select', label = 'Статья', options = opts, required = true, default = preset },
        { type = 'number', label = 'Сумма, ₽ (пусто — по статье)', min = 1 },
        { type = 'input', label = 'Описание (необязательно)', max = 160 },
    })
    if not input then return end
    TriggerServerEvent('kavkaz_fines:server:issue', target, input[1], input[2], input[3])
end, false)

local function openFines()
    local rows = lib.callback.await('kavkaz_fines:list', false)
    local options = {}
    for _, r in ipairs(rows) do
        options[#options + 1] = {
            title = ('№%d · %s · %s'):format(r.id, r.label, money(r.amount)),
            description = ('%s · инспектор %s%s%s'):format(r.t, r.officer, r.doubled == 1 and ' · удвоен за просрочку' or '', r.note and (' · ' .. r.note) or ''),
            icon = 'receipt',
            onSelect = function()
                local ok, msg = lib.callback.await('kavkaz_fines:pay', false, r.id)
                lib.notify({ description = msg or (ok and 'оплачено' or 'ошибка'), type = ok and 'success' or 'error' })
                openFines()
            end,
        }
    end
    if #options == 0 then options[1] = { title = 'Неоплаченных штрафов нет', readOnly = true } end
    lib.registerContext({ id = 'kavkaz_fines', title = 'Мои штрафы (оплата с карты)', options = options })
    lib.showContext('kavkaz_fines')
end
RegisterCommand('fines', openFines, false)

-- подсказки в чате — в kavkaz_help/config.lua
