"""KAVKAZ RP: наши щиты (make_billboards.py) на места убранных американских придорожных щитов prop_billboard_* у главных маршрутов.
blender -b --factory-startup -P setup/maps/billboards_place.py -- <out_dir> <scan1.json> [scan2.json …]
поворот и место — как у американского щита (кватернион из скана копируется как есть), по ~4 щита у каждой опорной точки,
не ближе 200 м друг к другу, макеты по очереди. постоянный ymap kv_billboards_ru (виден с 500 м).
"""
import addon_utils, json, math, sys, dataclasses
from pathlib import Path
addon_utils.enable('Sollumz', default_set=True)
from szio.gta5 import save_asset, try_load_asset, AssetTarget, AssetFormat, AssetVersion  # noqa: E402
from szio.gta5.maps import AssetMapData  # noqa: E402
from szio.gta5.entities import EntityLodLevel  # noqa: E402
from mathutils import Quaternion, Vector  # noqa: E402

a = sys.argv[sys.argv.index('--') + 1:]
OUT, SCANS = Path(a[0]), [Path(x) for x in a[1:]]
ADS = ['kv_p_bb_nagorsk', 'kv_p_bb_job', 'kv_p_bb_taxi', 'kv_p_bb_school', 'kv_p_bb_dps', 'kv_p_bb_pelmeni']
BIG = ('prop_billboard_01', 'prop_billboard_02', 'prop_billboard_03', 'prop_billboard_04', 'prop_billboard_05',
       'prop_billboard_06', 'prop_billboard_07', 'prop_billboard_09', 'prop_billboard_10', 'prop_billboard_11')
# опорные точки: выход из аэропорта, автовокзал (спавн), центр, Веспуччи, восточный фривей, Сэнди, Палето
ANCHORS = [(-845, -2460), (434, -646), (-50, -800), (-600, -1000), (900, -1500), (1800, 3700), (-200, 6300)]
PER = 4
TEMPLATE = try_load_asset('C:/kavkaz/fix-cr/data/cruss.ymap').entities[0]

seen, spots = set(), []
for s in SCANS:
    for e in json.load(open(s)):
        if e['m'] in BIG and 'HD' in e.get('lod', ''):
            k = (round(e['x']), round(e['y']))
            if k not in seen:
                seen.add(k); spots.append(e)
print('KAVKAZ американских щитов', len(spots), flush=True)
chosen = []
for ax, ay in ANCHORS:
    n = 0
    for e in sorted(spots, key=lambda e: math.dist((e['x'], e['y']), (ax, ay))):
        if math.dist((e['x'], e['y']), (ax, ay)) > 1500 or n >= PER:
            break
        if any(math.dist((e['x'], e['y']), (c['x'], c['y'])) < 200 for c in chosen):
            continue
        chosen.append(e); n += 1
ymap = AssetMapData(name='kv_billboards_ru')
mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
for i, e in enumerate(chosen):
    q = e.get('q') or [0, 0, 0, 1]
    en = dataclasses.replace(TEMPLATE, archetype_name=ADS[i % len(ADS)], position=Vector((e['x'], e['y'], e['z'])),
                             rotation=Quaternion((q[3], q[0], q[1], q[2])), parent_index=-1, lod_dist=500.0,
                             child_lod_dist=0.0, num_children=0, lod_level=EntityLodLevel.HD, guid=0, extensions=[])
    ymap.entities.append(en)
    mn = Vector((min(mn.x, e['x'] - 8), min(mn.y, e['y'] - 8), min(mn.z, e['z'] - 2)))
    mx = Vector((max(mx.x, e['x'] + 8), max(mx.y, e['y'] + 8), max(mx.z, e['z'] + 12)))
    print(f"KAVKAZ {ADS[i % len(ADS)]:18} вместо {e['m']} ({e['x']:.0f}, {e['y']:.0f}, {e['z']:.0f})", flush=True)
ymap.entities_extents = (mn.copy(), mx.copy())
ymap.streaming_extents = (mn - Vector((500, 500, 0)), mx + Vector((500, 500, 0)))
OUT.mkdir(parents=True, exist_ok=True)
save_asset(ymap, [AssetTarget(AssetFormat.NATIVE, AssetVersion.GEN8)], OUT, 'kv_billboards_ru')
print('KAVKAZ щитов', len(chosen), flush=True)
