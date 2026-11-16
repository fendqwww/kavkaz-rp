"""KAVKAZ RP: задание hide_geom_blender.py, чтобы убрать американские дома района на ЛЮБОМ расстоянии (15.11, Сэнди-Шорс).
blender -b --factory-startup -P setup/maps/district_hide_job.py -- <targets.json> <scan_entities.json> <job.json> <places.json>
targets.json — {имя HD-модели дома: [x, y, z, quat]} (выбрано по скану). собирается:
  - ближние: сам дом + всё, что названо его именем (`<дом>_rails`, `_details`, `_windows`…) + ночное свечение окон
    (`*emm*`, `*emiss*`) в той же точке (<= 3 м) — иначе ночью висят горящие окна;
  - дальние LOD: модели `<дом>_lod…` и свечение рядом — ищутся по joaat(имя) в `*_children.ydd` района (или отдельным .ydr);
  - общие дальние SLOD1/2/3 района: коробкой по настоящим габаритам дома из .ytyp (+ высота земли — без дыр).
places.json — габариты и курс домов (по ним ставятся наши здания).
"""
import addon_utils, json, math, re, sys
from pathlib import Path
addon_utils.enable('Sollumz', default_set=True)
from Sollumz.shared.game_assets.game_files import GameFiles  # noqa: E402
from szio.gta5 import try_load_asset  # noqa: E402
from mathutils import Quaternion, Vector  # noqa: E402

a = sys.argv[sys.argv.index('--') + 1:]
TARGETS, SCAN, JOB, PLACES = Path(a[0]), Path(a[1]), Path(a[2]), Path(a[3])
GAME = r'D:\gta enhansed\GTAV'
SKIP = re.compile(r'decal|_dec\b|land|terrain|glue|weed|rock|road|rd_|_shadow|shdw|shd\b')
EMIS = re.compile(r'emm|emiss|_em\b|_em_')


def joaat(s):
    h = 0
    for c in s.lower().encode():
        h = (h + c) & 0xFFFFFFFF; h = (h + (h << 10)) & 0xFFFFFFFF; h ^= h >> 6
    h = (h + (h << 3)) & 0xFFFFFFFF; h ^= h >> 11; h = (h + (h << 15)) & 0xFFFFFFFF
    return h


targets = json.load(open(TARGETS))
scan = json.load(open(SCAN))
tx = [v[0] for v in targets.values()]; ty = [v[1] for v in targets.values()]
area = (min(tx) - 700, max(tx) + 700, min(ty) - 700, max(ty) + 700)
ents = [e for e in scan if area[0] < e['x'] < area[1] and area[2] < e['y'] < area[3]]
prefix = sorted({m.split('_')[0] + '_' + m.split('_')[1] for m in targets})  # cs4_07 …
print('KAVKAZ тайлы', prefix, 'объектов рядом', len(ents), flush=True)


def near(e, r=3.0):
    return any(math.dist((e['x'], e['y']), v[:2]) <= r for v in targets.values())


def owned(m):
    return any(m == t or m.startswith(t + '_') for t in targets)


hd = set(targets)
lod = set()
for e in ents:
    m, lv = e['m'], e.get('lod', '')
    if SKIP.search(m) or m.startswith(('prop_', 'v_', 'p_')):
        continue
    if 'HD' in lv and (owned(m) or (EMIS.search(m) and near(e))):
        hd.add(m)
    if lv.endswith('.LOD'):
        stem = re.sub(r'_?lod.*$', '', m)
        if stem in targets or owned(stem) or (EMIS.search(m) and near(e)):
            lod.add(m)
print('KAVKAZ ближних', len(hd), 'дальних LOD', len(lod), flush=True)

idx = GameFiles(GAME).read_asset_filelist()
look = {}
for ext in ('.ydr', '.ydd', '.ytyp'):
    for k, v in idx.get((ext,), {}).items():
        look[(ext[1:], str(k).lower())] = v[0] if isinstance(v, (list, tuple)) else v

# габариты домов из .ytyp тайлов
arch = {}
for (kind, n), p in look.items():
    if kind == 'ytyp' and n.startswith(tuple(prefix)):
        for x in try_load_asset(p).archetypes:
            nm = x.name.lower()  # имена в .ytyp бывают хэшами hash_XXXXXXXX
            h = int(nm[5:], 16) if nm.startswith('hash_') else joaat(nm)
            arch[h] = (Vector(x.bb_min), Vector(x.bb_max))
boxes, places = [], []
for m, (x, y, z, q) in targets.items():
    if joaat(m) not in arch and ('ydr', m) in look:  # описания тайла нет в индексе — габарит по вершинам самой модели
        import numpy as np
        dr = try_load_asset(look[('ydr', m)])
        ps = np.concatenate([np.asarray(g.vertex_buffer['Position']) for ms in dr.models.values() for mm in ms for g in mm.geometries])
        arch[joaat(m)] = (Vector(ps.min(0).tolist()), Vector(ps.max(0).tolist()))
    if joaat(m) not in arch:
        print('KAVKAZ нет габаритов', m, flush=True); continue
    lo, hi = arch[joaat(m)]
    rot = Quaternion((q[3], q[0], q[1], q[2])) if q else Quaternion()
    # в ymap поворот хранится то прямым, то сопряжённым — берём габарит, покрывающий оба варианта
    pts = [r @ Vector((cx, cy, cz)) + Vector((x, y, z)) for r in (rot, rot.conjugated())
           for cx in (lo.x, hi.x) for cy in (lo.y, hi.y) for cz in (lo.z, hi.z)]
    mn = [min(p[i] for p in pts) for i in range(3)]; mx = [max(p[i] for p in pts) for i in range(3)]
    ground = mn[2]
    boxes.append([[round(mn[0] - 1, 1), round(mn[1] - 1, 1), round(ground - 2, 1)],
                  [round(mx[0] + 1, 1), round(mx[1] + 1, 1), round(mx[2] + 2, 1)], round(ground, 2)])
    yaw = math.degrees((rot @ Vector((1, 0, 0))).to_2d().angle_signed(Vector((1, 0))) * -1)
    places.append({'m': m, 'x': x, 'y': y, 'z': ground, 'w': round(hi.x - lo.x, 1), 'd': round(hi.y - lo.y, 1),
                   'h': round(hi.z - lo.z, 1), 'yaw': round(yaw, 1)})

job = []
for m in sorted(hd):
    if ('ydr', m) in look:
        job.append({'kind': 'ydr', 'name': m, 'mode': 'all'})
    else:
        print('KAVKAZ ближний не найден как ydr', m, flush=True)
# дальние: отдельные ydr или модели в *_children.ydd тайлов района
want = {joaat(m): m for m in lod}
found = {}
for m in list(lod):
    if ('ydr', m) in look:
        job.append({'kind': 'ydr', 'name': m, 'mode': 'all'}); found[joaat(m)] = m
slod = [e for e in ents if e.get('lod', '').split('.')[-1] in ('SLOD1', 'SLOD2', 'SLOD3')]
slod_h = {joaat(e['m']): e for e in slod}
for (kind, n), p in sorted(look.items()):
    if kind != 'ydd' or not n.endswith('_children') or not n.startswith(tuple(prefix) + (prefix[0].split('_')[0] + '_lod',)):
        continue
    dd = try_load_asset(p)
    spec = {}
    for key in dd.drawables:
        h = int(str(key).replace('hash_', ''), 16) if str(key).startswith('hash_') else joaat(str(key))
        if h in want:
            spec[str(key)] = {'mode': 'all'}; found[h] = want[h]
        elif h in slod_h:
            e = slod_h[h]
            spec[str(key)] = {'mode': 'box', 'origin': [e['x'], e['y'], e['z']], 'model': e['m']}
    if spec:
        job.append({'kind': 'ydd', 'name': n, 'drawables': spec, 'boxes': boxes})
        print('KAVKAZ', n, len(spec), flush=True)
# SLOD отдельными ydr
for h, e in slod_h.items():
    if ('ydr', e['m']) in look:
        job.append({'kind': 'ydr', 'name': e['m'], 'mode': 'box', 'origin': [e['x'], e['y'], e['z']], 'boxes': boxes})
print('KAVKAZ дальних найдено', len(found), 'из', len(lod), 'не найдены:', sorted(set(lod) - set(found.values())), flush=True)
json.dump(job, open(JOB, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
json.dump(places, open(PLACES, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('KAVKAZ задание', JOB, 'записей', len(job), 'мест', len(places), flush=True)
