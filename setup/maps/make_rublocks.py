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
]
# модели (половины размеров, м: из ydr) и доля в квартале
BUILD = [
    ('kv_p_soviet_residential_building', 27.7, 6.5, 3),
    ('kv_p_khrushchevka', 6.3, 15.3, 3),
    ('kv_p_russian_panel_house', 10.5, 4.7, 2),
    ('kv_p_soviet_garages_block', 2.1, 6.5, 1),
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


def free(occ, x, y, hx, hy, yaw):
    cs, sn = math.cos(yaw), math.sin(yaw)
    r = math.hypot(hx, hy) + MARGIN
    for px, py in occ.near(x, y, r):
        dx, dy = px - x, py - y
        lx, ly = dx * cs + dy * sn, -dx * sn + dy * cs  # в осях дома
        if abs(lx) < hx + MARGIN and abs(ly) < hy + MARGIN:
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
    lines = ['-- KAVKAZ RP: русские кварталы. генерирует setup/maps/make_rublocks.py, руками не править.',
             '-- { модель, x, y, курс } — высоту игра берёт с земли (kavkaz_replace/client.lua, groundFor)',
             'RuBlocksData = {']
    lines += [f"{{'{m}',{x:.1f},{y:.1f},{yaw:.0f}}}," for m, x, y, yaw in rows]
    lines += ['}', '']
    OUT.write_text('\n'.join(lines), encoding='utf-8')
    print('всего домов:', len(rows))


if __name__ == '__main__':
    main()
