-- подсказки команд в чате
local S = function(cmd, help, params) TriggerEvent('chat:addSuggestion', cmd, help, params) end
local TEXT = { { name = 'текст', help = '' } }
S('/do', 'Описание окружения или результата: «Паспорт в руке»', TEXT)
S('/try', 'Попытка: удачно или неудачно (случайно)', TEXT)
S('/todo', 'Фраза и действие: Привет, брат*пожимает руку', { { name = 'фраза*действие', help = '' } })
S('/s', 'Крикнуть (слышно до 40 м)', TEXT)
S('/w', 'Шепнуть игроку рядом', { { name = 'id', help = 'ID' }, { name = 'текст', help = '' } })
S('/b', 'Локальный NonRP-чат (OOC)', TEXT)
S('/pm', 'Личное сообщение OOC', { { name = 'id', help = 'ID' }, { name = 'текст', help = '' } })
S('/r', 'Рация организации (в роли)', TEXT)
S('/rn', 'Рация организации NonRP', TEXT)
S('/d', 'Департамент: общая рация госструктур', TEXT)
S('/f', 'Чат семьи / банды (в роли)', TEXT)
S('/fn', 'Чат семьи / банды NonRP', TEXT)
S('/gov', 'Госновости (лидеры и замы госструктур)', TEXT)
S('/pay', 'Передать наличные игроку рядом', { { name = 'id', help = 'ID' }, { name = 'сумма', help = 'в рублях' } })

-- анимация передачи денег
RegisterNetEvent('kavkaz_rp:client:payAnim', function()
    lib.requestAnimDict('mp_common')
    TaskPlayAnim(cache.ped, 'mp_common', 'givetake1_a', 8.0, -8.0, 1500, 49, 0, false, false, false)
    RemoveAnimDict('mp_common')
end)
