-- подсказки команд в чате, окно /help, список команд для админ-панели.
-- чат (system_resources/chat) и ox_lib сами рассылают подсказки: чат — по именам всех разрешённых команд
-- при старте любого ресурса, ox_lib — с английскими «(type: …)» для всех игроков. поэтому после каждой такой
-- рассылки мы заново накладываем свой список: русские тексты всем, админ-команды — только по уровню и на смене.

local function dutyLevel() return LocalPlayer.state.kavkazAdmin or 0 end
local function adminRank() return math.max(LocalPlayer.state.kavkazAdminRank or 0, dutyLevel()) end

local function levelOf(c)
    if c.level then return c.level end
    if c.perm then
        local ok, lvl = pcall(function() return exports.kavkaz_admin:PermLevel(c.perm) end)
        return ok and lvl or 99
    end
    return 0
end

local function visible(c)
    if c.ace and not IsAceAllowed(c.ace) then return false end
    if c.rank then return adminRank() > 0 end
    if c.perm or c.level then return dutyLevel() >= levelOf(c) end
    if c.ace then return dutyLevel() > 0 end
    return true
end

local function usage(c)
    local parts = { '/' .. c.cmd }
    for _, p in ipairs(c.p or {}) do parts[#parts + 1] = p[1] end
    return table.concat(parts, ' ')
end

local function chatParams(c)
    if not c.p then return nil end
    local out = {}
    for i, p in ipairs(c.p) do out[i] = { name = p[1], help = p[2] or '' } end
    return out
end

---------------------------------------------------------------------------
-- подсказки в чате
---------------------------------------------------------------------------

local function apply()
    if GetResourceState('chat') ~= 'started' then return end
    for _, c in ipairs(Config.Commands) do
        if c.cmd then
            local names = { '/' .. c.cmd, c.alias and ('/' .. c.alias) or nil }
            for _, name in ipairs(names) do
                if visible(c) then
                    -- export, а не событие: событие chat:addSuggestion мы слушаем сами (см. ниже)
                    exports.chat:addSuggestion(name, c.desc, chatParams(c))
                else
                    TriggerEvent('chat:removeSuggestion', name)
                end
            end
        end
    end
end

-- после любой рассылки подсказок ждём, пока всё успокоится, и накладываем свой список
local lastRequest, pending = 0, false
local function schedule()
    lastRequest = GetGameTimer()
    if pending then return end
    pending = true
    CreateThread(function()
        while GetGameTimer() - lastRequest < 1000 do Wait(250) end
        pending = false
        apply()
    end)
end

-- ox_lib и чат шлют подсказки и с сервера: регистрируем сетевые события, чтобы ловить и их
RegisterNetEvent('chat:addSuggestions')
RegisterNetEvent('chat:addSuggestion')
AddEventHandler('chat:addSuggestions', schedule)
AddEventHandler('chat:addSuggestion', schedule)
AddEventHandler('onClientResourceStart', schedule)
AddEventHandler('QBCore:Client:OnPlayerLoaded', schedule)
AddStateBagChangeHandler('kavkazAdmin', ('player:%d'):format(cache.serverId), schedule)
AddStateBagChangeHandler('kavkazAdminRank', ('player:%d'):format(cache.serverId), schedule)
schedule()

---------------------------------------------------------------------------
-- окно /help
---------------------------------------------------------------------------

local helpOpen = false

-- раздел админ-команды (Config.AdminGroups): номер раздела и название
local groupOf = {}
for i, g in ipairs(Config.AdminGroups or {}) do
    for _, name in ipairs(g.cmds) do groupOf[name] = i end
end

local function rowsFor(tabId)
    local rows = {}
    for i, c in ipairs(Config.Commands) do
        if c.tab == tabId and visible(c) then
            local lvl = levelOf(c)
            local gi = tabId == 'admin' and (groupOf[c.cmd or ''] or groupOf[c.key or ''] or 99) or nil
            rows[#rows + 1] = {
                cmd = c.cmd and (usage(c) .. (c.alias and (' · /' .. c.alias) or '')) or c.title,
                key = c.key,
                ex = c.ex,
                desc = c.desc,
                level = (c.perm or c.level) and lvl or nil,
                group = gi and (Config.AdminGroups[gi] and Config.AdminGroups[gi].label or 'Прочее') or nil,
                _gi = gi or 0, _i = i,
            }
        end
    end
    if tabId == 'admin' then
        table.sort(rows, function(a, b) if a._gi ~= b._gi then return a._gi < b._gi end return a._i < b._i end)
    end
    return rows
end

local function openHelp()
    if helpOpen then return end
    local tabs = {}
    for _, t in ipairs(Config.Tabs) do
        if t.id ~= 'admin' or dutyLevel() > 0 then
            local rows = rowsFor(t.id)
            if #rows > 0 then tabs[#tabs + 1] = { id = t.id, label = t.label, rows = rows } end
        end
    end
    helpOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', tabs = tabs })
end

RegisterNUICallback('close', function(_, cb)
    helpOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterCommand('help', openHelp, false)
RegisterCommand('команды', openHelp, false)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and helpOpen then SetNuiFocus(false, false) end
end)

---------------------------------------------------------------------------
-- для админ-панели (kavkaz_admin, вкладка «Команды»): админ-команды с уровнями
---------------------------------------------------------------------------

exports('GetAdminCommands', function()
    local list = {}
    for i, c in ipairs(Config.Commands) do
        if c.cmd and (c.perm or c.level or c.ace or c.rank) then
            list[#list + 1] = {
                usage = usage(c), ex = c.ex, desc = c.desc, key = c.key, idx = i,
                level = c.ace and 6 or (c.rank and 1) or levelOf(c),
            }
        end
    end
    -- по уровню, внутри уровня — в порядке config.lua
    table.sort(list, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.idx < b.idx
    end)
    return list
end)

---------------------------------------------------------------------------
-- проверка: все ли клиентские команды из списка существуют и у всех ли наших команд есть строка в списке
---------------------------------------------------------------------------

CreateThread(function()
    Wait(15000)
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
            if c.side == 'client' and not registered[c.cmd] then missing[#missing + 1] = c.cmd end
        end
    end
    for name, res in pairs(ours) do
        if not listed[name] then unlisted[#unlisted + 1] = ('%s (%s)'):format(name, res) end
    end
    if #missing > 0 or #unlisted > 0 then
        TriggerServerEvent('kavkaz_help:server:clientReport', missing, unlisted)
    end
end)
