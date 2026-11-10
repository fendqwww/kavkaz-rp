"""KAVKAZ RP: нарисовать русские дорожные знаки и рекламные щиты для kavkaz_world.
картинки подменяют текстуры GTA прямо в игре (AddReplaceTexture), игровые файлы не трогаем.
запуск из корня репозитория: python setup/signs/make_signs.py
шрифт знаков — DejaVu Sans Bold (похож на дорожный), рекламы — Manrope (OFL, лежит в setup/signs/fonts)."""
import pathlib
from PIL import Image, ImageDraw, ImageFont

root = pathlib.Path(__file__).resolve().parents[2]
out = root / 'resources' / '[kavkaz]' / 'kavkaz_world' / 'images'
out.mkdir(parents=True, exist_ok=True)
fonts = pathlib.Path(__file__).resolve().parent / 'fonts'

ROAD = None
for cand in ('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 'C:/Windows/Fonts/arialbd.ttf'):
    if pathlib.Path(cand).exists():
        ROAD = cand
        break
ROAD = ROAD or str(fonts / 'Manrope-800.ttf')
BOLD = str(fonts / 'Manrope-800.ttf')
MED = str(fonts / 'Manrope-500.ttf')

# цвета по ГОСТ Р 52290 (приблизительно)
BLUE = (0, 84, 166)
GREEN = (0, 120, 70)
WHITE = (255, 255, 255)
BLACK = (20, 20, 20)
RED = (200, 30, 35)
EMERALD = (47, 191, 138)
GOLD = (227, 179, 65)
DARK = (15, 20, 18)


def font(path, size):
    return ImageFont.truetype(path, size)


def fit(draw, text, path, max_w, size):
    while size > 8:
        f = font(path, size)
        if draw.textlength(text, font=f) <= max_w:
            return f
        size -= 2
    return font(path, size)


def frame(img, color, width, radius, inset=0):
    d = ImageDraw.Draw(img)
    w, h = img.size
    d.rounded_rectangle([inset, inset, w - 1 - inset, h - 1 - inset], radius=radius, outline=color, width=width)


def save(img, name):
    img.convert('RGB').save(out / f'{name}.png', optimize=True)
    print('готово:', name)


# 5.23.1 начало населённого пункта: белый фон, чёрная кайма, чёрные буквы
def city_sign(name, title, end=False):
    img = Image.new('RGB', (1024, 512), WHITE)
    d = ImageDraw.Draw(img)
    frame(img, BLACK, 22, 40, 18)
    f = fit(d, title, ROAD, 860, 190)
    d.text((512, 256), title, font=f, fill=BLACK, anchor='mm')
    if end:  # 5.24.1 конец: красная полоса наискось
        d.line([(110, 430), (914, 82)], fill=RED, width=44)
    save(img, name)


# 6.9.1 предварительный указатель направлений: синий фон, белые стрелки и названия
def direction_sign(name, rows, bg=BLUE):
    img = Image.new('RGB', (1024, 512), bg)
    d = ImageDraw.Draw(img)
    frame(img, WHITE, 12, 30, 14)
    y = 70
    step = (512 - 140) // max(1, len(rows))
    for arrow, text, km in rows:
        fa = font(ROAD, 96)
        d.text((80, y + step // 2), arrow, font=fa, fill=WHITE, anchor='lm')
        ft = fit(d, text, ROAD, 600, 80)
        d.text((200, y + step // 2), text, font=ft, fill=WHITE, anchor='lm')
        if km:
            fk = font(ROAD, 74)
            d.text((950, y + step // 2), km, font=fk, fill=WHITE, anchor='rm')
        y += step
    save(img, name)


# рекламный щит 2:1 в стиле KAVKAZ: тёмный фон, изумрудная полоса, золотая подпись, крупный знак справа
def billboard(name, title, sub, mark, accent=EMERALD):
    w, h = 2048, 1024
    img = Image.new('RGB', (w, h), DARK)
    d = ImageDraw.Draw(img)
    # мягкий свет справа
    for i in range(60):
        r = 900 - i * 14
        c = tuple(int(DARK[k] + (accent[k] - DARK[k]) * (i / 60) * 0.18) for k in range(3))
        d.ellipse([1700 - r, 512 - r, 1700 + r, 512 + r], fill=c)
    d.rectangle([0, 0, 36, h], fill=accent)
    d.text((120, 150), 'KAVKAZ RP · НАГОРЬЕ', font=font(BOLD, 58), fill=accent, anchor='lm')
    ft = fit(d, title, BOLD, 1020, 190)
    d.text((120, 470), title, font=ft, fill=WHITE, anchor='lm')
    fs = fit(d, sub, MED, 1020, 74)
    d.text((120, 680), sub, font=fs, fill=GOLD, anchor='lm')
    fm = fit(d, mark, BOLD, 560, 400)
    d.text((1700, 512), mark, font=fm, fill=accent, anchor='mm')
    save(img, name)


city_sign('city_nagorsk', 'НАГОРСК')
city_sign('city_nagorsk_end', 'НАГОРСК', end=True)
city_sign('city_lamyurt', 'ЛАМ-ЮРТ')
city_sign('city_sedayurt', 'СЕДА-ЮРТ')
city_sign('city_peschany', 'ПЕСЧАНЫЙ')

direction_sign('dir_city', [('↑', 'Нагорск-Сити', '2'), ('→', 'Аэропорт', '9'), ('←', 'Набережная', '4')])
direction_sign('dir_north', [('↑', 'Песчаный', '45'), ('↗', 'Лам-Юрт', '120'), ('←', 'Седа-Юрт', '70')])
direction_sign('dir_highway', [('↑', 'Р-217 «Кавказ»', ''), ('↑', 'Лам-Юрт', '120'), ('→', 'Нагорск', '8')], bg=GREEN)

billboard('ad_motors', 'Нагорье Моторс', 'Приора, Камри, Крузак — в наличии', 'АВТО')
billboard('ad_hazard', 'Хазард 7007', 'СГУ для настоящих · гараж Бислана', '7007', GOLD)
billboard('ad_shawarma', 'Шаурма у Расула', 'у автовокзала · 350 ₽ · круглосуточно', '350 ₽')
billboard('ad_tv', 'Нагорье-ТВ', 'только то, что было на самом деле', 'ТВ')
billboard('ad_chaikhana', 'Чайхана «У Румисы»', 'жижиг-галнаш, чепалгаш, чай с чабрецом', 'ЧАЙ', GOLD)
billboard('ad_dps', 'Пристегнись', 'ДПС Нагорья: ремень спасает жизнь', 'ДПС')
