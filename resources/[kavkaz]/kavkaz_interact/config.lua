Config = {}

-- клавиша меню. короткое нажатие в машине с СГУ — кряк; удержание — радиальное меню.
Config.Key = 'G'
Config.HoldMs = 220       -- дольше этого — открывается меню, короче — быстрое действие (кряк)
Config.ReachVehicle = 4.0 -- на таком расстоянии снаружи видим машину

-- иконки берутся из html (SVG по имени). подписи — по-русски.
-- act — что делает (client.lua), need — когда пункт показывать.
Config.Vehicle = {
    driver = { -- за рулём
        { id = 'hood',    label = 'Капот',    icon = 'hood' },
        { id = 'trunk',   label = 'Багажник', icon = 'trunk' },
        { id = 'doors',   label = 'Двери',    icon = 'door', sub = true },
        { id = 'belt',    label = 'Ремень',   icon = 'belt' },
        { id = 'lock',    label = 'Замок',    icon = 'lock' },
        { id = 'engine',  label = 'Зажигание', icon = 'key' },
        { id = 'lights',  label = 'Фары',     icon = 'light' },
        { id = 'seatout', label = 'Выйти',    icon = 'exit' },
    },
    passenger = { -- пассажиром
        { id = 'belt',    label = 'Ремень', icon = 'belt' },
        { id = 'seatout', label = 'Выйти',  icon = 'exit' },
    },
    outside = { -- рядом с машиной, пешком
        { id = 'hood',  label = 'Капот',    icon = 'hood' },
        { id = 'trunk', label = 'Багажник', icon = 'trunk' },
        { id = 'lock',  label = 'Замок',    icon = 'lock' },
    },
}

-- подменю дверей
Config.Doors = {
    { id = 'd0', label = 'Водителя',  icon = 'door', door = 0 },
    { id = 'd1', label = 'Пассажира', icon = 'door', door = 1 },
    { id = 'd2', label = 'Зад левая', icon = 'door', door = 2 },
    { id = 'd3', label = 'Зад правая', icon = 'door', door = 3 },
}

-- пешком (не у машины)
Config.Foot = {
    { id = 'hands',    label = 'Руки вверх',  icon = 'hands' },
    { id = 'passport', label = 'Паспорт',     icon = 'id' },
    { id = 'gps',      label = 'Навигатор',   icon = 'map' },
    { id = 'help',     label = 'Команды',     icon = 'list' },
}
