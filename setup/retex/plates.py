"""KAVKAZ RP: таблички учреждений Нагорья — по фото настоящих табличек (прислал основатель 11.11.2026).
стили, как это бывает в жизни:
  paint — крашеная с белой рамкой и вырезанными углами (полиция, МРЭО, ДПС; белая — больница);
  brass — латунь со шлифовкой и тёмными буквами (запасной вариант);
  dark  — тёмная матовая плита с объёмными золотыми буквами, как у Центробанка (Правительство, суд, ФСБ, банк);
  glass — под стеклом в алюминиевой рамке, золото на цветном фоне, с табличкой часов работы (военкомат, МЧС).
python setup/retex/plates.py — картинки в resources/[kavkaz]/kavkaz_world/images/retex/plate2_*.png,
примерка на стене — setup/retex/preview/ (не в git). гербы свои (щит, звезда/меч/весы/горы, лавр), официальные не копируем.
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



# ---------------------------------------------------------------- свои гербы: щит со знаком внутри и лавровые ветви
def emblem_mask(size, kind='star'):
    S = size
    m = Image.new('L', (S, S), 0)
    d = ImageDraw.Draw(m)
    cx, cy = S / 2, S * 0.48
    w, h = S * 0.42, S * 0.52
    shield = [(cx - w / 2, cy - h / 2), (cx + w / 2, cy - h / 2), (cx + w / 2, cy + h * 0.08), (cx, cy + h / 2), (cx - w / 2, cy + h * 0.08)]
    d.polygon(shield, fill=255)
    d.polygon([(cx + (x - cx) * 0.84, cy + (y - cy) * 0.86) for x, y in shield], fill=0)
    if kind == 'star':
        pts = []
        for i in range(10):
            r = S * (0.15 if i % 2 == 0 else 0.062)
            a = math.radians(-90 + i * 36)
            pts.append((cx + r * math.cos(a), cy - S * 0.02 + r * math.sin(a)))
        d.polygon(pts, fill=255)
    elif kind == 'sword':
        d.polygon([(cx - S * 0.018, cy - S * 0.19), (cx + S * 0.018, cy - S * 0.19), (cx + S * 0.014, cy + S * 0.12), (cx, cy + S * 0.17), (cx - S * 0.014, cy + S * 0.12)], fill=255)
        d.rectangle([cx - S * 0.09, cy + S * 0.06, cx + S * 0.09, cy + S * 0.085], fill=255)
        d.rectangle([cx - S * 0.12, cy - S * 0.05, cx + S * 0.12, cy - S * 0.03], fill=0)
    elif kind == 'scales':
        d.rectangle([cx - S * 0.012, cy - S * 0.17, cx + S * 0.012, cy + S * 0.14], fill=255)
        d.rectangle([cx - S * 0.15, cy - S * 0.13, cx + S * 0.15, cy - S * 0.11], fill=255)
        for sx in (-1, 1):
            x = cx + sx * S * 0.13
            d.line([(x, cy - S * 0.12), (x - S * 0.05, cy + S * 0.02)], fill=255, width=max(2, int(S * 0.01)))
            d.line([(x, cy - S * 0.12), (x + S * 0.05, cy + S * 0.02)], fill=255, width=max(2, int(S * 0.01)))
            d.chord([x - S * 0.07, cy - S * 0.03, x + S * 0.07, cy + S * 0.08], 0, 180, fill=255)
        d.rectangle([cx - S * 0.07, cy + S * 0.13, cx + S * 0.07, cy + S * 0.155], fill=255)
    elif kind == 'mountains':
        d.polygon([(cx - S * 0.16, cy + S * 0.12), (cx - S * 0.04, cy - S * 0.13), (cx + S * 0.03, cy - S * 0.02), (cx + S * 0.08, cy - S * 0.08), (cx + S * 0.16, cy + S * 0.12)], fill=255)
    elif kind == 'army':
        pts = []
        for i in range(10):
            r = S * (0.17 if i % 2 == 0 else 0.07)
            a = math.radians(-90 + i * 36)
            pts.append((cx + r * math.cos(a), cy - S * 0.01 + r * math.sin(a)))
        d.polygon(pts, fill=255)
        inner = [(cx + (x - cx) * 0.6, cy - S * 0.01 + (y - cy + S * 0.01) * 0.6) for x, y in pts]
        d.polygon(inner, fill=0)
    elif kind == 'cross':
        d.rectangle([cx - S * 0.04, cy - S * 0.15, cx + S * 0.04, cy + S * 0.13], fill=255)
        d.rectangle([cx - S * 0.14, cy - S * 0.05, cx + S * 0.14, cy + S * 0.03], fill=255)
    for side in (-1, 1):  # лавровые ветви
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


def put_emblem(img, cx, cy, size, kind='star', **kw):
    m = emblem_mask(size, kind)
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



# ================================================================ стили
def paint(header, kind, lines, last=None, bg=(22, 32, 120), bg2=(26, 38, 132), fg=(245, 246, 250), frame_c=(240, 242, 248)):
    img = Image.new('RGB', (W, H), bg)
    img = Image.composite(Image.new('RGB', (W, H), bg2), img, noise(W, H, 0.6, 1.2))
    img = lighting(img, 0.10)
    d = ImageDraw.Draw(img)
    m, cut = 50, 70
    pts = [(m + cut, m), (W - m - cut, m), (W - m, m + cut), (W - m, H - m - cut), (W - m - cut, H - m), (m + cut, H - m), (m, H - m - cut), (m, m + cut)]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]):
        d.line([(x0, y0), (x1, y1)], fill=frame_c, width=7)
    for x, y in ((30, 85), (W - 30, 85), (30, H - 85), (W - 30, H - 85)):
        d.ellipse([x - 7, y - 7, x + 7, y + 7], fill=frame_c)
    lines_block(img, [(header, 92)], 90, 230, W - 300, fg, OSWALD)
    put_emblem(img, W / 2, 330, 250, kind)
    body = [(s, 74) for s in lines] + ([(last, 96)] if last else [])
    lines_block(img, body, 430, H - 90, W - 280, fg, OSWALD)
    return img


def raised_gold(img, mask):
    """объёмные золотые буквы на плите: тень на плиту, градиент металла, светлая грань"""
    sh = ImageChops.offset(mask, 5, 7).filter(ImageFilter.GaussianBlur(4)).point(lambda v: v * 0.6)
    img.paste(Image.new('RGB', img.size, (0, 0, 0)), (0, 0), sh)
    img.paste(metal(mask, base=(212, 172, 78), dark=(118, 84, 28), light=(255, 232, 160)), (0, 0), mask)


def dark(header, kind, lines, plate=(52, 52, 54)):
    """как вывеска Центробанка: тёмная матовая плита, тонкая золотая рамка, объёмные буквы с засечками"""
    img = Image.new('RGB', (W, H), plate)
    img = Image.composite(Image.new('RGB', (W, H), tuple(c + 10 for c in plate)), img, noise(W, H, 0.9, 2.5))
    img = lighting(img, 0.16)
    gold_frame = Image.new('L', (W, H), 0)
    ImageDraw.Draw(gold_frame).rectangle([26, 26, W - 27, H - 27], outline=255, width=14)
    raised_gold(img, gold_frame)
    put_emblem(img, W / 2, 250, 330, kind)
    lines_block(img, [(header, 70)] + [(s, 104) for s in lines], 430, H - 90, W - 220, None, PTSERIF, layer_fx=raised_gold)
    return img


def brass(header, kind, lines):
    img = lighting(brushed(W, H), 0.08)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W - 1, H - 1], outline=(150, 118, 58), width=6)
    d.rectangle([6, 6, W - 7, H - 7], outline=(236, 210, 150), width=3)
    put_emblem(img, W / 2, 195, 290, kind, base=(206, 168, 80), dark=(110, 80, 26))
    lines_block(img, [(header, 64)], 320, 410, W - 400, None, PTSANS, layer_fx=engraved)
    lines_block(img, [(s, 92) for s in lines], 420, H - 70, W - 220, None, PTSANS, layer_fx=engraved)
    for x, y in ((60, 60), (W - 60, 60), (60, H - 60), (W - 60, H - 60)):
        screw(img, x, y, 13)
    return img


def glass_plate(left, right, kind, lines, hours, bg=(14, 30, 78), bg2=(18, 36, 90), gold=(226, 190, 92)):
    main = lighting(Image.composite(Image.new('RGB', (W, 900), bg2), Image.new('RGB', (W, 900), bg), noise(W, 900, 0.5, 1.5)), 0.12)
    d = ImageDraw.Draw(main)
    d.text((140, 120), left, font=ImageFont.truetype(PTSERIF, 84), fill=gold, anchor='lm')
    d.text((W - 140, 120), right, font=ImageFont.truetype(PTSERIF, 84), fill=gold, anchor='rm')
    put_emblem(main, W / 2, 140, 240, kind, base=(222, 184, 88))
    lines_block(main, [(s, 88) for s in lines], 250, 870, W - 200, gold, PTSERIF)
    main = frame(glass(main))
    hrs = lighting(Image.new('RGB', (W, 360), bg), 0.1)
    lines_block(hrs, hours, 10, 350, W - 200, gold, PTSERIF)
    hrs = frame(glass(hrs), 34)
    full = Image.new('RGBA', (main.width, main.height + 60 + hrs.height), (0, 0, 0, 0))
    full.paste(main, (0, 0))
    full.paste(hrs, ((main.width - hrs.width) // 2, main.height + 60))
    return main, hrs, full


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



if __name__ == '__main__':
    made = {}
    # полиция и ГИБДД — синие крашеные, как на фото МВД
    made['plate2_mvd'] = paint('МВД РОССИИ', 'star', ['ГЛАВНОЕ УПРАВЛЕНИЕ', 'МИНИСТЕРСТВА ВНУТРЕННИХ ДЕЛ', 'РОССИЙСКОЙ ФЕДЕРАЦИИ', 'ПО РЕСПУБЛИКЕ НАГОРЬЕ'], 'ОТДЕЛ ПОЛИЦИИ № 1 г. НАГОРСК')
    made['plate2_mreo'] = paint('МВД РОССИИ', 'star', ['УПРАВЛЕНИЕ ГИБДД', 'МВД ПО РЕСПУБЛИКЕ НАГОРЬЕ', 'МЕЖРАЙОННЫЙ РЕГИСТРАЦИОННО-', 'ЭКЗАМЕНАЦИОННЫЙ ОТДЕЛ'], 'МРЭО ГИБДД г. НАГОРСК')
    made['plate2_dps'] = paint('МВД РОССИИ', 'star', ['ОТДЕЛЬНЫЙ БАТАЛЬОН', 'ДОРОЖНО-ПАТРУЛЬНОЙ СЛУЖБЫ', 'ГИБДД МВД', 'ПО РЕСПУБЛИКЕ НАГОРЬЕ'], 'ПОЛК ДПС «ПЕСЧАНЫЙ»')
    # больница — белая крашеная с синими буквами
    made['plate2_hospital'] = paint('МИНЗДРАВ РЕСПУБЛИКИ НАГОРЬЕ', 'cross', ['ГОСУДАРСТВЕННОЕ БЮДЖЕТНОЕ УЧРЕЖДЕНИЕ', 'РЕСПУБЛИКАНСКАЯ', 'КЛИНИЧЕСКАЯ БОЛЬНИЦА'], 'ПРИЁМНОЕ ОТДЕЛЕНИЕ — КРУГЛОСУТОЧНО',
                                    bg=(238, 240, 242), bg2=(228, 231, 234), fg=(20, 50, 130), frame_c=(20, 50, 130))
    # власть, суд, ФСБ, банк — тёмная плита с объёмным золотом, как у Центробанка
    made['plate2_gov'] = dark('РЕСПУБЛИКА НАГОРЬЕ', 'mountains', ['Правительство', 'Республики Нагорье'])
    made['plate2_court'] = dark('РЕСПУБЛИКА НАГОРЬЕ', 'scales', ['Верховный суд', 'Республики Нагорье'])
    made['plate2_fsb'] = dark('ФЕДЕРАЛЬНАЯ СЛУЖБА БЕЗОПАСНОСТИ', 'sword', ['Управление ФСБ России', 'по Республике Нагорье'], plate=(46, 24, 28))
    made['plate2_bank'] = dark('НАГОРЬЕ-БАНК', 'mountains', ['Акционерный банк', '«Нагорье-Банк»'], plate=(30, 40, 56))
    # военкомат и МЧС — под стеклом, как на фото военкомата
    vm, vh, vf = glass_plate('ВС', 'РФ', 'army', ['ВОЕННЫЙ КОМИССАРИАТ', 'РЕСПУБЛИКИ НАГОРЬЕ', 'И ГОРОДА НАГОРСК'],
                             [('РАСПОРЯДОК РАБОТЫ: ПН.–ЧТ. 9.00–18.00, ПТ. 9.00–16.45', 52), ('ПРИЁМ ГРАЖДАН: ПН., СР. 10.00–17.00', 52), ('ОБЕДЕННЫЙ ПЕРЕРЫВ 13.00–14.00', 44)],
                             bg=(176, 22, 26), bg2=(190, 30, 34), gold=(242, 206, 90))
    made['plate2_voenkomat'], made['plate2_voenkomat_hours'] = vm, vh
    mm, mh, mf = glass_plate('МЧС', 'РФ', 'star', ['ГЛАВНОЕ УПРАВЛЕНИЕ МЧС РОССИИ', 'ПО РЕСПУБЛИКЕ НАГОРЬЕ', 'ПОЖАРНО-СПАСАТЕЛЬНАЯ ЧАСТЬ № 1'],
                             [('ДЕЖУРНАЯ СЛУЖБА — КРУГЛОСУТОЧНО', 60), ('ТЕЛЕФОН: 101, 112', 56)], bg=(196, 70, 20), bg2=(206, 82, 28), gold=(255, 236, 200))
    made['plate2_mchs'], made['plate2_mchs_hours'] = mm, mh
    for name, im in made.items():
        im.convert('RGB').save(out / f'{name}.png', optimize=True)
    for name in ('plate2_mvd', 'plate2_mreo', 'plate2_hospital', 'plate2_gov', 'plate2_court', 'plate2_fsb', 'plate2_bank'):
        mount(made[name], name)
    mount(vf, 'plate2_voenkomat')
    mount(mf, 'plate2_mchs')
    print('готово:', len(made), 'табличек, примерка в', prev)
