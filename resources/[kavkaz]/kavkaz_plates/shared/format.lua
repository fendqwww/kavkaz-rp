-- форматы номеров. в игре номер хранится латиницей без пробелов (GTA не рисует кириллицу, максимум 8 символов),
-- на экранах рисуется по ГОСТ (html/plate.js).
--   ru         А 777 АА 95  -> A777AA95   обычный
--   ru_taxi    АВ 123 95    -> AB12395    жёлтый, такси и автобусы
--   ru_police  А 1234 95    -> A123495    синий, полиция
--   ru_army    1234 АВ 95   -> 1234AB95   чёрный, военные
--   kz         123 ABC 02   -> 123ABC02   Казахстан
--   by         1234 AB-7    -> 1234AB7    Беларусь
--   am         12 AB 345    -> 12AB345    Армения
--   ge         AB-123-CD    -> AB123CD    Грузия
--   az         10-AB-123    -> 10AB123    Азербайджан

Plates = {}

-- буквы, у которых одинаковое написание в кириллице и латинице (только их рисует шрифт номеров)
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

local L = '[' .. Plates.LAT .. ']'
local ruRegions = {}
for _, r in ipairs(Config.Regions) do ruRegions[r.code] = true end

local function letter()
    local i = math.random(1, #Plates.LAT)
    return Plates.LAT:sub(i, i)
end
local function letters(n) local s = '' for _ = 1, n do s = s .. letter() end return s end
local function digits(n, min) return ('%0' .. n .. 'd'):format(math.random(min or 0, 10 ^ n - 1)) end

-- pattern — проверка, groups — как разбить для подписи, gen — случайный номер
Plates.STYLES = {
    ru = {
        pattern = '^(' .. L .. ')(%d%d%d)(' .. L .. L .. ')(%d%d)$',
        check = function(m) return m[2] ~= '000' and ruRegions[m[4]] end,
        gen = function(region) return letter() .. digits(3, 1) .. letters(2) .. (region or Config.DefaultRegion) end,
    },
    ru_taxi = {
        pattern = '^(' .. L .. L .. ')(%d%d%d)(%d%d)$',
        check = function(m) return m[2] ~= '000' and ruRegions[m[3]] end,
        gen = function(region) return letters(2) .. digits(3, 1) .. (region or Config.DefaultRegion) end,
    },
    ru_police = {
        pattern = '^(' .. L .. ')(%d%d%d%d)(%d%d)$',
        check = function(m) return m[2] ~= '0000' and ruRegions[m[3]] end,
        gen = function(region) return letter() .. digits(4, 1) .. (region or Config.DefaultRegion) end,
    },
    ru_army = {
        pattern = '^(%d%d%d%d)(' .. L .. L .. ')(%d%d)$',
        check = function(m) return m[1] ~= '0000' end,
        gen = function() return digits(4, 1) .. letters(2) .. digits(2, 10) end,
    },
    kz = {
        pattern = '^(%d%d%d)(' .. L .. L .. L .. ')(%d%d)$',
        check = function(m) local r = tonumber(m[3]) return m[1] ~= '000' and r >= 1 and r <= 20 end,
        gen = function() return digits(3, 1) .. letters(3) .. ('%02d'):format(math.random(1, 20)) end,
    },
    by = {
        pattern = '^(%d%d%d%d)(' .. L .. L .. ')([1-7])$',
        check = function(m) return m[1] ~= '0000' end,
        gen = function() return digits(4, 1) .. letters(2) .. math.random(1, 7) end,
    },
    am = {
        pattern = '^(%d%d)(' .. L .. L .. ')(%d%d%d)$',
        check = function(m) return m[3] ~= '000' end,
        gen = function() return digits(2, 1) .. letters(2) .. digits(3, 1) end,
    },
    ge = {
        pattern = '^(' .. L .. L .. ')(%d%d%d)(' .. L .. L .. ')$',
        check = function(m) return m[2] ~= '000' end,
        gen = function() return letters(2) .. digits(3, 1) .. letters(2) end,
    },
    az = {
        pattern = '^(%d%d)(' .. L .. L .. ')(%d%d%d)$',
        check = function(m) return m[3] ~= '000' end,
        gen = function() return digits(2, 1) .. letters(2) .. digits(3, 1) end,
    },
}

local function match(style, s)
    local st = Plates.STYLES[style]
    if not st then return nil end
    local m = { s:match(st.pattern) }
    if #m == 0 or not st.check(m) then return nil end
    return m
end

-- ввод игрока/админа («к 013 ра 95», «K013PA95») -> 'K013PA95' или nil
function Plates.normalize(input, style)
    if type(input) ~= 'string' then return nil end
    style = style or 'ru'
    local s = input:gsub('[%s%-]', '')
    s = s:gsub('[\208\209][\128-\191]', function(ch) return toLat[ch] or ch end)
    s = s:upper()
    if not match(style, s) then return nil end
    return s
end

-- какой стиль подходит к номеру (для пробивки и старых записей)
function Plates.detect(plate)
    for _, style in ipairs({ 'ru', 'ru_army', 'kz', 'ru_taxi', 'ru_police', 'by', 'ge', 'am' }) do
        if match(style, plate) then return style end
    end
    return nil
end

function Plates.isOurs(plate, style)
    return match(style or 'ru', plate) ~= nil
end

-- подпись: 'K013PA95' -> 'К 013 РА 95'
function Plates.pretty(plate, style)
    style = style or Plates.detect(plate or '') or 'ru'
    local m = plate and match(style, plate)
    if not m then return plate end
    local text = table.concat(m, ' ')
    if style:sub(1, 2) == 'ru' then text = text:gsub('%a', function(c) return toCyr[c] or c end) end
    return text
end

-- красивый ли обычный номер (ключ из Config.Tiers) или nil. касается только стиля ru.
function Plates.tier(plate)
    local m = match('ru', plate)
    if not m then return nil end
    local d, region = m[2], m[4]
    local lets = m[1] .. m[3]
    if lets == 'KPA' and region == '95' then return 'kra' end -- серия «КРА»
    local sameLetters = lets == lets:sub(1, 1):rep(3)
    local triple = d == d:sub(1, 1):rep(3)
    local zero = d:match('^00[1-9]$') ~= nil
    if sameLetters and (triple or zero) then return 'blat' end
    if zero then return 'zero' end
    if d == '095' and region == '95' then return 'region' end
    if triple then return 'triple' end
    if sameLetters then return 'letters' end
    return nil
end

-- случайный номер стиля (без проверки занятости); красивые обычные номера пропускаем
function Plates.random(style, region)
    local st = Plates.STYLES[style or 'ru']
    for _ = 1, 200 do
        local plate = st.gen(region)
        if match(style or 'ru', plate) and not (style == 'ru' and Plates.tier(plate)) then return plate end
    end
    return nil
end
