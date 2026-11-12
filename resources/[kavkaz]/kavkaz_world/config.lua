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
    -- пустыня: на Кавказе нет деревьев Джошуа, кактусов и перекати-поля (список — из карты игры, setup/maps)
    'prop_joshua_tree_01a', 'prop_joshua_tree_01b', 'prop_joshua_tree_01c', 'prop_joshua_tree_01d', 'prop_joshua_tree_01e',
    'prop_joshua_tree_02a', 'prop_joshua_tree_02b', 'prop_joshua_tree_02c', 'prop_joshua_tree_02d', 'prop_joshua_tree_02e',
    'prop_cactus_01a', 'prop_cactus_01b', 'prop_cactus_01c', 'prop_cactus_01d', 'prop_cactus_01e', 'prop_cactus_02', 'prop_cactus_03',
    'prop_creosote_b_01', 'prop_skunk_bush_01', 'prop_desert_iron_01', 'prop_grass_dry_02', 'prop_grass_dry_03',
    'prop_weeddry_nxg01', 'prop_weeddry_nxg01b', 'prop_weeddry_nxg02', 'prop_weeddry_nxg02b', 'prop_weeddry_nxg03',
    'prop_weeddry_nxg03b', 'prop_weeddry_nxg04', 'prop_weeddry_nxg05', 'prop_tumbleweed_01',
    -- американские мелочи на улицах: синие почтовые ящики, газетные автоматы, таксофоны
    'prop_postbox_01a',
    'prop_news_disp_01a', 'prop_news_disp_02a', 'prop_news_disp_02b', 'prop_news_disp_02c', 'prop_news_disp_02d',
    'prop_news_disp_02e', 'prop_news_disp_03a', 'prop_news_disp_03c', 'prop_news_disp_05a', 'prop_news_disp_06a',
    'prop_phonebox_01a', 'prop_phonebox_01b', 'prop_phonebox_01c', 'prop_phonebox_02', 'prop_phonebox_03', 'prop_phonebox_04',
    -- по скану карты 12.11 (setup/maps/scan_entities_blender.py): ещё ~2700 штук — почтовые ящики у частных домов,
    -- американские пожарные гидранты, газетный автомат-малыш, таксофон, флаг полиции Сан-Андреаса
    'prop_postbox_ss_01a', 'prop_news_disp_02a_s', 'prop_phonebox_05a',
    'prop_letterbox_01', 'prop_letterbox_02', 'prop_letterbox_03',
    'prop_fire_hydrant_1', 'prop_fire_hydrant_2', 'prop_fire_hydrant_4',
    'prop_flag_sapd',
    -- 12.11: колесо обозрения и вагончики американских горок на пирсе — второй по узнаваемости ориентир GTA
    'prop_ld_ferris_wheel', 'prop_ferris_car_01', 'prop_roller_car_01', 'prop_roller_car_02',
    -- 12.11: надпись VINEWOOD на холме — самое узнаваемое в GTA: буквы, каркас, лестницы, подсветка, дальние версии
    'ch2_03_sign', 'ch2_03_sign_lod', 'ch2_03_sign_slod', 'ch2_03_signdcal', 'ch2_03_emis_sign_hd', 'ch2_03_emis_sign_lod',
    'ch2_03_emis_sign_slod', 'ch2_03_vsignlite', 'prop_vinewood_sign_01', 'ch2_03_signstructure', 'ch2_03_signstructure_lod', 'ch2_03_ladder_mesh_00',
    'ch2_03_ladder_mesh_01', 'ch2_03_ladder_mesh_02', 'ch2_03_ladder_mesh_03', 'ch2_03_ladder_mesh_04', 'ch2_03_ladder_mesh_05', 'ch2_03_ladder_mesh_06',
    'ch2_03_ladder_mesh_07', 'ch2_03_ladder_mesh_08', 'ch2_03_ladder_mesh_09', 'ch2_03_ladder_mesh_10', 'ch2_03_ladder_mesh_11', 'ch2_03_ladder_mesh_12',
    'ch2_03_ladder_mesh_13', 'ch2_03_ladder_mesh_14', 'ch2_03_signedge01', 'ch2_03_signedge02', 'ch2_03_signedge03', 'ch2_03_signedge04',
    'ch2_03_signedge05', 'ch2_03_signedge06', 'ch2_03_signedge07', 'ch2_03_signedge08', 'ch2_03_signjoins01', 'ch2_03_signjoins02',
    'ch2_03_signjoins03', 'ch2_03_signjoins04', 'ch2_03_signjoins05', 'ch2_03_signjoins06', 'ch2_03_signjoins07', 'ch2_03_signjoins08',
    'ch2_03_signframinga', 'ch2_03_signframingb', 'ch2_03_signframingc', 'ch2_03_signframingd', 'ch2_03_signframinge', 'ch2_03_signframingf',
    'ch2_03_signframingg', 'ch2_03_signstructure_b', 'ch2_03_signstructure_b2', 'ch2_03_signstructure_b3', 'ch2_03_signstructure_b4', 'ch2_03_signstructure_b5',
    'ch2_03_signstructure_b6', 'ch2_03_signstructure_b7', 'ch2_03_signstructure_b8',
}

---------------------------------------------------------------------------
-- 3. посты ДПС: будка, шлагбаум, конусы, флаг России, инспекторы, машина
-- offset — от точки поста (x вправо, y вперёд по направлению heading), heading — поворот относительно поста
---------------------------------------------------------------------------
-- 12.11: пост стоял прямо на улице у участка шерифа (инспекторы и УАЗ на проезжей части, трафик в них врезался).
-- теперь — на обочине трассы на въездах в Песчаный. место найдено по американским знакам скорости из скана карты
-- (setup/maps/scan_entities_blender.py): знак стоит у края дороги, пост — в 10 м за ним, лицом к дороге.
-- всё стоит до края асфальта: конусы — на обочине, машина и инспекторы — не на полосе.
local function post(id, label, coords)
    return {
        id = id, label = label, coords = coords, auto = true,
        blip = { sprite = 60, color = 38 },
        props = {
            { model = 'prop_portacabin01', offset = vec3(-6.0, -1.0, 0.0), heading = 90.0 },
            { model = 'prop_flag_russia', offset = vec3(-9.5, 2.0, 0.0), heading = 0.0 },
            { model = 'prop_sec_barrier_ld_01a', offset = vec3(1.5, 4.0, 0.0), heading = 90.0 },
            { model = 'prop_roadcone02a', offset = vec3(3.0, 7.0, 0.0) },
            { model = 'prop_roadcone02a', offset = vec3(5.0, 7.5, 0.0) },
            { model = 'prop_roadcone02a', offset = vec3(7.0, 8.0, 0.0) },
            { model = 'prop_worklight_03b', offset = vec3(-2.5, 3.0, 0.0), heading = 20.0 },
        },
        peds = {
            -- s_m_y_ranger_01 в нашей сборке одет в форму ДПС (kv_peds)
            { model = 's_m_y_ranger_01', offset = vec3(0.5, 7.0, 0.0), heading = 0.0, scenario = 'WORLD_HUMAN_COP_IDLES' },
            { model = 's_m_y_ranger_01', offset = vec3(-4.0, 0.8, 0.0), heading = 270.0, scenario = 'WORLD_HUMAN_CLIPBOARD' },
        },
        vehicles = {
            { model = 'kv_uaz_dps', fallback = 'sheriff2', offset = vec3(-5.0, 6.0, 0.0), heading = 70.0 },
        },
    }
end

-- 12.11 (вечер): посты сами встают по дороге — near — примерная точка у трассы (знак скорости из скана карты),
-- игра находит ближайшую полосу, край асфальта и ставит пост в 8 м за обочиной лицом к дороге. ничего на асфальт не ставится
-- (каждый предмет проверяется: если на дороге — отодвигается), машины рядом сбавляют скорость, как перед настоящим постом.
-- вместо модов kv_map_kpp / kv_map_border (их шлагбаумы стояли поперёк трасс и в туннеле — трафик врезался)
Config.Posts = {
    post('vostok',   'Пост ДПС «Восточный въезд»',  vec4(2341.0, -391.0, 68.0, 0.0)),   -- фривей у Таватиам, въезд в Нагорск
    post('zapad',    'Пост ДПС «Западный»',         vec4(-3003.0, 290.0, 14.0, 0.0)),   -- побережье у Пасифик-Блафс
    post('zancudo',  'Пост ДПС «Мост»',             vec4(-1608.0, 2826.0, 17.0, 0.0)),  -- шоссе у моста Занкудо
    post('harmony',  'Пост ДПС «Гармония»',         vec4(718.0, 2710.0, 39.0, 0.0)),    -- шоссе 68
    post('senora',   'Пост ДПС «Сенора»',           vec4(2517.0, 3027.0, 41.0, 0.0)),   -- фривей через пустыню
    post('peschany', 'Пост ДПС «Песчаный»',         vec4(1509.1, 3481.6, 35.2, 0.0)),   -- въезд в Песчаный с запада
    post('peschany_east', 'Пост ДПС «Песчаный-Восток»', vec4(2134.9, 3770.8, 32.0, 0.0)),
    post('grapeseed', 'Пост ДПС «Грейпсид»',        vec4(1662.0, 4941.0, 41.0, 0.0)),
    post('paleto',   'Пост ДПС «Палето»',           vec4(-543.0, 6161.0, 6.0, 0.0)),    -- въезд в Палето
}

---------------------------------------------------------------------------
-- 4. места Нагорья в зданиях GTA: мебель, люди, машины вокруг (появляются, когда игрок рядом)
-- тот же формат, что у постов ДПС. offset от точки места: x вправо, y вперёд по heading.
-- всё помечено «сверить»: координаты по карте, без проверки в игре. встань на место, /mypos, пришли — поправим.
---------------------------------------------------------------------------
Config.Scenes = {
    -- 12.11: места на горах — чтобы знакомые по GTA вершины стали своими. snap — высота с земли на месте
    {
        id = 'chiliad_top', label = 'Вершина Шат-горы', snap = true,
        coords = vec4(501.7, 5604.5, 797.9, 160.0),
        blip = { sprite = 141, color = 25 },
        props = {
            { model = 'prop_flag_russia', offset = vec3(0.0, 4.0, 0.0) },
            { model = 'prop_skid_tent_01', offset = vec3(-7.0, -2.0, 0.0), heading = 70.0 },
            { model = 'prop_skid_tent_01', offset = vec3(-9.0, 4.0, 0.0), heading = 110.0 },
            { model = 'prop_beach_fire', offset = vec3(-4.0, 1.0, 0.0) },
            { model = 'prop_bench_05', offset = vec3(-2.5, 1.0, 0.0), heading = 90.0 },
            { model = 'prop_bench_05', offset = vec3(-5.5, 1.0, 0.0), heading = 270.0 },
            { model = 'prop_telescope_01', offset = vec3(3.5, 2.0, 0.0), heading = 0.0 },
        },
        peds = {
            { model = 'a_m_y_hiker_01', offset = vec3(-3.0, 2.5, 0.0), heading = 200.0, scenario = 'WORLD_HUMAN_HIKER_STANDING' },
            { model = 'a_f_y_hiker_01', offset = vec3(3.0, 3.5, 0.0), heading = 10.0, scenario = 'WORLD_HUMAN_BINOCULARS' },
            { model = 'a_m_m_farmer_01', offset = vec3(-5.0, -0.5, 0.0), heading = 40.0, scenario = 'WORLD_HUMAN_STAND_FIRE' },
        },
    },
    {
        id = 'galileo_shashlik', label = 'Шашлычная «Смотровая»', snap = true,
        coords = vec4(-426.0, 1110.0, 327.0, 340.0), -- лужайка у обсерватории над городом
        blip = { sprite = 93, color = 47 },
        props = {
            { model = 'prop_gazebo_02', offset = vec3(0.0, 0.0, 0.0) },
            { model = 'prop_bbq_1', offset = vec3(4.0, -1.0, 0.0), heading = 90.0 },
            { model = 'prop_table_03', offset = vec3(-1.2, 0.8, 0.0) },
            { model = 'prop_chair_01a', offset = vec3(-2.2, 0.8, 0.0), heading = 90.0 },
            { model = 'prop_chair_01a', offset = vec3(-0.2, 0.8, 0.0), heading = 270.0 },
            { model = 'prop_table_03', offset = vec3(1.4, -1.6, 0.0) },
            { model = 'prop_chair_01a', offset = vec3(0.4, -1.6, 0.0), heading = 90.0 },
            { model = 'prop_chair_01a', offset = vec3(2.4, -1.6, 0.0), heading = 270.0 },
            { model = 'prop_flag_russia', offset = vec3(-5.0, 3.0, 0.0) },
        },
        peds = {
            { model = 'a_m_m_eastsa_01', offset = vec3(4.0, 0.2, 0.0), heading = 270.0, scenario = 'PROP_HUMAN_BBQ' },
            { model = 'a_m_o_genstreet_01', offset = vec3(-1.2, 2.0, 0.0), heading = 180.0, scenario = 'WORLD_HUMAN_DRINKING' },
            { model = 'a_f_m_eastsa_01', offset = vec3(1.4, -0.4, 0.0), heading = 180.0, scenario = 'WORLD_HUMAN_TOURIST_MOBILE' },
        },
    },
    {
        id = 'konyak', label = 'Коньячный завод', snap = true,
        coords = vec4(-1888.0, 2050.0, 140.8, 160.0), -- бывшая винодельня на холмах
        blip = { sprite = 93, color = 21 },
        props = {
            { model = 'prop_wooden_barrel', offset = vec3(-3.0, 2.0, 0.0) },
            { model = 'prop_wooden_barrel', offset = vec3(-2.0, 2.0, 0.0) },
            { model = 'prop_wooden_barrel', offset = vec3(-2.5, 3.0, 0.0) },
            { model = 'prop_flag_russia', offset = vec3(5.0, 3.0, 0.0) },
        },
        peds = {
            { model = 'a_m_m_farmer_01', offset = vec3(-1.0, 1.0, 0.0), heading = 180.0, scenario = 'WORLD_HUMAN_CLIPBOARD' },
        },
    },
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

---------------------------------------------------------------------------
-- 5. рейсы на остров «Арзамас» (карта kv_map_cr — Арзамас, Батырево, Сопки, Лыткарино, Корякино, Роговичи, Рязань).
-- остров в море к юго-востоку, моста нет: E у точки — затемнение, перелёт, на месте ждём, пока остров подгрузится.
-- to — куда прилетаем (высота берётся с земли); точки помечены «сверить» — поправим по /mypos
---------------------------------------------------------------------------
Config.Transfers = {
    {
        id = 'to_arzamas', label = 'Рейс «Нагорск — Арзамас»',
        at = vec3(-1037.0, -2737.0, 20.17),   -- аэропорт Нагорска, зал прилёта
        to = vec4(6157.0, -5580.0, 60.0, 0.0), -- Арзамас, центр (сверить)
        blip = { sprite = 307, color = 3 },
        text = 'Летим в Арзамас…',
    },
    {
        id = 'to_nagorsk', label = 'Рейс «Арзамас — Нагорск»',
        at = vec3(6157.0, -5580.0, 0.0),       -- там же, где прилетаем (высота с земли)
        to = vec4(-1037.0, -2737.0, 20.17, 330.0),
        text = 'Летим в Нагорск…',
    },
}
