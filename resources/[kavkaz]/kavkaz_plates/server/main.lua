-- номера: регистрация в МРЭО, выдача ДПС, перевес, «карман», продажа игроку, пробивка по базе, /setplate.
-- номер принадлежит персонажу (citizenid): висит на одной из его машин (vehicle_id) или лежит «в кармане» (NULL).
-- машина с номером, которого нет в kavkaz_plates, считается «транзитом» (не зарегистрирована).

local choices = {} -- source -> { list, region, untilTs }

MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `kavkaz_plates` (
        `plate` VARCHAR(8) NOT NULL, `citizenid` VARCHAR(50) NOT NULL, `vehicle_id` INT NULL DEFAULT NULL,
        `tier` VARCHAR(16) NULL DEFAULT NULL, `source` VARCHAR(16) NOT NULL DEFAULT 'window',
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`plate`), KEY `idx_owner` (`citizenid`), KEY `idx_vehicle` (`vehicle_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `kavkaz_plate_history` (
        `id` INT NOT NULL AUTO_INCREMENT, `plate` VARCHAR(8) NOT NULL,
        `from_cid` VARCHAR(50) NULL DEFAULT NULL, `to_cid` VARCHAR(50) NULL DEFAULT NULL,
        `action` VARCHAR(16) NOT NULL, `price` INT NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `idx_plate` (`plate`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    -- 2026-11-10: вид номера и рамка (sql/2026-11-10_kavkaz_plates_styles.sql)
    MySQL.query.await([[ALTER TABLE `kavkaz_plates`
        ADD COLUMN IF NOT EXISTS `style` VARCHAR(16) NOT NULL DEFAULT 'ru',
        ADD COLUMN IF NOT EXISTS `frame` VARCHAR(24) NULL DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS `frame_text` VARCHAR(48) NULL DEFAULT NULL]])
end)

local STYLE, FRAME = {}, {}
for _, st in ipairs(Config.Styles) do STYLE[st.id] = st end
for _, fr in ipairs(Config.Frames) do FRAME[fr.id] = fr end

---------------------------------------------------------------------------
-- помощники
---------------------------------------------------------------------------

local function notify(src, text, kind)
    exports.qbx_core:Notify(src, text, kind or 'inform', 6000)
end

local function getPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

local function cidOf(src)
    local p = getPlayer(src)
    return p and p.PlayerData.citizenid
end

local function money(v)
    local s = tostring(math.floor(v)):reverse():gsub('(%d%d%d)', '%1 '):reverse()
    return (s:gsub('^ ', '')) .. ' ₽'
end

local function trim(plate)
    return ((plate or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

-- хэши моделей бывают со знаком и без — сравниваем по модулю 2^32
local function sameHash(a, b)
    a, b = tonumber(a), tonumber(b)
    return a ~= nil and b ~= nil and a % 4294967296 == b % 4294967296
end

local function nearOffice(src)
    local pos = GetEntityCoords(GetPlayerPed(src))
    return #(pos - Config.Office.ped.coords.xyz) <= Config.Office.radius + 2.0
end

-- списать деньги: сначала наличные, потом карта
local function pay(src, amount, reason)
    if amount <= 0 then return true end
    for _, account in ipairs({ 'cash', 'bank' }) do
        if (exports.qbx_core:GetMoney(src, account) or 0) >= amount then
            return exports.qbx_core:RemoveMoney(src, account, amount, reason)
        end
    end
    return false
end

local function history(plate, fromCid, toCid, action, price)
    MySQL.insert('INSERT INTO kavkaz_plate_history (plate, from_cid, to_cid, action, price) VALUES (?, ?, ?, ?, ?)',
        { plate, fromCid, toCid, action, price or 0 })
end

local function plateTaken(plate)
    return MySQL.scalar.await('SELECT 1 FROM kavkaz_plates WHERE plate = ? UNION SELECT 1 FROM player_vehicles WHERE plate = ? LIMIT 1',
        { plate, plate }) ~= nil
end

local function freeRandom(region, style)
    for _ = 1, 50 do
        local plate = Plates.random(style or 'ru', region)
        if plate and not plateTaken(plate) then return plate end
    end
    return nil
end

-- подходит ли работа игрока под список { работа = мин. ранг }
local function hasJob(src, jobs)
    if not jobs then return true end
    local p = exports.qbx_core:GetPlayer(src)
    local job = p and p.PlayerData.job
    local min = job and jobs[job.name]
    return min ~= nil and (job.grade.level or 0) >= min
end

-- транзитный номер для машины без номера: TR + 6 цифр (не наш формат — сразу видно, что не на учёте)
local function freeTransit()
    for _ = 1, 50 do
        local plate = ('TR%06d'):format(math.random(0, 999999))
        if not plateTaken(plate) then return plate end
    end
    return nil
end

local function validRegion(code)
    for _, r in ipairs(Config.Regions) do
        if r.code == code then return code end
    end
    return Config.DefaultRegion
end

local function findEntityByPlate(plate)
    for _, veh in ipairs(GetAllVehicles()) do
        if trim(GetVehicleNumberPlateText(veh)) == plate then return veh end
    end
    return nil
end

local function vehicleRow(cid, vehicleId)
    return MySQL.single.await('SELECT id, vehicle, plate, state FROM player_vehicles WHERE id = ? AND citizenid = ?', { vehicleId, cid })
end

-- машину можно перерегистрировать, если она в гараже или стоит рядом с точкой (МРЭО / пост ДПС)
local function vehicleReachable(row, near)
    local entity = findEntityByPlate(row.plate)
    if entity then
        return #(GetEntityCoords(entity) - near) <= Config.Office.vehicleRadius, entity
    end
    return row.state == 1, nil
end

-- сменить номер у машины в базе и в мире (ox_inventory переносит багажник и бардачок на новый номер).
-- style задаёт фон номера в GTA (Config.Styles[].index)
local function setVehiclePlate(row, newPlate, style)
    local oldPlate = row.plate
    local index = (STYLE[style or 'ru'] or STYLE.ru).index or 0
    MySQL.update.await("UPDATE player_vehicles SET plate = ?, mods = JSON_SET(mods, '$.plate', ?, '$.plateIndex', ?) WHERE id = ?",
        { newPlate, newPlate, index, row.id })
    local entity = findEntityByPlate(oldPlate)
    if entity then
        SetVehicleNumberPlateText(entity, newPlate)
        SetVehicleNumberPlateTextIndex(entity, index)
    end
    pcall(function() exports.ox_inventory:UpdateVehicle(oldPlate, newPlate) end)
    row.plate = newPlate
end

-- повесить наш номер на машину. старый зарегистрированный номер машины уходит в карман.
local function attach(cid, plate, row)
    if row.plate == plate then return end
    MySQL.update.await('UPDATE kavkaz_plates SET vehicle_id = NULL WHERE vehicle_id = ?', { row.id })

    -- если этот номер висел на другой машине — ей транзит
    local current = MySQL.scalar.await('SELECT vehicle_id FROM kavkaz_plates WHERE plate = ?', { plate })
    if current and current ~= row.id then
        local other = vehicleRow(cid, current)
        if other then setVehiclePlate(other, freeTransit()) end
    end

    MySQL.update.await('UPDATE kavkaz_plates SET vehicle_id = ? WHERE plate = ?', { row.id, plate })
    local style = MySQL.scalar.await('SELECT style FROM kavkaz_plates WHERE plate = ?', { plate })
    setVehiclePlate(row, plate, style)
end

local function create(cid, plate, sourceKind, style)
    style = style or 'ru'
    MySQL.insert.await('INSERT INTO kavkaz_plates (plate, citizenid, tier, source, style) VALUES (?, ?, ?, ?, ?)',
        { plate, cid, style == 'ru' and Plates.tier(plate) or nil, sourceKind, style })
    history(plate, nil, cid, sourceKind, 0)
end

local function modelLabel(model)
    local list = exports.qbx_core:GetVehiclesByName()
    local v = list and list[model]
    if v then return (('%s %s'):format(v.brand or '', v.name or model):gsub('^ ', '')) end
    return model
end

---------------------------------------------------------------------------
-- данные для окна МРЭО
---------------------------------------------------------------------------

local function buildData(src)
    local cid = cidOf(src)
    if not cid then return nil end
    local vehicles = MySQL.query.await('SELECT id, vehicle, plate, state FROM player_vehicles WHERE citizenid = ? ORDER BY id', { cid }) or {}
    local plates = MySQL.query.await('SELECT plate, vehicle_id, tier, style, frame, frame_text FROM kavkaz_plates WHERE citizenid = ? ORDER BY created_at', { cid }) or {}

    local registered = {}
    for _, p in ipairs(plates) do
        if p.vehicle_id then registered[p.vehicle_id] = p end
        p.pretty = Plates.pretty(p.plate, p.style)
        p.tierLabel = p.tier and Config.Tiers[p.tier] and Config.Tiers[p.tier].label
        p.frameText = p.frame_text or (p.frame and FRAME[p.frame] and FRAME[p.frame].text) or nil
    end
    local list = {}
    for _, v in ipairs(vehicles) do
        local reg = registered[v.id]
        reg = reg and reg.plate == v.plate and reg or nil
        list[#list + 1] = {
            id = v.id, model = v.vehicle, label = modelLabel(v.vehicle), plate = v.plate,
            pretty = Plates.pretty(v.plate, reg and reg.style), registered = reg ~= nil,
            style = reg and reg.style or nil, frameText = reg and reg.frameText or nil,
            state = v.state, -- 0 выгнана, 1 в гараже, 2 штрафстоянка
        }
    end

    -- какие виды номеров и рамки доступны этому игроку
    local styles, frames = {}, {}
    for _, st in ipairs(Config.Styles) do
        if st.sale ~= 'job' or hasJob(src, st.jobs) then
            styles[#styles + 1] = { id = st.id, label = st.label, sale = st.sale,
                price = st.sale == 'foreign' and Config.Prices.foreign or Config.Prices.window }
        end
    end
    for _, fr in ipairs(Config.Frames) do
        if hasJob(src, fr.jobs) then frames[#frames + 1] = { id = fr.id, label = fr.label, text = fr.text, price = fr.price } end
    end
    return { vehicles = list, plates = plates, prices = Config.Prices, regions = Config.Regions, region = Config.DefaultRegion,
        styles = styles, frames = frames }
end

lib.callback.register('kavkaz_plates:getData', function(src)
    if not nearOffice(src) then return nil end
    return buildData(src)
end)

-- общая обвязка для действий в окне: проверка дистанции, ответ с обновлёнными данными
local function officeAction(name, fn)
    lib.callback.register('kavkaz_plates:' .. name, function(src, ...)
        if not nearOffice(src) then return { error = 'подойди к окну МРЭО' } end
        local cid = cidOf(src)
        if not cid then return { error = 'персонаж не загружен' } end
        local ok, err, msg = pcall(fn, src, cid, ...)
        if not ok then
            lib.print.error(err)
            return { error = 'ошибка сервера, попробуй ещё раз' }
        end
        if err then return { error = err } end
        return { ok = msg or 'готово', data = buildData(src) }
    end)
end

local function reachableOrError(cid, vehicleId)
    local row = vehicleId and vehicleRow(cid, tonumber(vehicleId))
    if not row then return nil, 'машина не найдена' end
    if row.state == 2 then return nil, 'машина на штрафстоянке' end
    if not vehicleReachable(row, Config.Office.ped.coords.xyz) then
        return nil, 'поставь машину в гараж или пригони к МРЭО'
    end
    return row
end

-- случайный номер в окне (7 000 ₽); vehicleId = nil -> в карман
officeAction('buyRandom', function(src, cid, vehicleId, region, style)
    style = style or 'ru'
    local st = STYLE[style]
    if not st then return 'неизвестный вид номера' end
    if st.sale == 'job' and not hasJob(src, st.jobs) then return 'такие номера выдают только сотрудникам' end
    local price = st.sale == 'foreign' and Config.Prices.foreign or Config.Prices.window
    local row, err
    if vehicleId then
        row, err = reachableOrError(cid, vehicleId)
        if not row then return err end
    end
    local plate = freeRandom(validRegion(region), style)
    if not plate then return 'свободных номеров нет, попробуй другой регион' end
    if not pay(src, price, 'МРЭО: номер') then return 'не хватает денег: нужно ' .. money(price) end
    create(cid, plate, 'window', style)
    if row then attach(cid, plate, row) end
    return nil, nil, ('номер %s оформлен'):format(Plates.pretty(plate, style))
end)

-- рамка номера: из списка Config.Frames (служебные — только своим)
officeAction('setFrame', function(src, cid, plate, frameId)
    local fr = FRAME[frameId or '']
    if not fr then return 'такой рамки нет' end
    if not hasJob(src, fr.jobs) then return 'эта рамка только для сотрудников' end
    if not MySQL.scalar.await('SELECT 1 FROM kavkaz_plates WHERE plate = ? AND citizenid = ?', { plate, cid }) then return 'это не твой номер' end
    if not pay(src, fr.price or 0, 'МРЭО: рамка номера') then return 'не хватает денег: нужно ' .. money(fr.price) end
    MySQL.update.await('UPDATE kavkaz_plates SET frame = ?, frame_text = NULL WHERE plate = ?', { fr.id ~= 'none' and fr.id or nil, plate })
    return nil, nil, fr.id == 'none' and 'рамка снята' or ('рамка «%s» установлена'):format(fr.text)
end)

-- 5 вариантов на выбор (оплата при выборе)
lib.callback.register('kavkaz_plates:getChoices', function(src, region)
    if not nearOffice(src) then return nil end
    region = validRegion(region)
    local list, seen = {}, {}
    for _ = 1, 30 do
        local plate = freeRandom(region)
        if plate and not seen[plate] then
            seen[plate] = true
            list[#list + 1] = { plate = plate, pretty = Plates.pretty(plate) }
        end
        if #list == 5 then break end
    end
    choices[src] = { list = list, untilTs = os.time() + Config.ChoiceMinutes * 60 }
    return list
end)

officeAction('pickChoice', function(src, cid, index, vehicleId)
    local c = choices[src]
    if not c or os.time() > c.untilTs then return 'варианты устарели, запроси новые' end
    local pick = c.list[tonumber(index) or 0]
    if not pick then return 'вариант не найден' end
    local row, err
    if vehicleId then
        row, err = reachableOrError(cid, vehicleId)
        if not row then return err end
    end
    if plateTaken(pick.plate) then return 'этот номер только что забрали, запроси новые' end
    if not pay(src, Config.Prices.choose, 'МРЭО: номер на выбор') then return 'не хватает денег: нужно ' .. money(Config.Prices.choose) end
    choices[src] = nil
    create(cid, pick.plate, 'choose')
    if row then attach(cid, pick.plate, row) end
    return nil, nil, ('номер %s оформлен'):format(pick.pretty)
end)

-- перевесить свой номер (из кармана или с другой машины) — 2 000 ₽
officeAction('attach', function(src, cid, plate, vehicleId)
    local owned = MySQL.single.await('SELECT plate, vehicle_id FROM kavkaz_plates WHERE plate = ? AND citizenid = ?', { plate, cid })
    if not owned then return 'это не твой номер' end
    local row, err = reachableOrError(cid, vehicleId)
    if not row then return err end
    if owned.vehicle_id == row.id then return 'номер уже на этой машине' end
    if owned.vehicle_id then
        local other = vehicleRow(cid, owned.vehicle_id)
        if other and not vehicleReachable(other, Config.Office.ped.coords.xyz) then
            return 'машина, с которой снимаем номер, должна быть в гараже или у МРЭО'
        end
    end
    if not pay(src, Config.Prices.swap, 'МРЭО: перевес номера') then return 'не хватает денег: нужно ' .. money(Config.Prices.swap) end
    attach(cid, plate, row)
    history(plate, cid, cid, 'attach', Config.Prices.swap)
    return nil, nil, ('номер %s на машине %s'):format(Plates.pretty(plate), modelLabel(row.vehicle))
end)

-- снять номер в карман (бесплатно); машина получает транзит
officeAction('detach', function(src, cid, vehicleId)
    local row, err = reachableOrError(cid, vehicleId)
    if not row then return err end
    local plate = MySQL.scalar.await('SELECT plate FROM kavkaz_plates WHERE vehicle_id = ? AND citizenid = ?', { row.id, cid })
    if not plate then return 'на машине нет зарегистрированного номера' end
    MySQL.update.await('UPDATE kavkaz_plates SET vehicle_id = NULL WHERE plate = ?', { plate })
    setVehiclePlate(row, freeTransit())
    history(plate, cid, cid, 'detach', 0)
    return nil, nil, ('номер %s снят и лежит у тебя'):format(Plates.pretty(plate))
end)

-- продать номер из кармана игроку, который стоит рядом у МРЭО. покупатель платит цену, продавец получает минус 5%.
local selling = {}
officeAction('sell', function(src, cid, plate, targetId, price)
    targetId, price = tonumber(targetId), math.floor(tonumber(price) or -1)
    if selling[src] then return 'предыдущая сделка ещё не закрыта' end
    if price < 0 or price > 100000000 then return 'неверная цена' end
    local owned = MySQL.single.await('SELECT plate, vehicle_id FROM kavkaz_plates WHERE plate = ? AND citizenid = ?', { plate, cid })
    if not owned then return 'это не твой номер' end
    if owned.vehicle_id then return 'сначала сними номер с машины' end
    if not targetId or targetId == src or not GetPlayerName(targetId) or not nearOffice(targetId) then
        return 'покупатель должен стоять рядом у окна МРЭО'
    end
    local buyerCid = cidOf(targetId)
    if not buyerCid then return 'покупатель не загружен' end

    selling[src] = true
    notify(src, 'ждём ответа покупателя…', 'inform')
    local accepted = lib.callback.await('kavkaz_plates:confirmBuy', targetId, {
        pretty = Plates.pretty(plate), price = price, seller = GetPlayerName(src),
    })
    selling[src] = nil
    if not accepted then return 'покупатель отказался' end

    -- после ожидания всё перепроверяем
    owned = MySQL.single.await('SELECT vehicle_id FROM kavkaz_plates WHERE plate = ? AND citizenid = ?', { plate, cid })
    if not owned or owned.vehicle_id then return 'номер уже недоступен' end
    if not nearOffice(src) or not nearOffice(targetId) then return 'оба должны стоять у окна МРЭО' end
    if not pay(targetId, price, 'МРЭО: покупка номера ' .. plate) then
        notify(targetId, 'не хватает денег', 'error')
        return 'у покупателя не хватает денег'
    end
    local payout = math.floor(price * (1 - Config.Prices.commission))
    if payout > 0 then exports.qbx_core:AddMoney(src, 'bank', payout, 'МРЭО: продажа номера ' .. plate) end
    MySQL.update.await('UPDATE kavkaz_plates SET citizenid = ? WHERE plate = ?', { buyerCid, plate })
    history(plate, cid, buyerCid, 'sell', price)
    notify(targetId, ('номер %s твой. повесить на машину — в окне МРЭО'):format(Plates.pretty(plate)), 'success')
    return nil, nil, ('продано, на карту %s'):format(money(payout))
end)

AddEventHandler('playerDropped', function()
    choices[source] = nil
    selling[source] = nil
end)

---------------------------------------------------------------------------
-- ДПС: выдача номера на посту (/issueplate) и пробивка по базе
---------------------------------------------------------------------------

local function isPolice(src)
    local p = getPlayer(src)
    if not p then return false end
    local job = p.PlayerData.job
    local minGrade = Config.PoliceJobs[job.name]
    return minGrade ~= nil and job.onduty and (job.grade.level or 0) >= minGrade
end

lib.addCommand('issueplate', {
    help = 'ДПС: выдать номер водителю рядом (он платит, тебе процент)',
    params = { { name = 'target', type = 'playerId', help = 'ID водителя' } },
}, function(src, args)
    if not isPolice(src) then return notify(src, 'только для сотрудников на смене', 'error') end
    local target = args.target
    if target == src then return notify(src, 'себе номер выдают в МРЭО', 'error') end
    local myPos = GetEntityCoords(GetPlayerPed(src))
    local ped = GetPlayerPed(target)
    if #(GetEntityCoords(ped) - myPos) > Config.DpsDistance then return notify(src, 'водитель слишком далеко', 'error') end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return notify(src, 'игрок должен сидеть за рулём своей машины', 'error') end

    local cid = cidOf(target)
    local row = MySQL.single.await('SELECT id, vehicle, plate, state FROM player_vehicles WHERE plate = ? AND citizenid = ?',
        { trim(GetVehicleNumberPlateText(veh)), cid })
    if not row then return notify(src, 'это не личная машина водителя', 'error') end
    if MySQL.scalar.await('SELECT 1 FROM kavkaz_plates WHERE vehicle_id = ?', { row.id }) then
        return notify(src, 'машина уже на учёте', 'error')
    end

    notify(src, 'ждём согласия водителя…', 'inform')
    local accepted = lib.callback.await('kavkaz_plates:confirmIssue', target, { officer = GetPlayerName(src), price = Config.Prices.dps })
    if not accepted then return notify(src, 'водитель отказался', 'error') end

    local plate = freeRandom(Config.DefaultRegion)
    if not plate then return notify(src, 'нет свободных номеров', 'error') end
    if not pay(target, Config.Prices.dps, 'ДПС: регистрация номера') then
        notify(target, 'не хватает денег', 'error')
        return notify(src, 'у водителя не хватает денег', 'error')
    end
    create(cid, plate, 'dps')
    attach(cid, plate, row)
    exports.qbx_core:AddMoney(src, 'bank', Config.Prices.dpsShare, 'ДПС: процент за номер')
    notify(target, ('машина на учёте: %s'):format(Plates.pretty(plate)), 'success')
    notify(src, ('номер %s выдан, тебе %s'):format(Plates.pretty(plate), money(Config.Prices.dpsShare)), 'success')
end)

-- пробить номер: владелец, модель, учёт. липовые и чужие номера видно сразу.
lib.callback.register('kavkaz_plates:check', function(src, netId)
    if not isPolice(src) then return nil end
    local entity = NetworkGetEntityFromNetworkId(netId or 0)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    if #(GetEntityCoords(entity) - GetEntityCoords(GetPlayerPed(src))) > 30.0 then return nil end
    local plate = trim(GetVehicleNumberPlateText(entity))
    local res = { plate = plate, pretty = Plates.pretty(plate) }

    local reg = MySQL.single.await([[SELECT k.plate, k.citizenid, k.vehicle_id, k.style, k.frame, k.frame_text, v.vehicle, v.hash, p.charinfo
        FROM kavkaz_plates k LEFT JOIN player_vehicles v ON v.id = k.vehicle_id LEFT JOIN players p ON p.citizenid = k.citizenid
        WHERE k.plate = ?]], { plate })
    if reg then
        res.style = reg.style
        res.pretty = Plates.pretty(plate, reg.style)
        res.frameText = reg.frame_text or (reg.frame and FRAME[reg.frame] and FRAME[reg.frame].text) or nil
        local ci = reg.charinfo and json.decode(reg.charinfo) or {}
        res.owner = ci.firstname and ('%s %s'):format(ci.firstname, ci.lastname) or reg.citizenid
        if not reg.vehicle_id then
            res.status = 'stolen_plate' -- номер числится «в кармане», а висит на машине — подделка или снятый номер
        elseif reg.hash and not sameHash(reg.hash, GetEntityModel(entity)) then
            res.status = 'other_car'
            res.registeredModel = modelLabel(reg.vehicle)
        else
            res.status = 'ok'
            res.model = modelLabel(reg.vehicle)
        end
    else
        local veh = MySQL.single.await('SELECT v.vehicle, p.charinfo FROM player_vehicles v LEFT JOIN players p ON p.citizenid = v.citizenid WHERE v.plate = ?', { plate })
        if veh then
            local ci = veh.charinfo and json.decode(veh.charinfo) or {}
            res.status = 'transit'
            res.owner = ci.firstname and ('%s %s'):format(ci.firstname, ci.lastname) or '?'
            res.model = modelLabel(veh.vehicle)
        else
            res.status = 'unknown'
        end
    end
    return res
end)

---------------------------------------------------------------------------
-- админ: /setplate ID вид номер — красивые номера, серия «КРА», призы, номера других стран
-- /setframe номер текст — своя надпись на рамке (например «ФСО РОССИИ» для кортежа ивента)
---------------------------------------------------------------------------

local function adminOk(src)
    if src == 0 then return true end
    local ok, level = pcall(function() return exports.kavkaz_admin:GetDutyLevel(src) end)
    if ok and (level or 0) >= Config.AdminLevel then return true end
    notify(src, 'нужен админ на смене, уровень ' .. Config.AdminLevel, 'error')
    return false
end

local styleIds = {}
for _, st in ipairs(Config.Styles) do styleIds[#styleIds + 1] = st.id end

lib.addCommand('setplate', {
    help = 'Выдать номер игроку в карман: /setplate ID ru К 013 РА 95',
    params = {
        { name = 'target', type = 'playerId', help = 'ID игрока' },
        { name = 'style', type = 'string', help = table.concat(styleIds, ', ') },
        { name = 'plate', type = 'longString', help = 'номер, например К 013 РА 95' },
    },
}, function(src, args)
    if not adminOk(src) then return end
    local style = args.style:lower()
    if not STYLE[style] then return notify(src, 'вид номера: ' .. table.concat(styleIds, ', '), 'error') end
    local plate = Plates.normalize(args.plate, style)
    if not plate then return notify(src, 'неверный номер для вида ' .. style .. ' (буквы только АВЕКМНОРСТУХ)', 'error') end
    if plateTaken(plate) then return notify(src, 'номер уже занят', 'error') end
    local cid = cidOf(args.target)
    if not cid then return notify(src, 'персонаж не загружен', 'error') end
    create(cid, plate, 'admin', style)
    local pretty = Plates.pretty(plate, style)
    pcall(function() exports.kavkaz_admin:Log(src, 'setplate', args.target, ('%s (%s)'):format(pretty, style)) end)
    notify(args.target, ('тебе выдан номер %s. повесить — в МРЭО'):format(pretty), 'success')
    if src ~= 0 then notify(src, 'номер выдан', 'success') end
end)

lib.addCommand('setframe', {
    help = 'Своя надпись на рамке номера: /setframe К013РА95 ФСО РОССИИ (пусто — снять)',
    params = {
        { name = 'plate', type = 'string', help = 'номер без пробелов' },
        { name = 'text', type = 'longString', help = 'надпись (до 40 символов)', optional = true },
    },
}, function(src, args)
    if not adminOk(src) then return end
    local plate
    for _, st in ipairs(Config.Styles) do
        plate = Plates.normalize(args.plate, st.id)
        if plate then break end
    end
    if not plate or not MySQL.scalar.await('SELECT 1 FROM kavkaz_plates WHERE plate = ?', { plate }) then
        return notify(src, 'номер не найден в базе МРЭО', 'error')
    end
    local text = args.text and args.text:gsub('[\r\n]', ' '):sub(1, 40) or nil
    MySQL.update.await('UPDATE kavkaz_plates SET frame = ?, frame_text = ? WHERE plate = ?', { text and 'custom' or nil, text, plate })
    pcall(function() exports.kavkaz_admin:Log(src, 'setframe', nil, ('%s: %s'):format(plate, text or 'снята')) end)
    notify(src, text and ('рамка «%s» на %s'):format(text, Plates.pretty(plate)) or 'рамка снята', 'success')
end)

---------------------------------------------------------------------------
-- экспорты для других ресурсов (планшет ДПС, аукцион, телефон)
---------------------------------------------------------------------------

exports('Pretty', Plates.pretty)
exports('Normalize', Plates.normalize)
exports('Tier', Plates.tier)
exports('GetOwner', function(plate)
    return MySQL.scalar.await('SELECT citizenid FROM kavkaz_plates WHERE plate = ?', { plate })
end)
exports('Give', function(cid, plate, sourceKind, style)
    plate = Plates.normalize(plate, style or 'ru')
    if not plate or plateTaken(plate) then return false end
    create(cid, plate, sourceKind or 'event', style or 'ru')
    return true
end)
