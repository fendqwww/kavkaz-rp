-- KAVKAZ RP: дальнобой, клиент. показывает рейс, ставит метки, ловит события в пути; деньги считает сервер.

local job = nil          -- рейс от сервера (nil — нет)
local depotPed = 0
local targetBlip, trailerBlip = nil, nil
local trailerBlipOnEntity = false
local prompt = nil       -- { text, action } — подсказка с клавишей E
local shownText = nil
local busy = false       -- идёт действие (проверка, ремонт, доставка) — новые подсказки не ставим

---------------------------------------------------------------------------
-- мелочи
---------------------------------------------------------------------------
local function notify(text, kind, ms)
    pcall(function() exports.qbx_core:Notify(text, kind or 'inform', ms or 7000) end)
end

local function money(n)
    local s = tostring(math.floor((n or 0) + 0.5))
    local out = s:reverse():gsub('(%d%d%d)', '%1 '):reverse()
    return (out:gsub('^ ', ''))
end

local function flat(a, b)
    return #(vec2(a.x, a.y) - vec2(b.x, b.y))
end

local function netEntity(net)
    if not net or not NetworkDoesEntityExistWithNetworkId(net) then return 0 end
    local e = NetworkGetEntityFromNetworkId(net)
    if e ~= 0 and DoesEntityExist(e) then return e end
    return 0
end

local function setText(text)
    if text == shownText then return end
    shownText = text
    if text then lib.showTextUI(text, { position = 'top-center' }) else lib.hideTextUI() end
end

local function removeBlip(b)
    if b and DoesBlipExist(b) then RemoveBlip(b) end
    return nil
end

local function makeBlip(coords, sprite, color, label, route)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, sprite)
    SetBlipColour(b, color)
    SetBlipScale(b, 0.9)
    if route then SetBlipRoute(b, true); SetBlipRouteColour(b, color) end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(b)
    return b
end

local function clearJobUi()
    targetBlip = removeBlip(targetBlip)
    trailerBlip = removeBlip(trailerBlip)
    trailerBlipOnEntity = false
    prompt = nil
    setText(nil)
end

-- взять управление машиной (нужно, чтобы чинить её)
local function control(ent)
    if NetworkHasControlOfEntity(ent) then return true end
    local t = GetGameTimer()
    NetworkRequestControlOfEntity(ent)
    while not NetworkHasControlOfEntity(ent) do
        if GetGameTimer() - t > 2000 then return false end
        Wait(50)
        NetworkRequestControlOfEntity(ent)
    end
    return true
end

---------------------------------------------------------------------------
-- база: диспетчер, метка
---------------------------------------------------------------------------
CreateThread(function()
    local d = Config.Depot
    local b = AddBlipForCoord(d.ped.coords.x, d.ped.coords.y, d.ped.coords.z)
    SetBlipSprite(b, d.blip.sprite)
    SetBlipColour(b, d.blip.color)
    SetBlipScale(b, 0.8)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(d.label)
    EndTextCommandSetBlipName(b)
end)

local openOffers, cancelJob, returnTruck

local depotPoint = lib.points.new({ coords = Config.Depot.ped.coords.xyz, distance = 60.0 })

function depotPoint:onEnter()
    if depotPed ~= 0 and DoesEntityExist(depotPed) then return end
    local d = Config.Depot.ped
    local ok = pcall(lib.requestModel, d.model, 10000)
    if not ok then return end
    local ped = CreatePed(4, joaat(d.model), d.coords.x, d.coords.y, d.coords.z - 1.0, d.coords.w, false, true)
    SetModelAsNoLongerNeeded(joaat(d.model))
    if ped == 0 then return end
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    depotPed = ped
    exports.ox_target:addLocalEntity(ped, {
        { name = 'kv_trucker_offers', label = 'Рейсы', icon = 'fa-solid fa-truck', distance = Config.Depot.talk,
          onSelect = function() openOffers() end },
        { name = 'kv_trucker_cancel', label = 'Отменить рейс', icon = 'fa-solid fa-xmark', distance = Config.Depot.talk,
          canInteract = function() return job ~= nil end, onSelect = function() cancelJob() end },
        { name = 'kv_trucker_return', label = 'Сдать тягач', icon = 'fa-solid fa-square-parking', distance = Config.Depot.talk,
          canInteract = function() return job == nil end, onSelect = function() returnTruck() end },
    })
end

function depotPoint:onExit()
    if depotPed ~= 0 and DoesEntityExist(depotPed) then
        exports.ox_target:removeLocalEntity(depotPed, { 'kv_trucker_offers', 'kv_trucker_cancel', 'kv_trucker_return' })
        DeleteEntity(depotPed)
    end
    depotPed = 0
end

---------------------------------------------------------------------------
-- меню
---------------------------------------------------------------------------
local function accept(id)
    local ok, err = lib.callback.await('kavkaz_trucker:accept', false, id)
    if ok then
        notify('Рейс принят. Тягач твой — подцепи прицеп (метка на карте).', 'success')
    else
        notify(err or 'не получилось взять рейс', 'error')
    end
end

openOffers = function()
    local res = lib.callback.await('kavkaz_trucker:offers', false)
    if not res then return notify('Диспетчер тебя не слышит — подойди ближе.', 'error') end
    local head = ('Уровень: %s · рейсов %d · %.0f км'):format(res.levelLabel, res.trips or 0, res.km or 0)
    if res.nextXp then head = head .. (' · опыт %d/%d'):format(res.xp, res.nextXp) end
    local opts = { { title = head, icon = 'fa-solid fa-id-card', readOnly = true } }
    if res.hasJob then
        opts[#opts + 1] = { title = 'У тебя уже есть рейс', description = 'сначала доставь или отмени его', icon = 'fa-solid fa-route', readOnly = true }
    else
        for _, o in ipairs(res.list) do
            local title = ('%s → %s'):format(o.cargoLabel, o.to)
            if o.remote then title = ('%s: %s → %s'):format(o.cargoLabel, o.from, o.to) end
            local desc = ('%.1f км · ≈ %s ₽ · срок %d мин%s\n%s'):format(o.km, money(o.estimate), o.minutes,
                o.night and ' · ночной ×1.3' or '', o.note or '')
            opts[#opts + 1] = {
                title = title, description = desc,
                icon = o.contraband and 'fa-solid fa-box-open' or (o.remote and 'fa-solid fa-arrows-turn-to-dots' or 'fa-solid fa-truck-moving'),
                iconColor = o.contraband and '#e0a030' or nil,
                onSelect = function() accept(o.id) end,
            }
        end
        if #res.list == 0 then
            opts[#opts + 1] = { title = 'Рейсов нет', description = 'загляни через пару минут', readOnly = true }
        end
    end
    lib.registerContext({ id = 'kv_trucker_offers', title = Config.Depot.label, options = opts })
    lib.showContext('kv_trucker_offers')
end

cancelJob = function()
    local sure = lib.alertDialog({
        header = 'Отменить рейс?',
        content = ('Если прицеп уже выдан, удержат %s ₽.'):format(money(Config.CancelFine)),
        centered = true, cancel = true, labels = { confirm = 'Отменить рейс', cancel = 'Назад' },
    })
    if sure ~= 'confirm' then return end
    local ok, took = lib.callback.await('kavkaz_trucker:cancel', false)
    if ok then notify(('Рейс отменён%s.'):format((took or 0) > 0 and (', удержано ' .. money(took) .. ' ₽') or ''), 'inform') end
end

returnTruck = function()
    local ok, err = lib.callback.await('kavkaz_trucker:returnTruck', false)
    notify(ok and 'Тягач сдан. Спасибо за работу!' or (err or 'не получилось'), ok and 'success' or 'error')
end

-- в рейсе: /reis — эвакуация, отмена
RegisterCommand('reis', function()
    if not job then return notify('Рейса нет. Рейсы — у диспетчера автобазы в порту.', 'inform') end
    lib.registerContext({
        id = 'kv_trucker_trip', title = ('Рейс: %s → %s'):format(job.cargoLabel, job.to.label),
        options = {
            { title = 'Метка на точку', icon = 'fa-solid fa-location-dot', onSelect = function()
                local c = job.stage == 'pickup' and job.from.coords or job.to.coords
                SetNewWaypoint(c.x, c.y)
            end },
            { title = ('Новый тягач сюда — %s ₽'):format(money(Config.EvacPrice)), description = 'если тягач разбит или застрял',
              icon = 'fa-solid fa-truck-pickup', onSelect = function()
                local ok, err = lib.callback.await('kavkaz_trucker:evac', false)
                notify(ok and 'Новый тягач на месте. Езжай к прицепу.' or (err or 'не получилось'), ok and 'success' or 'error')
            end },
            { title = 'Отменить рейс', icon = 'fa-solid fa-xmark', onSelect = function() cancelJob() end },
        },
    })
    lib.showContext('kv_trucker_trip')
end, false)
TriggerEvent('chat:addSuggestion', '/reis', 'дальнобой: метка, новый тягач, отмена рейса')

---------------------------------------------------------------------------
-- место для прицепа/тягача: обочина ближайшей свободной дороги (спрашивает сервер)
---------------------------------------------------------------------------
lib.callback.register('kavkaz_trucker:roadSpot', function(c)
    if not c or not c.x then return nil end
    local x, y, z = c.x + 0.0, c.y + 0.0, c.z + 0.0
    for n = 1, 30 do
        local found, pos, heading = GetNthClosestVehicleNodeWithHeading(x, y, z, n, 1, 3.0, 2.5)
        if found and pos and flat(pos, c) <= 150.0 and not IsAnyVehicleNearPoint(pos.x, pos.y, pos.z, 9.0) then
            local rad = math.rad(heading)
            local px, py = pos.x + math.cos(rad) * 2.0, pos.y + math.sin(rad) * 2.0
            local ok, gz = GetGroundZFor_3dCoord(px, py, pos.z + 3.0, false)
            return vec4(px, py, (ok and gz or pos.z) + 0.6, heading)
        end
    end
    return nil
end)

---------------------------------------------------------------------------
-- рейс от сервера
---------------------------------------------------------------------------
RegisterNetEvent('kavkaz_trucker:client:job', function(data)
    local old = job
    job = data
    if not job then
        clearJobUi()
        return
    end
    job.receivedAt = GetGameTimer()
    job.postDone = {}
    if old and old.id == job.id then
        job.breakdownDone, job.broken, job.wp = old.breakdownDone, old.broken, old.wp
        for k, v in pairs(old.postDone or {}) do job.postDone[k] = v end
    end
    targetBlip = removeBlip(targetBlip)
    if job.stage == 'pickup' then
        targetBlip = makeBlip(job.from.coords, 479, 5, 'Погрузка: ' .. job.from.label, true)
    else
        targetBlip = makeBlip(job.to.coords, 478, 5, 'Разгрузка: ' .. job.to.label, true)
    end
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    job = nil
    clearJobUi()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearJobUi()
    if depotPed ~= 0 and DoesEntityExist(depotPed) then DeleteEntity(depotPed) end
end)

---------------------------------------------------------------------------
-- клавиша E для подсказок
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        if prompt and not busy then
            if IsControlJustPressed(0, 38) then
                local action = prompt.action
                prompt = nil
                busy = true
                local ok, err = pcall(action)
                if not ok then print('[kavkaz_trucker] ' .. tostring(err)) end
                busy = false
            end
            Wait(0)
        else
            Wait(200)
        end
    end
end)

---------------------------------------------------------------------------
-- события в пути
---------------------------------------------------------------------------
local function doDeliver(truck)
    if truck ~= 0 and IsVehicleAttachedToTrailer(truck) then
        if control(truck) then DetachVehicleFromTrailer(truck) end
        Wait(1200)
    end
    local ok, res = lib.callback.await('kavkaz_trucker:deliver', false)
    if ok then
        notify('Груз сдан.\n' .. table.concat(res or {}, '\n'), 'success', 12000)
    else
        notify(res or 'не получилось сдать груз', 'error')
    end
end

local function doRepair(truck, kind)
    local done = lib.progressBar({
        duration = Config.Breakdown.repairSeconds * 1000,
        label = kind == 'tyre' and 'Меняю колесо…' or 'Ковыряюсь в двигателе…',
        canCancel = true, disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
    })
    if not done then return end
    if truck == 0 or not DoesEntityExist(truck) or not control(truck) then
        return notify('Не получилось дотянуться до тягача — подойди ближе.', 'error')
    end
    for i = 0, 7 do SetVehicleTyreFixed(truck, i) end
    if GetVehicleEngineHealth(truck) < 900.0 then SetVehicleEngineHealth(truck, 900.0) end
    if job then job.broken = nil end
    notify('Готово, можно ехать.', 'success')
end

local function doCrane()
    local ok, err = lib.callback.await('kavkaz_trucker:crane', false)
    notify(ok and 'Кран поставил прицеп на колёса.' or (err or 'не получилось'), ok and 'success' or 'error')
end

local function postStop(idx, label)
    local done = lib.progressBar({
        duration = 8000, label = 'Инспектор проверяет документы на груз…', canCancel = false,
        disable = { move = true, car = true, combat = true },
    })
    if not done then return end
    local r = lib.callback.await('kavkaz_trucker:postStop', false, idx)
    if not r then return end
    if r.result == 'found' then
        notify(('%s: груз без документов изъят. Штраф %s ₽, рейс сорван.'):format(label, money(r.fine)), 'error', 10000)
    elseif r.result == 'overweight' then
        notify(('%s: перевес. Штраф %s ₽. Счастливого пути.'):format(label, money(r.fine)), 'error', 9000)
    else
        notify(('%s: документы в порядке. Счастливого пути!'):format(label), 'success')
    end
end

local whereAt = 0
local lostSent = false

local function tick()
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local inVeh = GetVehiclePedIsIn(ped, false)
    local truck = netEntity(job.truckNet)
    local trailer = netEntity(job.trailerNet)
    local newPrompt, text = nil, nil

    if job.stage == 'pickup' then
        if flat(pc, job.from.coords) < 120.0 and not job.arriving then
            job.arriving = true
            CreateThread(function()
                local ok = lib.callback.await('kavkaz_trucker:arrived', false)
                if not ok then Wait(5000) end
                if job then job.arriving = false end
            end)
        end
        text = ('Погрузка: %s · %.1f км'):format(job.from.label, flat(pc, job.from.coords) / 1000.0)
    else
        local attached = false
        if truck ~= 0 and trailer ~= 0 and IsVehicleAttachedToTrailer(truck) then
            local has, tr = GetVehicleTrailerVehicle(truck)
            attached = has and tr == trailer
        end

        -- метка на прицеп, если он не прицеплен
        if attached then
            trailerBlip = removeBlip(trailerBlip)
            trailerBlipOnEntity = false
        elseif trailer ~= 0 then
            if not trailerBlip or not trailerBlipOnEntity then
                trailerBlip = removeBlip(trailerBlip)
                trailerBlipOnEntity = true
                trailerBlip = AddBlipForEntity(trailer)
                SetBlipSprite(trailerBlip, 479); SetBlipColour(trailerBlip, 47)
                BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName('Прицеп'); EndTextCommandSetBlipName(trailerBlip)
            end
        elseif GetGameTimer() - whereAt > 5000 then
            whereAt = GetGameTimer()
            CreateThread(function()
                local c = lib.callback.await('kavkaz_trucker:where', false)
                if c and job and netEntity(job.trailerNet) == 0 then
                    trailerBlip = removeBlip(trailerBlip)
                    trailerBlipOnEntity = false
                    trailerBlip = makeBlip(c, 479, 47, 'Прицеп', false)
                end
            end)
        end

        -- прицеп уничтожен
        if trailer ~= 0 and not lostSent and (IsEntityDead(trailer) or GetVehicleBodyHealth(trailer) < 30.0) then
            lostSent = true
            CreateThread(function()
                lib.callback.await('kavkaz_trucker:trailerLost', false)
                Wait(3000)
                lostSent = false
            end)
        end

        local speed = truck ~= 0 and GetEntitySpeed(truck) or 0.0
        local driving = truck ~= 0 and inVeh == truck

        -- пост ДПС
        for _, ch in ipairs(job.checks or {}) do
            if not job.postDone[ch.i] then
                local d = flat(pc, ch.coords)
                local act = job.postActive
                if not act and driving and d < Config.PostCheck.radius then
                    job.postActive = { i = ch.i, label = ch.label, untilT = GetGameTimer() + Config.PostCheck.waitSeconds * 1000 }
                    notify(('%s: инспектор жезлом показывает остановиться у поста.'):format(ch.label), 'warning', 8000)
                    PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
                elseif act and act.i == ch.i then
                    if speed < 1.0 and d < Config.PostCheck.radius + 30.0 and not busy then
                        job.postDone[ch.i] = true
                        job.postActive = nil
                        busy = true
                        CreateThread(function()
                            local ok, err = pcall(postStop, ch.i, ch.label)
                            if not ok then print('[kavkaz_trucker] ' .. tostring(err)) end
                            busy = false
                        end)
                    elseif GetGameTimer() > act.untilT or d > Config.PostCheck.radius * 2.5 then
                        job.postDone[ch.i] = true
                        job.postActive = nil
                        CreateThread(function()
                            local r = lib.callback.await('kavkaz_trucker:postIgnored', false, ch.i)
                            if r then notify(('Камера поста: неподчинение требованию остановиться. Штраф %s ₽.'):format(money(r.fine)), 'error', 9000) end
                        end)
                    else
                        newPrompt = { text = ('Пост ДПС — остановись (%d с)'):format(math.max(0, math.ceil((act.untilT - GetGameTimer()) / 1000))) }
                    end
                end
            end
        end

        -- поломка на маршруте
        local bd = job.breakdown
        if bd and not job.breakdownDone and attached and driving and speed > 8.0 and GetPedInVehicleSeat(truck, -1) == ped then
            local total = flat(job.from.coords, job.to.coords)
            local frac = total > 0 and (1.0 - flat(pc, job.to.coords) / total) or 0.0
            if frac >= bd.at then
                job.breakdownDone = true
                job.broken = bd.kind
                if bd.kind == 'tyre' then
                    SetVehicleTyreBurst(truck, math.random(0, 1), true, 1000.0)
                    notify('Хлопок! Пробито колесо. Остановись у обочины и почини (выйди, подойди к тягачу).', 'error', 10000)
                else
                    SetVehicleEngineHealth(truck, 250.0)
                    notify('Двигатель греется и дымит. Остановись у обочины и посмотри, что с ним.', 'error', 10000)
                end
            end
        end
        if job.broken and truck ~= 0 and inVeh == 0 and #(pc - GetEntityCoords(truck)) < 6.0 and not newPrompt then
            local kind = job.broken
            newPrompt = { text = kind == 'tyre' and '[E] Поменять колесо' or '[E] Починить двигатель', action = function() doRepair(truck, kind) end }
        end

        -- перевёрнутый прицеп
        if trailer ~= 0 and inVeh == 0 and IsEntityUpsidedown(trailer) and #(pc - GetEntityCoords(trailer)) < 10.0 and not newPrompt then
            newPrompt = { text = ('[E] Вызвать кран — %s ₽'):format(money(Config.CranePrice)), action = doCrane }
        end

        -- разгрузка
        if trailer ~= 0 and flat(GetEntityCoords(trailer), job.to.coords) <= Config.UnloadRadius and not newPrompt then
            if attached and driving and speed < 1.0 then
                newPrompt = { text = '[E] Отцепить прицеп и сдать груз', action = function() doDeliver(truck) end }
            elseif not attached and #(pc - GetEntityCoords(trailer)) < 50.0 then
                newPrompt = { text = '[E] Сдать груз', action = function() doDeliver(truck) end }
            end
        end

        -- строка рейса
        local left = job.deadlineLeft - (GetGameTimer() - job.receivedAt) / 1000
        local timeText = left >= 0 and ('%d мин'):format(math.ceil(left / 60)) or 'опоздание'
        if not attached then
            text = ('%s: подцепи прицеп (метка «Прицеп»)'):format(job.cargoLabel)
        else
            text = ('%s → %s · %.1f км · %s'):format(job.cargoLabel, job.to.label, flat(pc, job.to.coords) / 1000.0, timeText)
        end
        if job.broken then text = text .. ' · поломка!' end
    end

    if busy then return setText(nil) end
    prompt = newPrompt and newPrompt.action and newPrompt or nil
    if newPrompt then
        setText(newPrompt.text)
    elseif inVeh ~= 0 then
        setText(text)
    else
        setText(nil)
    end
end

CreateThread(function()
    while true do
        if job then
            local ok, err = pcall(tick)
            if not ok then print('[kavkaz_trucker] ' .. tostring(err)) end
            Wait(250)
        else
            if shownText then setText(nil) end
            prompt = nil
            Wait(1000)
        end
    end
end)
