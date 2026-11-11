"""KAVKAZ RP: лицевая панель «Хазард 7007» — чёткая перерисовка (не фото). 2048x1408 + карта рельефа.
python -I setup/models/hazard_face.py <out_dir>
разметка — по пульту из роликов (жёлтая обводка, PREMIER HAZARD 7007, HILO/YELP/WAIL/STANDBY, PA MAN, RADIO HORN).
координаты ручек/кнопок/светодиодов отсюда же берёт make_hazard_blender.py (LAYOUT), чтобы всё совпадало.
"""
import json
import os
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 2048, 1408
BG = (38, 38, 40)
YEL = (236, 178, 38)
FONT = r'C:\Windows\Fonts\bahnschrift.ttf'

# доли ширины/высоты лицевой панели (0..1, y сверху вниз)
LAYOUT = {
    'knob_vol': (0.175, 0.30, 0.085),   # x, y, радиус (доля ширины)
    'knob_sel': (0.705, 0.32, 0.150),
    'btn_pa': (0.665, 0.855, 0.055),    # x, y, полуширина
    'btn_horn': (0.855, 0.855, 0.055),
    'led_l1': (0.665, 0.635, 0.012),
    'led_l2': (0.855, 0.635, 0.012),
    'rj45': (0.175, 0.80, 0.105, 0.135),  # x, y, полуширина, полувысота (доли W/H)
}


def font(size, style='Bold SemiCondensed'):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_name(style)
    except Exception:  # noqa
        pass
    return f


def P(x, y):
    return int(x * W), int(y * H)


def main(out):
    os.makedirs(out, exist_ok=True)
    img = Image.new('RGB', (W, H), BG)
    hgt = Image.new('L', (W, H), 128)  # рельеф: 128 — плоскость, светлее — выпукло
    d, hd = ImageDraw.Draw(img), ImageDraw.Draw(hgt)
    lw = 9

    def yline(pts, width=lw):
        d.line(pts, fill=YEL, width=width, joint='curve')
        hd.line(pts, fill=150, width=width, joint='curve')

    def text(xy, s, size, anchor='mm', style='Bold SemiCondensed', fill=YEL):
        f = font(size, style)
        d.text(xy, s, font=f, fill=fill, anchor=anchor)
        hd.text(xy, s, font=f, fill=150, anchor=anchor)

    def dot(x, y, r=14, fill=YEL):
        d.ellipse((x - r, y - r, x + r, y + r), fill=fill)
        hd.ellipse((x - r, y - r, x + r, y + r), fill=160)

    # внешняя жёлтая рамка
    m = 34
    d.rounded_rectangle((m, m, W - m, H - m), radius=70, outline=YEL, width=lw)
    hd.rounded_rectangle((m, m, W - m, H - m), radius=70, outline=150, width=lw)

    # нижняя ступенька: от левого края над разъёмом к табличке, вокруг кнопок буквой «U»
    y1 = int(0.60 * H)
    x_plate_l, x_plate_r = int(0.335 * W), int(0.555 * W)
    yline([(m, y1), (x_plate_l, y1), (x_plate_l, H - m)])
    # рамки-«стаканы» вокруг кнопок, открытые вниз к внешней рамке
    for key in ('btn_pa', 'btn_horn'):
        bx, by, bw = LAYOUT[key]
        x0b, x1b, yt = int((bx - 0.082) * W), int((bx + 0.082) * W), int(0.735 * H)
        yline([(x0b, H - m), (x0b, yt + 30)])
        yline([(x1b, H - m), (x1b, yt + 30)])
        d.arc((x0b, yt, x0b + 60, yt + 60), 180, 270, fill=YEL, width=lw)
        d.arc((x1b - 60, yt, x1b, yt + 60), 270, 360, fill=YEL, width=lw)
        yline([(x0b + 30, yt), (x1b - 30, yt)])

    # табличка PREMIER HAZARD + 7007
    px0, py0, px1, py1 = int(0.365 * W), int(0.66 * H), int(0.525 * W), int(0.80 * H)
    d.rounded_rectangle((px0, py0, px1, py1), radius=16, outline=YEL, width=6)
    hd.rounded_rectangle((px0, py0, px1, py1), radius=16, outline=165, width=6)
    text(((px0 + px1) // 2, py0 + 52), 'PREMIER', 58, style='Bold Condensed')
    text(((px0 + px1) // 2, py1 - 50), 'HAZARD', 58, style='Bold Condensed')
    text(((px0 + px1) // 2, int(0.89 * H)), '7007', 112, style='Bold')

    # переключатель мелодий: подписи справа налево к ручке, точки-риски
    sx, sy, sr = LAYOUT['knob_sel']
    labels = [('HILO', 0.185), ('YELP', 0.305), ('WAIL', 0.425), ('STANDBY', 0.545)]
    for s, y in labels:
        text((int(0.535 * W), int(y * H)), s, 76, anchor='rm')
        dot(int(0.555 * W), int(y * H), 13)

    # громкость
    vx, vy, vr = LAYOUT['knob_vol']
    text((int(vx * W), int(0.54 * H)), 'OFF/VOL', 74)
    dot(int(0.06 * W), int(0.50 * H), 13)
    # шкала громкости дугой
    R = int((vr + 0.03) * W)
    d.arc((int(vx * W) - R, int(vy * H) - R, int(vx * W) + R, int(vy * H) + R), 135, 405, fill=(120, 120, 124), width=6)

    # кнопки: подписи и светодиоды
    for key, lab in (('btn_pa', 'PA / MAN'), ('btn_horn', 'RADIO / HORN')):
        bx, by, bw = LAYOUT[key]
        text((int(bx * W), int(0.69 * H)), lab, 58, anchor='mm', style='Bold Condensed')
    for key in ('led_l1', 'led_l2'):
        lx, ly, lr = LAYOUT[key]
        dot(int(lx * W), int(ly * H), 18, fill=(150, 104, 22))

    # разъём RJ45: тёмная ниша с контактами
    rx, ry, rw, rh = LAYOUT['rj45']
    x0, y0, x1, y1_ = int((rx - rw) * W), int((ry - rh) * H), int((rx + rw) * W), int((ry + rh) * H)
    d.rounded_rectangle((x0, y0, x1, y1_), radius=12, fill=(18, 18, 19), outline=(70, 70, 74), width=10)
    hd.rounded_rectangle((x0, y0, x1, y1_), radius=12, fill=40, outline=200, width=10)
    ix0, iy0, ix1, iy1 = x0 + 50, y0 + 45, x1 - 50, y1_ - 60
    d.rectangle((ix0, iy0, ix1, iy1), fill=(8, 8, 9))
    hd.rectangle((ix0, iy0, ix1, iy1), fill=10)
    n = 8
    for i in range(n):
        cx = ix0 + 30 + i * (ix1 - ix0 - 60) // (n - 1)
        d.rectangle((cx - 6, iy0 + 8, cx + 6, iy0 + 70), fill=(190, 160, 70))
    d.rectangle(((ix0 + ix1) // 2 - 70, iy1, (ix0 + ix1) // 2 + 70, iy1 + 40), fill=(8, 8, 9))

    # шум пластика (мелкая шагрень), чтобы не было «пластмассы из пейнта»
    noise = Image.effect_noise((W, H), 18).filter(ImageFilter.GaussianBlur(0.8))
    img = Image.blend(img, Image.merge('RGB', (noise, noise, noise)), 0.035)
    hgt = Image.blend(hgt, noise, 0.08)
    img.save(os.path.join(out, 'kv_hazard7007_face.png'))
    hgt.save(os.path.join(out, 'kv_hazard7007_face_h.png'))
    with open(os.path.join(out, 'layout.json'), 'w') as f:
        json.dump({'W': W, 'H': H, **LAYOUT}, f)


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), 'hazard'))
