-- KAVKAZ RP: правила длинных нард. чистый Lua без FiveM — сервер решает, какой ход законный; клиенту не доверяем.
--
-- координаты: у каждого игрока свои позиции 1..24, ход всегда к меньшему числу.
--   24 — «голова» (старт, все 15 шашек), 1..6 — свой дом, 0 — шашка выброшена.
--   белые (1): своя позиция p = клетка доски p; чёрные (2): своя позиция p = клетка ((p + 11) % 24) + 1,
--   то есть голова чёрных напротив головы белых, оба идут в одну сторону по кругу.
-- правила: бить нельзя (на клетку соперника не встать); с головы — одна шашка за ход
--   (в первый ход при дубле 6-6, 4-4 или 3-3 — две); дубль — 4 хода; нельзя строить заслон из 6 подряд,
--   если впереди него нет ни одной шашки соперника; выбрасывать — когда все 15 в доме;
--   ходить обязательно максимально возможным числом костей, а если можно сыграть только одну
--   из двух разных — обязательно большую.

local R = {}

function R.abs(color, p)
    if color == 1 then return p end
    return ((p + 11) % 24) + 1
end

function R.new()
    local s = { pts = {}, off = { 0, 0 }, first = { true, true }, turn = 1, dice = {}, head = 0 }
    for a = 1, 24 do s.pts[a] = { c = 0, n = 0 } end
    s.pts[R.abs(1, 24)] = { c = 1, n = 15 }
    s.pts[R.abs(2, 24)] = { c = 2, n = 15 }
    return s
end

local function clone(s)
    local t = { pts = {}, off = { s.off[1], s.off[2] }, first = { s.first[1], s.first[2] }, turn = s.turn, dice = {}, head = s.head, headMax = s.headMax }
    for a = 1, 24 do t.pts[a] = { c = s.pts[a].c, n = s.pts[a].n } end
    for i = 1, #s.dice do t.dice[i] = s.dice[i] end
    return t
end
R.clone = clone

local function at(s, color, p)
    local pt = s.pts[R.abs(color, p)]
    if pt.c == color then return pt.n end
    return 0
end
R.at = at

local function allHome(s, color)
    for p = 7, 24 do
        if at(s, color, p) > 0 then return false end
    end
    return true
end

local function highest(s, color)
    for p = 24, 1, -1 do
        if at(s, color, p) > 0 then return p end
    end
    return 0
end

-- заслон из 6 подряд на пути соперника, перед которым нет ни одной шашки соперника
local function badBlock(s, color)
    local opp = 3 - color
    local oppAhead = 25 -- самая дальняя (ближняя к дому) шашка соперника на доске
    for p = 1, 24 do
        if at(s, opp, p) > 0 then oppAhead = p break end
    end
    local run = 0
    for p = 24, 1, -1 do -- позиции соперника, по ходу его движения
        local pt = s.pts[R.abs(opp, p)]
        if pt.c == color and pt.n > 0 then
            run = run + 1
            if run >= 6 then
                local blockLow = p -- нижняя (по ходу соперника — последняя) клетка заслона
                if oppAhead >= blockLow then return true end
            end
        else
            run = 0
        end
    end
    return false
end

local function headLimit(s)
    return s.headMax or 1
end

-- один шаг: шашка с позиции from на кость die. возвращает новую позицию (0 — выброс) или nil
local function target(s, color, from, die)
    if at(s, color, from) == 0 then return nil end
    if from == 24 and s.head >= headLimit(s) then return nil end
    local to = from - die
    if to >= 1 then
        local pt = s.pts[R.abs(color, to)]
        if pt.n > 0 and pt.c ~= color then return nil end
        return to
    end
    if not allHome(s, color) then return nil end
    if to == 0 then return 0 end
    if highest(s, color) == from then return 0 end -- выброс большей костью с самой дальней клетки
    return nil
end

local function removeDie(dice, die)
    for i = 1, #dice do
        if dice[i] == die then table.remove(dice, i) return true end
    end
    return false
end

local function applyRaw(s, color, from, die, to)
    local a = s.pts[R.abs(color, from)]
    a.n = a.n - 1
    if a.n == 0 then a.c = 0 end
    if to == 0 then
        s.off[color] = s.off[color] + 1
    else
        local b = s.pts[R.abs(color, to)]
        b.c = color
        b.n = b.n + 1
    end
    if from == 24 then s.head = s.head + 1 end
    removeDie(s.dice, die)
end

-- все шаги без учёта «максимум костей»
local function rawSteps(s, color)
    local list, seen = {}, {}
    for _, die in ipairs(s.dice) do
        if not seen[die] then
            seen[die] = true
            for from = 24, 1, -1 do
                local to = target(s, color, from, die)
                if to then
                    local t = clone(s)
                    applyRaw(t, color, from, die, to)
                    if not badBlock(t, color) then
                        list[#list + 1] = { from = from, die = die, to = to, after = t }
                    end
                end
            end
        end
    end
    return list
end

-- сколько ещё костей можно сыграть из этого положения (с запоминанием по позиции)
local function depth(s, color, memo)
    if #s.dice == 0 or s.off[color] == 15 then return 0 end
    local key = {}
    for a = 1, 24 do key[a] = s.pts[a].c .. ':' .. s.pts[a].n end
    key = table.concat(key, ',') .. '|' .. table.concat(s.dice, ',') .. '|' .. s.head
    if memo[key] then return memo[key] end
    local best = 0
    for _, st in ipairs(rawSteps(s, color)) do
        local d = 1 + depth(st.after, color, memo)
        if d > best then best = d end
        if best == #s.dice then break end
    end
    memo[key] = best
    return best
end

-- законные шаги для игрока, чей ход: только те, что ведут к максимуму сыгранных костей
function R.legal(s)
    local color = s.turn
    local memo = {}
    local steps = rawSteps(s, color)
    local best, out = 0, {}
    for _, st in ipairs(steps) do
        st.d = 1 + depth(st.after, color, memo)
        if st.d > best then best = st.d end
    end
    for _, st in ipairs(steps) do
        if st.d == best then out[#out + 1] = st end
    end
    -- две разные кости, сыграть можно только одну — обязательно большую, если ею есть ход
    if best == 1 and #s.dice == 2 and s.dice[1] ~= s.dice[2] then
        local big = math.max(s.dice[1], s.dice[2])
        local hasBig = false
        for _, st in ipairs(out) do if st.die == big then hasBig = true end end
        if hasBig then
            local only = {}
            for _, st in ipairs(out) do if st.die == big then only[#only + 1] = st end end
            out = only
        end
    end
    local res = {}
    for _, st in ipairs(out) do res[#res + 1] = { from = st.from, die = st.die, to = st.to } end
    return res
end

-- бросок: rnd(n) -> 1..n (сервер передаёт math.random)
function R.roll(s, rnd)
    local a, b = rnd(6), rnd(6)
    s.head = 0
    if a == b then s.dice = { a, a, a, a } else s.dice = { a, b } end
    -- первый ход с дублем 6-6, 4-4, 3-3: с головы можно снять две шашки
    s.headMax = (s.first[s.turn] and a == b and (a == 6 or a == 4 or a == 3)) and 2 or 1
    return a, b
end

-- сделать шаг, если он законный. true — принят
function R.move(s, from, die)
    for _, st in ipairs(R.legal(s)) do
        if st.from == from and st.die == die then
            applyRaw(s, s.turn, from, die, st.to)
            return true
        end
    end
    return false
end

-- ход окончен: кости кончились или ходить нечем
function R.turnOver(s)
    return #s.dice == 0 or #R.legal(s) == 0 or s.off[s.turn] == 15
end

function R.nextTurn(s)
    s.first[s.turn] = false
    s.turn = 3 - s.turn
    s.dice = {}
    s.head = 0
end

function R.winner(s)
    if s.off[1] == 15 then return 1 end
    if s.off[2] == 15 then return 2 end
    return nil
end

Nardy = R -- для сервера FiveM (shared_script)
return R
