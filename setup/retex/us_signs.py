"""KAVKAZ RP: американские дорожные знаки GTA → знаки ГОСТ (gost_*.png из road_signs.py).

у каждого знака GTA своя табличка: квадрат, прямоугольник, ромб (повёрнут на 45°), иногда зеркальная развёртка.
us_signs_geom.json — как текстура лежит на табличке (вектора a, b: куда в мире идут +u и +v), вытащено из файлов игры
скриптом Blender + Sollumz (только числа, моделей и текстур игры в репозитории нет).
скрипт рисует для каждой таблички текстуру, на которой наш знак стоит в мире ровно, не растянут и влезает целиком.
выход: kavkaz_world/images/retex/us_*.png и kavkaz_world/us_signs_list.lua (Config.UsSignImages, Config.UsSigns).
python setup/retex/us_signs.py
"""
import hashlib
import json
import pathlib

import numpy as np
from PIL import Image, ImageDraw

here = pathlib.Path(__file__).resolve().parent
root = here.parents[1]
world = root / 'resources' / '[kavkaz]' / 'kavkaz_world'
img_dir = world / 'images' / 'retex'
GEOM = json.load(open(here / 'us_signs_geom.json', encoding='utf-8'))

PLATE = (168, 172, 174)   # оцинкованная табличка вокруг круглого знака
WHITE = (250, 250, 250)
BLUE = (0, 76, 152)

# модель GTA, имя текстуры в ней, наш знак, (ширина, высота) текстуры, фон
# фон 'shape' — табличка повторяет форму знака (восьмиугольник STOP, треугольник «уступи»): поля белые, без отступа
SPEED = {'5': '20', '15': '20', '25': '40', '35': '60', '50': '90', '60': '90', 'exit_25': '40', 'exit_55': '90',
         'ramp': '60', 'trucks_5': '20', 'trucks_20': '40', 'trucks_45': '60', 'trucks_55': '90', 'school': '20'}
MAP = [
    ('prop_sign_road_01a', 'prop_sign_road_stop_01', 'gost_2_5', (256, 256), 'shape'),
    ('prop_sign_road_01b', 'prop_sign_road_stop_01', 'gost_2_5', (256, 256), 'shape'),
    ('prop_sign_road_02a', 'prop_sign_road_yield_01', 'gost_2_4', (256, 256), 'shape'),
    ('prop_sign_road_03a', 'prop_sign_road_donotenter_01', 'gost_3_1', (256, 256), 'plate'),
    ('prop_sign_road_03b', 'prop_sign_road_donotenter_01', 'gost_3_1', (256, 256), 'plate'),
    ('prop_sign_road_03c', 'prop_sign_road_alltraffic_01', 'gost_4_1_2', (256, 256), 'plate'),
    ('prop_sign_road_03f', 'prop_sign_road_keepright_01', 'gost_4_2_1', (256, 256), 'plate'),
    ('prop_sign_road_03g', 'prop_sign_road_keepright_02', 'gost_4_2_1', (128, 128), 'plate'),
    ('prop_sign_road_03q', 'prop_sign_road_roadclosed_01', 'gost_3_2', (256, 256), 'plate'),
    ('prop_sign_road_04a', 'prop_sign_road_parking_16', 'gost_3_28', (128, 256), 'plate'),
    ('prop_sign_road_04r', 'prop_sign_road_parking_01', 'gost_3_27', (256, 256), 'plate'),
    ('prop_sign_road_04w', 'prop_sign_road_parking_02', 'gost_3_28', (256, 256), 'plate'),
    ('prop_sign_road_04x', 'prop_sign_road_parking_03', 'gost_3_27', (256, 256), 'plate'),
    ('prop_sign_road_04y', 'prop_sign_road_parking_09', 'gost_6_4', (64, 128), 'plate'),
    ('prop_sign_road_04y', 'prop_sign_road_parking_17', 'gost_3_28', (128, 256), 'plate'),
    ('prop_sign_road_04z', 'prop_sign_road_parking_10', 'gost_6_4', (128, 256), 'plate'),
    ('prop_sign_road_05a', 'prop_sign_road_pedxing_01', 'gost_1_22', (256, 256), 'plate'),
    ('prop_sign_road_05b', 'prop_sign_road_pedxing_02', 'gost_1_22', (128, 128), 'plate'),
    ('prop_sign_road_05c', 'prop_sign_road_45arrow_01', 'curve', (256, 256), 'plate'),
    ('prop_sign_road_05d', 'prop_sign_road_45arrow_01', 'curve', (256, 256), 'plate'),
    ('prop_sign_road_05e', 'prop_sign_road_90arrow_01', 'curve', (256, 256), 'plate'),
    ('prop_sign_road_05f', 'prop_sign_road_90arrow_01', 'curve', (256, 256), 'plate'),
    ('prop_sign_road_05x', 'prop_sign_road_windingroad_01', 'gost_1_11_1', (256, 256), 'plate'),
    ('prop_sign_road_05y', 'prop_sign_road_windingroad_02', 'gost_1_11_2', (256, 256), 'plate'),
    ('prop_sign_road_07a', 'prop_sign_road_oneway_01', 'oneway_up', (64, 128), 'paint'),
    ('prop_sign_road_07b', 'prop_sign_road_oneway_02', 'oneway_down', (64, 128), 'paint'),
]
SPEED_MODELS = {'5': '06b', '25': '06d', '35': '06e', '50': '06f', '60': '06g', 'exit_25': '06i', 'exit_55': '06j',
                'ramp': '06k', 'school': '06l', 'trucks_5': '06m', 'trucks_20': '06n', 'trucks_45': '06o', 'trucks_55': '06p'}
SMALL = {'school', 'trucks_20'}
for k, m in SPEED_MODELS.items():
    MAP.append((f'prop_sign_road_{m}', f'prop_sign_speed_{k}', f'gost_3_24_{SPEED[k]}', (128, 128) if k in SMALL else (256, 256), 'plate'))
for m in ('06a', '06c'):
    MAP.append((f'prop_sign_road_{m}', 'prop_sign_speed_15', 'gost_3_24_20', (256, 256), 'plate'))


def frame(a, b):
    """матрица (u-0.5, v-0.5) → (вправо, вверх) в метрах на табличке; flip — развёртка зеркальная (смотрим с другой стороны)"""
    a, b = np.array(a, float), np.array(b, float)
    hx = a[:2] if np.hypot(*a[:2]) >= np.hypot(*b[:2]) else b[:2]
    e = hx / np.hypot(*hx)
    M = np.array([[a[:2] @ e, b[:2] @ e], [a[2], b[2]]])
    flip = np.linalg.det(M) > 0  # без зеркала: u → вправо, v → вниз, det < 0
    if flip:
        M[0] *= -1
    return M, flip


def render(src, M, size, bg, margin):
    """src — RGBA знак (квадрат, прозрачный фон); рисуем его в текстуру так, чтобы в мире он стоял ровно"""
    W, H = size
    SS = 4
    s = np.asarray(src)[..., 3] > 128
    ys, xs = np.nonzero(s)
    n = src.size[0]
    pts = np.stack([(xs + 0.5) / n - 0.5, 0.5 - (ys + 0.5) / n])  # (вправо, вверх) в долях знака
    Mi = np.linalg.inv(M)
    w = Mi @ pts  # uv-0.5 на метр размера знака
    Sz = (0.5 - margin) / np.abs(w).max()  # самый большой знак, который влезает в табличку
    # аффинное преобразование: пиксель выхода (x, y) → пиксель знака
    # u = (x+0.5)/(W*SS), v = (y+0.5)/(H*SS); (r, up) = M (u-.5, v-.5); sx = (0.5 + r/Sz) n, sy = (0.5 - up/Sz) n
    A = np.zeros((2, 3))
    du = np.array([1 / (W * SS), 0]); dv = np.array([0, 1 / (H * SS)])
    c0 = np.array([0.5 / (W * SS) - 0.5, 0.5 / (H * SS) - 0.5])

    def to_src(uv):
        r, up = M @ uv
        return np.array([(0.5 + r / Sz) * n, (0.5 - up / Sz) * n])
    o = to_src(c0)
    A[:, 0] = to_src(c0 + du) - o
    A[:, 1] = to_src(c0 + dv) - o
    A[:, 2] = o
    big = src.transform((W * SS, H * SS), Image.AFFINE, tuple(A.flatten()), resample=Image.BICUBIC, fillcolor=(0, 0, 0, 0))
    out = Image.new('RGBA', big.size, bg + (255,))
    out.alpha_composite(big)
    return out.resize((W, H), Image.LANCZOS)


def oneway(size, up):
    """ГОСТ 5.7.1/5.7.2 «выезд на дорогу с односторонним движением»: синяя табличка, белая стрелка вдоль длинной стороны"""
    W, H = size
    K = 8
    im = Image.new('RGBA', (W * K, H * K), WHITE + (255,))
    d = ImageDraw.Draw(im)
    bw = int(W * K * 0.07)
    d.rectangle([bw, bw, W * K - bw, H * K - bw], fill=BLUE + (255,))
    cx = W * K / 2
    sw, hw, hl = W * K * 0.16, W * K * 0.34, H * K * 0.18
    top, bot = H * K * 0.12, H * K * 0.88
    if up:
        d.rectangle([cx - sw, top + hl * 0.9, cx + sw, bot], fill=WHITE + (255,))
        d.polygon([(cx, top), (cx - hw, top + hl), (cx + hw, top + hl)], fill=WHITE + (255,))
    else:
        d.rectangle([cx - sw, top, cx + sw, bot - hl * 0.9], fill=WHITE + (255,))
        d.polygon([(cx, bot), (cx - hw, bot - hl), (cx + hw, bot - hl)], fill=WHITE + (255,))
    return im.resize((W, H), Image.LANCZOS)


def grain(im, seed):
    a = np.asarray(im).astype(float)
    n = np.random.default_rng(seed).normal(0, 3.0, a.shape[:2])[..., None]
    a[..., :3] = (a[..., :3] + n).clip(0, 255)
    return Image.fromarray(a.astype('uint8'), 'RGBA')


def main():
    for f in img_dir.glob('us_*.png'):
        f.unlink()
    by_hash, rows, images = {}, [], []
    for model, txn, sign, size, bg in MAP:
        g = GEOM.get(f'{model}|{txn}')
        if not g:
            print('нет геометрии', model, txn)
            continue
        M, flip = frame(g[0]['a'], g[0]['b'])
        if sign.startswith('oneway'):
            im = oneway(size, sign == 'oneway_up')
        else:
            if sign == 'curve':
                # у американского знака стрелка уходит влево; на зеркальной развёртке — вправо
                sign = 'gost_1_11_1' if flip else 'gost_1_11_2'
            src = Image.open(img_dir / f'{sign}.png').convert('RGBA')
            if bg == 'shape':
                im = render(src, M, size, WHITE, 0.0)
            else:
                im = render(src, M, size, PLATE, 0.04)
            im = grain(im, 7)  # одинаковое зерно — одинаковые таблички склеиваются в одну картинку
        data = im.tobytes()
        h = hashlib.md5(data + bytes(str(im.size), 'ascii')).hexdigest()[:6]
        name = by_hash.get(h)
        if not name:
            name = f'us_{sign.replace("gost_", "")}_{h}'
            im.save(img_dir / f'{name}.png', optimize=True)
            by_hash[h] = name
            images.append(name)
        rows.append((model, txn, name))
        # STOP, «въезд запрещён» и «15» лежат ещё и в общем словаре v_signs (им пользуются другие модели знаков)
    for txn, sign in (('prop_sign_road_stop_01', 'gost_2_5'), ('prop_sign_road_donotenter_01', 'gost_3_1'),
                      ('prop_sign_speed_15', 'gost_3_24_20')):
        src = Image.open(img_dir / f'{sign}.png').convert('RGBA')
        M = np.array([[1.0, 0.0], [0.0, -1.0]])
        im = grain(render(src, M, (256, 256), WHITE if sign == 'gost_2_5' else PLATE, 0.0 if sign == 'gost_2_5' else 0.04), 7)
        h = hashlib.md5(im.tobytes()).hexdigest()[:6]
        name = by_hash.get(h) or f'us_{sign.replace("gost_", "")}_{h}'
        if name not in images:
            im.save(img_dir / f'{name}.png', optimize=True)
            by_hash[h] = name
            images.append(name)
        rows.append(('v_signs', txn, name))

    lua = ['-- собрано setup/retex/us_signs.py — не править руками',
           '-- американские знаки GTA → ГОСТ: txd (модель знака или общий словарь v_signs), txn (текстура), image (наша картинка)',
           'Config.UsSignImages = {']
    lua += [f"    '{n}'," for n in images]
    lua += ['}', '', 'Config.UsSigns = {']
    lua += [f"    {{ txd = '{m}', txn = '{t}', image = '{n}' }}," for m, t, n in rows]
    lua += ['}', '']
    (world / 'us_signs_list.lua').write_text('\n'.join(lua), encoding='utf-8')
    print(f'картинок {len(images)}, подмен {len(rows)}')


if __name__ == '__main__':
    main()
