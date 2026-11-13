-- KAVKAZ RP: забегаловки Нагорья. продавец-NPC, меню на русском, цены в ₽.
-- цены и что продаётся проверяет сервер (server.lua), клиент только показывает меню.
-- координаты помеченные «сверить» — встань на место в игре, набери /mypos и поменяй строку.

Config = {}

-- что можно купить (предметы описаны в overrides/resources/[ox]/ox_inventory/data/items.lua)
Config.Items = {
    shawarma     = { label = 'Шаурма',               desc = 'курица, овощи, чесночный соус' },
    shawarma_xl  = { label = 'Шаурма XL',            desc = 'двойная, с сыром — хватит надолго' },
    shashlyk     = { label = 'Шашлык',               desc = 'баранина на углях, лук, лаваш' },
    zhizhig      = { label = 'Жижиг-галнаш',         desc = 'мясо с галушками и бульоном' },
    chepalgash   = { label = 'Чепалгаш',             desc = 'лепёшка с творогом и маслом' },
    samsa        = { label = 'Самса',                desc = 'с мясом, горячая' },
    chai         = { label = 'Чай с чабрецом',       desc = 'горячий, в стакане-армуде' },
    ayran        = { label = 'Айран',                desc = 'холодный, утоляет жажду' },
    water        = { label = 'Вода',                 desc = 'бутылка 0,5 л' },
    coffee       = { label = 'Кофе',                 desc = 'с собой' },
    lepeshka     = { label = 'Тандырная лепёшка',    desc = 'горячая, только из тандыра' },
    yabloki      = { label = 'Яблоки',               desc = 'кулёк, с гор' },
    tvorog       = { label = 'Творог домашний',      desc = 'полкило, на развес' },
    kompot       = { label = 'Компот',               desc = 'из алычи, литр' },
}

Config.MaxPerBuy = 5      -- за одну покупку
Config.Distance = 4.0     -- сервер проверяет, что игрок стоит у продавца

-- места. menu = { предмет = цена в ₽ }
Config.Places = {
    {
        id = 'rasul',
        label = 'Шаурма у Расула',
        desc = 'у автовокзала, первое место, куда идёт новичок',
        seller = { model = 'a_m_m_eastsa_02', coords = vec4(454.6, -651.8, 28.2, 0.0) }, -- сверить
        props = { { model = 'prop_hotdogstand_01', offset = vec3(0.0, 1.2, 0.0), heading = 180.0 } },
        blip = { sprite = 93, color = 17 },
        menu = { shawarma = 350, shawarma_xl = 550, ayran = 120, water = 60, chai = 80 },
    },
    {
        id = 'shawarma24',
        label = 'Шаурма 24',
        desc = 'центр, площадь у Правительства — круглосуточно',
        seller = { model = 'a_m_y_stbla_02', coords = vec4(196.8, -933.6, 30.7, 145.0) }, -- сверить
        props = { { model = 'prop_burgerstand_01', offset = vec3(0.0, 1.2, 0.0), heading = 325.0 } },
        blip = { sprite = 93, color = 17 },
        menu = { shawarma = 350, shawarma_xl = 550, samsa = 150, ayran = 120, coffee = 150, water = 60 },
    },
    {
        id = 'chaikhana',
        label = 'Чайхана «У Румисы»',
        desc = 'горячая кухня, повар рядом с Румисой Халвовной',
        seller = { model = 'a_m_m_soucent_03', coords = vec4(-719.6, -909.4, 19.2, 90.0) }, -- сверить
        props = {},
        blip = false, -- метку ставит kavkaz_quests (Румиса)
        menu = { zhizhig = 600, chepalgash = 250, samsa = 150, chai = 80, ayran = 120, water = 60 },
    },
    {
        id = 'bazar',
        label = 'Восточный базар',
        desc = 'лепёшки, фрукты, творог — рядом с чайханой',
        seller = { model = 'a_f_m_soucent_01', coords = vec4(-697.5, -898.7, 19.2, 180.0) }, -- сверить (за 4-м прилавком сцены bazar в kavkaz_world)
        props = {},
        blip = false, -- метку ставит kavkaz_map, прилавки — kavkaz_world
        menu = { lepeshka = 60, yabloki = 90, tvorog = 180, kompot = 70, samsa = 150, chai = 80 },
    },
    {
        id = 'mangal',
        label = 'Шашлычная «Мангал» у трассы',
        desc = 'трасса на Песчаный, остановка дальнобойщиков',
        seller = { model = 'a_m_m_hillbilly_01', coords = vec4(1175.4, 2696.8, 37.9, 90.0) }, -- сверить
        props = {
            { model = 'prop_bbq_5', offset = vec3(-1.4, 0.0, 0.0), heading = 90.0 },
            { model = 'prop_table_03', offset = vec3(-3.5, 2.0, 0.0), heading = 0.0 },
            { model = 'prop_table_03', offset = vec3(-3.5, -2.0, 0.0), heading = 0.0 },
        },
        blip = { sprite = 93, color = 47 },
        menu = { shashlyk = 700, chepalgash = 250, chai = 80, ayran = 120, water = 60 },
    },
}
