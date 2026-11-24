"""KAVKAZ RP: нарисовать вывески, таблички и эмблемы для перетекстуровки зданий GTA (МВД, ФСБ, военкомат, магазины, кафе…).
запуск из корня репозитория: python setup/retex/make_art.py
картинки — в resources/[kavkaz]/kavkaz_world/images/retex/, список — kavkaz_world/retex_list.lua (для подмены текстур в игре).
размеры «с запасом»: вывески 2048×512 (4:1), таблички 1024×768 (4:3), эмблемы 1024×1024. под точный размер текстуры GTA
их подгоняет setup/retex/fit.py (обрезка/поля по цвету фона), поэтому важное держим в центре.
все эмблемы — свои, вымышленные (Республика Нагорье): официальные гербы и знаки ведомств не копируем.
"""
import math
import pathlib

from PIL import Image, ImageDraw, ImageFont

root = pathlib.Path(__file__).resolve().parents[2]
out = root / 'resources' / '[kavkaz]' / 'kavkaz_world' / 'images' / 'retex'
out.mkdir(parents=True, exist_ok=True)
signs = root / 'setup' / 'signs' / 'fonts'


def pick(*cands):
    for c in cands:
        if pathlib.Path(c).exists():
            return str(c)
    raise SystemExit('нет шрифта: ' + ', '.join(map(str, cands)))


SANS = pick('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 'C:/Windows/Fonts/arialbd.ttf')
SERIF = pick('/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf', 'C:/Windows/Fonts/timesbd.ttf')
BRAND = str(signs / 'Manrope-800.ttf')
BRAND_M = str(signs / 'Manrope-500.ttf')

WHITE = (255, 255, 255)
GOLD = (214, 178, 92)
GOLD_D = (150, 118, 52)
MVD_BLUE = (14, 52, 120)
NAVY = (12, 30, 62)
BORDO = (96, 18, 30)
ARMY_RED = (122, 16, 16)
ARMY_GREEN = (52, 70, 44)
names = []


def save(img, name):
    img.convert('RGB').save(out / f'{name}.png', optimize=True)
    names.append(name)
    print('готово:', name)


def text(img, xy, s, path, max_w, size, fill, anchor='mm', condense=1.0, spacing=0):
    """надпись, ужатая по ширине до max_w; condense < 1 — сжать буквы по горизонтали (как узкий шрифт вывесок)"""
    d = ImageDraw.Draw(img)
    while size > 8:
        f = ImageFont.truetype(path, size)
        w = d.textlength(s, font=f) * condense + spacing * (len(s) - 1)
        if w <= max_w:
            break
        size -= 2
    f = ImageFont.truetype(path, size)
    if condense == 1.0 and spacing == 0:
        d.text(xy, s, font=f, fill=fill, anchor=anchor)
        return
    # рисуем отдельно и сжимаем по ширине
    bbox = d.textbbox((0, 0), s, font=f, anchor='ls')
    tw = int(sum(d.textlength(ch, font=f) for ch in s) + spacing * len(s)) + int(f.size * 0.3)  # по буквам: без кернинга шире
    th = bbox[3] - bbox[1] + 8
    layer = Image.new('L', (tw, th), 0)
    ld = ImageDraw.Draw(layer)
    x = 2
    for ch in s:
        ld.text((x, th - 4 - bbox[3]), ch, font=f, fill=255, anchor='ls')
        x += d.textlength(ch, font=f) + spacing
    layer = layer.resize((max(1, int(tw * condense)), th), Image.LANCZOS)
    if layer.width > max_w:  # страховка: если всё же шире места — уменьшаем целиком
        k = max_w / layer.width
        layer = layer.resize((int(layer.width * k), max(1, int(layer.height * k))), Image.LANCZOS)
    cx, cy = xy
    ox = {'m': cx - layer.width // 2, 'l': cx, 'r': cx - layer.width}[anchor[0]]
    oy = cy - layer.height // 2
    img.paste(Image.new('RGB', layer.size, fill), (int(ox), int(oy)), layer)


def star(d, cx, cy, r, fill, points=5, inner=0.42, rot=-90):
    pts = []
    for i in range(points * 2):
        rr = r if i % 2 == 0 else r * inner
        a = math.radians(rot + i * 180 / points)
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=fill)


def shield(d, cx, cy, w, h, fill, outline=None, width=0):
    pts = [(cx - w / 2, cy - h / 2), (cx + w / 2, cy - h / 2), (cx + w / 2, cy + h * 0.05),
           (cx, cy + h / 2), (cx - w / 2, cy + h * 0.05)]
    d.polygon(pts, fill=fill)
    if outline:
        d.line(pts + [pts[0]], fill=outline, width=width, joint='curve')


def mountains(d, x, y, w, h, fill, snow=None):
    """наш знак Нагорья: две вершины (картинка, не буква)"""
    d.polygon([(x, y + h), (x + w * 0.38, y), (x + w * 0.58, y + h * 0.45), (x + w * 0.72, y + h * 0.2), (x + w, y + h)], fill=fill)
    if snow:
        d.polygon([(x + w * 0.38, y), (x + w * 0.29, y + h * 0.24), (x + w * 0.38, y + h * 0.18), (x + w * 0.46, y + h * 0.24)], fill=snow)


# ---------------------------------------------------------------- эмблемы (свои)
def emblem(name, field, mark, ring_text):
    S = 1024
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([20, 20, S - 20, S - 20], fill=GOLD)
    d.ellipse([52, 52, S - 52, S - 52], fill=field)
    d.ellipse([200, 200, S - 200, S - 200], fill=GOLD)
    d.ellipse([222, 222, S - 222, S - 222], fill=field)
    # надпись по кругу
    f = ImageFont.truetype(SANS, 54)
    n = len(ring_text)
    for i, ch in enumerate(ring_text):
        a = math.radians(-90 - 150 + i * (300 / max(1, n - 1)))
        r = 375
        x, y = S / 2 + r * math.cos(a), S / 2 + r * math.sin(a)
        g = Image.new('RGBA', (90, 90), (0, 0, 0, 0))
        ImageDraw.Draw(g).text((45, 45), ch, font=f, fill=GOLD, anchor='mm')
        g = g.rotate(-math.degrees(a) - 90, resample=Image.BICUBIC)
        img.alpha_composite(g, (int(x - 45), int(y - 45)))
    mark(d, S / 2, S / 2)
    flat = Image.new('RGB', (S, S), field)
    flat.paste(img, (0, 0), img)
    save(flat, name)


def mark_police(d, cx, cy):
    shield(d, cx, cy, 300, 360, GOLD)
    shield(d, cx, cy, 262, 322, MVD_BLUE)
    star(d, cx, cy - 10, 105, GOLD)


def mark_fsb(d, cx, cy):
    shield(d, cx, cy, 300, 360, GOLD)
    shield(d, cx, cy, 262, 322, BORDO)
    d.polygon([(cx - 14, cy - 140), (cx + 14, cy - 140), (cx + 10, cy + 90), (cx, cy + 120), (cx - 10, cy + 90)], fill=GOLD)  # клинок
    d.rectangle([cx - 70, cy + 40, cx + 70, cy + 58], fill=GOLD)  # гарда
    star(d, cx, cy - 30, 60, GOLD)


def mark_army(d, cx, cy):
    star(d, cx, cy, 190, GOLD)
    star(d, cx, cy, 150, ARMY_RED)
    star(d, cx, cy, 60, GOLD)


def mark_nagorye(d, cx, cy):
    mountains(d, cx - 170, cy - 110, 340, 220, GOLD, snow=WHITE)


emblem('emb_mvd', MVD_BLUE, mark_police, 'МВД · РЕСПУБЛИКА НАГОРЬЕ')
emblem('emb_fsb', BORDO, mark_fsb, 'ФСБ · РЕСПУБЛИКА НАГОРЬЕ')
emblem('emb_army', ARMY_GREEN, mark_army, 'ВООРУЖЁННЫЕ СИЛЫ · НАГОРЬЕ')
emblem('emb_nagorye', NAVY, mark_nagorye, 'РЕСПУБЛИКА НАГОРЬЕ · НАГОРСК')


# ---------------------------------------------------------------- таблички учреждений (4:3)
def plate(name, bg, lines, emb_mark=None, emb_field=None):
    """официальная табличка: фон, двойная золотая рамка, эмблема сверху, золотые буквы с засечками"""
    W, H = 1024, 768
    img = Image.new('RGB', (W, H), bg)
    d = ImageDraw.Draw(img)
    d.rectangle([14, 14, W - 15, H - 15], outline=GOLD, width=8)
    d.rectangle([34, 34, W - 35, H - 35], outline=GOLD_D, width=3)
    y = 120
    if emb_mark:
        d.ellipse([W / 2 - 92, 44, W / 2 + 92, 228], fill=GOLD)
        d.ellipse([W / 2 - 80, 56, W / 2 + 80, 216], fill=emb_field or bg)
        sub = Image.new('RGBA', (400, 480), (0, 0, 0, 0))
        emb_mark(ImageDraw.Draw(sub), 200, 240)
        sub = sub.resize((100, 120), Image.LANCZOS)
        img.paste(sub, (int(W / 2 - 50), 76), sub)
        y = 300
    total = sum(s for _, s in lines)
    gap = (H - 70 - y) / max(1, len(lines))
    for i, (s, size) in enumerate(lines):
        text(img, (W / 2, y + gap * i + gap / 2), s, SERIF, W - 150, size, GOLD)
    save(img, name)


plate('plate_mvd', MVD_BLUE, [('ГЛАВНОЕ УПРАВЛЕНИЕ', 58), ('МИНИСТЕРСТВА ВНУТРЕННИХ ДЕЛ', 50), ('ПО РЕСПУБЛИКЕ НАГОРЬЕ', 58)], mark_police, MVD_BLUE)
plate('plate_fsb', BORDO, [('УПРАВЛЕНИЕ', 62), ('ФЕДЕРАЛЬНОЙ СЛУЖБЫ БЕЗОПАСНОСТИ', 44), ('ПО РЕСПУБЛИКЕ НАГОРЬЕ', 56)], mark_fsb, BORDO)
plate('plate_voenkomat', ARMY_RED, [('ВОЕННЫЙ КОМИССАРИАТ', 60), ('РЕСПУБЛИКИ НАГОРЬЕ', 60)], mark_army, ARMY_RED)
plate('plate_gov', NAVY, [('ПРАВИТЕЛЬСТВО', 70), ('РЕСПУБЛИКИ НАГОРЬЕ', 62)], mark_nagorye, NAVY)
plate('plate_court', NAVY, [('ВЕРХОВНЫЙ СУД', 70), ('РЕСПУБЛИКИ НАГОРЬЕ', 62)], mark_nagorye, NAVY)
plate('plate_mreo', MVD_BLUE, [('МРЭО ГИБДД', 80), ('МВД ПО РЕСПУБЛИКЕ НАГОРЬЕ', 46), ('регистрация транспорта · номера', 40)], mark_police, MVD_BLUE)
plate('plate_hospital', (16, 82, 70), [('РЕСПУБЛИКАНСКАЯ', 64), ('КЛИНИЧЕСКАЯ БОЛЬНИЦА', 58), ('приёмное отделение — круглосуточно', 36)])
plate('plate_mchs', (150, 40, 20), [('ГЛАВНОЕ УПРАВЛЕНИЕ МЧС', 54), ('ПО РЕСПУБЛИКЕ НАГОРЬЕ', 58), ('пожарная часть № 1', 44)])


# ---------------------------------------------------------------- фасадные надписи (4:1)
def band(name, bg, s, fg=WHITE, stripe=None, font=SANS, condense=0.86, spacing=10, sub=None, logo=None):
    W, H = 2048, 512
    img = Image.new('RGB', (W, H), bg)
    d = ImageDraw.Draw(img)
    if stripe:  # полосы как на машинах полиции: белая и красная — по самому низу
        d.rectangle([0, H - 64, W, H - 40], fill=stripe[0])
        d.rectangle([0, H - 40, W, H - 16], fill=stripe[1])
    x0 = 120
    if logo:
        logo(img, d)
        x0 = 520
    bottom = H - 64 if stripe else H
    cy = (bottom / 2) - (34 if sub else 0)
    text(img, ((x0 + W - 80) / 2, cy), s, font, W - x0 - 160, 280 if sub else 300, fg, condense=condense, spacing=spacing)
    if sub:
        text(img, ((x0 + W - 80) / 2, bottom - 70), sub, BRAND_M, W - x0 - 160, 60, fg)
    save(img, name)


def logo_emb(field, mark):
    def draw(img, d):
        d.ellipse([130, 70, 430, 370], fill=GOLD)
        d.ellipse([150, 90, 410, 350], fill=field)
        sub = Image.new('RGBA', (400, 480), (0, 0, 0, 0))
        mark(ImageDraw.Draw(sub), 200, 240)
        sub = sub.resize((170, 204), Image.LANCZOS)
        img.paste(sub, (195, 118), sub)
    return draw


band('facade_police', MVD_BLUE, 'ПОЛИЦИЯ', stripe=(WHITE, (200, 24, 32)), logo=logo_emb(MVD_BLUE, mark_police))
band('facade_police_white', WHITE, 'ПОЛИЦИЯ', fg=MVD_BLUE, stripe=(MVD_BLUE, (200, 24, 32)), logo=logo_emb(MVD_BLUE, mark_police))
band('facade_dps', MVD_BLUE, 'ДПС ГИБДД', stripe=(WHITE, (200, 24, 32)), logo=logo_emb(MVD_BLUE, mark_police))
band('facade_fsb', (24, 24, 26), 'ФСБ РОССИИ', fg=GOLD, logo=logo_emb(BORDO, mark_fsb), sub='управление по Республике Нагорье')
band('facade_voenkomat', ARMY_RED, 'ВОЕНКОМАТ', fg=GOLD, logo=logo_emb(ARMY_RED, mark_army), sub='призывной пункт · контракт')
band('facade_army_kpp', WHITE, 'КПП · СТОЙ!', fg=(190, 20, 20), stripe=((190, 20, 20), (190, 20, 20)), sub='войсковая часть 31415 · проход по пропускам')
band('facade_gov', NAVY, 'ПРАВИТЕЛЬСТВО', fg=GOLD, logo=logo_emb(NAVY, mark_nagorye), sub='Республики Нагорье')
band('facade_hospital', WHITE, 'БОЛЬНИЦА', fg=(16, 110, 80), stripe=((16, 110, 80), (16, 110, 80)), sub='Республиканская клиническая · 103')
band('facade_avtovokzal', NAVY, 'АВТОВОКЗАЛ', logo=logo_emb(NAVY, mark_nagorye), sub='Нагорск · междугородние рейсы')


# ---------------------------------------------------------------- магазины и кафе (вымышленные сети, 4:1)
def shop(name, bg, title, fg=WHITE, sub=None, badge=None, mark=None, font=BRAND):
    W, H = 2048, 512
    img = Image.new('RGB', (W, H), bg)
    d = ImageDraw.Draw(img)
    x0 = 110
    if mark:
        mark(img, d)
        x0 = 470
    if badge:
        bx = W - 330
        d.ellipse([bx, 86, bx + 250, 336], fill=badge[1])
        text(img, (bx + 125, 211), badge[0], BRAND, 200, 150, badge[2])
        right = bx - 40
    else:
        right = W - 110
    cy = H / 2 - (36 if sub else 0)
    text(img, ((x0 + right) / 2, cy), title, font, right - x0, 230, fg, condense=0.92)
    if sub:
        text(img, ((x0 + right) / 2, H - 84), sub, BRAND_M, right - x0, 58, fg)
    save(img, name)


def m_mountains(color, snow=None):
    return lambda img, d: mountains(d, 110, 130, 300, 230, color, snow)


def m_cup(color):
    def draw(img, d):
        d.rounded_rectangle([140, 170, 330, 380], radius=30, fill=color)
        d.arc([300, 210, 400, 320], 270, 90, fill=color, width=26)
        for x in (180, 235, 290):
            d.arc([x - 20, 80, x + 20, 160], 100, 260, fill=color, width=12)
    return draw


def m_teapot(color):
    def draw(img, d):
        d.ellipse([150, 190, 370, 380], fill=color)
        d.rectangle([215, 160, 305, 200], fill=color)
        d.ellipse([240, 130, 280, 170], fill=color)
        d.polygon([(360, 270), (430, 200), (440, 215), (380, 300)], fill=color)
        d.arc([100, 220, 180, 330], 90, 270, fill=color, width=22)
    return draw


def m_cross(color):
    def draw(img, d):
        d.rectangle([215, 120, 315, 390], fill=color)
        d.rectangle([130, 205, 400, 305], fill=color)
    return draw


def m_drop(color):
    def draw(img, d):
        d.polygon([(265, 100), (180, 280), (350, 280)], fill=color)
        d.ellipse([175, 210, 355, 390], fill=color)
    return draw


def m_fish(color):
    def draw(img, d):
        d.ellipse([130, 200, 360, 330], fill=color)
        d.polygon([(350, 265), (430, 200), (430, 330)], fill=color)
        d.ellipse([175, 245, 200, 270], fill=(0, 0, 0))
    return draw


def m_skewer(color, meat):
    def draw(img, d):
        d.line([(120, 380), (430, 140)], fill=color, width=14)
        for i, t in enumerate((0.3, 0.5, 0.7)):
            x, y = 120 + (430 - 120) * t, 380 + (140 - 380) * t
            d.rounded_rectangle([x - 42, y - 42, x + 42, y + 42], radius=14, fill=meat)
    return draw


def m_wrap(color, inside):
    """шаурма: лаваш конусом, сверху начинка, снизу бумажная обёртка"""
    def draw(img, d):
        d.polygon([(170, 150), (380, 150), (300, 430), (250, 430)], fill=(236, 196, 130))      # лаваш
        d.ellipse([170, 110, 380, 190], fill=(236, 196, 130))
        for x, y, c in ((215, 140, (60, 150, 60)), (260, 128, (200, 40, 30)), (305, 140, (60, 150, 60)), (335, 150, (240, 220, 160))):
            d.ellipse([x - 26, y - 22, x + 26, y + 22], fill=c)                                  # зелень, помидор, соус
        d.polygon([(205, 270), (345, 270), (305, 440), (245, 440)], fill=WHITE)                # бумага
        d.line([(212, 300), (338, 300)], fill=color, width=12)
    return draw


def m_coin(color, inner):
    def draw(img, d):
        d.ellipse([140, 120, 400, 380], fill=color)
        text(img, (270, 255), '₽', SANS, 200, 190, inner)
    return draw


shop('shop_produkty24', (18, 120, 62), 'ПРОДУКТЫ', sub='круглосуточно · у дома', badge=('24', (255, 210, 60), (18, 60, 30)))
shop('shop_market', (200, 20, 44), 'НАГОРЬЕ-МАРКЕТ', sub='супермаркет', mark=m_mountains(WHITE))
shop('shop_gastronom', (16, 40, 80), 'ГАСТРОНОМ', fg=GOLD, font=SERIF, sub='с 1974 года')
shop('shop_napitki', (60, 20, 40), 'НАПИТКИ', sub='соки · воды · лимонады', mark=m_drop((120, 200, 255)))
shop('shop_ohota', (36, 58, 32), 'ОХОТА И РЫБАЛКА', fg=(255, 170, 60), sub='снаряжение · лицензии', mark=m_fish((255, 170, 60)))
shop('shop_apteka', WHITE, 'АПТЕКА', fg=(16, 130, 70), sub='круглосуточно', mark=m_cross((16, 160, 80)))
shop('cafe_shaurma', (250, 196, 30), 'ШАУРМА У РАСУЛА', fg=(150, 20, 20), sub='с 2009 года · шаурма 350 ₽', mark=m_wrap((150, 20, 20), (255, 240, 200)))
shop('cafe_chaikhana', (14, 70, 64), 'ЧАЙХАНА «У РУМИСЫ»', fg=GOLD, sub='чай · жижиг-галнаш · чепалгаш', mark=m_teapot(GOLD))
shop('cafe_shashlyk', (40, 24, 18), 'ШАШЛЫЧНАЯ «МАНГАЛ»', fg=(255, 140, 40), sub='на углях · у трассы', mark=m_skewer((200, 200, 200), (180, 70, 30)))
shop('cafe_coffee', (70, 44, 30), 'КОФЕЙНЯ «ГОРЫ»', fg=(245, 230, 210), sub='кофе с собой', mark=m_cup((245, 230, 210)))
shop('bank_nagorye', (14, 36, 80), 'НАГОРЬЕ-БАНК', sub='вклады · кредиты · банкоматы', mark=m_coin(GOLD, (14, 36, 80)))
shop('azs_nagorye', (0, 92, 160), 'НАГОРЬЕ-НЕФТЬ', sub='АЗС · АИ-92 · АИ-95 · ДТ', mark=m_drop(WHITE))

# список для игры: эти картинки kavkaz_world загружает и может подставить вместо любой текстуры GTA (Config.Textures)
lst = root / 'resources' / '[kavkaz]' / 'kavkaz_world' / 'retex_list.lua'
lst.write_text('-- собрано setup/retex/make_art.py — не править руками\nConfig.RetexImages = {\n' +
               ''.join(f"    '{n}',\n" for n in names) + '}\n', encoding='utf-8')
print('всего картинок:', len(names))
