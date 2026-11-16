-- KAVKAZ RP: силовики с NPC — ДПС и ФСБ. посты с NPC-инспекторами, остановка NPC-машин игроком, режимы города,
-- наряды и спецгруппа по вызову лидера. сервер для себя и 1–2 друзей: в городе работают NPC, игрок может заступить на смену.

Config = {}

Config.Debug = false

-- клавиши (игрок может поменять в настройках FiveM: «Привязки клавиш» → FiveM)
Config.ActionKey = 'M'   -- «требование остановиться» (в машине — тому, кто впереди; пешком — машине, на которую смотришь); у отдела — «сдать задержанного»
Config.PanelKey = 'F7'   -- пульт лидера

---------------------------------------------------------------------------
-- службы
---------------------------------------------------------------------------
Config.Orgs = {
    dps = {
        label = 'ДПС', full = 'Полк ДПС ГИБДД',
        ped = 's_m_y_ranger_01',            -- в нашей сборке (kv_peds) одет в форму ДПС
        cars = { 'kv_2114_dps', 'kv_uaz_dps', 'police4' }, -- первая, что есть на сервере
        carColor = nil, plateIndex = 2,      -- синий номер (kavkaz_plates: plate03 = полиция)
        weapon = 'WEAPON_PISTOL',
        ranks = { [0] = 'Стажёр', 'Инспектор', 'Старший инспектор', 'Командир взвода', 'Командир роты', 'Командир полка' },
        station = vec4(434.0, -975.0, 30.71, 90.0),   -- отдел (у капитана Адама, kavkaz_quests)
        stationLabel = 'Отдел ГИБДД',
    },
    fsb = {
        label = 'ФСБ', full = 'Управление ФСБ по Нагорью',
        ped = 's_m_y_blackops_01',          -- в нашей сборке (kv_peds) — форма ФСБ
        cars = { 'kv_lc300', 'kv_camry70', 'fbi2' },
        carColor = 0, plateIndex = 0,        -- чёрная машина, обычный номер
        weapon = 'WEAPON_CARBINERIFLE',
        ranks = { [0] = 'Стажёр', 'Оперуполномоченный', 'Старший оперуполномоченный', 'Начальник отделения', 'Начальник отдела', 'Начальник управления' },
        station = vec4(115.0, -760.0, 45.75, 160.0),  -- здание ФСБ (у майора, kavkaz_quests)
        stationLabel = 'Управление ФСБ',
    },
}

-- опыт для званий (индекс — звание). с 4-го звания — лидер: режимы города, посты, наряды, спецгруппа
Config.RankXp = { [0] = 0, 300, 1000, 2500, 5000, 10000 }
Config.LeaderRank = 4
Config.AdminIsLeader = true -- админ (kavkaz_admin уровень ≥ 1) — всегда лидер

---------------------------------------------------------------------------
-- посты. coords — примерная точка у трассы: игра сама находит дорогу и ставит пост в 8 м за обочиной лицом к дороге.
-- normal — стоит в обычном режиме; org — кто стоит: dps / fsb / mixed. gate — въезд в город: пост только в «Перехват» и КТО.
-- 16.11: посты переехали сюда из kavkaz_world (там они только стояли — теперь проверяют машины).
---------------------------------------------------------------------------
Config.Posts = {
    { id = 'vostok',        label = 'Пост ДПС «Восточный въезд»', coords = vec4(2341.0, -391.0, 68.0, 0.0),  org = 'dps', normal = true },
    { id = 'zapad',         label = 'Пост ДПС «Западный»',        coords = vec4(-3003.0, 290.0, 14.0, 0.0),  org = 'dps', normal = true },
    { id = 'zancudo',       label = 'Пост ДПС «Мост»',            coords = vec4(-1608.0, 2826.0, 17.0, 0.0), org = 'dps', normal = false },
    { id = 'harmony',       label = 'Пост ДПС «Гармония»',        coords = vec4(718.0, 2710.0, 39.0, 0.0),   org = 'dps', normal = true },
    { id = 'senora',        label = 'Пост ДПС «Сенора»',          coords = vec4(2517.0, 3027.0, 41.0, 0.0),  org = 'dps', normal = false },
    { id = 'peschany',      label = 'Пост ДПС «Песчаный»',        coords = vec4(1509.1, 3481.6, 35.2, 0.0),  org = 'dps', normal = true },
    { id = 'peschany_east', label = 'Пост ДПС «Песчаный-Восток»', coords = vec4(2134.9, 3770.8, 32.0, 0.0),  org = 'dps', normal = false },
    { id = 'grapeseed',     label = 'Пост ДПС «Грейпсид»',        coords = vec4(1662.0, 4941.0, 41.0, 0.0),  org = 'dps', normal = false },
    { id = 'paleto',        label = 'Пост ДПС «Палето»',          coords = vec4(-543.0, 6161.0, 6.0, 0.0),   org = 'mixed', normal = true },
    -- въезды в Нагорск (у стел kavkaz_world Config.Gates, пост на 35 м дальше по дороге, чтобы не встать на стелу)
    { id = 'gate_airport', label = 'КПП «Аэропорт»',   coords = vec4(-845.0, -2460.0, 13.0, 0.0), org = 'fsb', gate = true, shift = 35.0 },
    { id = 'gate_east',    label = 'КПП «Восток»',     coords = vec4(2443.0, -476.0, 70.0, 0.0),  org = 'fsb', gate = true, shift = 35.0 },
    { id = 'gate_north',   label = 'КПП «Север»',      coords = vec4(1700.0, 1460.0, 84.0, 0.0),  org = 'fsb', gate = true, shift = 35.0 },
    { id = 'gate_west',    label = 'КПП «Побережье»',  coords = vec4(-3080.0, 791.0, 18.0, 0.0),  org = 'fsb', gate = true, shift = 35.0 },
}
Config.MaxTempPosts = 6        -- временные посты лидера («поставить пост здесь»)
Config.PostSpawnDistance = 170.0

-- обстановка поста (offset: x вправо, y вперёд — к дороге). у временного поста — только конусы, машина и люди
Config.PostProps = {
    { model = 'prop_portacabin01', offset = vec3(-6.0, -1.0, 0.0), heading = 90.0 },
    { model = 'prop_flag_russia', offset = vec3(-9.5, 2.0, 0.0), heading = 0.0 },
    { model = 'prop_flag_scotland', offset = vec3(-12.0, 2.0, 0.0), heading = 0.0 }, -- флаг Нагорска (kv_props)
    { model = 'prop_sec_barrier_ld_01a', offset = vec3(1.5, 4.0, 0.0), heading = 90.0 },
    { model = 'prop_worklight_03b', offset = vec3(-2.5, 3.0, 0.0), heading = 20.0 },
}
Config.ConeModel = 'prop_roadcone02a'

---------------------------------------------------------------------------
-- режимы города (объявляет лидер). check — раз в сколько секунд пост останавливает NPC-машину (мин, макс);
-- player — вероятность, что пост остановит игрока; patrols — сколько NPC-патрулей катается рядом с каждым игроком
---------------------------------------------------------------------------
Config.Modes = {
    normal    = { label = 'обычный режим', check = { 60, 120 }, player = 0.12, patrols = 0, minutes = 0 },
    enhanced  = { label = 'усиленный режим', check = { 30, 60 }, player = 0.30, patrols = 1, minutes = 30,
                  text = 'в Нагорье введён усиленный режим: все посты ДПС работают, проверки документов чаще' },
    intercept = { label = 'план «Перехват»', check = { 12, 22 }, player = 0.85, patrols = 2, minutes = 20,
                  text = 'объявлен план «Перехват»: на въездах КПП, на постах проверяют каждую машину, патрули на улицах' },
    kto       = { label = 'режим КТО', check = { 15, 30 }, player = 0.60, patrols = 2, minutes = 30,
                  text = 'введён режим контртеррористической операции: КПП ФСБ на въездах в город, усиленные проверки' },
}
Config.ModeCooldown = 120 -- секунд между сменами режима

---------------------------------------------------------------------------
-- наряды и спецгруппа (вызывает лидер)
---------------------------------------------------------------------------
Config.Units = {
    dps   = { label = 'наряд ДПС', cars = { 'kv_2114_dps', 'kv_uaz_dps', 'police4' }, ped = 's_m_y_ranger_01', count = 2, weapon = 'WEAPON_PISTOL', plateIndex = 2 },
    fsb   = { label = 'оперативная группа ФСБ', cars = { 'kv_lc300', 'kv_camry70', 'fbi2' }, ped = 's_m_y_blackops_01', count = 2, weapon = 'WEAPON_CARBINERIFLE', color = 0 },
    alpha = { label = 'спецгруппа ФСБ', cars = { 'kv_gazel', 'fbi2' }, ped = 's_m_y_blackops_01', count = 4, weapon = 'WEAPON_CARBINERIFLE', color = 0, armour = 100, helmet = true },
}
Config.MaxUnits = 3        -- нарядов одновременно у одного лидера (спецгруппа — отдельно, одна)
Config.UnitSpawnMin, Config.UnitSpawnMax = 140.0, 260.0 -- откуда выезжает наряд (не на глазах)

---------------------------------------------------------------------------
-- статьи КоАП для NPC-водителей. viol — какое нарушение профиля доказывает статья
---------------------------------------------------------------------------
Config.Fines = {
    { id = 'belt',     label = '12.6 — не пристёгнут ремнём',            amount = 1000,  viol = 'belt' },
    { id = 'phone',    label = '12.36.1 — телефон за рулём',              amount = 1500,  viol = 'phone' },
    { id = 'osago',    label = '12.37 ч.2 — нет ОСАГО',                    amount = 800,   viol = 'osago' },
    { id = 'sts',      label = '12.3 ч.1 — нет документов на машину',      amount = 500,   viol = 'sts' },
    { id = 'nolic',    label = '12.7 ч.1 — без прав (нет или просрочены)', amount = 15000, viol = 'nolic' },
    { id = 'revoked',  label = '12.7 ч.2 — лишён прав',                    amount = 30000, viol = 'revoked' },
    { id = 'drunk',    label = '12.8 ч.1 — за рулём пьяный',               amount = 45000, viol = 'drunk' },
    { id = 'flee',     label = '12.25 ч.2 — не остановился по требованию', amount = 800,   viol = 'flee' },
}

-- за что задерживают (иначе задержание — превышение полномочий)
Config.DetainReasons = { drunk = true, revoked = true, wanted = true, contraband = true, stolen = true, flee = true }

-- деньги и опыт игрока на смене (₽ — на карту в конце каждого действия)
Config.Reward = {
    check     = { money = 150, xp = 5 },    -- проверил документы и отпустил
    fineShare = 0.10,                        -- доля от верного штрафа
    fineXp    = 10,
    detain    = { money = 2500, xp = 40 },  -- доставил задержанного в отдел
    caught    = { money = 1500, xp = 25 },  -- догнал удиравшего
    wrongFine = { money = -500, xp = -15 }, -- штраф без нарушения — жалоба
    wrongDetain = { money = -1500, xp = -40 },
}
Config.MaxComplaints = 3 -- столько жалоб за смену — служебная проверка, смена закрыта

-- игрок, которого остановил NPC-пост
Config.PlayerStop = {
    radius = 30.0,         -- проезжает ближе — может получить требование
    wait = 15,             -- секунд на то, чтобы остановиться
    stopRadius = 35.0,     -- где надо встать (от кармана поста)
    cooldown = 600,        -- одного игрока не чаще раза в 10 минут
    fineIgnore = 'other',  -- статья kavkaz_fines за «не остановился» (сумма — ниже)
    fineIgnoreAmount = 2000,
    fineNoLicense = 'nolic',
}

-- куда смотрят точки «сдать задержанного» (радиус от отдела)
Config.DeliverRadius = 35.0
