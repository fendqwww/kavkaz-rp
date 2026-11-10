-- формат номера «А 777 АА 95».
-- в игре номер хранится латиницей без пробелов (GTA не рисует кириллицу, максимум 8 символов): A777AA95.
-- на экранах показываем кириллицей с пробелами.

Plates = {}

-- 12 букв, у которых есть одинаковое написание в кириллице и латинице
Plates.LAT = 'ABEKMHOPCTYX'
local CYR = { 'А', 'В', 'Е', 'К', 'М', 'Н', 'О', 'Р', 'С', 'Т', 'У', 'Х' }
local CYR_LOWER = { 'а', 'в', 'е', 'к', 'м', 'н', 'о', 'р', 'с', 'т', 'у', 'х' }

local toLat, toCyr = {}, {}
for i = 1, #Plates.LAT do
    local l = Plates.LAT:sub(i, i)
    toLat[CYR[i]] = l
    toLat[CYR_LOWER[i]] = l
    toCyr[l] = CYR[i]
end

local regions = {}
for _, r in ipairs(Config.Regions) do regions[r.code] = true end

local PATTERN = '^([' .. Plates.LAT .. '])(%d%d%d)([' .. Plates.LAT .. '][' .. Plates.LAT .. '])(%d%d)$'

-- ввод игрока/админа («а777аа 95», «A 777 AA 95») -> 'A777AA95' или nil
function Plates.normalize(input)
    if type(input) ~= 'string' then return nil end
    local s = input:gsub('[%s%-]', '')
    s = s:gsub('[\208\209][\128-\191]', function(ch) return toLat[ch] or ch end)
    s = s:upper()
    local l1, digits, l2, region = s:match(PATTERN)
    if not l1 or digits == '000' or not regions[region] then return nil end
    return s
end

function Plates.isOurs(plate)
    return Plates.normalize(plate) == plate
end

-- 'A777AA95' -> 'А 777 АА 95'
function Plates.pretty(plate)
    if not plate or not Plates.isOurs(plate) then return plate end
    local function c(i) return toCyr[plate:sub(i, i)] end
    return ('%s %s %s%s %s'):format(c(1), plate:sub(2, 4), c(5), c(6), plate:sub(7, 8))
end

-- красивый ли номер (ключ из Config.Tiers) или nil
function Plates.tier(plate)
    local digits = plate:sub(2, 4)
    local letters = plate:sub(1, 1) .. plate:sub(5, 6)
    local sameLetters = letters == letters:sub(1, 1):rep(3)
    local triple = digits == digits:sub(1, 1):rep(3)
    local zero = digits:match('^00[1-9]$') ~= nil
    if sameLetters and (triple or zero) then return 'blat' end
    if zero then return 'zero' end
    if digits == '095' and plate:sub(7, 8) == '95' then return 'region' end
    if triple then return 'triple' end
    if sameLetters then return 'letters' end
    return nil
end

-- случайный обычный номер (без проверки занятости)
function Plates.random(region)
    local function letter()
        local i = math.random(1, #Plates.LAT)
        return Plates.LAT:sub(i, i)
    end
    while true do
        local plate = ('%s%03d%s%s%s'):format(letter(), math.random(1, 999), letter(), letter(), region)
        if not Plates.tier(plate) then return plate end
    end
end
