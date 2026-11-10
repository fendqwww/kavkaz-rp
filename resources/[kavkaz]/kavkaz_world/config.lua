-- KAVKAZ RP: облик Нагорья поверх карты GTA — русские знаки и щиты, посты ДПС, убираем американское.
-- координаты помеченные «сверить» — встань на место в игре, набери /mypos и поменяй строку.

Config = {}

---------------------------------------------------------------------------
-- 1. подмена текстур GTA своими картинками (images/*.png рисует setup/signs/make_signs.py)
-- txd — словарь текстур GTA, txn — имя текстуры в нём, image — наша картинка без .png.
-- имена txd/txn берутся из файлов игры: CodeWalker (RPF Explorer → поиск по «sign»/«billboard»)
-- или setup/cars/ytdinfo.py на вытащенном .ytd. пока список пустой — в игре ничего не меняется.
-- пример строки: { txd = 'prop_sign_road_01a', txn = 'prop_sign_road_01a_d', image = 'city_nagorsk' },
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
