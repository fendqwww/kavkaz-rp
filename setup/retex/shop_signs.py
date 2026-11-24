"""KAVKAZ RP: вывески магазинов, кафе, АЗС и фасадов — по фото настоящих вывесок (прислал основатель 11.11.2026):
  lightbox — световой короб с объёмными буквами (как «Народный продукт»);
  letters  — отдельные объёмные буквы на композитной панели (как «Шаурма #1», банк);
  banner   — баннер на люверсах (как «Шиномонтаж», «Avto Tuning»);
  fascia   — козырёк АЗС с цветными полосами (как на фото заправок).
python setup/retex/shop_signs.py → resources/[kavkaz]/kavkaz_world/images/retex/sign2_*.png (4:1), примерка — setup/retex/preview/.
старые плоские вывески из make_art.py (shop_*, cafe_*, facade_*) — заглушки, в игру не ставить.
шрифты — как на улицах: Russo One, Rubik Black, Lobster, Ruslan Display, Oswald (все OFL, setup/retex/fonts).
"""
import pathlib

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

from plates import lighting, noise  # те же фактуры и свет, что у табличек

root = pathlib.Path(__file__).resolve().parents[2]
out = root / 'resources' / '[kavkaz]' / 'kavkaz_world' / 'images' / 'retex'
prev = pathlib.Path(__file__).resolve().parent / 'preview'
prev.mkdir(exist_ok=True)
FD = pathlib.Path(__file__).resolve().parent / 'fonts'
RUSSO, RUBIK, LOBSTER, RUSLAN = (str(FD / n) for n in ('RussoOne-Regular.ttf', 'Rubik-Black.ttf', 'Lobster-Regular.ttf', 'RuslanDisplay-Regular.ttf'))
OSWALD, PTSANS, PTSERIF = (str(FD / n) for n in ('Oswald-SemiBold.ttf', 'PTSans-Bold.ttf', 'PTSerif-Bold.ttf'))
W, H = 2048, 512
WHITE = (250, 250, 248)
made = {}


def fit(s, path, max_w, size):
    d = ImageDraw.Draw(Image.new('L', (8, 8)))
    while size > 20:
        f = ImageFont.truetype(path, size)
        if d.textlength(s, font=f) <= max_w:
            return f
        size -= 4
    return ImageFont.truetype(path, size)


def text_mask(s, path, cx, cy, max_w, size, canvas=(W, H)):
    m = Image.new('L', canvas, 0)
    ImageDraw.Draw(m).text((cx, cy), s, font=fit(s, path, max_w, size), fill=255, anchor='mm')
    return m


def face(bg, glow=0.22, grain=0.5):
    """лицевая панель короба: акрил, подсвеченный изнутри — в середине светлее, к краям темнее, лёгкая неровность"""
    img = Image.new('RGB', (W, H), bg)
    y, x = np.mgrid[0:H, 0:W]
    lamp = 1 + glow * (np.cos((x / W - 0.5) * np.pi) * 0.6 + np.cos((y / H - 0.5) * np.pi) * 0.4) - glow * 0.5
    a = np.asarray(img).astype(float) * lamp[..., None]
    a *= (0.97 + 0.06 * np.asarray(noise(W, H, grain, 3)) / 255)[..., None]
    return Image.fromarray(a.clip(0, 255).astype('uint8'))


def box_frame(img, color=(170, 172, 176), w=14):
    """алюминиевый профиль короба"""
    d = ImageDraw.Draw(img)
    for i in range(w):
        t = i / w
        c = tuple(int(v * (1.12 - 0.35 * t)) for v in color)
        d.rectangle([i, i, W - 1 - i, H - 1 - i], outline=c)
    return img


def volume(img, mask, color=WHITE, depth=14, side=None, shadow=0.55):
    """объёмные буквы: тень на панели, боковина (борт), лицевая часть со светом сверху"""
    side = side or tuple(int(c * 0.62) for c in color)
    sh = ImageChops.offset(mask, depth + 10, depth + 14).filter(ImageFilter.GaussianBlur(9)).point(lambda v: int(v * shadow))
    img.paste((0, 0, 0), (0, 0), sh)
    for dpt in range(depth, 0, -1):
        k = 0.75 + 0.25 * (1 - dpt / depth)
        img.paste(tuple(int(c * k) for c in side), (0, 0), ImageChops.offset(mask, dpt, dpt))
    y = np.linspace(1.04, 0.93, H)[:, None, None]
    lit = (np.ones((H, W, 3)) * np.array(color) * y).clip(0, 255).astype('uint8')
    img.paste(Image.fromarray(lit), (0, 0), mask)
    hi = ImageChops.subtract(mask, ImageChops.offset(mask, 2, 3))
    img.paste((255, 255, 255), (0, 0), hi.point(lambda v: int(v * 0.5)))


def flat(img, mask, color, shadow=True):
    """плёнка (аппликация) на панели"""
    if shadow:
        img.paste((0, 0, 0), (0, 0), ImageChops.offset(mask, 3, 4).filter(ImageFilter.GaussianBlur(2)).point(lambda v: int(v * 0.35)))
    img.paste(color, (0, 0), mask)


def ornament(img, color, x0, x1, step=92):
    """наш горный орнамент вместо хохломы: ромбы и зубцы по краям короба"""
    d = ImageDraw.Draw(img)
    for x in range(x0, x1, step):
        cx, cy = x + step // 2, H // 2
        for r, wd in ((150, 10), (96, 8), (44, 0)):
            pts = [(cx, cy - r), (cx + r * 0.42, cy), (cx, cy + r), (cx - r * 0.42, cy)]
            if wd:
                d.line(pts + [pts[0]], fill=color, width=wd, joint='curve')
            else:
                d.polygon(pts, fill=color)
        for yy in (70, H - 70):
            d.polygon([(x + 8, yy + 24), (cx, yy - 24), (x + step - 8, yy + 24)] if yy < H / 2 else
                      [(x + 8, yy - 24), (cx, yy + 24), (x + step - 8, yy - 24)], fill=color)


def dirt(img, amount=0.10):
    """уличная пыль и потёки сверху вниз — чтобы не выглядело стерильно"""
    streak = noise(W // 6, 8, 1.0).resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(6))
    y = np.linspace(0.35, 1.0, H)[:, None]
    k = 1 - amount * (np.asarray(streak) / 255) * y
    a = np.asarray(img).astype(float) * k[..., None]
    return Image.fromarray(a.clip(0, 255).astype('uint8'))


def save(name, img):
    img = dirt(img.convert('RGB'))
    img.save(out / f'{name}.png', optimize=True)
    made[name] = img
    print('готово:', name)


# ---------------------------------------------------------------- виды вывесок
def lightbox(name, title, bg, font=RUSSO, fg=WHITE, sub=None, orn=None, size=300, title_w=None):
    img = face(bg)
    left, right = 70, W - 70
    if orn:
        ornament(img, orn, 60, 60 + 276)
        ornament(img, orn, W - 60 - 276, W - 60)
        left, right = 370, W - 370
    cy = H / 2 - (46 if sub else 0)
    volume(img, text_mask(title, font, (left + right) / 2, cy, title_w or (right - left), size), fg, depth=12)
    if sub:
        flat(img, text_mask(sub, PTSANS, (left + right) / 2, H - 92, right - left, 76), fg)
    save(name, box_frame(img))


def letters(name, title, panel, font=RUBIK, fg=WHITE, sub=None, sub_fg=None, badge=None, size=330, seams=True):
    """композитная панель (кассеты со швами) и отдельные объёмные буквы"""
    img = lighting(Image.composite(Image.new('RGB', (W, H), tuple(min(255, c + 8) for c in panel)), Image.new('RGB', (W, H), panel), noise(W, H, 0.5, 2)), 0.10)
    d = ImageDraw.Draw(img)
    if seams:
        for x in range(512, W, 512):
            d.line([(x, 0), (x, H)], fill=tuple(int(c * 0.72) for c in panel), width=4)
            d.line([(x + 4, 0), (x + 4, H)], fill=tuple(min(255, int(c * 1.12)) for c in panel), width=2)
    right = W - 110
    if badge:  # круглый объёмный знак справа: «24», «№1»
        txt, col, tc = badge
        bm = Image.new('L', (W, H), 0)
        ImageDraw.Draw(bm).ellipse([W - 420, 76, W - 60, 436], fill=255)
        volume(img, bm, col, depth=14)
        flat(img, text_mask(txt, RUBIK, W - 240, 256, 250, 210), tc, shadow=False)
        right = W - 470
    cy = H / 2 - (50 if sub else 0)
    volume(img, text_mask(title, font, (110 + right) / 2, cy, right - 110, size), fg, depth=16)
    if sub:
        flat(img, text_mask(sub, PTSANS, (110 + right) / 2, H - 88, right - 110, 72), sub_fg or fg)
    save(name, img)


def banner(name, title, bg, fg, sub=None, sub_fg=None, font=RUBIK, size=300):
    """баннер на люверсах: ткань чуть волнами, края подвёрнуты, кольца по периметру"""
    img = Image.new('RGB', (W, H), bg)
    wave = noise(24, 6, 1.0).resize((W, H), Image.BICUBIC)
    a = np.asarray(img).astype(float) * (0.90 + 0.2 * np.asarray(wave) / 255)[..., None] + 14 * (np.asarray(wave) / 255)[..., None]
    img = Image.fromarray(a.clip(0, 255).astype('uint8'))
    cy = H / 2 - (56 if sub else 0)
    flat(img, text_mask(title, font, W / 2, cy, W - 260, size), fg, shadow=False)
    if sub:
        flat(img, text_mask(sub, OSWALD, W / 2, H - 100, W - 260, 92), sub_fg or fg, shadow=False)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W - 1, H - 1], outline=tuple(int(c * 0.6) for c in bg), width=10)  # подворот
    xs = list(range(70, W - 40, 318))
    for x, y in [(x, 36) for x in xs] + [(x, H - 36) for x in xs] + [(36, H // 2), (W - 36, H // 2)]:
        d.ellipse([x - 20, y - 20, x + 20, y + 20], fill=(196, 198, 202))
        d.ellipse([x - 17, y - 17, x + 17, y + 17], fill=(120, 122, 126))
        d.ellipse([x - 10, y - 10, x + 10, y + 10], fill=(24, 24, 24))
    save(name, img)


def fascia(name, title, base, stripe1, stripe2, fg=WHITE, font=RUSSO):
    """козырёк АЗС: светлая панель, две цветные полосы понизу, название объёмными буквами"""
    img = face(base, glow=0.12)
    d = ImageDraw.Draw(img)
    d.rectangle([0, H - 150, W, H - 78], fill=stripe1)
    d.rectangle([0, H - 78, W, H], fill=stripe2)
    img = lighting(img, 0.08)
    volume(img, text_mask(title, font, W / 2, 180, W - 300, 250), fg, depth=12)
    save(name, box_frame(img, w=8))


# ---------------------------------------------------------------- вывески
RED, GREEN, NAVY, YEL = (196, 22, 30), (18, 122, 62), (16, 34, 78), (252, 200, 20)

lightbox('sign2_produkty', 'ПРОДУКТЫ 24', RED, font=RUSLAN, orn=(250, 196, 40), size=250)
lightbox('sign2_market', 'НАГОРЬЕ-МАРКЕТ', GREEN, sub='супермаркет · свежие продукты каждый день', size=230)
lightbox('sign2_gastronom', 'Гастроном', (120, 20, 34), font=LOBSTER, fg=(255, 236, 190), sub='мясо · сыры · выпечка', size=300)
lightbox('sign2_apteka', 'АПТЕКА', (238, 242, 240), fg=(14, 150, 76), sub='круглосуточно', size=300)
lightbox('sign2_napitki', 'НАПИТКИ', (24, 60, 140), sub='соки · воды · лимонады', size=280)
lightbox('sign2_ohota', 'ОХОТА И РЫБАЛКА', (44, 66, 36), fg=(255, 196, 70), size=230)
lightbox('sign2_police', 'ПОЛИЦИЯ', (16, 52, 150), size=330)
lightbox('sign2_dps', 'ДПС', (16, 52, 150), sub='пост дорожно-патрульной службы', size=280)
lightbox('sign2_hospital', 'ПРИЁМНОЕ ОТДЕЛЕНИЕ', (236, 240, 242), fg=(196, 22, 30), size=220)

letters('sign2_shaurma', 'ШАУРМА', RED, sub='у Расула · с 2009 года', badge=('№1', WHITE, RED))
letters('sign2_chaikhana', 'Чайхана', (20, 70, 60), font=LOBSTER, fg=(240, 204, 110), sub='«У Румисы» · чай · жижиг-галнаш · чепалгаш', sub_fg=(240, 204, 110), size=340)
letters('sign2_coffee', 'Кофейня «Горы»', (58, 40, 30), font=LOBSTER, fg=(250, 236, 214), size=300)
letters('sign2_bank', 'НАГОРЬЕ-БАНК', (28, 30, 34), font=RUSSO, fg=(226, 190, 100), sub='вклады · кредиты · банкоматы 24 часа', sub_fg=(226, 228, 232), size=250)
letters('sign2_avtovokzal', 'АВТОВОКЗАЛ', (228, 230, 232), font=RUSSO, fg=(16, 44, 110), sub='Нагорск', sub_fg=(16, 44, 110), size=290)
letters('sign2_motors', 'НАГОРЬЕ МОТОРС', (20, 22, 26), font=RUSSO, fg=WHITE, sub='автосалон · трейд-ин · тест-драйв', sub_fg=(47, 191, 138), size=240)

banner('sign2_shinomontazh', 'ШИНОМОНТАЖ', (14, 14, 14), (252, 220, 0), sub='24 ЧАСА · БАЛАНСИРОВКА · РЕМОНТ ДИСКОВ', sub_fg=(240, 120, 20))
banner('sign2_tuning', 'АВТОТЮНИНГ', (236, 110, 20), (16, 30, 90), sub='ТОНИРОВКА · ЧЕХЛЫ · ШУМОИЗОЛЯЦИЯ · АВТОЭЛЕКТРИК', sub_fg=WHITE)
banner('sign2_shashlyk', 'ШАШЛЫК', (120, 16, 16), (255, 214, 60), sub='НА УГЛЯХ · ЛЮЛЯ-КЕБАБ · ЛАВАШ · «МАНГАЛ»', sub_fg=WHITE)
banner('sign2_sto', 'СТО БИСЛАНА', (20, 44, 110), WHITE, sub='РЕМОНТ · СГУ · ПНЕВМОПОДВЕСКА', sub_fg=(252, 220, 0))

fascia('sign2_azs', 'НАГОРЬЕ-НЕФТЬ', (244, 246, 248), (236, 120, 20), (16, 60, 150), fg=(16, 60, 150))

(root / 'resources' / '[kavkaz]' / 'kavkaz_world' / 'signs2_list.lua').write_text(
    '-- собрано setup/retex/shop_signs.py — не править руками\nConfig.Sign2Images = {\n' + ''.join(f"    '{n}',\n" for n in made) + '}\n', encoding='utf-8')

# примерка: все вывески на кирпичной стене, чуть сбоку
names = list(made)
cols = 3
tw, th = 640, 160
sheet = Image.new('RGB', (cols * (tw + 36) + 36, ((len(names) + cols - 1) // cols) * (th + 44) + 44), (150, 96, 78))
sd = ImageDraw.Draw(sheet)
for yy in range(0, sheet.height, 26):  # кирпич
    sd.line([(0, yy), (sheet.width, yy)], fill=(122, 76, 62), width=2)
    for xx in range((yy // 26 % 2) * 40, sheet.width, 80):
        sd.line([(xx, yy), (xx, yy + 26)], fill=(122, 76, 62), width=2)
sheet = lighting(sheet, 0.22)
for i, n in enumerate(names):
    x, y = 36 + (i % cols) * (tw + 36), 44 + (i // cols) * (th + 44)
    sh = Image.new('L', sheet.size, 0)
    ImageDraw.Draw(sh).rectangle([x + 8, y + 12, x + tw + 8, y + th + 12], fill=170)
    sheet.paste((20, 14, 10), (0, 0), sh.filter(ImageFilter.GaussianBlur(8)))
    sheet.paste(made[n].resize((tw, th), Image.LANCZOS), (x, y))
sheet.save(prev / 'signs2_all.jpg', quality=90)
print('всего:', len(names))
