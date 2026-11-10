-- ядро квестов: состояние персонажа, диалоги с NPC, цели на карте, награды. всё решает сервер.
-- состояние хранится в metadata персонажа: kavkaz_q = { line, step, rep, afterRent, trust, isaDay, theory, title, career, lineDone }

Q = { handlers = {}, objectives = {}, cars = {} }

local function player(src) return exports.qbx_core:GetPlayer(src) end

function Q.get(src)
    local p = player(src)
    if not p then return nil end
    local st = p.PlayerData.metadata.kavkaz_q
    if type(st) ~= 'table' then st = {} end
    st.porog = st.porog or 0
    st.trust = st.trust or 0
    st.bag = st.bag or {}
    return st
end

function Q.save(src, st)
    local p = player(src)
    if p then p.Functions.SetMetaData('kavkaz_q', st) end
end

function Q.notify(src, text, kind)
    exports.qbx_core:Notify(src, text, kind or 'inform', 6000)
end

function Q.reward(src, amount, reason)
    if amount and amount > 0 then exports.qbx_core:AddMoney(src, 'cash', amount, reason or 'квест') end
end

function Q.pay(src, amount, reason)
    if amount <= 0 then return true end
    for _, acc in ipairs({ 'cash', 'bank' }) do
        if (exports.qbx_core:GetMoney(src, acc) or 0) >= amount then return exports.qbx_core:RemoveMoney(src, acc, amount, reason) end
    end
    return false
end

function Q.trust(src, st, delta)
    st.trust = math.max(-20, math.min(100, (st.trust or 0) + delta))
    if delta > 0 then Q.notify(src, ('доверие Румисы +%d (сейчас %d)'):format(delta, st.trust), 'success')
    elseif delta < 0 then Q.notify(src, ('доверие Румисы %d (сейчас %d)'):format(delta, st.trust), 'error') end
end

function Q.charName(src)
    local p = player(src)
    if not p then return '' end
    return p.PlayerData.charinfo.firstname
end

function Q.today() return os.date('%Y-%m-%d') end

function Q.money(n)
    local s = tostring(math.floor(n)):reverse():gsub('(%d%d%d)', '%1 '):reverse()
    return (s:gsub('^ ', '')) .. ' ₽'
end

---------------------------------------------------------------------------
-- цели на карте: сервер ставит, клиент сообщает «дошёл», сервер проверяет дистанцию
---------------------------------------------------------------------------

-- obj = { id, text, coords (vec3), radius, drive (нужно быть в машине vehNet), deadline (os.time), anim, onReach(src) }
function Q.objective(src, obj)
    Q.objectives[src] = obj
    if not obj then
        TriggerClientEvent('kavkaz_quests:client:objective', src, nil)
        return
    end
    obj.started = os.time()
    TriggerClientEvent('kavkaz_quests:client:objective', src, {
        id = obj.id, text = obj.text, coords = obj.coords, radius = obj.radius or 3.0,
        drive = obj.vehNet ~= nil, anim = obj.anim, deadline = obj.deadline and (obj.deadline - os.time()) or nil,
    })
end

RegisterNetEvent('kavkaz_quests:server:reach', function(id)
    local src = source
    local obj = Q.objectives[src]
    if not obj or obj.id ~= id then return end
    local ped = GetPlayerPed(src)
    local pos = GetEntityCoords(ped)
    if #(pos.xy - obj.coords.xy) > (obj.radius or 3.0) + 3.0 then return end
    if obj.vehNet then
        local veh = NetworkGetEntityFromNetworkId(obj.vehNet)
        if not veh or veh == 0 or GetVehiclePedIsIn(ped, false) ~= veh then
            return Q.notify(src, 'нужно приехать на той машине, что тебе дали', 'error')
        end
    end
    Q.objectives[src] = nil
    TriggerClientEvent('kavkaz_quests:client:objective', src, nil)
    obj.onReach(src)
end)

-- машина для квеста: спавн рядом, ключи, удаляется при выходе с сервера
function Q.giveCar(src, model, at, warp)
    local ok, netId, veh = pcall(qbx.spawnVehicle, { model = model, spawnSource = at, warp = warp and GetPlayerPed(src) or nil })
    if not ok or not veh or veh == 0 then return nil end
    pcall(function() exports.qbx_vehiclekeys:GiveKeys(src, veh) end)
    Q.cars[src] = Q.cars[src] or {}
    Q.cars[src][#Q.cars[src] + 1] = netId
    return netId, veh
end

function Q.removeCar(src, netId)
    local veh = netId and NetworkGetEntityFromNetworkId(netId)
    if veh and veh ~= 0 and DoesEntityExist(veh) then DeleteEntity(veh) end
end

AddEventHandler('playerDropped', function()
    local src = source
    Q.objectives[src] = nil
    for _, netId in ipairs(Q.cars[src] or {}) do Q.removeCar(src, netId) end
    Q.cars[src] = nil
end)

---------------------------------------------------------------------------
-- диалоги: клиент спрашивает узел диалога, сервер собирает его по состоянию игрока
-- узел: { name, text, options = { { id, label } } } ; nil — закрыть окно
---------------------------------------------------------------------------

local function nearNpc(src, npcId)
    if npcId == 'start' then return true end -- окно выбора линии, проверка внутри обработчика
    local npc = Config.Npcs[npcId]
    if not npc then return false end
    return #(GetEntityCoords(GetPlayerPed(src)) - npc.coords.xyz) <= 5.0
end

function Q.node(npcId, text, options)
    return { npc = npcId, name = Config.Npcs[npcId] and Config.Npcs[npcId].name or 'Республика Нагорье', text = text, options = options or { { id = 'bye', label = 'До свидания' } } }
end

lib.callback.register('kavkaz_quests:talk', function(src, npcId, choice)
    if not nearNpc(src, npcId) then return nil end
    if choice == 'bye' then return nil end
    local st = Q.get(src)
    if not st then return nil end
    -- сначала сюжет: если у этого NPC сейчас шаг линии — разговор по шагу, иначе обычный разговор
    local ok, node = pcall(function()
        local storyNode = Q.storyTalk(src, st, npcId, choice)
        if storyNode then return storyNode end
        local handler = Q.handlers[npcId]
        return handler and handler(src, st, choice) or nil
    end)
    if not ok then
        lib.print.error(node)
        return nil
    end
    Q.save(src, st)
    return node
end)

-- после перезахода: вернуть текущую цель сюжета (story.lua)
RegisterNetEvent('kavkaz_quests:server:resume', function()
    local src = source
    if Q.objectives[src] then return end
    Q.storyResume(src)
end)
