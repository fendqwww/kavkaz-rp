"""KAVKAZ RP: дорожные знаки России по ГОСТ Р 52290 (по таблице, которую прислал основатель 11.11.2026).
python setup/retex/road_signs.py → resources/[kavkaz]/kavkaz_world/images/retex/gost_*.png (512×512, прозрачный фон) и
kavkaz_world/signs_list.lua. знаки рисуются строго по геометрии ГОСТ (доли от размера), цвета — RAL из ГОСТ:
красный 3020, синий 5017, жёлтый 1023, белый, чёрный. в игре ими заменяются американские знаки (Config.Textures)
или их наносят на свои модели столбов (docs/tasks/2026-11-11-signs-lights.md).
"""
import math
import pathlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

root = pathlib.Path(__file__).resolve().parents[2]
out = root / 'resources' / '[kavkaz]' / 'kavkaz_world' / 'images' / 'retex'
out.mkdir(parents=True, exist_ok=True)
FONT = str(pathlib.Path(__file__).resolve().parent / 'fonts' / 'PTSansNarrow-Bold.ttf')

RED = (196, 22, 28, 255)
BLUE = (0, 76, 152, 255)
YEL = (245, 196, 0, 255)
WHITE = (250, 250, 250, 255)
BLACK = (20, 20, 20, 255)
GREY = (120, 120, 120, 255)
S = 512
K = 4  # рисуем в 4 раза крупнее и уменьшаем — ровные края
names = []


def canvas():
    return Image.new('RGBA', (S * K, S * K), (0, 0, 0, 0))


def finish(img, name):
    img = img.resize((S, S), Image.LANCZOS)
    # чуть-чуть «жизни»: ровная заливка выглядит как картинка, а не как знак — добавим едва заметную зернистость плёнки
    a = np.asarray(img).astype(float)
    n = np.random.default_rng(len(name)).normal(0, 3.0, a.shape[:2])[..., None]
    a[..., :3] = (a[..., :3] + n).clip(0, 255)
    Image.fromarray(a.astype('uint8'), 'RGBA').save(out / f'gost_{name}.png', optimize=True)
    names.append(f'gost_{name}')
    print('готово:', name)


def P(x, y):
    return (x * S * K, y * S * K)


def circle(d, r, fill, cx=0.5, cy=0.5):
    d.ellipse([P(cx - r, cy - r), P(cx + r, cy + r)], fill=fill)


def text(img, s, cx, cy, h, fill):
    d = ImageDraw.Draw(img)
    size = int(h * S * K * 1.35)
    f = ImageFont.truetype(FONT, size)
    d.text(P(cx, cy), s, font=f, fill=fill, anchor='mm')


def arrow(d, x0, y0, x1, y1, w, head, fill):
    """стрелка по ГОСТ: ствол ширины w, наконечник-треугольник длиной head"""
    ang = math.atan2(y1 - y0, x1 - x0)
    ux, uy = math.cos(ang), math.sin(ang)
    px, py = -uy, ux
    bx, by = x1 - ux * head, y1 - uy * head
    d.polygon([P(x0 + px * w / 2, y0 + py * w / 2), P(bx + px * w / 2, by + py * w / 2), P(bx + px * head * 0.62, by + py * head * 0.62),
               P(x1, y1), P(bx - px * head * 0.62, by - py * head * 0.62), P(bx - px * w / 2, by - py * w / 2), P(x0 - px * w / 2, y0 - py * w / 2)], fill=fill)


def pedestrian(d, cx, cy, h, fill):
    """пешеход как на знаках 5.19 и 1.22: голова, корпус, шаг"""
    def L(a, b, w):
        d.line([P(*a), P(*b)], fill=fill, width=int(w * S * K))
        for q in (a, b):
            circle(d, w / 2, fill, *q)
    circle(d, h * 0.08, fill, cx + h * 0.02, cy - h * 0.40)
    L((cx, cy - h * 0.28), (cx - h * 0.04, cy + h * 0.05), h * 0.13)          # корпус
    L((cx - h * 0.04, cy + h * 0.05), (cx - h * 0.20, cy + h * 0.44), h * 0.09)  # нога назад
    L((cx - h * 0.04, cy + h * 0.05), (cx + h * 0.16, cy + h * 0.44), h * 0.09)  # нога вперёд
    L((cx, cy - h * 0.22), (cx - h * 0.20, cy - h * 0.02), h * 0.07)          # рука назад
    L((cx, cy - h * 0.22), (cx + h * 0.18, cy - h * 0.05), h * 0.07)          # рука вперёд


# ---------------------------------------------------------------- 2. знаки приоритета
def sign_2_1():  # главная дорога
    img = canvas(); d = ImageDraw.Draw(img)
    d.polygon([P(0.5, 0.02), P(0.98, 0.5), P(0.5, 0.98), P(0.02, 0.5)], fill=WHITE)
    d.polygon([P(0.5, 0.05), P(0.95, 0.5), P(0.5, 0.95), P(0.05, 0.5)], fill=BLACK)
    d.polygon([P(0.5, 0.07), P(0.93, 0.5), P(0.5, 0.93), P(0.07, 0.5)], fill=WHITE)
    d.polygon([P(0.5, 0.22), P(0.78, 0.5), P(0.5, 0.78), P(0.22, 0.5)], fill=YEL)
    finish(img, '2_1')


def sign_2_2():  # конец главной дороги
    img = canvas(); d = ImageDraw.Draw(img)
    d.polygon([P(0.5, 0.02), P(0.98, 0.5), P(0.5, 0.98), P(0.02, 0.5)], fill=WHITE)
    d.polygon([P(0.5, 0.05), P(0.95, 0.5), P(0.5, 0.95), P(0.05, 0.5)], fill=BLACK)
    d.polygon([P(0.5, 0.07), P(0.93, 0.5), P(0.5, 0.93), P(0.07, 0.5)], fill=WHITE)
    d.polygon([P(0.5, 0.22), P(0.78, 0.5), P(0.5, 0.78), P(0.22, 0.5)], fill=YEL)
    for t in (-0.07, -0.025, 0.02, 0.065):
        d.line([P(0.26 + t, 0.30 + t), P(0.70 + t, 0.74 + t)], fill=BLACK, width=int(0.022 * S * K))
    finish(img, '2_2')


def sign_2_4():  # уступите дорогу
    img = canvas(); d = ImageDraw.Draw(img)
    d.polygon([P(0.02, 0.08), P(0.98, 0.08), P(0.5, 0.92)], fill=RED)
    d.polygon([P(0.17, 0.165), P(0.83, 0.165), P(0.5, 0.74)], fill=WHITE)
    finish(img, '2_4')


def sign_2_5():  # движение без остановки запрещено (STOP — по ГОСТ латиницей)
    img = canvas(); d = ImageDraw.Draw(img)
    pts = [P(0.5 + 0.48 * math.cos(math.radians(22.5 + i * 45)), 0.5 + 0.48 * math.sin(math.radians(22.5 + i * 45))) for i in range(8)]
    d.polygon(pts, fill=WHITE)
    pts = [P(0.5 + 0.45 * math.cos(math.radians(22.5 + i * 45)), 0.5 + 0.45 * math.sin(math.radians(22.5 + i * 45))) for i in range(8)]
    d.polygon(pts, fill=RED)
    text(img, 'STOP', 0.5, 0.5, 0.26, WHITE)
    finish(img, '2_5')


# ---------------------------------------------------------------- 3. запрещающие
def ring(d, fill=WHITE):
    circle(d, 0.48, RED)
    circle(d, 0.38, fill)


def sign_3_1():  # въезд запрещён
    img = canvas(); d = ImageDraw.Draw(img)
    circle(d, 0.48, RED)
    d.rectangle([P(0.14, 0.43), P(0.86, 0.57)], fill=WHITE)
    finish(img, '3_1')


def sign_3_2():  # движение запрещено
    img = canvas(); d = ImageDraw.Draw(img)
    ring(d)
    finish(img, '3_2')


def sign_speed(v):  # 3.24 ограничение максимальной скорости
    img = canvas(); d = ImageDraw.Draw(img)
    ring(d)
    text(img, str(v), 0.5, 0.515, 0.34 if v < 100 else 0.28, BLACK)
    finish(img, f'3_24_{v}')


def sign_3_25(v):  # конец ограничения
    img = canvas(); d = ImageDraw.Draw(img)
    circle(d, 0.48, BLACK)
    circle(d, 0.465, WHITE)
    text(img, str(v), 0.5, 0.515, 0.34, GREY)
    d.line([P(0.17, 0.83), P(0.83, 0.17)], fill=BLACK, width=int(0.05 * S * K))
    finish(img, f'3_25_{v}')


def sign_3_27():  # остановка запрещена
    img = canvas(); d = ImageDraw.Draw(img)
    circle(d, 0.48, RED)
    circle(d, 0.38, BLUE)
    for a, b in ((P(0.23, 0.23), P(0.77, 0.77)), (P(0.77, 0.23), P(0.23, 0.77))):
        d.line([a, b], fill=RED, width=int(0.10 * S * K))
    finish(img, '3_27')


def sign_3_28():  # стоянка запрещена
    img = canvas(); d = ImageDraw.Draw(img)
    circle(d, 0.48, RED)
    circle(d, 0.38, BLUE)
    d.line([P(0.23, 0.23), P(0.77, 0.77)], fill=RED, width=int(0.10 * S * K))
    finish(img, '3_28')


# ---------------------------------------------------------------- 4. предписывающие
def blue_disc(d):
    circle(d, 0.48, WHITE)
    circle(d, 0.46, BLUE)


def sign_4_1(name, x0, y0, x1, y1):
    img = canvas(); d = ImageDraw.Draw(img)
    blue_disc(d)
    arrow(d, x0, y0, x1, y1, 0.13, 0.22, WHITE)
    finish(img, name)


def sign_4_3():  # круговое движение: три дуги-стрелки против часовой стрелки
    img = canvas(); d = ImageDraw.Draw(img)
    blue_disc(d)
    r, w = 0.235, 0.075
    for i in range(3):
        start = -90 + i * 120 + 85   # градусы на экране (ось y вниз)
        end = start - 80             # едем против часовой — угол уменьшается
        d.arc([P(0.5 - r, 0.5 - r), P(0.5 + r, 0.5 + r)], end + 14, start, fill=WHITE, width=int(w * S * K))
        t = math.radians(end)
        hx, hy = 0.5 + r * math.cos(t), 0.5 + r * math.sin(t)
        tx, ty = math.sin(t), -math.cos(t)        # направление движения в конце дуги
        nx, ny = -ty, tx
        L, Wd = 0.13, 0.085
        bx, by = hx - tx * L * 0.35, hy - ty * L * 0.35
        d.polygon([P(bx + tx * L, by + ty * L), P(bx + nx * Wd, by + ny * Wd), P(bx - nx * Wd, by - ny * Wd)], fill=WHITE)
    finish(img, '4_3')


# ---------------------------------------------------------------- 5 и 6. особые предписания и информационные
def blue_square(d, white_inner=False):
    d.rounded_rectangle([P(0.03, 0.03), P(0.97, 0.97)], radius=0.06 * S * K, fill=WHITE)
    d.rounded_rectangle([P(0.05, 0.05), P(0.95, 0.95)], radius=0.05 * S * K, fill=BLUE)


def sign_5_19():  # пешеходный переход
    img = canvas(); d = ImageDraw.Draw(img)
    blue_square(d)
    d.polygon([P(0.5, 0.11), P(0.89, 0.86), P(0.11, 0.86)], fill=WHITE)
    for i in range(4):  # «зебра» под ногами
        d.polygon([P(0.30 + i * 0.11, 0.79), P(0.36 + i * 0.11, 0.79), P(0.35 + i * 0.11, 0.83), P(0.29 + i * 0.11, 0.83)], fill=BLACK)
    pedestrian(d, 0.52, 0.55, 0.50, BLACK)
    finish(img, '5_19_1')


def sign_6_4():  # парковка
    img = canvas(); d = ImageDraw.Draw(img)
    blue_square(d)
    text(img, 'P', 0.5, 0.5, 0.58, WHITE)
    finish(img, '6_4')


def sign_5_16():  # остановка автобуса — на синем квадрате белый прямоугольник с буквой «А»
    img = canvas(); d = ImageDraw.Draw(img)
    blue_square(d)
    d.rectangle([P(0.2, 0.2), P(0.8, 0.8)], fill=WHITE)
    text(img, 'А', 0.5, 0.5, 0.42, BLACK)
    finish(img, '5_16')


def sign_1_11(right=True):  # опасный поворот
    img = canvas(); d = ImageDraw.Draw(img)
    d.polygon([P(0.5, 0.06), P(0.98, 0.9), P(0.02, 0.9)], fill=RED)
    d.polygon([P(0.5, 0.20), P(0.86, 0.83), P(0.14, 0.83)], fill=WHITE)
    sx = 1 if right else -1
    d.line([P(0.5 - sx * 0.03, 0.78), P(0.5 - sx * 0.03, 0.56)], fill=BLACK, width=int(0.06 * S * K))
    arrow(d, 0.5 - sx * 0.03, 0.58, 0.5 + sx * 0.14, 0.40, 0.06, 0.12, BLACK)
    finish(img, '1_11_1' if right else '1_11_2')


def sign_1_22():  # пешеходный переход (предупреждающий)
    img = canvas(); d = ImageDraw.Draw(img)
    d.polygon([P(0.5, 0.06), P(0.98, 0.9), P(0.02, 0.9)], fill=RED)
    d.polygon([P(0.5, 0.20), P(0.86, 0.83), P(0.14, 0.83)], fill=WHITE)
    for i in range(4):
        d.rectangle([P(0.31 + i * 0.1, 0.75), P(0.36 + i * 0.1, 0.79)], fill=BLACK)
    pedestrian(d, 0.51, 0.58, 0.36, BLACK)
    finish(img, '1_22')


def sign_city(name, title, end=False):  # 5.23.1 / 5.24.1 — населённый пункт (белый, чёрная кайма), 2:1 внутри квадрата
    img = canvas(); d = ImageDraw.Draw(img)
    d.rounded_rectangle([P(0.02, 0.26), P(0.98, 0.74)], radius=0.04 * S * K, fill=BLACK)
    d.rounded_rectangle([P(0.035, 0.275), P(0.965, 0.725)], radius=0.035 * S * K, fill=WHITE)
    f = ImageFont.truetype(FONT, int(0.20 * S * K))
    while ImageDraw.Draw(img).textlength(title, font=f) > 0.84 * S * K:
        f = ImageFont.truetype(FONT, f.size - 8)
    d.text(P(0.5, 0.5), title, font=f, fill=BLACK, anchor='mm')
    if end:
        d.line([P(0.08, 0.68), P(0.92, 0.32)], fill=RED, width=int(0.035 * S * K))
    finish(img, name)


sign_2_1(); sign_2_2(); sign_2_4(); sign_2_5()
sign_3_1(); sign_3_2(); sign_3_27(); sign_3_28()
for v in (20, 40, 60, 90): sign_speed(v)
sign_3_25(60)
sign_4_1('4_1_1', 0.5, 0.80, 0.5, 0.18)
sign_4_1('4_1_2', 0.20, 0.5, 0.82, 0.5)
sign_4_1('4_1_3', 0.80, 0.5, 0.18, 0.5)
sign_4_1('4_2_1', 0.28, 0.28, 0.74, 0.74)
sign_4_3()
sign_5_19(); sign_6_4(); sign_5_16()
sign_1_11(True); sign_1_11(False); sign_1_22()
sign_city('5_23_nagorsk', 'НАГОРСК'); sign_city('5_24_nagorsk', 'НАГОРСК', end=True)
sign_city('5_23_lamyurt', 'ЛАМ-ЮРТ'); sign_city('5_23_peschany', 'ПЕСЧАНЫЙ')

(root / 'resources' / '[kavkaz]' / 'kavkaz_world' / 'signs_list.lua').write_text(
    '-- собрано setup/retex/road_signs.py — не править руками\nConfig.SignImages = {\n' + ''.join(f"    '{n}',\n" for n in names) + '}\n', encoding='utf-8')

# лист для просмотра
cols = 8
sheet = Image.new('RGB', (cols * 140 + 10, ((len(names) + cols - 1) // cols) * 150 + 10), (70, 74, 78))
for i, n in enumerate(names):
    im = Image.open(out / f'{n}.png').resize((128, 128), Image.LANCZOS)
    sheet.paste(im, (10 + (i % cols) * 140, 10 + (i // cols) * 150), im)
prev = pathlib.Path(__file__).resolve().parent / 'preview'
prev.mkdir(exist_ok=True)
sheet.save(prev / 'gost_signs.png')
print('всего знаков:', len(names))
