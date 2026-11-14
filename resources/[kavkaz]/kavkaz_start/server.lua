local function notify(src, text, kind)
    exports.qbx_core:Notify(src, text, kind or 'inform')
end

-- приветствие показывается один раз на каждого нового персонажа
RegisterNetEvent('kavkaz_start:server:loaded', function()
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    if player.PlayerData.metadata.kavkaz_welcomed then return end

    player.Functions.SetMetaData('kavkaz_welcomed', true)
    -- новый персонаж: вместо памятки — пролог «Домой» (самолёт, дядя Хамзат). памятка остаётся в /gaid
    if GetResourceState('kavkaz_intro') == 'started' and not player.PlayerData.metadata.kavkaz_intro then
        return exports.kavkaz_intro:Start(src)
    end
    TriggerClientEvent('kavkaz_start:client:welcome', src)
end)

-- имя: только буквы (кириллица или латиница) и дефис, без цифр, пробелов и знаков
local function checkName(value)
    if type(value) ~= 'string' then return nil end
    local len = utf8.len(value)
    if not len or len < Config.NameMin or len > Config.NameMax then return nil end
    -- байты < 128, кроме латинских букв и дефиса, запрещены; кириллица в UTF-8 — байты >= 128
    if value:find('[\0-\44\46-\64\91-\96\123-\127]') then return nil end
    return value
end

local function setCharName(target, firstname, lastname)
    local player = exports.qbx_core:GetPlayer(target)
    if not player then return false, 'игрок с таким ID не найден' end

    firstname, lastname = checkName(firstname), checkName(lastname)
    if not firstname or not lastname then
        return false, ('имя и фамилия: только буквы и дефис, от %d до %d символов'):format(Config.NameMin, Config.NameMax)
    end

    local charinfo = player.PlayerData.charinfo
    local old = ('%s %s'):format(charinfo.firstname, charinfo.lastname)
    charinfo.firstname = firstname
    charinfo.lastname = lastname
    player.Functions.SetPlayerData('charinfo', charinfo)
    player.Functions.Save()

    lib.print.info(('смена имени: %s -> %s %s (citizenid %s)'):format(old, firstname, lastname, player.PlayerData.citizenid))
    return true, ('%s %s'):format(firstname, lastname)
end

-- /rename Имя Фамилия — сменить имя своему персонажу (только админы)
lib.addCommand('rename', {
    help = 'Сменить имя своему персонажу',
    params = {
        { name = 'firstname', type = 'string', help = 'Имя' },
        { name = 'lastname', type = 'string', help = 'Фамилия' },
    },
    restricted = 'group.admin',
}, function(source, args)
    local ok, result = setCharName(source, args.firstname, args.lastname)
    notify(source, ok and ('теперь тебя зовут %s'):format(result) or result, ok and 'success' or 'error')
end)

-- /setname ID Имя Фамилия — сменить имя другому игроку (только админы)
lib.addCommand('setname', {
    help = 'Сменить имя персонажу игрока',
    params = {
        { name = 'target', type = 'playerId', help = 'ID игрока' },
        { name = 'firstname', type = 'string', help = 'Имя' },
        { name = 'lastname', type = 'string', help = 'Фамилия' },
    },
    restricted = 'group.admin',
}, function(source, args)
    local ok, result = setCharName(args.target, args.firstname, args.lastname)
    notify(source, ok and ('имя игрока %d изменено на %s'):format(args.target, result) or result, ok and 'success' or 'error')
    if ok then notify(args.target, ('администратор сменил имя твоего персонажа на %s'):format(result), 'inform') end
end)
