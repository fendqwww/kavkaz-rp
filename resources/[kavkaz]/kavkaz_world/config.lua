-- KAVKAZ RP: облик Нагорья поверх карты GTA — русские знаки и щиты, посты ДПС, убираем американское.
-- координаты помеченные «сверить» — встань на место в игре, набери /mypos и поменяй строку.

Config = {}

---------------------------------------------------------------------------
-- 1. подмена текстур GTA своими картинками (images/*.png рисует setup/signs/make_signs.py)
-- txd — словарь текстур GTA, txn — имя текстуры в нём, image — наша картинка без .png.
-- имена txd/txn берутся из файлов игры: CodeWalker (RPF Explorer → поиск по «sign»/«billboard»)
-- или setup/cars/ytdinfo.py на вытащенном .ytd. пока список пустой — в игре ничего не меняется.
-- пример строки: { txd = 'prop_sign_road_01a', txn = 'prop_sign_road_01a_d', image = 'city_nagorsk' },
-- вывески зданий (МВД, ФСБ, магазины…) — image из Config.RetexImages (retex_list.lua), например image = 'facade_police'.
-- как найти txd/txn здания и подогнать картинку по размеру — docs/tasks/2026-11-11-retex-mvd.md
---------------------------------------------------------------------------
Config.Textures = {
}

-- какие картинки есть (для справки и для /kvsign — показать картинку на экране)
Config.Images = {
    'city_nagorsk', 'city_nagorsk_end', 'city_lamyurt', 'city_sedayurt', 'city_peschany',
    'dir_city', 'dir_north', 'dir_highway',
    'ad_motors', 'ad_hazard', 'ad_shawarma', 'ad_tv', 'ad_chaikhana', 'ad_dps',
}

---------------------------------------------------------------------------
-- 2. убрать американские флаги, символику и уличные мелочи по всей карте
---------------------------------------------------------------------------
Config.HideEverywhere = {
    'prop_flag_us',
    'prop_flag_usboat',
    'prop_flag_ls',
    'prop_flag_lsfd',
    'prop_flag_lsservices',
    'prop_flag_sa',
    'prop_flag_sheriff',
    -- маленькие варианты тех же флагов и флаги на яхтах (моделей, которых нет в игре, клиент просто пропускает)
    'prop_flag_us_s', 'prop_flag_ls_s', 'prop_flag_lsfd_s', 'prop_flag_lsservices_s', 'prop_flag_sa_s', 'prop_flag_sheriff_s',
    'apa_prop_flag_us_yt', 'apa_prop_flag_mexico_yt', 'prop_flag_mexico', 'prop_flag_mexico_s', 'prop_flag_canada', 'prop_flag_canada_s',
    -- американские мелочи на улицах: синие почтовые ящики, газетные автоматы, таксофоны
    'prop_postbox_01a',
    'prop_news_disp_01a', 'prop_news_disp_02a', 'prop_news_disp_02b', 'prop_news_disp_02c', 'prop_news_disp_02d',
    'prop_news_disp_02e', 'prop_news_disp_03a', 'prop_news_disp_03c', 'prop_news_disp_05a', 'prop_news_disp_06a',
    'prop_phonebox_01a', 'prop_phonebox_01b', 'prop_phonebox_01c', 'prop_phonebox_02', 'prop_phonebox_03', 'prop_phonebox_04',
}

---------------------------------------------------------------------------
-- 3. посты ДПС: будка, шлагбаум, конусы, флаг России, инспекторы, машина
-- offset — от точки поста (x вправо, y вперёд по направлению heading), heading — поворот относительно поста
---------------------------------------------------------------------------
Config.Posts = {
    {
        id = 'peschany',
        label = 'Пост ДПС «Песчаный»',
        coords = vec4(1866.0, 3680.0, 33.7, 210.0), -- сверить: лучше на въезде в город, у края дороги
        blip = { sprite = 60, color = 38 },
        props = {
            { model = 'prop_portacabin01', offset = vec3(-6.0, 0.0, 0.0), heading = 90.0 },
            { model = 'prop_sec_barrier_ld_01a', offset = vec3(0.0, 4.0, 0.0), heading = 90.0 },
            { model = 'prop_flag_russia', offset = vec3(-9.5, 3.0, 0.0), heading = 0.0 },
            { model = 'prop_roadcone02a', offset = vec3(2.0, 8.0, 0.0) },
            { model = 'prop_roadcone02a', offset = vec3(3.0, 11.0, 0.0) },
            { model = 'prop_roadcone02a', offset = vec3(4.0, 14.0, 0.0) },
            { model = 'prop_worklight_03b', offset = vec3(-3.0, 6.0, 0.0), heading = 30.0 },
        },
        peds = {
            -- s_m_y_ranger_01 в нашей сборке одет в форму ДПС (kv_peds)
            { model = 's_m_y_ranger_01', offset = vec3(-1.5, 6.5, 0.0), heading = 0.0, scenario = 'WORLD_HUMAN_COP_IDLES' },
            { model = 's_m_y_ranger_01', offset = vec3(-4.0, 1.5, 0.0), heading = 270.0, scenario = 'WORLD_HUMAN_CLIPBOARD' },
        },
        vehicles = {
            { model = 'kv_uaz_dps', fallback = 'sheriff2', offset = vec3(-5.5, 9.5, 0.0), heading = 20.0 },
        },
    },
}

---------------------------------------------------------------------------
-- 4. места Нагорья в зданиях GTA: мебель, люди, машины вокруг (появляются, когда игрок рядом)
-- тот же формат, что у постов ДПС. offset от точки места: x вправо, y вперёд по heading.
-- всё помечено «сверить»: координаты по карте, без проверки в игре. встань на место, /mypos, пришли — поправим.
---------------------------------------------------------------------------
Config.Scenes = {
    {
        id = 'avtovokzal',
        label = 'Автовокзал Нагорска',
        coords = vec4(462.2, -641.2, 28.5, 180.0), -- точка появления новичка (kavkaz_start)
        blip = false,                               -- метку и навигатор ставит kavkaz_map
        props = {
            { model = 'prop_bench_01a', offset = vec3(-6.0, 3.0, 0.0), heading = 180.0 },
            { model = 'prop_bench_01a', offset = vec3(-9.0, 3.0, 0.0), heading = 180.0 },
            { model = 'prop_flag_russia', offset = vec3(-12.0, -2.0, 0.0) },
        },
        peds = {
            { model = 'a_m_m_eastsa_02', offset = vec3(-6.5, 1.8, 0.0), heading = 0.0, scenario = 'WORLD_HUMAN_STAND_MOBILE' },
            { model = 'a_f_m_eastsa_01', offset = vec3(-8.6, 1.6, 0.0), heading = 10.0, scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
            { model = 'a_m_y_stbla_02', offset = vec3(-4.0, 5.5, 0.0), heading = 200.0, scenario = 'WORLD_HUMAN_SMOKING' },
        },
        vehicles = {
            -- стоянка такси у вокзала (Приоры в цвет такси)
            { model = 'kv_priora', fallback = 'asea', offset = vec3(9.0, 4.0, 0.0), heading = 90.0, color = 88, plate = 'T205AX95' },
            { model = 'kv_logan', fallback = 'asea', offset = vec3(9.0, 9.5, 0.0), heading = 90.0, color = 88, plate = 'T318KM95' },
        },
    },
    {
        id = 'chaikhana_terrace',
        label = 'Чайхана «У Румисы»: терраса',
        coords = vec4(-714.0, -914.0, 19.2, 90.0), -- рядом с Румисой (kavkaz_quests) и поваром (kavkaz_food)
        blip = false,
        props = {
            { model = 'prop_gazebo_02', offset = vec3(0.0, 0.0, 0.0), heading = 0.0 },
            { model = 'prop_table_03', offset = vec3(-1.2, 0.8, 0.0) },
            { model = 'prop_chair_01a', offset = vec3(-2.2, 0.8, 0.0), heading = 90.0 },
            { model = 'prop_chair_01a', offset = vec3(-0.2, 0.8, 0.0), heading = 270.0 },
            { model = 'prop_table_03', offset = vec3(1.4, -1.0, 0.0) },
            { model = 'prop_chair_01a', offset = vec3(0.4, -1.0, 0.0), heading = 90.0 },
            { model = 'prop_chair_01a', offset = vec3(2.4, -1.0, 0.0), heading = 270.0 },
        },
        peds = {
            { model = 'a_m_m_eastsa_01', offset = vec3(-1.2, 2.2, 0.0), heading = 180.0, scenario = 'WORLD_HUMAN_HANG_OUT_STREET' },
            { model = 'a_m_o_genstreet_01', offset = vec3(1.4, 0.6, 0.0), heading = 180.0, scenario = 'WORLD_HUMAN_DRINKING' },
        },
    },
    {
        id = 'bazar',
        label = 'Восточный базар',
        coords = vec4(-702.0, -900.0, 19.2, 0.0), -- метка базара уже есть в kavkaz_map; продавцы еды — kavkaz_food
        blip = false,
        props = {
            { model = 'prop_fruit_stand_01', offset = vec3(-4.5, 0.0, 0.0), heading = 0.0 },
            { model = 'prop_fruit_stand_02', offset = vec3(-1.5, 0.0, 0.0), heading = 0.0 },
            { model = 'prop_fruit_stand_03', offset = vec3(1.5, 0.0, 0.0), heading = 0.0 },
            { model = 'prop_fruit_stand_01', offset = vec3(4.5, 0.0, 0.0), heading = 0.0 },
        },
        peds = {
            { model = 'a_f_m_soucent_02', offset = vec3(-4.5, 1.3, 0.0), heading = 180.0, scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
            { model = 'a_m_m_soucent_01', offset = vec3(1.5, 1.3, 0.0), heading = 180.0, scenario = 'WORLD_HUMAN_STAND_MOBILE' },
            { model = 'a_f_o_soucent_01', offset = vec3(0.0, -2.5, 0.0), heading = 0.0, scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
        },
    },
    {
        id = 'mreo',
        label = 'МРЭО ГИБДД у Правительства',
        coords = vec4(-541.0, -212.0, 37.6, 210.0), -- окно МРЭО — kavkaz_plates
        blip = false,
        props = {
            { model = 'prop_flag_russia', offset = vec3(-4.0, -3.0, 0.0) },
            { model = 'prop_roadcone02a', offset = vec3(5.0, -6.0, 0.0) },
            { model = 'prop_roadcone02a', offset = vec3(6.5, -6.0, 0.0) },
        },
        peds = {
            -- очередь за номерами
            { model = 'a_m_y_business_02', offset = vec3(1.0, -1.5, 0.0), heading = 30.0, scenario = 'WORLD_HUMAN_STAND_MOBILE' },
            { model = 'a_m_m_eastsa_02', offset = vec3(1.4, -3.0, 0.0), heading = 30.0, scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
            { model = 's_m_y_ranger_01', offset = vec3(-2.0, -4.5, 0.0), heading = 120.0, scenario = 'WORLD_HUMAN_CLIPBOARD' },
        },
        vehicles = {
            { model = 'kv_uaz_dps', fallback = 'sheriff2', offset = vec3(6.0, -9.0, 0.0), heading = 120.0, plate = 'A177795' },
        },
    },
}
