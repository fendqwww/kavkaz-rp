-- проверка на живом сервере: все ли команды из config.lua существуют, и у всех ли команд наших ресурсов
-- есть строка в списке. результат — в консоли сервера после старта (и от первого игрока — по клиентским командам).

local function report(title, list)
    if #list == 0 then return end
    table.sort(list)
    print(('^3[kavkaz_help] %s: %s^0'):format(title, table.concat(list, ', ')))
end

CreateThread(function()
    Wait(10000) -- ждём, пока стартуют остальные ресурсы
    local registered, ours = {}, {}
    for _, rc in ipairs(GetRegisteredCommands()) do
        registered[rc.name] = true
        if rc.resource and rc.resource:find('^kavkaz_') then ours[rc.name] = rc.resource end
    end
    local listed, missing, unlisted = {}, {}, {}
    for _, c in ipairs(Config.Commands) do
        if c.cmd then
            listed[c.cmd] = true
            if c.alias then listed[c.alias] = true end
            if c.side ~= 'client' and not registered[c.cmd] then missing[#missing + 1] = c.cmd end
        end
    end
    for name, res in pairs(ours) do
        if not listed[name] then unlisted[#unlisted + 1] = ('%s (%s)'):format(name, res) end
    end
    report('в списке есть, на сервере нет команды', missing)
    report('команда есть, а в списке kavkaz_help её нет', unlisted)
    local total = 0
    for _, c in ipairs(Config.Commands) do if c.cmd then total += 1 end end
    print(('[kavkaz_help] команд в справке: %d, серверных не найдено: %d, без строки в справке: %d'):format(total, #missing, #unlisted))
end)

-- клиентские команды видны только на клиенте: первый игрок присылает, чего не хватает. один отчёт за запуск.
local clientReported = false
RegisterNetEvent('kavkaz_help:server:clientReport', function(missing, unlisted)
    if clientReported or type(missing) ~= 'table' or type(unlisted) ~= 'table' then return end
    clientReported = true
    local function clean(list)
        local out = {}
        for i = 1, math.min(#list, 50) do
            if type(list[i]) == 'string' then out[#out + 1] = list[i]:sub(1, 60) end
        end
        return out
    end
    report('клиент: в списке есть, в игре нет команды', clean(missing))
    report('клиент: команда есть, а в списке kavkaz_help её нет', clean(unlisted))
end)
