-- KAVKAZ: автосалон «Нагорье Моторс» продаёт только наш автопарк из resources/[kavkaz]/kavkaz_cars/cars.lua
-- (машины с sale = 'shop'). квестовые, рабочие и служебные машины здесь не продаются.
-- лодки и авиация — как в оригинале qbx_vehicleshop. остальное в файле не менялось.
local function kavkazCars()
    local code = LoadResourceFile('kavkaz_cars', 'cars.lua')
    local chunk = code and load(code, '@@kavkaz_cars/cars.lua', 't', {})
    local ok, cars = false, nil
    if chunk then ok, cars = pcall(chunk) end
    if ok and type(cars) == 'table' and type(cars.List) == 'table' then return cars end
    print('^1[qbx_vehicleshop] KAVKAZ: kavkaz_cars/cars.lua не прочитан — в салоне нет машин^7')
    return { List = {}, Categories = {}, current = function(car) return car.stub end }
end
local Cars = kavkazCars()

local models, pdmCategories, byId = {}, {}, {}
for _, car in ipairs(Cars.List) do
    byId[car.spawn] = car
    if car.sale == 'shop' then
        models[Cars.current(car)] = 'pdm'
        pdmCategories[car.category] = Cars.Categories[car.category] or car.category
    end
end

-- витрина: машины, у которых уже есть картинки в лаунчере, и пара народных
local showroom = {
    { vec4(-45.65, -1093.66, 25.44, 69.5), 'kv_camry80' },
    { vec4(-48.27, -1101.86, 25.44, 294.5), 'kv_lc300' },
    { vec4(-39.6, -1096.01, 25.44, 66.5), 'kv_g63' },
    { vec4(-51.21, -1096.77, 25.44, 254.5), 'kv_m5f90' },
    { vec4(-40.18, -1104.13, 25.44, 338.5), 'kv_priora' },
    { vec4(-43.31, -1099.02, 25.44, 52.5), 'kv_vaz2114' },
    { vec4(-50.66, -1093.05, 25.44, 222.5), 'kv_octavia' },
    { vec4(-44.28, -1102.47, 25.44, 298.5), 'kv_w223' },
}
local showroomVehicles = {}
for _, s in ipairs(showroom) do
    local car = byId[s[2]]
    if car and car.sale == 'shop' then
        showroomVehicles[#showroomVehicles + 1] = { coords = s[1], vehicle = Cars.current(car) }
    end
end

-- лодки и авиация (как в оригинале)
for _, m in ipairs({ 'squalo', 'marquis', 'seashark', 'seashark2', 'seashark3', 'jetmax', 'tropic', 'tropic2', 'dinghy', 'dinghy2',
    'dinghy3', 'dinghy4', 'suntrap', 'speeder', 'speeder2', 'longfin', 'toro', 'toro2' }) do models[m] = 'boats' end
for _, m in ipairs({ 'buzzard2', 'frogger', 'frogger2', 'maverick', 'swift', 'swift2', 'seasparrow', 'seasparrow2', 'seasparrow3',
    'supervolito', 'supervolito2', 'volatus', 'havok', 'duster', 'luxor', 'luxor2', 'stunt', 'mammatus', 'velum', 'velum2', 'shamal',
    'vestra', 'dodo', 'howard', 'alphaz1', 'nimbus', 'conada' }) do models[m] = 'air' end

return {
    finance = {
        minimumDown = 10, -- minimum percentage allowed down
        maximumPayments = 24, -- maximum payments allowed
        enable = true, -- Enables the financing system. Turning this off does not affect already financed vehicles
        zone = vec3(-29.53, -1103.67, 26.42), -- Where the finance menu is located
    },

    enableFreeUseBuy = true, -- Allows players to buy from NPC shops
    enableTestDrive = true,

    vehicles = {
        -- KAVKAZ: default убран — машины GTA, которых нет в cars.lua, в салоне не продаются
        default = nil,

        categories = {
            boats = 'boats',
            air = 'air',
        },

        models = models,

        blocklist = {
            'police',
            'police2',
            'police3',
            'police4',
        }
    },

    ---@type table<string, Dealership>
    shops = {
        pdm = {
            type = 'free-use',
            zone = {
                shape = {
                    vec3(-56.727394104004, -1086.2325439453, 26.0),
                    vec3(-60.612808227539, -1096.7795410156, 26.0),
                    vec3(-58.26834487915, -1100.572265625, 26.0),
                    vec3(-35.927803039551, -1109.0034179688, 26.0),
                    vec3(-34.427627563477, -1108.5111083984, 26.0),
                    vec3(-32.02657699585, -1101.5877685547, 26.0),
                    vec3(-33.342102050781, -1101.0377197266, 26.0),
                    vec3(-31.292987823486, -1095.3717041016, 26.0)
                },
                size = vec3(3, 3, 4),
                targetDistance = 1,
            },
            blip = {
                label = 'Автосалон «Нагорье Моторс»', -- KAVKAZ
                coords = vec3(-45.67, -1098.34, 26.42),
                show = true,
                sprite = 326,
                color = 3,
            },
            categories = pdmCategories, -- KAVKAZ: разделы из cars.lua
            testDrive = {
                limit = 5.0,
                endBehavior = 'return'
            },
            returnLocation = vec3(-32.77, -1095.75, 26.42),
            vehicleSpawns = {
                vec4(-61.35, -1110.31, 25.86, 71.01),
                vec4(-59.61, -1104.74, 25.85, 70.13),
                vec4(-52.96, -1113.49, 25.87, 71.53),
                vec4(-52.34, -1107.93, 25.87, 71.63),
                vec4(-44.27, -1116.36, 25.87, 71.7),
                vec4(-41.75, -1111.49, 25.87, 71.5),
            },
            showroomVehicles = showroomVehicles, -- KAVKAZ
        },

        boats = {
            type = 'free-use',
            zone = {
                shape = {
                    vec3(-729.39, -1315.84, 0),
                    vec3(-766.81, -1360.11, 0),
                    vec3(-754.21, -1371.49, 0),
                    vec3(-716.94, -1326.88, 0)
                },
                size = vec3(8, 8, 6),
                targetDistance = 10,
            },
            blip = {
                label = 'Лодочная станция', -- KAVKAZ
                coords = vec3(-738.25, -1334.38, 1.6),
                show = true,
                sprite = 410,
                color = 3,
            },
            categories = {
                boats = 'Лодки'
            },
            testDrive = {
                limit = 5.0,
                endBehavior = 'return'
            },
            returnLocation = vec3(-714.34, -1343.31, 0.0),
            vehicleSpawns = {
                vec4(-727.87, -1353.1, -0.17, 137.09),
            },
            showroomVehicles = {
                { coords = vec4(-727.05, -1326.59, -0.50, 229.5), vehicle = 'seashark' },
                { coords = vec4(-732.84, -1333.5, -0.50, 229.5), vehicle = 'dinghy' },
                { coords = vec4(-737.84, -1340.83, -0.50, 229.5), vehicle = 'speeder' },
                { coords = vec4(-741.53, -1349.7, -0.50, 229.5), vehicle = 'marquis' },
            },
        },

        air = {
            type = 'free-use',
            zone = {
                shape = {
                    vec3(-1607.58, -3141.7, 12.99),
                    vec3(-1672.54, -3103.87, 12.99),
                    vec3(-1703.49, -3158.02, 12.99),
                    vec3(-1646.03, -3190.84, 12.99)
                },
                size = vec3(10, 10, 8),
                targetDistance = 5,
            },
            blip = {
                label = 'Авиасалон', -- KAVKAZ
                coords = vec3(-1652.76, -3143.4, 13.99),
                show = true,
                sprite = 251,
                color = 3,
            },
            categories = {
                helicopters = 'Вертолёты',
                planes = 'Самолёты'
            },
            testDrive = {
                limit = 5.0,
                endBehavior = 'return'
            },
            returnLocation = vec3(-1628.44, -3104.7, 13.94),
            vehicleSpawns = {
                vec4(-1617.49, -3086.17, 13.94, 329.2),
            },
            showroomVehicles = {
                { coords = vec4(-1651.36, -3162.66, 12.99, 346.89), vehicle = 'volatus' },
                { coords = vec4(-1668.53, -3152.56, 12.99, 303.22), vehicle = 'luxor2' },
                { coords = vec4(-1632.02, -3144.48, 12.99, 31.08), vehicle = 'nimbus' },
                { coords = vec4(-1663.74, -3126.32, 12.99, 275.03), vehicle = 'frogger' },
            },
        },
    },
}