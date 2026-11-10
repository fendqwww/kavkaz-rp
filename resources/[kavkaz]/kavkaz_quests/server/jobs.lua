-- работа: доставка обедов из чайханы. смена у Румисы, заказ -> адрес -> оплата -> следующий заказ.

local D = Config.Delivery
local shifts = {} -- src -> { last = индекс адреса, done = заказов, earned = ₽ }

local function nextOrder(src)
    local sh = shifts[src]
    if not sh then return end
    local idx
    repeat idx = math.random(1, #D.addresses) until idx ~= sh.last or #D.addresses == 1
    sh.last = idx
    local target = D.addresses[idx]
    local from = GetEntityCoords(GetPlayerPed(src))
    local minSeconds = #(from - target) / D.speed -- быстрее нельзя: защита от телепорта
    local startedAt = os.time()
    Q.objective(src, {
        id = 'delivery_' .. idx, text = ('Доставка обеда · заказ %d'):format(sh.done + 1), coords = target, radius = 4.0,
        onReach = function(s)
            local cur = shifts[s]
            if not cur then return end
            if os.time() - startedAt < minSeconds then
                Q.notify(s, 'слишком быстро… заказ не засчитан', 'error')
                return nextOrder(s)
            end
            local pay = D.pay + math.random(0, D.tipMax)
            Q.reward(s, pay, 'работа: доставка обедов')
            cur.done, cur.earned = cur.done + 1, cur.earned + pay
            Q.notify(s, ('заказ доставлен: %s. следующий — на карте'):format(Q.money(pay)), 'success')
            nextOrder(s)
        end,
    })
end

Q.delivery = {
    active = function(src) return shifts[src] ~= nil end,
    start = function(src)
        if shifts[src] then return 'Ты и так на смене.' end
        shifts[src] = { last = 0, done = 0, earned = 0 }
        nextOrder(src)
        return ('Бери термосумку. Заказ на карте. Плачу %s за каждый, чаевые твои. Пешком, на машине — как хочешь, но горячим!'):format(Q.money(D.pay))
    end,
    stop = function(src)
        local sh = shifts[src]
        if not sh then return 'Ты не на смене.' end
        shifts[src] = nil
        Q.objective(src, nil)
        return ('Смена закрыта. Доставлено заказов: %d, заработал %s. Молодец.'):format(sh.done, Q.money(sh.earned))
    end,
}

AddEventHandler('playerDropped', function() shifts[source] = nil end)
