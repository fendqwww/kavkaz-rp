-- KAVKAZ RP: силовики — игрок на смене останавливает NPC-машину.
-- M (Config.ActionKey): в машине — тому, кто впереди; пешком — машине, на которую смотришь (жест жезлом).
-- дальше у водительской двери (ALT, ox_target): документы, алкотестер, база, осмотр, штраф, задержать, отпустить.

local cur = nil      -- текущая остановка: { id, veh, driver, state, temper, male, plate, car, blip, onFoot }
local busy = false   -- идёт действие (прогресс-бар, ответ сервера)
local textShown = false

local addTargets -- объявлена ниже (нужна задержанию до определения)
local OPT_NAMES = { 'kvlaw_talk', 'kvlaw_docs', 'kvlaw_alco', 'kvlaw_base', 'kvlaw_search', 'kvlaw_fine', 'kvlaw_detain', 'kvlaw_release' }

local function myName()
    local ok, pd = pcall(function() return exports.qbx_core:GetPlayerData() end)
    local d = Law.duty()
    local rank = d and Config.Orgs[d.org] and Config.Orgs[d.org].ranks[d.rank or 0] or 'инспектор'
    local last = ok and pd and pd.charinfo and pd.charinfo.lastname or ''
    return (rank:lower() .. ' ' .. last):gsub('%s+$', '')
end

local function driverWho() return cur and (cur.male and 'Водитель' or 'Водитель') or 'Водитель' end

local function removeTargets(c)
    if not c then return end
    for _, e in ipairs({ c.veh, c.driver }) do
        if e and DoesEntityExist(e) then pcall(function() exports.ox_target:removeLocalEntity(e, OPT_NAMES) end) end
    end
end

local function hideText()
    if textShown then lib.hideTextUI() textShown = false end
end

-- закончить остановку: отпустить NPC (если ещё наш), убрать метки и опции
local function cleanup(release)
    local c = cur
    cur = nil
    hideText()
    if not c then return end
    removeTargets(c)
    if c.blip and DoesBlipExist(c.blip) then RemoveBlip(c.blip) end
    if release ~= false then Law.releaseDriver(c.veh, c.driver) end
end

local function stillValid()
    return cur and cur.veh and DoesEntityExist(cur.veh)
end

---------------------------------------------------------------------------
-- действия у окна
---------------------------------------------------------------------------
local function act(action, arg)
    if not cur then return nil end
    local res = lib.callback.await('kavkaz_law:action', false, cur.id, action, arg)
    if not res then return nil end
    if res.error then Law.notify(res.error, 'error') return nil end
    return res
end

local function progress(label, ms, dict, clip, flag)
    local anim = dict and { dict = dict, clip = clip, flag = flag or 49 } or nil
    return lib.progressBar({ duration = ms, label = label, canCancel = true, useWhileDead = false,
        disable = { move = true, car = true, combat = true }, anim = anim })
end

local function yesno(v) return v and 'да' or 'нет' end

local function talk()
    if not cur then return end
    local d = Law.duty()
    local list = (d and d.org == 'fsb') and Phrases.officerGreetFsb or Phrases.officerGreet
    Law.say('Вы', list[math.random(#list)]:format(myName()), 4500)
    SetTimeout(4600, function()
        if cur then Law.say(driverWho(), Phrases.pick(Phrases.driverGreet, cur.temper), 4500) end
    end)
end

local function docs()
    if busy or not cur then return end
    busy = true
    if not cur.greeted then cur.greeted = true talk() Wait(2500) end
    if not cur then busy = false return end
    if progress('проверка документов', 4000, 'mp_common', 'givetake1_a', 0) then
        local r = act('docs')
        if r then
            local lic = r.license == 'ok' and 'действительно' or r.license == 'expired' and '**просрочено**'
                or r.license == 'revoked' and '**лишён права управления** (по базе ГИБДД)' or '**не предъявлено**'
            local seen = {}
            if not r.belt then seen[#seen + 1] = '— водитель **не пристёгнут**' end
            if r.phone then seen[#seen + 1] = '— в руке **телефон**' end
            if r.smell then seen[#seen + 1] = '— из салона **запах алкоголя**' end
            lib.alertDialog({
                header = 'Документы водителя',
                content = ('**%s**, %d г. р.  \n\nводительское удостоверение: %s  \n№ %s  \n\nмашина: %s, госномер **%s**  \nСТС: %s  \nОСАГО: %s%s'):format(
                    r.name, r.born, lic, r.licNumber, r.car or 'автомобиль', r.plate or '—',
                    r.sts == 'ok' and 'есть' or '**нет**',
                    r.osago == 'ok' and 'действует' or r.osago == 'expired' and '**просрочен**' or '**нет**',
                    #seen > 0 and ('\n\n' .. table.concat(seen, '  \n')) or ''),
                centered = true, cancel = false,
            })
            if r.smell and cur then Law.say(driverWho(), Phrases.driverSmell[math.random(#Phrases.driverSmell)], 4000) end
        end
    end
    busy = false
end

local function alco()
    if busy then return end
    busy = true
    if progress('алкотестер: водитель дует в трубку', 5000, 'mp_common', 'givetake1_a', 0) then
        local r = act('alco')
        if r then
            local drunk = r.bac > 0.16
            Law.notify(('алкотестер: %.2f мг/л — %s'):format(r.bac, drunk and 'опьянение (норма до 0,16)' or 'в пределах нормы'), drunk and 'error' or 'success', 'Алкотестер')
            if drunk and cur then Law.say(driverWho(), 'Да это прибор у вас сломанный!', 3500) end
        end
    end
    busy = false
end

local function base()
    if busy then return end
    busy = true
    Law.anim('random@arrests')
    if progress('запрос по рации в дежурную часть', 4500, 'random@arrests', 'generic_radio_chatter', 49) then
        local r = act('base')
        if r then
            local lines = {}
            lines[#lines + 1] = r.wanted and ('водитель **в розыске**: %s'):format(r.wanted) or 'водитель в розыске не значится'
            lines[#lines + 1] = r.stolen and ('машина **%s в угоне**'):format(r.plate or '') or 'машина в угоне не числится'
            lib.alertDialog({ header = 'Ответ дежурной части', content = table.concat(lines, '  \n'), centered = true, cancel = false })
            if (r.wanted or r.stolen) and cur then PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true) end
        end
    end
    busy = false
end

local function search()
    if busy then return end
    busy = true
    Law.anim('mini@repair')
    if progress('осмотр салона и багажника', 8000, 'mini@repair', 'fixing_a_ped', 1) then
        local r = act('search')
        if r then
            if r.item then
                Law.notify(('найдено: %s'):format(r.item), 'error', 'Осмотр')
                if cur then Law.say(driverWho(), 'Это не моё! Машина вообще не моя!', 3500) end
            else
                Law.notify('ничего запрещённого не найдено', 'success', 'Осмотр')
            end
        end
    end
    busy = false
end

local function fineMenu()
    if not cur then return end
    local options = {}
    for _, f in ipairs(Config.Fines) do
        options[#options + 1] = {
            title = f.label, description = ('%d ₽'):format(f.amount), icon = 'file-invoice',
            onSelect = function()
                if busy or not cur then return end
                busy = true
                if progress('составление протокола', 5000, 'amb@medic@standing@timeofdeath@base', 'base', 49) then
                    local r = act('fine', f.id)
                    if r and cur then
                        if r.complaint then
                            Law.say(driverWho(), Phrases.driverWrongFine[math.random(#Phrases.driverWrongFine)], 4500)
                            Law.notify(r.text, 'error', 'Жалоба')
                        else
                            Law.say(driverWho(), Phrases.pick(Phrases.driverFined, cur.temper), 4000)
                            Law.notify(r.text, 'success', 'Протокол')
                        end
                    end
                end
                busy = false
            end,
        }
    end
    lib.registerContext({ id = 'kvlaw_fine', title = 'Статья КоАП', options = options })
    lib.showContext('kvlaw_fine')
end

---------------------------------------------------------------------------
-- задержание и доставка
---------------------------------------------------------------------------
local function cuffAnim(ped)
    if not DoesEntityExist(ped) then return end
    Law.anim('mp_arresting')
    if not IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3) then
        TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0.0, false, false, false)
    end
    SetEnableHandcuffs(ped, true)
end

local function detain()
    if busy or not cur then return end
    busy = true
    local r = act('detain')
    if not r then busy = false return end
    if r.refused then
        Law.notify(r.text, 'error', 'Превышение полномочий')
        busy = false
        return
    end
    local c = cur
    local driver = c.driver
    if not Law.control(driver, 1000) then
        Law.notify('не получилось — попробуйте ещё раз', 'error')
        busy = false
        return
    end
    removeTargets(c)
    if IsPedInAnyVehicle(driver, false) then
        TaskLeaveVehicle(driver, c.veh, 256)
        local t = GetGameTimer() + 8000
        while IsPedInAnyVehicle(driver, false) and GetGameTimer() < t do Wait(200) end
        if IsPedInAnyVehicle(driver, false) then TaskLeaveVehicle(driver, c.veh, 16) Wait(800) end
    end
    if not DoesEntityExist(driver) then busy = false cleanup(false) return end
    ClearPedTasks(driver)
    SetBlockingOfNonTemporaryEvents(driver, true)
    Law.say(driverWho(), Phrases.driverDetained[math.random(#Phrases.driverDetained)], 3500)
    Law.anim('mp_arresting')
    TaskPlayAnim(PlayerPedId(), 'mp_arresting', 'a_uncuff', 8.0, -8.0, 2500, 49, 0.0, false, false, false)
    Wait(1500)
    cuffAnim(driver)
    local res = act('detain_confirm', NetworkGetNetworkIdFromEntity(driver))
    if not cur then busy = false return end
    if not res then -- не вышло: снимаем наручники, проверку можно продолжить
        if DoesEntityExist(driver) then ClearPedTasks(driver) SetEnableHandcuffs(driver, false) end
        addTargets(c)
        busy = false
        return
    end
    c.state = 'detained'
    -- машина задержанного остаётся с аварийкой, игра уберёт её сама
    if DoesEntityExist(c.veh) and Law.control(c.veh, 500) then
        SetVehicleIndicatorLights(c.veh, 0, true)
        SetVehicleIndicatorLights(c.veh, 1, true)
        SetEntityAsNoLongerNeeded(c.veh)
    end
    if c.blip and DoesBlipExist(c.blip) then RemoveBlip(c.blip) c.blip = nil end
    TaskFollowToOffsetOfEntity(driver, PlayerPedId(), 0.4, -1.0, 0.0, 1.3, -1, 1.0, true)
    local st = Law.nearestStation(GetEntityCoords(PlayerPedId()))
    SetNewWaypoint(st.x, st.y)
    Law.notify('задержанный идёт за вами. посадите его в служебную машину (ALT на машине) и отвезите в отдел — метка на карте', 'inform', 'Задержание')
    busy = false
end

-- посадить в служебную машину
exports.ox_target:addGlobalVehicle({
    {
        name = 'kvlaw_seat', icon = 'fa-solid fa-car-side', label = 'Посадить задержанного', distance = 3.0,
        canInteract = function(entity)
            if not cur or cur.state ~= 'detained' or not cur.driver or not DoesEntityExist(cur.driver) then return false end
            if IsPedInAnyVehicle(cur.driver, false) then return false end
            return GetVehicleClass(entity) == 18 or Entity(entity).state.kvLawCar == GetPlayerServerId(PlayerId())
        end,
        onSelect = function(data)
            local veh = data.entity
            local ped = cur and cur.driver
            if not ped or not Law.control(ped, 800) then return end
            local seat = IsVehicleSeatFree(veh, 2) and 2 or IsVehicleSeatFree(veh, 1) and 1 or 0
            TaskEnterVehicle(ped, veh, 10000, seat, 1.0, 1, 0)
            local t = GetGameTimer() + 12000
            while DoesEntityExist(ped) and not IsPedInVehicle(ped, veh, false) and GetGameTimer() < t do Wait(250) end
            if DoesEntityExist(ped) and not IsPedInVehicle(ped, veh, false) then SetPedIntoVehicle(ped, veh, seat) end
            if cur then cur.seatVeh = veh end
        end,
    },
})

local function deliver()
    if busy or not cur then return end
    busy = true
    local r = lib.callback.await('kavkaz_law:deliver', false, cur.id)
    if r and r.ok then
        local ped = cur.driver
        Law.notify(r.text, 'success', 'Задержанный сдан')
        if ped and DoesEntityExist(ped) and Law.control(ped, 800) then
            if IsPedInAnyVehicle(ped, false) then
                TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
                Wait(600)
            end
            NetworkFadeOutEntity(ped, false, true)
            Wait(1000)
            Law.delete(ped)
        end
        cleanup(false)
    elseif r and r.error then
        Law.notify(r.error, 'error')
    end
    busy = false
end

---------------------------------------------------------------------------
-- отпустить
---------------------------------------------------------------------------
local function release()
    if busy or not cur then return end
    busy = true
    local r = act('release')
    if r then
        Law.say('Вы', Phrases.officerRelease[math.random(#Phrases.officerRelease)], 3500)
        local temper = cur.temper
        SetTimeout(3600, function() Law.say('Водитель', Phrases.pick(Phrases.driverReleased, temper), 3500) end)
        if r.text then Law.notify(r.text, 'success') end
        cleanup(true)
    end
    busy = false
end

addTargets = function(c)
    local function can(_, distance) return cur == c and cur.state == 'stopped' and not busy and distance <= 3.0 end
    local opts = {
        { name = 'kvlaw_talk', icon = 'fa-solid fa-comments', label = 'Представиться', distance = 3.0, canInteract = can, onSelect = talk },
        { name = 'kvlaw_docs', icon = 'fa-solid fa-id-card', label = 'Проверить документы', distance = 3.0, canInteract = can, onSelect = docs },
        { name = 'kvlaw_alco', icon = 'fa-solid fa-wind', label = 'Алкотестер', distance = 3.0, canInteract = can, onSelect = alco },
        { name = 'kvlaw_base', icon = 'fa-solid fa-tower-broadcast', label = 'Пробить по базе', distance = 3.0, canInteract = can, onSelect = base },
        { name = 'kvlaw_search', icon = 'fa-solid fa-magnifying-glass', label = 'Осмотреть машину', distance = 3.0, canInteract = can, onSelect = search },
        { name = 'kvlaw_fine', icon = 'fa-solid fa-file-invoice', label = 'Выписать штраф', distance = 3.0, canInteract = can, onSelect = fineMenu },
        { name = 'kvlaw_detain', icon = 'fa-solid fa-handcuffs', label = 'Задержать', distance = 3.0, canInteract = can, onSelect = detain },
        { name = 'kvlaw_release', icon = 'fa-solid fa-hand', label = 'Отпустить', distance = 3.0, canInteract = can, onSelect = release },
    }
    for _, e in ipairs({ c.veh, c.driver }) do
        if e and DoesEntityExist(e) then exports.ox_target:addLocalEntity(e, opts) end
    end
end

---------------------------------------------------------------------------
-- погоня
---------------------------------------------------------------------------
local function surrender(c)
    local driver = c.driver
    if Law.control(driver, 800) then
        if IsPedInAnyVehicle(driver, false) then
            TaskLeaveVehicle(driver, c.veh, 0)
            local t = GetGameTimer() + 6000
            while IsPedInAnyVehicle(driver, false) and GetGameTimer() < t do Wait(200) end
        end
        TaskHandsUp(driver, -1, PlayerPedId(), -1, true)
    end
    Law.say(driverWho(), Phrases.driverSurrender[math.random(#Phrases.driverSurrender)], 4000)
    lib.callback.await('kavkaz_law:stopState', false, c.id, 'surrendered')
    if cur ~= c then return end
    c.state = 'stopped'
    if c.blip and DoesBlipExist(c.blip) then SetBlipFlashes(c.blip, false) SetBlipColour(c.blip, 3) end
    addTargets(c)
    Law.notify('нарушитель сдался — подойдите (ALT): задержать по ст. 12.25 или проверить документы', 'success', 'Погоня')
end

local function flee(c)
    local veh, driver = c.veh, c.driver
    if not Law.control(veh, 800) or not Law.control(driver, 800) then return false end
    SetEntityAsMissionEntity(veh, true, true)
    SetEntityAsMissionEntity(driver, true, true)
    SetBlockingOfNonTemporaryEvents(driver, true)
    SetDriverAbility(driver, 1.0)
    SetDriverAggressiveness(driver, 0.75)
    SetVehicleEngineOn(veh, true, true, false)
    local function task()
        TaskVehicleMissionPedTarget(driver, veh, PlayerPedId(), 8, 40.0, 1074528293, 0.0, 0.0, true)
        SetPedKeepTask(driver, true)
    end
    task()
    c.state = 'flee'
    c.blip = AddBlipForEntity(veh)
    SetBlipColour(c.blip, 1)
    SetBlipFlashes(c.blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Нарушитель')
    EndTextCommandSetBlipName(c.blip)
    Law.notify('водитель удирает! догоните и прижмите его — сдастся, когда встанет', 'warning', 'Погоня')
    PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
    local started, far, slow, lastTask = GetGameTimer(), 0.0, 0.0, GetGameTimer()
    while cur == c and c.state == 'flee' do
        Wait(500)
        if not DoesEntityExist(veh) or not DoesEntityExist(driver) or IsPedDeadOrDying(driver, true) then
            lib.callback.await('kavkaz_law:stopState', false, c.id, 'lost')
            Law.notify('погоня окончена: нарушитель погиб или пропал', 'error', 'Погоня')
            cleanup(false)
            return
        end
        local d = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(veh))
        far = d > 550.0 and far + 0.5 or 0.0
        local stuck = GetEntitySpeed(veh) < 1.5 or GetVehicleEngineHealth(veh) < 150.0 or IsEntityUpsidedown(veh) or not IsPedInAnyVehicle(driver, false)
        slow = (stuck and d < 35.0) and slow + 0.5 or 0.0
        if slow >= 3.0 then surrender(c) return end
        if far >= 12.0 or GetGameTimer() - started > 360000 then
            lib.callback.await('kavkaz_law:stopState', false, c.id, 'escaped')
            Law.notify('нарушитель скрылся', 'error', 'Погоня')
            cleanup(true)
            return
        end
        if GetGameTimer() - lastTask > 10000 and IsPedInAnyVehicle(driver, false) and Law.control(driver, 300) then
            lastTask = GetGameTimer()
            task()
        end
    end
end

---------------------------------------------------------------------------
-- требование остановиться
---------------------------------------------------------------------------
local function findTarget()
    local me = PlayerPedId()
    local myVeh = GetVehiclePedIsIn(me, false)
    local origin, fwd, minDot
    if myVeh ~= 0 then
        origin, fwd, minDot = GetEntityCoords(myVeh), GetEntityForwardVector(myVeh), 0.94
    else
        local rot = GetGameplayCamRot(2)
        local rx, rz = math.rad(rot.x), math.rad(rot.z)
        origin = GetEntityCoords(me)
        fwd = vector3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
        minDot = 0.90
    end
    local best, bestScore
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if veh ~= myVeh and DoesEntityExist(veh) then
            local driver = GetPedInVehicleSeat(veh, -1)
            if driver ~= 0 and not IsPedAPlayer(driver) and not IsPedDeadOrDying(driver, true) and not Law.hasPlayerInside(veh) and GetVehicleClass(veh) ~= 18 then
                local to = GetEntityCoords(veh) - origin
                local dist = #to
                if dist > 4.0 and dist < 60.0 then
                    local dot = (to.x * fwd.x + to.y * fwd.y + to.z * fwd.z) / dist
                    if dot > minDot then
                        local score = dist * (2.0 - dot)
                        if not bestScore or score < bestScore then best, bestScore = veh, score end
                    end
                end
            end
        end
    end
    return best
end

local function requestStop()
    if not Law.duty() then return end
    if cur then
        if cur.state == 'pulling' then return end
        Law.notify('сначала закончите с текущей машиной (отпустить или задержать)', 'error')
        return
    end
    if busy or IsPauseMenuActive() then return end
    local me = PlayerPedId()
    local onFoot = not IsPedInAnyVehicle(me, false)
    local veh = findTarget()
    if not veh then
        Law.notify(onFoot and 'посмотрите на машину, которую останавливаете' or 'впереди нет машины', 'error')
        return
    end
    local driver = GetPedInVehicleSeat(veh, -1)
    busy = true
    if onFoot then
        CreateThread(function()
            TaskStartScenarioInPlace(me, 'WORLD_HUMAN_CAR_PARK_ATTENDANT', 0, true) -- жест жезлом
            Wait(3000)
            if not IsPedInAnyVehicle(me, false) then ClearPedTasks(me) end
        end)
    else
        BlipSiren(GetVehiclePedIsIn(me, false)) -- короткий «кряк»
    end
    if not Law.control(veh, 1200) or not Law.control(driver, 1200) then
        busy = false
        Law.notify('водитель вас не заметил — повторите', 'error')
        return
    end
    local res = lib.callback.await('kavkaz_law:stopRequest', false, NetworkGetNetworkIdFromEntity(veh), IsPedMale(driver))
    busy = false
    if not res or res.error then
        if res and res.error then Law.notify(res.error, 'error') end
        return
    end
    if res.outcome == 'ignore' then
        Law.notify('водитель делает вид, что не видит. повторите требование (M)', 'warning')
        return
    end
    local c = { id = res.id, veh = veh, driver = driver, temper = res.temper, male = res.male, plate = res.plate, car = res.car, onFoot = onFoot }
    cur = c
    if res.outcome == 'flee' then
        CreateThread(function() flee(c) end)
        return
    end
    c.state = 'pulling'
    CreateThread(function()
        local pocket
        if onFoot then
            local p = GetEntityCoords(PlayerPedId())
            local edge, out, dir = Law.roadEdge(p, GetEntityForwardVector(veh))
            pocket = edge and (edge - out * 2.3 + dir * 6.0) or p
        else
            pocket = Law.pocketAhead(veh, 30.0)
        end
        local ok = Law.pullOver(veh, driver, pocket, 30000)
        if cur ~= c then return end
        if not ok then
            lib.callback.await('kavkaz_law:stopState', false, c.id, 'lost')
            Law.notify('водитель не смог остановиться', 'error')
            cleanup(true)
            return
        end
        lib.callback.await('kavkaz_law:stopState', false, c.id, 'stopped')
        if cur ~= c then return end
        c.state = 'stopped'
        addTargets(c)
        Law.notify(('%s, госномер %s, остановился. подойдите к водителю (ALT)'):format(res.car or 'машина', res.plate or ''), 'success')
    end)
end

-- клавиша действия: у отдела с задержанным — сдать, иначе — требование остановиться
function Law.actionKey()
    if not Law.duty() then return end
    if cur and cur.state == 'detained' then
        local _, d = Law.nearestStation(GetEntityCoords(PlayerPedId()))
        if d <= Config.DeliverRadius then deliver() return end
        Law.notify('задержанного сдают у отдела ГИБДД или управления ФСБ (метка на карте)', 'inform')
        return
    end
    requestStop()
end

---------------------------------------------------------------------------
-- присмотр за остановкой: пропала машина, ушли далеко, задержанный потерялся, подсказка у отдела
---------------------------------------------------------------------------
CreateThread(function()
    local farSince
    while true do
        local sleep = 1000
        local c = cur
        if c then
            local myPos = GetEntityCoords(PlayerPedId())
            if c.state == 'stopped' then
                if not stillValid() or not DoesEntityExist(c.driver) or IsPedDeadOrDying(c.driver, true) then
                    lib.callback.await('kavkaz_law:stopState', false, c.id, 'lost')
                    Law.notify('проверка прервана: машина или водитель пропали', 'error')
                    cleanup(false)
                elseif #(myPos - GetEntityCoords(c.veh)) > 200.0 then
                    farSince = farSince or GetGameTimer()
                    if GetGameTimer() - farSince > 15000 then
                        lib.callback.await('kavkaz_law:stopState', false, c.id, 'lost')
                        Law.notify('вы уехали — водитель уехал тоже', 'inform')
                        cleanup(true)
                        farSince = nil
                    end
                else
                    farSince = nil
                end
            elseif c.state == 'detained' then
                local ped = c.driver
                if not ped or not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) or #(myPos - GetEntityCoords(ped)) > 120.0 then
                    lib.callback.await('kavkaz_law:detaineeLost', false, c.id)
                    Law.notify('задержанный потерян', 'error')
                    cleanup(false)
                else
                    if not IsPedInAnyVehicle(ped, false) then
                        cuffAnim(ped)
                        -- отстал и стоит — задача следования слетела, даём заново
                        if #(GetEntityCoords(ped) - myPos) > 3.5 and GetEntitySpeed(ped) < 0.3 and Law.control(ped, 300) then
                            TaskFollowToOffsetOfEntity(ped, PlayerPedId(), 0.4, -1.0, 0.0, 1.3, -1, 1.0, true)
                        end
                    end
                    local _, d = Law.nearestStation(myPos)
                    if d <= Config.DeliverRadius then
                        if not textShown then lib.showTextUI(('[%s] Сдать задержанного'):format(Config.ActionKey)) textShown = true end
                    else
                        hideText()
                    end
                end
            end
        else
            farSince = nil
        end
        Wait(sleep)
    end
end)

-- смена закончилась (сам, жалобы, выход) — остановку бросаем
RegisterNetEvent('kavkaz_law:client:dutyEnded', function()
    if cur then
        if cur.state == 'detained' and cur.driver and DoesEntityExist(cur.driver) then
            Law.releaseDriver(nil, cur.driver)
            if Law.control(cur.driver, 400) then ClearPedTasks(cur.driver) SetEnableHandcuffs(cur.driver, false) end
        end
        cleanup(cur.state ~= 'detained')
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= Law.RES then return end
    hideText()
    if cur then removeTargets(cur) if cur.blip then RemoveBlip(cur.blip) end end
    pcall(function() exports.ox_target:removeGlobalVehicle({ 'kvlaw_seat' }) end)
end)
