"""KAVKAZ RP: русские кварталы — хрущёвки, панельки, гаражи на пустых местах у дорог (без ручной расстановки).
python -I setup/maps/make_rublocks.py <entities.json> [<entities2.json> ...]
entities.json — все объекты карты в районе (скан ymap игры, scan_box в Blender + Sollumz): [{m, x, y, z, lod}].
место считается свободным, если рядом нет ни одного объекта GTA (дома, заборы, столбы, деревья, «Рублёвка»), а дорога
недалеко — рядом столбы ЛЭП или фонари. высоту дома игра берёт с земли на месте (kavkaz_replace, Config.MaxSlope):
неровное место, вода — дом не ставится. выход: resources/[kavkaz]/kavkaz_replace/data_rublocks.lua
"""
import json
import math
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[2]
OUT = root / 'resources' / '[kavkaz]' / 'kavkaz_replace' / 'data_rublocks.lua'

# районы: центр (вокруг него — в первую очередь), радиус, сколько домов максимум
AREAS = [
    {'name': 'Песчаный', 'c': (1850.0, 3700.0), 'r': 650.0, 'max': 34},
    # 12.11 вечер: основатель — «ненавижу пустыню и пустующие места, везде расставь»
    {'name': 'Гармония', 'c': (560.0, 2700.0), 'r': 450.0, 'max': 14},
    {'name': 'юг пустыни', 'c': (1300.0, 2950.0), 'r': 550.0, 'max': 16},
    {'name': 'Аламо-восток', 'c': (2500.0, 3550.0), 'r': 400.0, 'max': 10},
    {'name': 'Грейпсид', 'c': (1900.0, 4900.0), 'r': 500.0, 'max': 18},
    {'name': 'Палето', 'c': (-150.0, 6350.0), 'r': 500.0, 'max': 16},
    # 13.11: город (Нагорск) — пустыри промзон и окраин; рядом не ставим к точкам скриптов (гаражи, работы, участки)
    {'name': 'Сайпресс-Флэтс', 'c': (850.0, -2200.0), 'r': 450.0, 'max': 14},
    {'name': 'Эль-Бурро', 'c': (1350.0, -1800.0), 'r': 450.0, 'max': 14},
    {'name': 'Ранчо', 'c': (450.0, -1850.0), 'r': 350.0, 'max': 10},
    {'name': 'Дэвис', 'c': (100.0, -1700.0), 'r': 350.0, 'max': 10},
    {'name': 'Ла-Меса', 'c': (850.0, -1050.0), 'r': 350.0, 'max': 10},
    {'name': 'Мирор-Парк', 'c': (1150.0, -600.0), 'r': 350.0, 'max': 8},
    {'name': 'порт', 'c': (500.0, -2900.0), 'r': 450.0, 'max': 10},
]
SCRIPT_POINTS = root.parent / 'incoming-terrain' / 'script_points.txt'  # координаты из скриптов сервера (grep vec3/vec4)
# рощи на пустырях: прямоугольники (x0, y0, x1, y1), сколько рощ; деревья — модели GTA, есть у всех
GROVE_BOXES = [((300, 2400, 2900, 3950), 70), ((-1300, 1900, 300, 2900), 25), ((1300, 4300, 2600, 5300), 25)]
TREES = ['prop_tree_birch_01', 'prop_tree_birch_02', 'prop_tree_birch_03', 'prop_tree_oak_01', 'prop_tree_maple_02',
         'prop_tree_pine_01', 'prop_tree_pine_02', 'prop_tree_cedar_02']
# модели (половины размеров, м: из ydr) и доля в квартале
BUILD = [
    ('kv_p_soviet_residential_building', 27.7, 6.5, 3),
    ('kv_p_khrushchevka', 6.3, 15.3, 3),
    ('kv_p_russian_panel_house', 10.5, 4.7, 2),
    ('kv_p_soviet_garages_block', 2.1, 6.5, 1),
    ('kv_p_simple_90s_kiosk', 2.8, 3.0, 1),
]
MARGIN = 7.0        # м свободной земли вокруг дома
ROAD_NEAR = (18.0, 75.0)  # до ближайшего столба/фонаря: не на дороге, но и не в чистом поле
STEP = 9.0

SKIP = re.compile(r'lod|slod|terrain|_land|decal|_dcl|shadow|proxy|_emissive|_reflect|water|_ocean|occl', re.I)
ROADMARK = re.compile(r'^prop_(telegraph|telepole|streetlight|elecbox|sign_road|traffic)', re.I)


def load(paths):
    pts, road = [], []
    for p in paths:
        for e in json.load(open(p, encoding='utf-8')):
            if e.get('lod') and 'LOD' in e['lod'].upper() and 'HD' not in e['lod'].upper():
                continue
            if SKIP.search(e['m']):
                continue
            pts.append((e['x'], e['y']))
            if ROADMARK.search(e['m']):
                road.append((e['x'], e['y']))
    # «Рублёвка» (своя расстановка) — тоже занятые места
    rub = root / 'resources' / '[kavkaz]' / 'kavkaz_replace' / 'data_rublevka.lua'
    for m in re.finditer(r'\{-?\d+,(-?[\d.]+),(-?[\d.]+),', rub.read_text(encoding='utf-8')):
        pts.append((float(m.group(1)), float(m.group(2))))
    # точки скриптов (гаражи, работы, магазины, участки) — круг 25 м свободным
    if SCRIPT_POINTS.exists():
        for line in SCRIPT_POINTS.read_text(encoding='utf-8').split():
            try:
                px, py = (float(v) for v in line.split(',')[:2])
            except ValueError:
                continue
            if abs(px) < 50 and abs(py) < 50:
                continue  # это смещения, а не места
            for a in range(0, 360, 30):
                for r in (0, 10, 20, 25):
                    pts.append((px + r * math.cos(math.radians(a)), py + r * math.sin(math.radians(a))))
    # посты ДПС (kavkaz_world) — тоже заняты: круг 25 м
    for px, py in ((1511.9, 3472.0), (2139.4, 3778.6)):
        for a in range(0, 360, 20):
            for r in (5, 12, 20, 25):
                pts.append((px + r * math.cos(math.radians(a)), py + r * math.sin(math.radians(a))))
    return pts, road


class Grid:
    def __init__(self, pts, cell=20.0):
        self.c, self.g = cell, {}
        for p in pts:
            self.add(p)

    def add(self, p):
        self.g.setdefault((int(p[0] // self.c), int(p[1] // self.c)), []).append(p)

    def near(self, x, y, r):
        n = int(r // self.c) + 1
        cx, cy = int(x // self.c), int(y // self.c)
        for i in range(cx - n, cx + n + 1):
            for j in range(cy - n, cy + n + 1):
                yield from self.g.get((i, j), ())


def free(occ, x, y, hx, hy, yaw, margin=MARGIN):
    cs, sn = math.cos(yaw), math.sin(yaw)
    r = math.hypot(hx, hy) + margin
    for px, py in occ.near(x, y, r):
        dx, dy = px - x, py - y
        lx, ly = dx * cs + dy * sn, -dx * sn + dy * cs  # в осях дома
        if abs(lx) < hx + margin and abs(ly) < hy + margin:
            return False
    return True


def main():
    pts, road = load(sys.argv[1:])
    occ, rg = Grid(pts), Grid(road, 40.0)
    rows = []
    for a in AREAS:
        cx, cy = a['c']
        cand = []
        n = int(a['r'] // STEP)
        for i in range(-n, n + 1):
            for j in range(-n, n + 1):
                x, y = cx + i * STEP, cy + j * STEP
                d = math.hypot(x - cx, y - cy)
                if d > a['r']:
                    continue
                dr = min((math.hypot(px - x, py - y) for px, py in rg.near(x, y, ROAD_NEAR[1])), default=1e9)
                if ROAD_NEAR[0] <= dr <= ROAD_NEAR[1]:
                    cand.append((d, x, y))
        cand.sort()
        bag = [b for b in BUILD for _ in range(b[3])]
        placed = 0
        for k, (_, x, y) in enumerate(cand):
            if placed >= a['max']:
                break
            m, hx, hy, _ = bag[placed % len(bag)]
            for yaw_deg in (0.0, 90.0, 45.0, 135.0):
                if free(occ, x, y, hx, hy, math.radians(yaw_deg)):
                    rows.append((m, x, y, yaw_deg))
                    cs, sn = math.cos(math.radians(yaw_deg)), math.sin(math.radians(yaw_deg))
                    # дом занимает место: точки по его площади
                    for u in range(-int(hx), int(hx) + 1, 4):
                        for v in range(-int(hy), int(hy) + 1, 4):
                            occ.add((x + u * cs - v * sn, y + u * sn + v * cs))
                    placed += 1
                    break
        print(f"{a['name']}: кандидатов {len(cand)}, поставлено {placed}")
    # рощи: 8–14 деревьев в круге 20 м, не ближе 15 м к столбам/знакам (дороге) и с отступом от всего
    import random
    rnd = random.Random(12)
    groves = trees = 0
    for (x0, y0, x1, y1), want in GROVE_BOXES:
        tries = 0
        made = 0
        while made < want and tries < want * 60:
            tries += 1
            gx, gy = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
            if not free(occ, gx, gy, 12, 12, 0.0, 4.0):
                continue
            if any(True for _ in rg.near(gx, gy, 30.0) if math.hypot(_[0] - gx, _[1] - gy) < 30.0):
                continue
            n = rnd.randint(8, 14)
            for _ in range(n):
                a_, r_ = rnd.uniform(0, 2 * math.pi), rnd.uniform(0, 20)
                tx, ty = gx + r_ * math.cos(a_), gy + r_ * math.sin(a_)
                if free(occ, tx, ty, 1.0, 1.0, 0.0, 2.5):
                    rows.append((rnd.choice(TREES), tx, ty, rnd.uniform(0, 360)))
                    occ.add((tx, ty))
                    trees += 1
            made += 1
            groves += 1
    print('рощ:', groves, 'деревьев:', trees)
    lines = ['-- KAVKAZ RP: русские кварталы. генерирует setup/maps/make_rublocks.py, руками не править.',
             '-- { модель, x, y, курс } — высоту игра берёт с земли (kavkaz_replace/client.lua, groundFor)',
             'RuBlocksData = {']
    lines += [f"{{'{m}',{x:.1f},{y:.1f},{yaw:.0f}}}," for m, x, y, yaw in rows]
    lines += ['}', '']
    OUT.write_text('\n'.join(lines), encoding='utf-8')
    print('всего домов:', len(rows))


if __name__ == '__main__':
    main()
