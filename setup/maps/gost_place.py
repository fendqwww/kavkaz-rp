"""KAVKAZ RP: русские знаки ГОСТ на места убранных американских (16.11, основатель: «знаки там расставь»).
blender -b --factory-startup -P setup/maps/gost_place.py -- <out_dir> <signs_q.json> <nodes_compact.json> [--check]
signs_q.json — scan_entities_blender.py (модель, место, кватернион); nodes_compact.json — дорожная сеть GTA
(github.com/DurtyFree/gta-v-data-dumps nodes.zip, сжата в session-2026-11-16). поворот копируется как есть: лицо знаков GTA
и наших моделей смотрит в -Y. шевроны 1.34: направление — по стороне дороги (знак слева от едущего → поворот направо).
выход: kv_gost_<x>_<y>.ymap по клеткам 1 км (виден со 150 м).
"""
import addon_utils, collections, dataclasses, json, math, sys
from pathlib import Path
import numpy as np
addon_utils.enable('Sollumz', default_set=True)
from szio.gta5 import save_asset, try_load_asset, AssetTarget, AssetFormat, AssetVersion  # noqa: E402
from szio.gta5.maps import AssetMapData  # noqa: E402
from szio.gta5.entities import EntityLodLevel  # noqa: E402
from mathutils import Quaternion, Vector  # noqa: E402

a = sys.argv[sys.argv.index('--') + 1:]
OUT, SCAN, NODES = Path(a[0]), Path(a[1]), Path(a[2])
CHECK = '--check' in a

R = 'prop_sign_road_'
MAP = {
    '01a': '2_5', '01b': '2_5', '01c': '2_5', '02a': '2_4',
    '03a': '3_1', '03b': '3_1', '03c': '4_1_2', '03e': '2_1', '03f': '4_2_1', '03g': '4_2_1', '03l': '4_1_1', '03m': '4_1_1',
    '03q': '3_2', '04a': '3_28', '04r': '3_27', '04w': '3_28', '04x': '3_27', '04y': '6_4', '04z': '6_4',
    '05a': '5_19_1', '05b': '5_19_1', '05c': '1_11_1', '05d': '1_11_2', '05e': '1_11_1', '05f': '1_11_2',
    '05x': '1_11_1', '05y': '1_11_2', '05g': '1_22',
    '06a': '3_24_20', '06b': '3_24_20', '06c': '3_24_20', '06d': '3_24_40', '06e': '3_24_60', '06f': '3_24_90', '06g': '3_24_90',
    '06i': '3_24_40', '06j': '3_24_90', '06k': '3_24_60', '06l': '3_24_20', '06q': '4_1_1', '06r': '4_1_1',
    '07a': '5_5', '07b': '5_5', '09a': 'chev', '09b': 'chev', '09e': 'stolbik',
}
OTHER = {'prop_sign_freewayentrance': '5_1'}

# --- дорожная сеть: отрезки для «ближайшей дороги»
G = json.load(open(NODES))
P = np.array([[n[0], n[1], n[2]] for n in G['nodes']], dtype=np.float64)
water = np.array([n[8] for n in G['nodes']], dtype=bool)
segs = np.array([(i, j) for i, j, *_ in G['links'] if not water[i] and not water[j]], dtype=np.int64)
A, B = P[segs[:, 0], :2], P[segs[:, 1], :2]
cell = collections.defaultdict(list)
for k, (p, q) in enumerate(zip(A, B)):
    for cx in range(int(min(p[0], q[0]) // 50), int(max(p[0], q[0]) // 50) + 1):
        for cy in range(int(min(p[1], q[1]) // 50), int(max(p[1], q[1]) // 50) + 1):
            cell[(cx, cy)].append(k)


def nearest(x, y):
    """ближайшая точка дороги и направление отрезка"""
    ks = set()
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            ks.update(cell.get((int(x // 50) + dx, int(y // 50) + dy), ()))
    if not ks:
        return None
    ks = np.fromiter(ks, np.int64)
    p, q = A[ks], B[ks]
    d = q - p
    L = (d ** 2).sum(1) + 1e-9
    t = (((np.array([x, y]) - p) * d).sum(1) / L).clip(0, 1)
    c = p + d * t[:, None]
    dist = np.hypot(*(c - [x, y]).T)
    i = dist.argmin()
    return c[i], d[i] / math.sqrt(L[i]), dist[i]


def facing(q):
    """куда смотрит лицо знака в мире: (0,-1,0), повёрнутое сопряжённым кватернионом (в ymap поворот хранится обратным)"""
    rot = Quaternion((q[3], q[0], q[1], q[2])).conjugated()
    v = rot @ Vector((0, -1, 0))
    return np.array([v.x, v.y])


spots, seen = [], set()
for e in json.load(open(SCAN)):
    m = e['model'].lower()
    code = MAP.get(m[len(R):]) if m.startswith(R) else OTHER.get(m)
    if not code:
        continue
    k = (m, round(e['x']), round(e['y']))
    if k in seen:
        continue
    seen.add(k)
    spots.append((code, e))
print('KAVKAZ мест под знаки', len(spots), flush=True)

# проверка поворота: знак должен смотреть навстречу движению и стоять справа от едущего
right = left = far = 0
out = []
for code, e in spots:
    q = e['q']
    if code == 'chev' or CHECK:
        r = nearest(e['x'], e['y'])
        if r is None or r[2] > 40:
            far += 1
            if code == 'chev':
                continue
        else:
            c, d, _ = r
            n = facing(q)
            trav = -n                                     # едущий смотрит на лицо знака
            s = np.array([e['x'], e['y']]) - c
            side = trav[0] * s[1] - trav[1] * s[0]       # > 0 — знак слева от едущего
            if side > 0:
                left += 1
            else:
                right += 1
            if code == 'chev':
                code = '1_34_1' if side > 0 else '1_34_2'
    out.append((code, e))
print(f'KAVKAZ сторона: справа {right}, слева {left}, далеко от дорог {far}', flush=True)
if CHECK:
    sys.exit(0)

TEMPLATE = try_load_asset('C:/kavkaz/fix-cr/data/cruss.ymap').entities[0]
groups = collections.defaultdict(list)
for code, e in out:
    groups[(int(e['x'] // 1000), int(e['y'] // 1000))].append((code, e))
OUT.mkdir(parents=True, exist_ok=True)
stat = collections.Counter()
for (gx, gy), items in sorted(groups.items()):
    name = f'kv_gost_{gx + 10}_{gy + 10}'
    ymap = AssetMapData(name=name)
    mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
    for code, e in items:
        q = e['q']
        arch = 'kv_p_stolbik' if code == 'stolbik' else f'kv_p_gost_{code}'
        en = dataclasses.replace(TEMPLATE, archetype_name=arch, position=Vector((e['x'], e['y'], e['z'])),
                                 rotation=Quaternion((q[3], q[0], q[1], q[2])), parent_index=-1, lod_dist=150.0,
                                 child_lod_dist=0.0, num_children=0, lod_level=EntityLodLevel.HD, guid=0, extensions=[])
        ymap.entities.append(en)
        stat[arch] += 1
        mn = Vector((min(mn.x, e['x'] - 2), min(mn.y, e['y'] - 2), min(mn.z, e['z'] - 1)))
        mx = Vector((max(mx.x, e['x'] + 2), max(mx.y, e['y'] + 2), max(mx.z, e['z'] + 4)))
    ymap.entities_extents = (mn.copy(), mx.copy())
    ymap.streaming_extents = (mn - Vector((150, 150, 0)), mx + Vector((150, 150, 0)))
    save_asset(ymap, [AssetTarget(AssetFormat.NATIVE, AssetVersion.GEN8)], OUT, name)
print('KAVKAZ ymap', len(groups), 'знаков', sum(stat.values()), flush=True)
for k, v in stat.most_common():
    print('KAVKAZ  ', v, k, flush=True)
