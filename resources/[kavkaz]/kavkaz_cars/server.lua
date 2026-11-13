-- автопарк: проверка cars.lua, выдача машин (квест, админ, ивенты), лимит редких машин в салоне,
-- перенос уже купленных машин с заглушки GTA на настоящую модель (консоль: kavkaz_cars_migrate).

local Cars = assert(load(LoadResourceFile(GetCurrentResourceName(), 'cars.lua'), '@@kavkaz_cars/cars.lua', 't', {}))()
local DEFAULT_GARAGE = 'motelgarage' -- куда кладём выданную машину (как /agivecar в kavkaz_admin)

local bySpawn, byModel = {}, {}
do
    local stubs, problems = {}, {}
    for _, car in ipairs(Cars.List) do
        if bySpawn[car.spawn] then problems[#problems + 1] = 'повтор имени спавна ' .. car.spawn end
        if stubs[car.stub] then problems[#problems + 1] = ('заглушка %s у двух машин: %s и %s'):format(car.stub, stubs[car.stub], car.spawn) end
        if not car.placeholder and not car.model then problems[#problems + 1] = car.spawn .. ': placeholder = false, но model не указан' end
        bySpawn[car.spawn], stubs[car.stub] = car, car.spawn
        byModel[Cars.current(car)] = car
    end
    for _, p in ipairs(problems) do print('^1[kavkaz_cars] ' .. p .. '^7') end
end

local function label(car) return ('%s %s'):format(car.brand, car.name) end

-- машина по имени спавна, текущей модели или заглушке
local function find(name)
    if type(name) ~= 'string' then return nil end
    name = name:lower()
    if bySpawn[name] then return bySpawn[name] end
    if byModel[name] then return byModel[name] end
    return nil
end

local function countOnServer(car)
    return MySQL.scalar.await('SELECT COUNT(*) FROM player_vehicles WHERE vehicle IN (?, ?)', { Cars.current(car), car.spawn }) or 0
end

local function notify(src, text, kind)
    pcall(function() exports.qbx_core:Notify(src, text, kind or 'inform', 7000) end)
end

---------------------------------------------------------------------------
-- лимит редких машин (limit в cars.lua). салон спрашивает CanBuy перед списанием денег
-- (overrides/resources/[qbx]/qbx_vehicleshop/config/server.lua → removePlayerFunds)
---------------------------------------------------------------------------

local pending = {} -- source -> { model, at }: какую машину игрок только что попросил купить
local function remember(src, model)
    if type(model) == 'string' then pending[src] = { model = model, at = os.time() } end
end
RegisterNetEvent('qbx_vehicleshop:server:buyShowroomVehicle', function(model) remember(source, model) end)
RegisterNetEvent('qbx_vehicleshop:server:financeVehicle', function(_, _, model) remember(source, model) end)
AddEventHandler('playerDropped', function() pending[source] = nil end)

exports('CanBuy', function(src)
    local p = pending[src]
    if not p or os.time() - p.at > 10 then return true end
    local car = find(p.model)
    if not car or not car.limit then return true end
    local count = countOnServer(car)
    if count >= car.limit then
        notify(src, ('%s — редкая машина: на сервере уже %d из %d. ждите, пока кто-то продаст'):format(label(car), count, car.limit), 'error')
        return false
    end
    return true
end)

---------------------------------------------------------------------------
-- выдача машины в гараж: квест Румисы («Семёрка»), админ, ивенты, призы
---------------------------------------------------------------------------

-- target — server id игрока или citizenid. opts = { garage, reason, ignoreLimit }
local function giveCar(target, spawn, opts)
    opts = opts or {}
    local car = find(spawn)
    if not car then return nil, 'такой машины нет в kavkaz_cars/cars.lua' end
    local cid = target
    if type(target) == 'number' then
        local p = exports.qbx_core:GetPlayer(target)
        cid = p and p.PlayerData.citizenid
    end
    if type(cid) ~= 'string' then return nil, 'персонаж не загружен' end
    if car.limit and not opts.ignoreLimit and countOnServer(car) >= car.limit then
        return nil, ('лимит: на сервере уже %d %s'):format(car.limit, label(car))
    end
    local id, err = exports.qbx_vehicles:CreatePlayerVehicle({ model = Cars.current(car), citizenid = cid, garage = opts.garage or DEFAULT_GARAGE })
    if not id then return nil, err and err.message or 'не удалось создать машину' end
    -- номер ставит kavkaz_plates: транзит или сразу на учёт (kavkaz_plates/config.lua → Config.NewVehiclePlate)
    if GetResourceState('kavkaz_plates') == 'started' then
        local ok, e = pcall(function() exports.kavkaz_plates:AssignNew(id, opts.reason or 'gift') end)
        if not ok then print('^3[kavkaz_cars] номер не выдан: ' .. tostring(e) .. '^7') end
    end
    print(('[kavkaz_cars] %s -> %s (id %d, %s)'):format(label(car), cid, id, opts.reason or 'выдача'))
    return id
end

exports('GiveCar', giveCar)
exports('GetCar', function(name)
    local car = find(name)
    if not car then return nil end
    local copy = {}
    for k, v in pairs(car) do copy[k] = v end
    copy.current, copy.label = Cars.current(car), label(car)
    return copy
end)
-- поиск по неточному имени для админов: «camry» → все Камри, «killinan» → kv_cullinan (опечатка до 2 букв)
local function dist(a, b)
    local la, lb = #a, #b
    if math.abs(la - lb) > 2 then return 99 end
    local prev = {}
    for j = 0, lb do prev[j] = j end
    for i = 1, la do
        local cur = { [0] = i }
        for j = 1, lb do
            cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a:sub(i, i) == b:sub(j, j) and 0 or 1))
        end
        prev = cur
    end
    return prev[lb]
end
exports('Search', function(name)
    if type(name) ~= 'string' or name == '' then return {} end
    name = name:lower():gsub('^kv_', '')
    local exact = find('kv_' .. name)
    if exact then return { exact.spawn } end
    local hits, best, bestD = {}, nil, 3
    for _, car in ipairs(Cars.List) do
        local short = car.spawn:gsub('^kv_', '')
        if short:find(name, 1, true) or label(car):lower():find(name, 1, true) then
            hits[#hits + 1] = car.spawn
        else
            local d = dist(short, name)
            if d < bestD then best, bestD = car.spawn, d end
        end
    end
    if #hits == 0 and best then hits[1] = best end
    return hits
end)

exports('Label', function(name)
    local car = find(name)
    return car and label(car) or nil
end)

---------------------------------------------------------------------------
-- консоль сервера
---------------------------------------------------------------------------

-- kavkaz_cars — сводка: сколько на заглушках, сколько настоящих, вес стрима
RegisterCommand('kavkaz_cars', function(src)
    if src ~= 0 then return end
    local real, stub, mb = 0, 0, 0
    for _, car in ipairs(Cars.List) do
        if car.placeholder then stub = stub + 1 else real = real + 1; mb = mb + (car.mb or 0) end
        print(('  %-16s %-34s %-12s %s'):format(car.spawn, label(car), Cars.current(car), car.placeholder and 'заглушка' or ('настоящая, ' .. (car.mb or '?') .. ' МБ')))
    end
    print(('[kavkaz_cars] всего %d: настоящих %d, на заглушках %d. стрим машин: %.1f МБ из 5120'):format(#Cars.List, real, stub, mb))
end, true)

-- kavkaz_cars_migrate [apply] — машины, купленные на заглушке, переводим на настоящую модель.
-- без apply только показывает, сколько строк поменяется. ничего не удаляет.
RegisterCommand('kavkaz_cars_migrate', function(src, args)
    if src ~= 0 then return end
    local apply = args[1] == 'apply'
    local total = 0
    for _, car in ipairs(Cars.List) do
        if not car.placeholder and car.model and car.model ~= car.stub then
            local n = MySQL.scalar.await('SELECT COUNT(*) FROM player_vehicles WHERE vehicle = ?', { car.stub }) or 0
            if n > 0 then
                total = total + n
                print(('  %s: %d шт. %s -> %s'):format(label(car), n, car.stub, car.model))
                if apply then
                    local hash = joaat(car.model)
                    MySQL.update.await("UPDATE player_vehicles SET vehicle = ?, hash = ?, mods = JSON_SET(mods, '$.model', ?) WHERE vehicle = ?",
                        { car.model, hash, hash, car.stub })
                end
            end
        end
    end
    if total == 0 then return print('[kavkaz_cars] переносить нечего') end
    print(apply and ('[kavkaz_cars] перенесено машин: %d'):format(total)
        or ('[kavkaz_cars] к переносу: %d. выполнить: kavkaz_cars_migrate apply'):format(total))
end, true)

-- при старте: настоящие модели должны быть запущены (resources/[cars]/<spawn>, ensure в cars.cfg)
CreateThread(function()
    Wait(15000)
    local real, missing = 0, {}
    for _, car in ipairs(Cars.List) do
        if not car.placeholder and car.model then
            real = real + 1
            if GetResourceState(car.model) ~= 'started' then missing[#missing + 1] = car.model end
        end
    end
    print(('[kavkaz_cars] машин: %d, настоящих моделей: %d, на заглушках: %d'):format(#Cars.List, real, #Cars.List - real))
    if #missing > 0 then
        print('^1[kavkaz_cars] не запущены ресурсы моделей: ' .. table.concat(missing, ', ') .. ' (setup/install-cars.ps1, cars.cfg)^7')
    end
    MySQL.ready(function()
        local wait = 0
        for _, car in ipairs(Cars.List) do
            if not car.placeholder and car.model and car.model ~= car.stub then
                wait = wait + (MySQL.scalar.await('SELECT COUNT(*) FROM player_vehicles WHERE vehicle = ?', { car.stub }) or 0)
            end
        end
        if wait > 0 then print(('^3[kavkaz_cars] %d машин игроков ещё на заглушках — в консоли: kavkaz_cars_migrate^7'):format(wait)) end
    end)
end)

-- модели машин игрока для предзагрузки (client.lua): только личные машины
RegisterNetEvent('kavkaz_cars:server:prefetch', function()
    local src = source
    local player = GetResourceState('qbx_core') == 'started' and exports.qbx_core:GetPlayer(src)
    if not player then return end
    -- только 4 последние машины: у основателей в гараже весь автопарк (~450 МБ), остальные качаются при вызове из гаража
    local rows = MySQL.query.await('SELECT vehicle FROM player_vehicles WHERE citizenid = ? ORDER BY id DESC LIMIT 4', { player.PlayerData.citizenid }) or {}
    local models = {}
    for _, r in ipairs(rows) do models[#models + 1] = r.vehicle end
    TriggerClientEvent('kavkaz_cars:client:prefetch', src, models)
end)
