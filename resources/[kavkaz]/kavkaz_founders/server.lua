-- KAVKAZ RP — усадьбы основателей: гараж, все машины автопарка с СГУ «Хазард Про», деньги (один раз).

local function loadCars()
    local code = LoadResourceFile('kavkaz_cars', 'cars.lua')
    if not code then return {} end
    local env = {}
    local fn = load(code, '@kavkaz_cars/cars.lua', 't', env)
    if not fn then return {} end
    local ok, res = pcall(fn)
    local Cars = (ok and type(res) == 'table' and res.List and res) or env.Cars
    local list = {}
    for _, car in ipairs(Cars and Cars.List or {}) do
        if car.model and not car.placeholder then list[#list + 1] = car.model end
    end
    return list
end

-- место выезда: найденное клиентом основателя на ближайшей дороге (хранится на сервере), иначе запасное из конфига
local function garageSpawn()
    local saved = GetResourceKvpString('garage_spawn')
    if saved then
        local x, y, z, h = saved:match('([%-%d%.]+),([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)')
        if x then return vec4(tonumber(x), tonumber(y), tonumber(z), tonumber(h)) end
    end
    return Config.Garage.spawn
end

local function registerGarage()
    local g = Config.Garage
    exports.qbx_garages:RegisterGarage(g.name, {
        label = g.label,
        vehicleType = 'car',
        accessPoints = {
            { coords = g.access, spawn = garageSpawn(), blip = { name = g.label, sprite = 357, color = 5 } },
        },
    })
end

local function isFounder(src)
    local p = exports.qbx_core:GetPlayer(src)
    if not p then return false end
    for _, f in ipairs(Config.Founders) do
        if f.citizenid == p.PlayerData.citizenid then return true end
    end
    return false
end

lib.callback.register('kavkaz_founders:isFounder', function(src) return isFounder(src) end)
lib.callback.register('kavkaz_founders:garageSpawn', function(src)
    if not isFounder(src) then return nil end
    local s = garageSpawn()
    return { s.x, s.y, s.z }
end)

-- клиент основателя нашёл дорогу у дома — запомнить место выезда машин
RegisterNetEvent('kavkaz_founders:server:garageSpawn', function(x, y, z, h)
    local src = source
    if GetResourceKvpString('garage_spawn') or not isFounder(src) then return end
    local pos = vec3(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
    if #(pos - Config.Garage.access.xyz) > 120.0 then return end
    SetResourceKvp('garage_spawn', ('%.2f,%.2f,%.2f,%.1f'):format(pos.x, pos.y, pos.z, tonumber(h) or 0.0))
    registerGarage()
    TriggerClientEvent('kavkaz_founders:client:spawnReset', -1)
    print(('[kavkaz_founders] место выезда гаража: %.1f, %.1f, %.1f'):format(pos.x, pos.y, pos.z))
end)

-- выдать недостающие машины (можно запускать сколько угодно раз: что уже есть — не дублирует)
local function giveCars(cid)
    local have = {}
    for _, r in ipairs(MySQL.query.await('SELECT id, vehicle FROM player_vehicles WHERE citizenid = ?', { cid }) or {}) do
        have[r.vehicle] = have[r.vehicle] or r.id
    end
    local added = 0
    for _, model in ipairs(loadCars()) do
        local id = have[model]
        if not id then
            id = exports.qbx_vehicles:CreatePlayerVehicle({ model = model, citizenid = cid, garage = Config.Garage.name })
            if id then
                added = added + 1
                pcall(function() exports.kavkaz_plates:AssignNew(id, 'founder') end)
            end
        end
        if id and Config.Sgu and GetResourceState('kavkaz_sgu') == 'started' then
            exports.kavkaz_sgu:SetById(id, Config.Sgu, cid)
        end
        if id and GetResourceState('kavkaz_air') == 'started' then
            exports.kavkaz_air:SetById(id, true, cid) -- основателям пневма на всех машинах
        end
    end
    return added
end

local function giveMoneyOnce(cid)
    local key = 'money_v1_' .. cid
    if GetResourceKvpInt(key) == 1 then return false end
    local p = exports.qbx_core:GetPlayerByCitizenId(cid)
    if p then
        p.Functions.AddMoney('bank', Config.Money.bank, 'founder')
        p.Functions.AddMoney('cash', Config.Money.cash, 'founder')
    else
        MySQL.update.await([[UPDATE players SET money = JSON_SET(money,
            '$.bank', COALESCE(JSON_EXTRACT(money, '$.bank'), 0) + ?,
            '$.cash', COALESCE(JSON_EXTRACT(money, '$.cash'), 0) + ?) WHERE citizenid = ?]], { Config.Money.bank, Config.Money.cash, cid })
    end
    SetResourceKvpInt(key, 1)
    return true
end

local function setupAll()
    for _, f in ipairs(Config.Founders) do
        local added = giveCars(f.citizenid)
        local money = giveMoneyOnce(f.citizenid)
        print(('[kavkaz_founders] %s: машин добавлено %d, деньги %s'):format(f.citizenid, added, money and 'начислены' or 'уже были'))
    end
end

CreateThread(function()
    Wait(1000)
    registerGarage()
    Wait(9000) -- ждём kavkaz_plates, kavkaz_sgu и базу
    setupAll()
end)

-- новые клиенты получат гараж от qbx_garages (он хранит список), но после рестарта qbx_garages — регистрируем заново
AddEventHandler('onResourceStart', function(res)
    if res == 'qbx_garages' then SetTimeout(1000, registerGarage) end
end)

-- консоль: kavkaz_founders — выдать основателям машины, добавленные в автопарк позже
RegisterCommand('kavkaz_founders', function(src)
    if src ~= 0 then return end
    setupAll()
end, true)

-- KAVKAZ: проверка при старте — сколько машин гараж усадьбы отдаст основателю и какие отсеются (11.12: «машины исчезли из списка»)
CreateThread(function()
    Wait(15000)
    if GetResourceState('qbx_vehicles') ~= 'started' then return end
    -- после перезапуска сервера машин в мире нет, а в базе они могли остаться «выгнанными» (state 0) и пропасть из списка.
    -- возвращаем их в гараж усадьбы (только машины основателей и только при старте)
    local cids = {}
    for _, f in ipairs(Config.Founders) do cids[#cids + 1] = f.citizenid end
    local back = MySQL.update.await(('UPDATE player_vehicles SET state = 1 WHERE state = 0 AND garage = ? AND citizenid IN (%s)')
        :format(string.rep('?', #cids, ',')), { Config.Garage.name, table.unpack(cids) })
    if back and back > 0 then print(('[kavkaz_founders] вернул в гараж усадьбы машин: %d'):format(back)) end
    local byName = exports.qbx_core:GetVehiclesByName() or {}
    for _, f in ipairs(Config.Founders) do
        local all = exports.qbx_vehicles:GetPlayerVehicles({ citizenid = f.citizenid }) or {}
        local shown, hidden = 0, {}
        for _, v in ipairs(all) do
            local why
            if v.garage ~= Config.Garage.name then why = 'гараж ' .. tostring(v.garage)
            elseif v.state ~= 1 then why = 'state ' .. tostring(v.state)
            elseif not byName[v.modelName] then why = 'нет в списке qbx_core'
            end
            if why then hidden[#hidden + 1] = ('%s (%s)'):format(v.modelName, why) else shown = shown + 1 end
        end
        print(('[kavkaz_founders] гараж %s: всего %d, в списке %d, скрыто: %s'):format(f.citizenid, #all, shown,
            #hidden > 0 and table.concat(hidden, ', ') or 'нет'))
    end
end)
