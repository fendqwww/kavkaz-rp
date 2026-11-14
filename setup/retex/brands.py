"""KAVKAZ RP: узнаваемые вывески GTA (Burger Shot, Cluckin' Bell, Bean Machine, Fleeca, LSPD, 24/7 …) → наши.
python setup/retex/brands.py <папка с оригиналами .dds> [ещё папки …]
оригиналы выгружены из игры скриптом Blender + Sollumz (в git их нет); здесь берётся только их размер и где на них
непрозрачное (туда кладём нашу вывеску), чтобы раскладка текстуры не поехала. картинки — images/retex/brand_*.png,
список подмен — kavkaz_world/brands_list.lua (Config.BrandImages, Config.Brands: txd, txn, image).
"""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

root = pathlib.Path(__file__).resolve().parents[2]
world = root / 'resources' / '[kavkaz]' / 'kavkaz_world'
img = world / 'images'
out = img / 'retex'
FD = pathlib.Path(__file__).resolve().parent / 'fonts'
BYNAME = None  # --byname <папка>: ещё и <имя_текстуры>.png для retex_job.py
if '--byname' in sys.argv:
    i = sys.argv.index('--byname')
    BYNAME = pathlib.Path(sys.argv[i + 1])
    BYNAME.mkdir(parents=True, exist_ok=True)
    del sys.argv[i:i + 2]
SRCS = [pathlib.Path(a) for a in sys.argv[1:]]

# словарь (без +hi / +hidr — обе версии заменяем), текстура, что ставим, как
# 12.11: стиль — минимализм (ориентир Majestic RP), без этники: ровная плашка, крупное слово, строка помельче
MIN = {
    'burger': ((214, 64, 36), 'БУРГЕР ГРИЛЬ', 'сочно · быстро · рядом'),
    'chicken': ((242, 178, 26), 'КУРОЧКА ГРИЛЬ', 'крылья · стрипсы · комбо'),
    'coffee': ((74, 50, 36), 'КОФЕЙНЯ', 'кофе с собой'),
    'bank': ((24, 120, 84), 'НАРОДНЫЙ БАНК', 'вклады · кредиты · переводы'),
    'shop': ((30, 30, 32), 'ПРОДУКТЫ 24', 'круглосуточно'),
    # 12.11, второй проход (клубы, бары, места, щиты)
    'jewel': ((58, 58, 62), 'ЮВЕЛИРНЫЙ', 'закрыто на ремонт'),
    'club': ((22, 22, 26), 'РЕСТОРАН', 'кухня · банкеты'),  # 13.11: основатель — никаких клубов
    'fish': ((28, 72, 104), 'РЫБНЫЙ ДОМ', 'кафе · уха · гриль'),
    'hospital': ((240, 242, 245), 'ГОРОДСКАЯ БОЛЬНИЦА', 'скорая помощь — 103'),
    'beer': ((176, 110, 24), 'ХОЛОДНОЕ ПИВО', 'разливное'),
    'soda': ((30, 140, 70), 'ЛИМОНАД', 'вкус детства'),
    'kvas': ((120, 62, 26), 'КВАС', 'живой · холодный'),
    'shawarma': ((200, 40, 30), 'ШАУРМА', 'круглосуточно'),
    'guns': ((34, 34, 36), 'ОРУЖИЕ', 'охота · рыбалка'),
    'shop2': ((24, 84, 160), 'ПРОДУКТЫ', 'у дома'),
    'welcome': ((32, 96, 64), 'ДОБРО ПОЖАЛОВАТЬ', 'счастливого пути'),
    'view': ((92, 62, 36), 'СМОТРОВАЯ ПЛОЩАДКА', 'вид на озеро'),
    'farm': ((150, 40, 30), 'ПТИЦЕФАБРИКА', 'с 1972 года'),
    'fire': ((190, 30, 28), 'ПОЖАРНАЯ ОХРАНА', 'телефон 101'),
    'ad_build': ((236, 236, 238), 'НОВОСТРОЙКИ', 'ипотека от 6%'),
    'ad_mobile': ((110, 40, 160), 'МОБИЛЬНАЯ СВЯЗЬ', 'безлимит за 300 ₽'),
    'ad_auto': ((20, 20, 22), 'АВТОСАЛОН', 'новые и с пробегом'),
    # 13.11, третий проход: уличные рекламные щиты (Outsource, Pisswasser, Sludgie, Cranley и др.)
    'ad_cinema': ((26, 26, 30), 'КИНО', 'премьеры каждую неделю'),
    'ad_theatre': ((112, 24, 32), 'ТЕАТР', 'премьера сезона'),
    'ad_tv': ((36, 36, 40), 'ГОРОД ТВ', 'новости каждый час'),
    'ad_pawn': ((44, 40, 34), 'ЛОМБАРД', 'золото · техника · часы'),
    'ad_realty': ((48, 64, 84), 'КВАРТИРЫ', 'аренда и продажа'),
    'ad_sport': ((214, 64, 40), 'ФИТНЕС-КЛУБ', 'первая неделя бесплатно'),
    'ad_travel': ((24, 118, 178), 'ТУРЫ НА МОРЕ', 'горящие путёвки'),
    'ad_icecream': ((236, 128, 166), 'МОРОЖЕНОЕ', 'пломбир · эскимо · рожки'),
    'ad_furniture': ((196, 160, 112), 'МЕБЕЛЬ', 'кухни на заказ'),
    'ad_job': ((34, 110, 200), 'ЕСТЬ РАБОТА', 'водители · курьеры · грузчики'),
    'ad_lawyer': ((40, 52, 70), 'ЮРИСТ', 'консультация бесплатно'),
    'ad_electro': ((88, 44, 150), 'ЭЛЕКТРОНИКА', 'смартфоны в рассрочку'),
    'ad_bakery': ((232, 150, 60), 'ПЕКАРНЯ', 'горячая выпечка'),
    'ad_sweets': ((92, 50, 30), 'КОНДИТЕРСКАЯ', 'торты на заказ'),
    'ad_water': ((40, 140, 200), 'ПИТЬЕВАЯ ВОДА', 'доставка 19 л'),
    'ad_internet': ((236, 236, 238), 'ДОМАШНИЙ ИНТЕРНЕТ', 'от 450 ₽ в месяц'),
    'ad_dent': ((244, 246, 248), 'СТОМАТОЛОГИЯ', 'лечим без боли'),
    'ad_police': ((24, 52, 110), 'СЛУЖБА В ПОЛИЦИИ', 'набор по контракту'),
}
NEON = {'ТАТУ': (255, 70, 50), 'ПИВО': (255, 176, 40), 'РЫБНЫЙ ДОМ': (60, 170, 255)}
B = [
    ('dt1_16_build', 'burgershot_meatshavings_billboard_final_short', 'min:burger', 'full'),
    ('kt1_15_shop_06', 'kt1_15_cluckinbellsign_01_d', 'min:chicken', 'bbox'),
    ('dt1_15_steetdetailb', 'dt1_15_rsn_cmk_beanmachinedt1_15_rsn_cmk_beanmachine_a', 'min:coffee', 'bbox'),
    ('kt1_07', 'kt1_07_beanmachine_01_d', 'coffee_round', 'full'),
    ('cs2_01_shop_dec3', 'cs2_01_rsl_vc_bank_fleecasign02cs2_01_rsl_vc_bank_fleecasign02_a', 'min:bank', 'bbox'),
    ('v_20_policehtxd', 'xj_v_lspd_logoxj_v_lspd_logo_a', 'retex/emb_mvd', 'bbox_keep'),
    ('v_ret_247_win1', 'gz_v_247_winglass01gz_v_247_winglass01_a', 'min:shop', 'bbox'),
    ('v_ret_247_win2', 'gz_v_247_winglass02gz_v_247_winglass02_a', 'min:shop', 'bbox'),
    # 12.11, второй проход: только цельные вывески; атласы с кучей мелких табличек (Ammu-Nation, Xero, LTD-заправки,
    # Tequi-la-la, буквы LOS SANTOS) не трогаем — у них раскладка по кускам, подмена поехала бы
    ('bh1_16_bld02', 'vangelico_boarded_upvangelico_boarded_up_a', 'min:jewel', 'full'),
    ('bh1_16_post_heist_boards', 'vangelico_boarded_upvangelico_boarded_up_a', 'min:jewel', 'full'),
    ('sc1_04_bld_03', 'sc1_04_rsn_am_van_unicorn_sign', 'min:club', 'full'),
    ('sc1_04_bld_03', 'vanillaunicorn_billboard_2x1', 'min:ad_auto', 'full'),
    ('cs3_08_hookies', 'cs3_08_ih_hookieslogofish_d', 'min:fish', 'full'),
    ('cs3_08_hookies', 'cs3_08_ih_hookiesneon', 'neon:РЫБНЫЙ ДОМ', 'full'),
    ('sc1_15_ground1', 'mountzonah_hospital_billboard_2x1', 'min:hospital', 'full'),
    ('id1_13_structure1', 'pisswasser_vertical_billboard_1024', 'min:beer', 'full'),
    ('ss1_13_billboard_start', 'im_ss_13_sprunksign', 'min:soda', 'full'),
    ('vb_09_build01', 'ecola_wall_adecola_wall_ad_a', 'min:kvas', 'bbox'),
    ('cs4_03_billboards', 'bw_alamosea_billboard01', 'two:ad_build,ad_mobile', 'full'),
    ('kt1_07_wiltern_01', 'kt1_07_tacobranding_01_d', 'min:shawarma', 'full'),
    ('prop_ammu_sign01', 'prop_ammu_sign_01', 'min:guns', 'full'),
    ('kt1_11_lod', 'sc1_ltd_decalsc1_ltd_decal_a', 'min:shop2', 'bbox'),
    ('sc1_21_lod', 'sc1_ltd_decalsc1_ltd_decal_a', 'min:shop2', 'bbox'),
    ('cs2_roadsa_paleto_welcome', 'rsl_bw_paletowelcomersl_bw_paletowelcome_a', 'min:welcome', 'bbox'),
    ('cs1_roadsa', 'cs1_rda_chumash_01', 'min:welcome', 'full'),
    ('ch1_01_chumash_sign', 'ch1_01_chumash_sign_d', 'min:welcome', 'full'),
    ('cs3_03_overlookasign', 'cs3_03_eastalamoview', 'min:view', 'full'),
    ('cs1_05_indust_18', 'rsl_bw_clucking_ghostrsl_bw_clucking_ghost_a', 'min:farm', 'bbox'),
    ('v_41_overlays', 'xj_v_blaine_logoxj_v_blaine_logo_a', 'min:bank', 'bbox'),
    ('prop_loggneon', 'km_v_loggerneonkm_v_loggerneon_a', 'neon:ПИВО', 'full'),
    ('prop_patriotneon', 'km_v_patriotneonkm_v_patriotneon_a', 'neon:ПИВО', 'full'),
    ('prop_flags', 'prop_flag_lossantos', 'flag:ru', 'full'),
    ('prop_flags', 'prop_flag_lossantosservices', 'flag:ru', 'full'),
    ('prop_flags', 'prop_flag_sanandreas', 'flag:ru', 'full'),
    ('prop_flags', 'prop_flag_lsfd', 'min:fire', 'full'),
] + [(t, 'gz_v_ta_tattoowingz_v_ta_tattoowin_a', 'neon:ТАТУ', 'full')
     for t in ('ch1_11_ilod', 'hw1_02_bld3x', 'hw1_02_ilod', 'id1_25_lod', 'v_36_tattootxd', 'vb_28_lod')]

# 13.11, третий проход: уличные щиты. одна реклама на всю текстуру — 'bbox' (у непрозрачных = вся текстура);
# две рекламы верх/низ (проверено: делятся ровно пополам) — 'two:верх,низ'
B += [
    ('dt1_20_ground2', 'accountant_tvshow_billboard_3x1_ingame', 'min:ad_tv', 'bbox'),
    ('hei_dt1_20_ground2', 'accountant_tvshow_billboard_3x1_ingame', 'min:ad_tv', 'bbox'),
    ('cs4_09_bilbrd_01', 'bills_foreclosure_billboard_1024', 'min:ad_realty', 'bbox'),
    ('id1_25_billboard01', 'bills_foreclosure_billboard_2x1', 'min:ad_realty', 'bbox'),
    ('id1_07_lod', 'burgershot_meatshavings_billboard_graffiti_512x256', 'min:burger', 'bbox'),
    ('cs2_01_bb_global_hd', 'cs2_01_rsl_bw_billboard_a', 'min:ad_water', 'bbox'),
    ('kt1_01_04', 'divorce_wall_poster_richardsmajesticposter_alpha_testv2', 'min:ad_theatre', 'bbox'),
    ('kt1_01_04', 'nelsonnaples_wall_poster_richardsmajesticposter_alpha_test', 'min:ad_cinema', 'bbox'),
    ('kt1_01_04', 'orion_wall_poster_richardsmajesticposter_alpha_test', 'min:ad_theatre', 'bbox'),
    ('dt1_14_build3', 'dt1_14_cmk_billboard02', 'min:ad_internet', 'bbox'),
    ('dt1_17_bb_credit', 'dt1_17_cmk_billboard01', 'min:ad_sport', 'bbox'),
    ('dt1_17_build1', 'dt1_17_cmk_billboard01', 'min:ad_sport', 'bbox'),
    ('dt1_18_build', 'egochaser_energy_billboard_short', 'min:ad_travel', 'bbox'),
    ('id1_30_build05', 'fridgit2by1_decalfridgit2by1_billboard_a', 'min:ad_water', 'bbox'),
    ('dt1_09_carpark', 'im_billboard_piswasser_01', 'min:beer', 'bbox'),
    ('hw1_02_bld6', 'imarriedmydad_movie_billboard_2x1', 'min:ad_cinema', 'bbox'),
    ('id1_32_build666a', 'krapea_store_billboard_2x1', 'min:ad_furniture', 'bbox'),
    ('kt1_04_landa', 'kt1_04_ragebillboard_01_d', 'min:ad_cinema', 'bbox'),
    ('sc1_18_build1', 'lavacaloca_fastfood_billboard_2x1', 'min:burger', 'bbox'),
    ('dt1_09_billboards', 'lenny_avery_billboard_long_ingame', 'min:ad_realty', 'bbox'),
    ('dt1_15_build3', 'no_joker_pawnbroker_creditcrunchwebsite_billboard_1024', 'min:ad_pawn', 'bbox'),
    ('sc1_02_sprayshop2', 'piswasser_billboard_night_2x1', 'min:beer', 'bbox'),
    ('ch3_03_col', 'ql_coil_billboard_24x1', 'min:ad_auto', 'bbox'),
    ('ch3_03_righteousslaughter', 'ql_righteousslaughter_billboard_24x1', 'min:ad_cinema', 'bbox'),
    ('sc1_13_stripsgn', 'sc1_13_rsd_hj_bboard_0001', 'min:ad_sweets', 'bbox'),
    ('sc1_14_build2', 'sc1_14_rsn_ns_billboard_0001', 'min:ad_job', 'bbox'),
    ('sc1_24_build1', 'sc1_24_rsn_ns_bboard_0001', 'min:bank', 'bbox'),
    ('sc1_25_shops_02', 'sc1_25_rsd_jp_billboard_0001', 'min:ad_cinema', 'bbox'),
    ('id1_30_build03', 'sludgie24by1_billboard_colourful', 'min:ad_icecream', 'bbox'),
    ('hw1_23_build1', 'hw_23_rsd_hj_billboard_001', 'min:ad_furniture', 'bbox'),
    ('hw1_14_building', 'hw1_14_rsn_billboard_0001', 'two:ad_tv,ad_sport', 'full'),  # Outsource / Vinewood Sports
    ('hw1_18_ground01', 'sludgie3by1_billboard_col_bb', 'two:ad_icecream,ad_auto', 'full'),
    ('id1_26_building_sign', 'id1_26_cmk_bboard01', 'two:bank,kvas', 'full'),
    ('id1_26_ground', 'id1_26_cmk_bboard01', 'two:bank,kvas', 'full'),
    ('po1_05_billboard_01', 'po1_05_billboards_01', 'two:ad_cinema,ad_auto', 'full'),
    ('po1_09_ground', 'coil_billboard_dirty', 'two:ad_auto,beer', 'full'),
    ('sc1_01_bb_meltdown', 'sc1_03_rsn_ns_bboard_0001', 'two:ad_cinema,ad_bakery', 'full'),
    ('sc1_01_build1', 'sc1_03_rsn_ns_bboard_0001', 'two:ad_cinema,ad_bakery', 'full'),
    ('sc1_04_bld_01', 'sc1_04_rsn_ns_bboard_0001', 'two:ad_pawn,bank', 'full'),
    ('sc1_04_bld_02', 'sc1_04_rsn_ns_bboard_0002', 'two:ad_icecream,ad_cinema', 'full'),
    ('sc1_06_build01', 'sc1_06_rsd_hj_bboard_0001', 'two:ad_furniture,ad_dent', 'full'),
    ('sc1_11_mall2', 'sc1_11_rsn_billboard1', 'two:ad_cinema,ad_electro', 'full'),
    ('sc1_12_bb', 'sc1_12_rsd_hj_bboard_0001', 'two:beer,ad_bakery', 'full'),
    ('sc1_20_building', 'sc1_20_bboard_0002', 'two:ad_lawyer,burger', 'full'),
    ('sc1_31_shops01', 'sc1_20_rsn_ns_bboard_0001', 'two:ad_cinema,ad_auto', 'full'),
    ('sc1_20_ground', 'sc1_20_rsn_ns_bboard_0002', 'two:ad_internet,ad_mobile', 'full'),
    ('sc1_28_shops', 'sc1_28_rsn_ns_bboards_0002', 'two:ad_water,ad_tv', 'full'),
    ('sc1_28_shops2', 'sc1_28_rsn_ns_bboards_0003', 'two:ad_dent,beer', 'full'),
    ('po1_03', 'gg_po1_03_billboard1', 'two:ad_police,ad_electro', 'full'),
]


def minimal(kind, w, h):
    bg, title, sub = MIN[kind]
    K = 2
    im = Image.new('RGBA', (w * K, h * K), bg + (255,))
    d = ImageDraw.Draw(im)
    light = 0.299 * bg[0] + 0.587 * bg[1] + 0.114 * bg[2] > 160  # по яркости: на светлом (и жёлтом) — тёмный текст
    fg = (30, 30, 32, 255) if light else (250, 250, 250, 255)
    # высокая узкая вывеска — слова столбиком
    lines = title.split(' ') if h > w * 1.2 else [title]
    size = int(h * K * (0.42 if len(lines) == 1 else 0.6 / len(lines)))
    while size > 8:
        title_f = ImageFont.truetype(str(FD / 'Rubik-Black.ttf'), size)
        if max(d.textlength(t, font=title_f) for t in lines) <= w * K * 0.86:
            break
        size -= 2
    sub_f = ImageFont.truetype(str(FD / 'Oswald-SemiBold.ttf'), max(8, int(size * 0.34)))
    step = size * 1.05
    y0 = h * K * 0.44 - step * (len(lines) - 1) / 2
    for i, t in enumerate(lines):
        d.text((w * K / 2, y0 + i * step), t, font=title_f, fill=fg, anchor='mm')
    d.text((w * K / 2, y0 + (len(lines) - 1) * step + size * 0.62), sub.upper(), font=sub_f, fill=fg[:3] + (200,), anchor='mt')
    return im.resize((w, h), Image.LANCZOS)


def neon(word, w, h, transparent):
    """неоновая надпись: яркие буквы с ореолом на прозрачном (или чёрном, если у оригинала не было прозрачности)"""
    from PIL import ImageFilter
    col = NEON[word]
    K = 2
    glyph = Image.new('L', (w * K, h * K), 0)
    d = ImageDraw.Draw(glyph)
    size = int(h * K * 0.5)
    while size > 8:
        f = ImageFont.truetype(str(FD / 'RussoOne-Regular.ttf'), size)
        if d.textlength(word, font=f) <= w * K * 0.84:
            break
        size -= 2
    d.text((w * K / 2, h * K / 2), word, font=f, fill=255, anchor='mm')
    glow = glyph.filter(ImageFilter.GaussianBlur(size * 0.12))
    base = Image.new('RGBA', (w * K, h * K), (0, 0, 0, 0 if transparent else 255))
    base.alpha_composite(Image.merge('RGBA', [Image.new('L', glyph.size, c) for c in col] + [glow.point(lambda v: min(255, v * 2))]))
    core = Image.merge('RGBA', [Image.new('L', glyph.size, min(255, c + 120)) for c in col] + [glyph])
    base.alpha_composite(core)
    return base.resize((w, h), Image.LANCZOS)


def flag_ru(w, h):
    im = Image.new('RGBA', (w, h), (255, 255, 255, 255))
    d = ImageDraw.Draw(im)
    d.rectangle([0, h // 3, w, 2 * h // 3], fill=(0, 57, 166, 255))
    d.rectangle([0, 2 * h // 3, w, h], fill=(213, 43, 30, 255))
    return im
SUFFIX = ('', '+hi', '+hidr', '+hifr')


def original(txd, txn):
    for src in SRCS:
        for suf in SUFFIX:
            p = src / f'{txd}{suf}__{txn}.dds'
            if p.exists():
                return Image.open(p).convert('RGBA')
    return None


def coffee_round(w, h):
    """круглый знак кофейни на бежевом, как был у Bean Machine — но свой"""
    im = Image.new('RGBA', (w, h), (226, 214, 190, 255))
    d = ImageDraw.Draw(im)
    r = min(w, h) * 0.42
    cx, cy = w / 2, h / 2
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(92, 58, 30, 255))
    d.ellipse([cx - r * 0.86, cy - r * 0.86, cx + r * 0.86, cy + r * 0.86], fill=(226, 214, 190, 255))
    f1 = ImageFont.truetype(str(FD / 'RussoOne-Regular.ttf'), int(r * 0.42))
    f2 = ImageFont.truetype(str(FD / 'Oswald-SemiBold.ttf'), int(r * 0.22))
    d.text((cx, cy - r * 0.12), 'КОФЕ', font=f1, fill=(92, 58, 30, 255), anchor='mm')
    d.text((cx, cy + r * 0.38), 'КОФЕЙНЯ', font=f2, fill=(92, 58, 30, 255), anchor='mm')
    return im


def main():
    names, rows = [], []
    for txd, txn, src, how in B:
        o = original(txd, txn)
        if o is None:
            print('нет оригинала', txd, txn)
            continue
        w, h = o.size
        if src == 'coffee_round':
            res = coffee_round(w, h)
        elif src.startswith('neon:'):
            res = neon(src[5:], w, h, o.getchannel('A').getextrema()[0] < 200)
        elif src == 'flag:ru':
            res = flag_ru(w, h)
        elif src.startswith('two:'):  # щит из двух реклам: верхняя и нижняя половины
            a, b = src[4:].split(',')
            res = Image.new('RGBA', (w, h))
            res.paste(minimal(a, w, h // 2), (0, 0))
            res.paste(minimal(b, w, h - h // 2), (0, h // 2))
        else:
            if src.startswith('min:') and how == 'full':
                art = minimal(src[4:], w, h)
            elif src.startswith('min:'):
                a = o.getchannel('A').point(lambda v: 255 if v > 24 else 0).getbbox() or (0, 0, w, h)
                art = minimal(src[4:], a[2] - a[0], a[3] - a[1])
            else:
                art = Image.open(img / f'{src}.png').convert('RGBA')
            if how == 'full':
                res = art.resize((w, h), Image.LANCZOS)
            else:
                a = o.getchannel('A')
                box = a.point(lambda v: 255 if v > 24 else 0).getbbox() or (0, 0, w, h)
                bw, bh = box[2] - box[0], box[3] - box[1]
                if how == 'bbox_keep':  # герб — без растяжения, по центру
                    k = min(bw / art.width, bh / art.height)
                    art = art.resize((max(1, int(art.width * k)), max(1, int(art.height * k))), Image.LANCZOS)
                    pos = (box[0] + (bw - art.width) // 2, box[1] + (bh - art.height) // 2)
                else:
                    art = art.resize((bw, bh), Image.LANCZOS)
                    pos = (box[0], box[1])
                res = Image.new('RGBA', (w, h), (0, 0, 0, 0))
                res.paste(art, pos)
        name = 'brand_' + txn[:40].lower()
        res.save(out / f'{name}.png', optimize=True)
        # 13.11: копия под именем текстуры игры — для пересборки моделей (setup/maps/retex_job.py), вне git
        if BYNAME:
            res.save(BYNAME / f'{txn.lower()}.png')
        if name not in names:
            names.append(name)
        for suf in SUFFIX:
            rows.append((txd + suf, txn, name))
        print('done', txd, src)
    lua = ['-- собрано setup/retex/brands.py — не править руками. вывески GTA → наши (txd с +hi/+hidr — HD-версии тех же словарей)',
           'Config.BrandImages = {'] + [f"    '{n}'," for n in names] + ['}', '', 'Config.Brands = {']
    lua += [f"    {{ txd = '{a}', txn = '{b}', image = '{c}' }}," for a, b, c in rows]
    lua += ['}', '']
    (world / 'brands_list.lua').write_text('\n'.join(lua), encoding='utf-8')


if __name__ == '__main__':
    main()
