-- KAVKAZ RP: силовики — общие функции клиента (загрузка моделей, управление NPC, речь, обочина)

Law = {}
Law.RES = GetCurrentResourceName()

function Law.duty() return LocalPlayer.state.kvLaw end
function Law.org() local d = LocalPlayer.state.kvLaw return d and d.org or nil end
function Law.mode() return (GlobalState.kvLawMode or {}).id or 'normal' end

-- первая буква заглавная (кириллица тоже: string.upper её не трогает)
function Law.ucfirst(s)
    if type(s) ~= 'string' or s == '' then return s end
    local cp = utf8.codepoint(s, 1)
    local up = cp
    if cp >= 0x430 and cp <= 0x44F then up = cp - 0x20
    elseif cp == 0x451 then up = 0x401
    elseif cp >= 97 and cp <= 122 then up = cp - 32 end
    return utf8.char(up) .. s:sub((utf8.offset(s, 2))) -- скобки: в новых Lua offset отдаёт два числа
end

function Law.notify(text, kind, title)
    lib.notify({ title = title or 'Служба', description = text, type = kind or 'inform', duration = 7000 })
end

-- речь NPC субтитром внизу экрана, как в игре. длинный текст режем на куски (у GTA предел ~99 байт на кусок)
function Law.say(who, text, ms)
    local s = who and ('~y~%s:~s~ %s'):format(who, text) or text
    BeginTextCommandPrint('CELL_EMAIL_BCON')
    local chunk, n = {}, 0
    for _, c in utf8.codes(s) do
        chunk[#chunk + 1] = utf8.char(c)
        n = n + 1
        if n >= 40 then
            AddTextComponentSubstringPlayerName(table.concat(chunk))
            chunk, n = {}, 0
        end
    end
    if n > 0 then AddTextComponentSubstringPlayerName(table.concat(chunk)) end
    EndTextCommandPrint(ms or 5000, true)
end

-- модель: hash, если есть на сервере и загрузилась, иначе nil (без ошибок)
function Law.loadModel(name)
    local m = type(name) == 'number' and name or joaat(name)
    if not IsModelInCdimage(m) then return nil end
    local ok = pcall(lib.requestModel, m, 10000)
    return ok and HasModelLoaded(m) and m or nil
end

function Law.firstModel(list)
    for _, name in ipairs(list or {}) do
        if IsModelInCdimage(joaat(name)) then return name end
    end
end

function Law.anim(dict)
    return pcall(lib.requestAnimDict, dict, 5000)
end

-- управление чужой (сетевой) сущностью: задачи NPC работают только у владельца
function Law.control(ent, ms)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return false end
    if not NetworkGetEntityIsNetworked(ent) or NetworkHasControlOfEntity(ent) then return true end
    local untilT = GetGameTimer() + (ms or 1000)
    repeat
        NetworkRequestControlOfEntity(ent)
        Wait(50)
        if not DoesEntityExist(ent) then return false end
    until NetworkHasControlOfEntity(ent) or GetGameTimer() > untilT
    return NetworkHasControlOfEntity(ent)
end

function Law.hasPlayerInside(veh)
    for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 and IsPedAPlayer(ped) then return true end
    end
    return false
end

local function norm2(v)
    local l = math.sqrt(v.x * v.x + v.y * v.y)
    if l < 0.001 then return vector3(0.0, 1.0, 0.0), 0.0 end
    return vector3(v.x / l, v.y / l, 0.0), l
end
Law.norm2 = norm2

function Law.dirOf(heading)
    local r = math.rad(heading)
    return vector3(-math.sin(r), math.cos(r), 0.0)
end

-- край дороги у точки: возвращает edge (край асфальта), out (наружу от дороги), dir (направление полосы у этого края)
-- wantDir — примерное направление движения (вектор), чтобы взять край справа по ходу
function Law.roadEdge(p, wantDir)
    local found, node, heading = GetClosestVehicleNodeWithHeading(p.x, p.y, p.z, 1, 3.0, 0)
    if not found then return nil end
    local dir = Law.dirOf(heading)
    if wantDir and (dir.x * wantDir.x + dir.y * wantDir.y) < 0 then
        heading = (heading + 180.0) % 360.0
        dir = Law.dirOf(heading)
    end
    local ok, edge = GetRoadBoundaryUsingHeading(node.x, node.y, node.z, heading)
    if not ok then return nil end
    local out, len = norm2(vector3(edge.x - node.x, edge.y - node.y, 0.0))
    if len < 0.5 then return nil end
    return vector3(edge.x, edge.y, edge.z), out, dir, heading, node
end

-- «карман»: точка на асфальте у правого края, ahead метров впереди машины по её ходу
function Law.pocketAhead(veh, ahead)
    local pos = GetEntityCoords(veh)
    local fwd = GetEntityForwardVector(veh)
    local p = pos + fwd * (ahead or 25.0)
    local edge, out, dir, heading = Law.roadEdge(p, fwd)
    if not edge then return p, GetEntityHeading(veh) end
    return edge - out * 2.3, heading
end

-- остановить машину у точки: едет к ней, тормозит, глушит мотор и включает аварийку. true — встала
function Law.pullOver(veh, driver, pocket, timeoutMs)
    if not Law.control(veh, 800) or not Law.control(driver, 800) then return false end
    SetEntityAsMissionEntity(veh, true, true)
    SetEntityAsMissionEntity(driver, true, true)
    SetBlockingOfNonTemporaryEvents(driver, true)
    SetPedKeepTask(driver, true)
    SetVehicleIndicatorLights(veh, 0, true) -- правый поворотник
    TaskVehicleDriveToCoord(driver, veh, pocket.x, pocket.y, pocket.z, 7.0, 0, GetEntityModel(veh), 786603, 3.0, true)
    local untilT = GetGameTimer() + (timeoutMs or 25000)
    local slowSince
    while GetGameTimer() < untilT do
        Wait(250)
        if not DoesEntityExist(veh) or not DoesEntityExist(driver) or IsPedDeadOrDying(driver, true) then return false end
        if GetPedInVehicleSeat(veh, -1) ~= driver then return false end
        local d = #(GetEntityCoords(veh) - pocket)
        local v = GetEntitySpeed(veh)
        if d < 5.0 then break end
        if v < 1.0 then
            slowSince = slowSince or GetGameTimer()
            if GetGameTimer() - slowSince > 4000 and d < 25.0 then break end -- уткнулся рядом — хватит
        else
            slowSince = nil
        end
    end
    if not DoesEntityExist(veh) then return false end
    TaskVehicleTempAction(driver, veh, 27, 4000) -- тормозить до остановки
    local t2 = GetGameTimer() + 4000
    while GetEntitySpeed(veh) > 0.4 and GetGameTimer() < t2 do Wait(100) end
    SetVehicleIndicatorLights(veh, 0, true)
    SetVehicleIndicatorLights(veh, 1, true) -- аварийка
    SetVehicleEngineOn(veh, false, true, true)
    return true
end

-- отпустить: заводит мотор и уезжает по своим делам, игра снова сама управляет машиной
function Law.releaseDriver(veh, driver)
    if veh and DoesEntityExist(veh) and Law.control(veh, 600) then
        SetVehicleIndicatorLights(veh, 0, false)
        SetVehicleIndicatorLights(veh, 1, false)
        SetVehicleEngineOn(veh, true, true, false)
        if driver and DoesEntityExist(driver) and not IsPedDeadOrDying(driver, true) and Law.control(driver, 600) then
            if GetPedInVehicleSeat(veh, -1) == driver then
                TaskVehicleDriveWander(driver, veh, 15.0, 786603)
            end
            SetBlockingOfNonTemporaryEvents(driver, false)
            SetPedKeepTask(driver, true)
            SetEntityAsNoLongerNeeded(driver)
        end
        SetEntityAsNoLongerNeeded(veh)
    elseif driver and DoesEntityExist(driver) and Law.control(driver, 400) then
        SetEntityAsNoLongerNeeded(driver)
    end
end

-- удалить свою (созданную скриптом) сущность аккуратно
function Law.delete(ent)
    if ent and ent ~= 0 and DoesEntityExist(ent) and Law.control(ent, 600) then
        SetEntityAsMissionEntity(ent, true, true)
        DeleteEntity(ent)
    end
end

-- точки отдела: ближайший к позиции
function Law.nearestStation(pos)
    local best, bestD, bestOrg
    for id, org in pairs(Config.Orgs) do
        local d = #(pos - org.station.xyz)
        if not bestD or d < bestD then best, bestD, bestOrg = org.station, d, id end
    end
    return best, bestD, bestOrg
end

-- группа отношений для наших NPC-силовиков: дружат с игроками
local _, LAW_GROUP = AddRelationshipGroup('KV_LAW')
Law.GROUP = LAW_GROUP
CreateThread(function()
    local player = joaat('PLAYER')
    SetRelationshipBetweenGroups(0, LAW_GROUP, player)
    SetRelationshipBetweenGroups(0, player, LAW_GROUP)
    SetRelationshipBetweenGroups(0, LAW_GROUP, LAW_GROUP)
    SetRelationshipBetweenGroups(1, LAW_GROUP, joaat('COP'))
    SetRelationshipBetweenGroups(1, joaat('COP'), LAW_GROUP)
end)

-- NPC-силовик: не пугается, не падает от толчка, дружит с игроками
function Law.setupOfficer(ped, weapon, armour)
    SetPedRelationshipGroupHash(ped, LAW_GROUP)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)  -- драться до конца, если напали
    SetPedCombatAttributes(ped, 5, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetPedConfigFlag(ped, 208, true)
    SetPedConfigFlag(ped, 281, true)       -- не пугается выстрелов вдалеке
    SetPedArmour(ped, armour or 50)
    SetPedAccuracy(ped, 55)
    if weapon then GiveWeaponToPed(ped, joaat(weapon), 250, false, false) end
    SetPedKeepTask(ped, true)
end
