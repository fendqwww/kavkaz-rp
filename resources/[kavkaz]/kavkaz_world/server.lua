-- KAVKAZ RP: задание «Четыре въезда» (15.11) — побывать у стел «НАГОРСК» на всех въездах в город (Config.Gates).
-- отметка ставится сервером: игрок должен реально стоять у въезда (проверка расстояния), отметки хранятся в metadata персонажа.
-- за все въезды — награда один раз (Config.GatesReward).

local NEAR = 90.0 -- м от точки въезда (стела ставится у ближайшей дороги, в пределах нескольких десятков метров)
local last = {}   -- антиспам: source -> время последней отметки

local function gateById(id)
    for _, g in ipairs(Config.Gates or {}) do
        if g.id == id then return g end
    end
end

RegisterNetEvent('kavkaz_world:gateVisit', function(id)
    local src = source
    if type(id) ~= 'string' then return end
    local now = os.time()
    if last[src] and now - last[src] < 3 then return end
    last[src] = now
    local g = gateById(id)
    if not g then return end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local c = GetEntityCoords(ped)
    if #(vec2(c.x, c.y) - vec2(g.coords.x, g.coords.y)) > NEAR then return end
    local p = exports.qbx_core:GetPlayer(src)
    if not p then return end
    local seen = p.PlayerData.metadata.kv_gates or {}
    if seen[id] then return end
    seen[id] = true
    p.Functions.SetMetaData('kv_gates', seen)
    local total, got = #Config.Gates, 0
    for _, gg in ipairs(Config.Gates) do if seen[gg.id] then got = got + 1 end end
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Четыре въезда', description = ('%s — отмечено (%d/%d)'):format(g.label, got, total), type = 'inform',
    })
    if got >= total and not seen.done then
        seen.done = true
        p.Functions.SetMetaData('kv_gates', seen)
        local r = Config.GatesReward or 0
        if r > 0 then exports.qbx_core:AddMoney(src, 'cash', r, 'задание: четыре въезда') end
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Четыре въезда', type = 'success', duration = 8000,
            description = ('Ты объехал все въезды Нагорска. Теперь город знает тебя в лицо.%s'):format(r > 0 and (' +%d ₽'):format(r) or ''),
        })
    end
end)

AddEventHandler('playerDropped', function() last[source] = nil end)
