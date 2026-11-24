-- KAVKAZ RP: пролог «Домой» — кто его смотрит, можно ли пропустить, что дальше (kavkaz_quests: глава 1).

local playing = {}

local function player(src) return exports.qbx_core:GetPlayer(src) end

-- пропускать можно, если у аккаунта уже есть другой персонаж (пролог уже видел) или это админ
local function canSkip(src)
    if IsPlayerAceAllowed(src, 'group.admin') then return true end
    local license = GetPlayerIdentifierByType(src, 'license')
    if not license then return false end
    local n = MySQL.scalar.await('SELECT COUNT(*) FROM players WHERE license = ?', { license }) or 0
    return n > 1
end

local function start(src)
    if playing[src] then return end
    playing[src] = true
    TriggerClientEvent('kavkaz_intro:client:play', src, { skippable = canSkip(src) })
end
exports('Start', start)

-- тон первого ответа дяде: дядя потом это вспомнит (kavkaz_quests)
local TONES = { respect = true, joke = true, dry = true }
RegisterNetEvent('kavkaz_intro:server:tone', function(tone)
    local src = source
    if not playing[src] or not TONES[tone] then return end
    local p = player(src)
    if not p then return end
    local st = p.PlayerData.metadata.kavkaz_q
    if type(st) ~= 'table' then st = {} end
    st.uncleTone = tone
    p.Functions.SetMetaData('kavkaz_q', st)
end)

RegisterNetEvent('kavkaz_intro:server:done', function(skipped)
    local src = source
    if not playing[src] then return end
    playing[src] = nil
    local p = player(src)
    if not p then return end
    p.Functions.SetMetaData('kavkaz_intro', true)
    lib.print.info(('пролог: %s %s (citizenid %s)%s'):format(p.PlayerData.charinfo.firstname, p.PlayerData.charinfo.lastname,
        p.PlayerData.citizenid, skipped and ' — пропущен' or ''))
    -- дальше глава 1 «Свой человек»: метка к дяде во дворе
    if GetResourceState('kavkaz_quests') == 'started' then TriggerEvent('kavkaz_quests:server:startHome', src) end
end)

AddEventHandler('playerDropped', function() playing[source] = nil end)

-- /intro [id] — показать пролог ещё раз (админ: проверить сцены)
lib.addCommand('intro', {
    help = 'Показать пролог «Домой» (себе или игроку)',
    params = { { name = 'target', type = 'playerId', help = 'ID игрока', optional = true } },
    restricted = 'group.admin',
}, function(src, args)
    local target = args.target or src
    playing[target] = nil
    start(target)
end)
