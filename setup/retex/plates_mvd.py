"""KAVKAZ RP: табличка ГУ МВД по Республике Нагорье в трёх вариантах — по фото настоящих табличек (прислал основатель 11.11.2026):
А — синяя крашеная, белые узкие буквы, белая рамка с вырезанными углами (как «МВД России … ЛОП Новоиерусалимская»);
Б — латунь с полосками шлифовки, тёмные буквы, литой герб, винты (как «Управление МВД по Приморскому краю»);
В — под стеклом в алюминиевой рамке, золото на тёмно-синем, отдельная табличка часов приёма (как у военкомата).
python setup/retex/plates_mvd.py — картинки в resources/[kavkaz]/kavkaz_world/images/retex/, примерка на стене — в setup/retex/preview/.
герб свой (щит со звездой и лавровые ветви), официальные гербы не копируем.
"""
import math
import pathlib

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

root = pathlib.Path(__file__).resolve().parents[2]
out = root / 'resources' / '[kavkaz]' / 'kavkaz_world' / 'images' / 'retex'
prev = pathlib.Path(__file__).resolve().parent / 'preview'
out.mkdir(parents=True, exist_ok=True)
prev.mkdir(exist_ok=True)
FD = pathlib.Path(__file__).resolve().parent / 'fonts'
OSWALD = str(FD / 'Oswald-SemiBold.ttf')
NARROW = str(FD / 'PTSansNarrow-Bold.ttf')
PTSANS = str(FD / 'PTSans-Bold.ttf')
PTSERIF = str(FD / 'PTSerif-Bold.ttf')
rng = np.random.default_rng(7)

W, H = 1600, 1200  # 4:3, как настоящая табличка 600×450 мм


def noise(w, h, scale=1.0, blur=0):
    a = rng.normal(0.5, 0.5 * scale, (h, w)).clip(0, 1)
    im = Image.fromarray((a * 255).astype('uint8'), 'L')
    return im.filter(ImageFilter.GaussianBlur(blur)) if blur else im


def lighting(img, strength=0.12):
    """мягкий свет сверху-слева и затемнение к краям — как на фото, а не плоская заливка"""
    w, h = img.size
    y, x = np.mgrid[0:h, 0:w]
    g = 1 + strength * (1 - (x / w * 0.6 + y / h * 0.9))
    v = 1 - 0.10 * (((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2)
    a = np.asarray(img.convert('RGB')).astype(float) * (g * v)[..., None]
    return Image.fromarray(a.clip(0, 255).astype('uint8'))


def fit_font(d, s, path, max_w, size):
    while size > 10:
        f = ImageFont.truetype(path, size)
        if d.textlength(s, font=f) <= max_w:
            return f
        size -= 2
    return ImageFont.truetype(path, size)


def lines_block(img, lines, top, bottom, max_w, color, path, layer_fx=None):
    """строки по центру; размер у каждой свой (как на настоящих табличках — главное крупнее)"""
    d = ImageDraw.Draw(img)
    fonts = [fit_font(d, s, path, max_w, size) for s, size in lines]
    hs = [f.getbbox('ЁЙ')[3] - f.getbbox('ЁЙ')[1] for f in fonts]
    gap = (bottom - top - sum(hs)) / (len(lines) + 1)
    y = top + gap
    mask = Image.new('L', img.size, 0)
    md = ImageDraw.Draw(mask)
    for (s, _), f, h in zip(lines, fonts, hs):
        md.text((img.width / 2, y + h / 2), s, font=f, fill=255, anchor='mm')
        y += h + gap
    if layer_fx:
        layer_fx(img, mask)
    else:
        img.paste(Image.new('RGB', img.size, color), (0, 0), mask)


# ---------------------------------------------------------------- свой герб: щит, звезда, лавровые ветви
def emblem_mask(size):
    S = size
    m = Image.new('L', (S, S), 0)
    d = ImageDraw.Draw(m)
    cx, cy = S / 2, S * 0.48
    w, h = S * 0.42, S * 0.52
    shield = [(cx - w / 2, cy - h / 2), (cx + w / 2, cy - h / 2), (cx + w / 2, cy + h * 0.08), (cx, cy + h / 2), (cx - w / 2, cy + h * 0.08)]
    d.polygon(shield, fill=255)
    inner = [(cx + (x - cx) * 0.84, cy + (y - cy) * 0.86) for x, y in shield]
    d.polygon(inner, fill=0)
    pts = []
    for i in range(10):
        r = S * (0.15 if i % 2 == 0 else 0.062)
        a = math.radians(-90 + i * 36)
        pts.append((cx + r * math.cos(a), cy - S * 0.02 + r * math.sin(a)))
    d.polygon(pts, fill=255)
    # лавровые ветви по дуге снизу
    for side in (-1, 1):
        for i in range(7):
            t = 0.15 + i * 0.11
            a = math.radians(90 + side * (35 + t * 110))
            r = S * 0.40
            x, y = cx + r * math.cos(a), cy + S * 0.06 + r * math.sin(a)
            leaf = Image.new('L', (int(S * 0.12), int(S * 0.05)), 0)
            ImageDraw.Draw(leaf).ellipse([0, 0, leaf.width - 1, leaf.height - 1], fill=255)
            leaf = leaf.rotate(-math.degrees(a) + side * 60 + 90, expand=True, resample=Image.BICUBIC)
            m.paste(255, (int(x - leaf.width / 2), int(y - leaf.height / 2)), leaf)
    return m


def metal(mask, base=(214, 176, 84), dark=(120, 88, 30), light=(255, 236, 170)):
    """литой металл: градиент сверху вниз, светлая грань сверху-слева, тёмная снизу-справа, мелкая зернистость"""
    w, h = mask.size
    y = np.linspace(0, 1, h)[:, None]
    grad = np.array(light) * (1 - y)[..., None] * 0.5 + np.array(base) * 0.75 + np.array(dark) * y[..., None] * 0.25
    grad = np.broadcast_to(grad, (h, w, 3)).copy()
    grad *= (0.94 + 0.12 * np.asarray(noise(w, h, 0.4, 1)) / 255)[..., None]
    img = Image.fromarray(grad.clip(0, 255).astype('uint8'))
    hi = ImageChops.subtract(mask, ImageChops.offset(mask, 3, 3)).filter(ImageFilter.GaussianBlur(1))
    lo = ImageChops.subtract(mask, ImageChops.offset(mask, -3, -3)).filter(ImageFilter.GaussianBlur(1))
    img.paste(Image.new('RGB', img.size, light), (0, 0), hi)
    img.paste(Image.new('RGB', img.size, dark), (0, 0), lo)
    return img


def put_emblem(img, cx, cy, size, **kw):
    m = emblem_mask(size)
    sh = Image.new('L', img.size, 0)
    sh.paste(m, (int(cx - size / 2 + 6), int(cy - size / 2 + 8)))
    img.paste(Image.new('RGB', img.size, (0, 0, 0)), (0, 0), sh.filter(ImageFilter.GaussianBlur(6)).point(lambda v: v * 0.45))
    img.paste(metal(m, **kw), (int(cx - size / 2), int(cy - size / 2)), m)


def screw(img, x, y, r=14):
    d = ImageDraw.Draw(img)
    for i in range(r, 0, -1):
        c = int(150 + 90 * (1 - i / r))
        d.ellipse([x - i, y - i, x + i, y + i], fill=(c, c, c - 6))
    d.line([(x - r * 0.6, y + r * 0.2), (x + r * 0.6, y - r * 0.2)], fill=(70, 70, 70), width=3)


# ================================================================ вариант А: синяя крашеная
def variant_a():
    blue = (22, 32, 120)
    img = Image.new('RGB', (W, H), blue)
    img = Image.composite(Image.new('RGB', (W, H), (26, 38, 132)), img, noise(W, H, 0.6, 1.2))
    img = lighting(img, 0.10)
    d = ImageDraw.Draw(img)
    # белая рамка с «вырезанными» углами и точками, как на фото
    m, cut = 50, 70
    pts = [(m + cut, m), (W - m - cut, m), (W - m, m + cut), (W - m, H - m - cut), (W - m - cut, H - m), (m + cut, H - m), (m, H - m - cut), (m, m + cut)]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]):
        d.line([(x0, y0), (x1, y1)], fill=(240, 242, 248), width=7)
    for cx, cy in ((m + cut - 10, m + cut - 10), (W - m - cut + 10, m + cut - 10), (m + cut - 10, H - m - cut + 10), (W - m - cut + 10, H - m - cut + 10)):
        d.arc([cx - cut + 10, cy - cut + 10, cx + cut - 10, cy + cut - 10], 0, 360, fill=blue, width=1)
    for x, y in ((30, 85), (W - 30, 85), (30, H - 85), (W - 30, H - 85)):
        d.ellipse([x - 7, y - 7, x + 7, y + 7], fill=(235, 238, 245))
    lines_block(img, [('МВД РОССИИ', 92)], 90, 230, W - 300, (245, 246, 250), OSWALD)
    put_emblem(img, W / 2, 330, 250)
    lines_block(img, [('ГЛАВНОЕ УПРАВЛЕНИЕ', 74), ('МИНИСТЕРСТВА ВНУТРЕННИХ ДЕЛ', 74), ('РОССИЙСКОЙ ФЕДЕРАЦИИ', 74),
                      ('ПО РЕСПУБЛИКЕ НАГОРЬЕ', 74), ('ОТДЕЛ ПОЛИЦИИ № 1 г. НАГОРСК', 96)], 430, H - 90, W - 280, (245, 246, 250), OSWALD)
    return img


# ================================================================ вариант Б: латунь
def brushed(w, h, base=(196, 160, 86)):
    n = noise(w // 8, h, 1.0).resize((w, h), Image.BICUBIC).filter(ImageFilter.BoxBlur(0))
    streak = noise(w // 40 + 1, h, 1.0).resize((w, h), Image.BILINEAR)  # длинные полосы шлифовки по горизонтали
    a = (np.asarray(n).astype(float) * 0.35 + np.asarray(streak).astype(float) * 0.65) / 255
    col = np.array(base, float)[None, None, :] * (0.86 + 0.24 * a[..., None])
    x = np.linspace(0, 1, w)[None, :]
    sheen = 0.18 * np.exp(-((x - 0.62) ** 2) / 0.02)  # блик, как от окна напротив
    col = col * (1 + sheen[..., None])
    return Image.fromarray(col.clip(0, 255).astype('uint8'))


def engraved(img, mask, ink=(38, 30, 22)):
    """буквы краской в гравировке: тёмные, с тонким светлым краем снизу"""
    edge = ImageChops.subtract(ImageChops.offset(mask, 0, 2), mask)
    img.paste(Image.new('RGB', img.size, (240, 214, 150)), (0, 0), edge)
    img.paste(Image.new('RGB', img.size, ink), (0, 0), mask)


def variant_b():
    img = lighting(brushed(W, H), 0.08)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W - 1, H - 1], outline=(150, 118, 58), width=6)  # фаска по краю
    d.rectangle([6, 6, W - 7, H - 7], outline=(236, 210, 150), width=3)
    put_emblem(img, W / 2, 195, 290, base=(206, 168, 80), dark=(110, 80, 26))
    lines_block(img, [('МВД РОССИИ', 64)], 320, 410, W - 400, None, PTSANS, layer_fx=engraved)
    lines_block(img, [('ГЛАВНОЕ УПРАВЛЕНИЕ МИНИСТЕРСТВА', 92), ('ВНУТРЕННИХ ДЕЛ', 92), ('РОССИЙСКОЙ ФЕДЕРАЦИИ', 92),
                      ('ПО РЕСПУБЛИКЕ НАГОРЬЕ', 92)], 420, H - 70, W - 220, None, PTSANS, layer_fx=engraved)
    for x, y in ((60, 60), (W - 60, 60), (60, H - 60), (W - 60, H - 60)):
        screw(img, x, y, 13)
    return img


# ================================================================ вариант В: стекло в алюминиевой рамке + часы приёма
def frame(img, width=42):
    w, h = img.size
    big = Image.new('RGB', (w + 2 * width, h + 2 * width), (180, 182, 186))
    d = ImageDraw.Draw(big)
    for i in range(width):  # профиль рамки: светлый сверху-слева, тёмный снизу-справа
        t = i / width
        c1 = int(225 - 60 * t)
        c2 = int(120 + 40 * t)
        d.line([(i, i), (w + 2 * width - i, i)], fill=(c1, c1, c1 + 3))
        d.line([(i, i), (i, h + 2 * width - i)], fill=(c1 - 10, c1 - 10, c1 - 7))
        d.line([(i, h + 2 * width - 1 - i), (w + 2 * width - i, h + 2 * width - 1 - i)], fill=(c2, c2, c2 + 3))
        d.line([(w + 2 * width - 1 - i, i), (w + 2 * width - 1 - i, h + 2 * width - i)], fill=(c2 + 10, c2 + 10, c2 + 13))
    big.paste(img, (width, width))
    return big


def glass(img):
    """блик стекла: широкая светлая полоса наискось и лёгкая дымка"""
    w, h = img.size
    y, x = np.mgrid[0:h, 0:w]
    band = np.clip(1 - np.abs((x / w) - (y / h) * 0.55 - 0.35) / 0.12, 0, 1) * 0.16
    haze = 0.04
    a = np.asarray(img).astype(float)
    a = a * (1 - band - haze)[..., None] + 255 * (band + haze)[..., None]
    return Image.fromarray(a.clip(0, 255).astype('uint8'))


def variant_c():
    navy = (14, 30, 78)
    gold = (226, 190, 92)
    main = lighting(Image.composite(Image.new('RGB', (W, 900), (18, 36, 90)), Image.new('RGB', (W, 900), navy), noise(W, 900, 0.5, 1.5)), 0.12)
    d = ImageDraw.Draw(main)
    d.text((140, 120), 'МВД', font=ImageFont.truetype(PTSERIF, 84), fill=gold, anchor='lm')
    d.text((W - 140, 120), 'РФ', font=ImageFont.truetype(PTSERIF, 84), fill=gold, anchor='rm')
    put_emblem(main, W / 2, 140, 240, base=(222, 184, 88))
    lines_block(main, [('ГЛАВНОЕ УПРАВЛЕНИЕ', 92), ('МИНИСТЕРСТВА ВНУТРЕННИХ ДЕЛ', 80), ('ПО РЕСПУБЛИКЕ НАГОРЬЕ', 92),
                       ('ОТДЕЛ ПОЛИЦИИ № 1', 84)], 250, 870, W - 200, gold, PTSERIF)
    main = frame(glass(main))
    hours = lighting(Image.new('RGB', (W, 360), navy), 0.1)
    lines_block(hours, [('ДЕЖУРНАЯ ЧАСТЬ — КРУГЛОСУТОЧНО', 70), ('ПРИЁМ ГРАЖДАН: ПН.–ПТ. 9.00–18.00', 58), ('ТЕЛЕФОН ДЕЖУРНОЙ ЧАСТИ: 102', 50)],
                10, 350, W - 200, gold, PTSERIF)
    hours = frame(glass(hours), 34)
    full = Image.new('RGBA', (main.width, main.height + 60 + hours.height), (0, 0, 0, 0))  # между табличками видно стену
    full.paste(main, (0, 0))
    full.paste(hours, ((main.width - hours.width) // 2, main.height + 60))
    return main, hours, full


# ---------------------------------------------------------------- примерка: табличка на стене в перспективе, как на фото
def wall(w, h):
    base = Image.new('RGB', (w, h), (196, 194, 188))
    base = Image.composite(Image.new('RGB', (w, h), (210, 208, 202)), base, noise(w, h, 0.8, 2))
    d = ImageDraw.Draw(base)
    for y in range(0, h, 150):  # швы плитки
        d.line([(0, y), (w, y)], fill=(170, 168, 162), width=3)
    for x in range(0, w, 300):
        d.line([(x, 0), (x, h)], fill=(170, 168, 162), width=3)
    return lighting(base, 0.2)


def coeffs(src, dst):
    m = []
    for (x, y), (u, v) in zip(dst, src):
        m.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        m.append([0, 0, 0, x, y, 1, -v * x, -v * y])
    a = np.array(m, float)
    b = np.array(src, float).reshape(8)
    return np.linalg.solve(a, b)


def mount(plate, name):
    W2, H2 = 1600, 1100
    bg = wall(W2, H2)
    pw, ph = plate.size
    dst = [(260, 150), (1380, 230), (1360, 960), (250, 1010)]
    warped = plate.convert('RGBA').transform((W2, H2), Image.PERSPECTIVE, tuple(coeffs([(0, 0), (pw, 0), (pw, ph), (0, ph)], dst)), Image.BICUBIC)
    shadow = Image.new('L', (W2, H2), 0)
    sm = plate.convert('RGBA').split()[3].transform((W2, H2), Image.PERSPECTIVE, tuple(coeffs([(0, 0), (pw, 0), (pw, ph), (0, ph)], dst)), Image.BICUBIC)
    shadow.paste(ImageChops.offset(sm, 18, 22).point(lambda v: v * 0.6), (0, 0))
    bg.paste((40, 38, 34), (0, 0), shadow.filter(ImageFilter.GaussianBlur(16)))
    bg.paste(warped, (0, 0), warped)
    bg.save(prev / f'{name}.jpg', quality=90)


a = variant_a()
a.save(out / 'mvd_plate_a.png', optimize=True)
mount(a, 'mvd_plate_a_wall')
b = variant_b()
b.save(out / 'mvd_plate_b.png', optimize=True)
mount(b, 'mvd_plate_b_wall')
c_main, c_hours, c_full = variant_c()
c_main.save(out / 'mvd_plate_c.png', optimize=True)
c_hours.save(out / 'mvd_plate_c_hours.png', optimize=True)
mount(c_full, 'mvd_plate_c_wall')
print('готово: три варианта, примерка в', prev)
