-- KAVKAZ RP: русский поток машин и прохожие без американских ролей.
-- машины-NPC вдалеке или вне экрана заменяются нашими моделями из kavkaz_cars, у всех NPC русские номера.
-- модели, которых нет на сервере, просто пропускаются (IsModelInCdimage).

Config = {}

-- наши модели в потоке и их доля (чем больше число, тем чаще)
-- 11.11: тяжёлые текстуры перепакованы (setup/cars/repack_ytd.py, каждая машина ≤ 24 МБ видеопамяти) — все снова в потоке.
-- суперкары (jesko, chiron, roadster, cybertruck) в поток не ставим: на улицах Нагорья их почти нет.
Config.Models = {
    kv_priora  = 14,
    kv_vaz2114 = 12,
    kv_vaz2107 = 10,
    kv_granta  = 12,
    kv_vaz2110 = 9,
    kv_vaz2109 = 7,
    kv_vesta   = 9,
    kv_logan   = 8,
    kv_camry70 = 6,
    kv_camry80 = 4,
    kv_largus  = 5,
    kv_focus3  = 5,
    kv_octavia = 5,
    kv_lc300   = 3,
    kv_gazel   = 4,
    kv_mondeo  = 3,
    kv_m5f90   = 1,
    kv_g63     = 1,
    kv_zeekr001 = 1,
}

-- какие классы GTA заменяем: 0 компакт, 1 седан, 2 внедорожник, 3 купе, 4 маслкар, 5 классика, 6 спорт, 7 супер, 9 бездорожье, 12 фургон
Config.SwapClasses = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [9] = true, [12] = true }

Config.Interval = 1200     -- мс между проверками
Config.PerTick = 2         -- сколько машин менять за одну проверку (чтобы не было подтормаживаний)
Config.MinDistance = 45.0  -- ближе этого не трогаем вообще
Config.SafeDistance = 110.0 -- дальше этого меняем даже на экране (издалека подмену не видно)
Config.MaxDistance = 260.0

-- американские машины, которые не должны появляться в потоке совсем
Config.SuppressVehicles = {
    'police', 'police2', 'police3', 'police4', 'policeold1', 'policeold2', 'policet', 'policeb',
    'sheriff', 'sheriff2', 'fbi', 'fbi2', 'pranger', 'lguard', 'taxi', 'schoolbus', 'stretch',
    'bodhi2', 'sadler', 'bison', 'bobcatxl', 'emperor2', 'tornado3', 'tornado4', 'voodoo2', 'ratloader',
}

-- прохожие, которых в Нагорье нет: американская полиция, шерифы, банды Лос-Сантоса, реднеки
Config.SuppressPeds = {
    's_m_y_cop_01', 's_f_y_cop_01', 's_m_y_sheriff_01', 's_f_y_sheriff_01', 's_m_y_hwaycop_01', 's_m_m_snowcop_01',
    'g_m_y_ballaeast_01', 'g_m_y_ballaorig_01', 'g_m_y_ballasout_01', 'g_f_y_ballas_01',
    'g_m_y_famca_01', 'g_m_y_famdnf_01', 'g_m_y_famfor_01', 'g_f_y_families_01',
    'g_m_y_mexgang_01', 'g_m_y_mexgoon_01', 'g_m_y_mexgoon_02', 'g_m_y_mexgoon_03', 'g_f_y_vagos_01',
    'g_m_y_salvaboss_01', 'g_m_y_salvagoon_01', 'g_m_y_salvagoon_02', 'g_m_y_salvagoon_03',
    'g_m_y_lost_01', 'g_m_y_lost_02', 'g_m_y_lost_03', 'g_f_y_lost_01',
    'a_m_m_hillbilly_01', 'a_m_m_hillbilly_02', 'a_m_y_hippy_01', 'a_f_y_hippie_01',
    'a_m_m_rurmeth_01', 'a_m_y_methhead_01', 'a_f_y_rurmeth_01',
}

-- русские номера NPC: буквы, которые есть и в кириллице, и в латинице; регион — по весу
Config.PlateLetters = 'ABEKMHOPCTYX'
Config.Regions = { ['95'] = 10, ['05'] = 3, ['06'] = 2, ['07'] = 2, ['09'] = 1, ['15'] = 2, ['20'] = 3, ['26'] = 2, ['77'] = 1 }
