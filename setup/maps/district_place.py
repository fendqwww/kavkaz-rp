"""KAVKAZ RP: наши дома на места убранных американских (district_hide_job.py → places.json) — постоянным ymap, видно издалека.
blender -b --factory-startup -P setup/maps/district_place.py -- <places.json> <scan_entities.json> <out_dir> <имя_ymap> [rublocks.lua]
модель по размеру участка: гараж -> гаражи; крошечный -> ларёк; остальное по очереди (нет одинаковых рядом); дом может быть
длиннее старого участка не больше чем на 10 м (не вылезать на дорогу); не ставить, если задевает уже поставленный дом,
оставленные здания (шериф, больница, магазин…) или наши «русские кварталы» kavkaz_replace.
"""
import addon_utils, json, math, re, sys, copy
from pathlib import Path
addon_utils.enable('Sollumz', default_set=True)
from szio.gta5 import save_asset, try_load_asset, AssetTarget, AssetFormat, AssetVersion  # noqa: E402
from szio.gta5.maps import AssetMapData  # noqa: E402
from szio.gta5.entities import EntityLodLevel  # noqa: E402
import dataclasses  # noqa: E402
# образец сущности — из рабочего ymap острова (у Entity в szio нет значений по умолчанию)
TEMPLATE = try_load_asset('C:/kavkaz/fix-cr/data/cruss.ymap').entities[0]
from mathutils import Quaternion, Vector  # noqa: E402

a = sys.argv[sys.argv.index('--') + 1:]
PLACES, SCAN, OUT, NAME = Path(a[0]), Path(a[1]), Path(a[2]), a[3]
RUB = Path(a[4]) if len(a) > 4 else None
# наши модели: (имя, ширина по X, глубина по Y) — из сборки props_blender.py
M = {'kv_p_khrushchevka': (12.7, 30.6), 'kv_p_panelka': (15.2, 41.0), 'kv_p_soviet_panel_9floor': (26.0, 11.8),
     'kv_p_russian_panel_house': (21.0, 9.4), 'kv_p_soviet_residential_building': (55.5, 13.0),
     'kv_p_soviet_garages_block': (4.2, 13.0), 'kv_p_soviet_brick_storage_garage_low_poly': (4.2, 26.5),
     'kv_p_simple_90s_kiosk': (5.6, 6.0)}
HOMES = ['kv_p_khrushchevka', 'kv_p_panelka', 'kv_p_soviet_panel_9floor', 'kv_p_russian_panel_house']

places = [p for p in json.load(open(PLACES, encoding='utf-8'))
          if not re.search(r'(o|o\d+|_o|2d)$', p['m'])]  # «o»/«2d» — накладки и дубли того же дома
keep = []  # что оставили из зданий GTA (сервисы) — не задевать
for e in json.load(open(SCAN)):
    if 'HD' in e.get('lod', '') and re.search(r'sheriff|medic|firestation|store|_bar\b|dinner|motel|247|gas|tatto|barber', e['m']) \
            and not re.search(r'decal|_dec|sign|emm|em\b|detail|rail|dummy|terrain|land', e['m']):
        keep.append((e['x'], e['y'], 14.0))
if RUB and RUB.exists():
    for m, x, y in re.findall(r"\{'(kv_p_\w+)',(-?[\d.]+),(-?[\d.]+)", RUB.read_text(encoding='utf-8')):
        w, d = M.get(m, (20, 20)); keep.append((float(x), float(y), math.hypot(w, d) / 2))

placed, ents, turn = [], [], 0
for p in sorted(places, key=lambda p: (p['x'], p['y'])):
    L, S = max(p['w'], p['d']), min(p['w'], p['d'])
    long_x = p['w'] >= p['d']
    if 'garage' in p['m']:
        cand = ['kv_p_soviet_brick_storage_garage_low_poly', 'kv_p_soviet_garages_block', 'kv_p_simple_90s_kiosk']
    elif L < 9:
        cand = ['kv_p_simple_90s_kiosk']
    else:
        cand = HOMES[turn % len(HOMES):] + HOMES[:turn % len(HOMES)]
        cand += ['kv_p_soviet_brick_storage_garage_low_poly', 'kv_p_soviet_garages_block', 'kv_p_simple_90s_kiosk']  # дом не влез — не пустырь
    chosen = None
    for m in cand:
        w, d = M[m]
        ml, ms = max(w, d), min(w, d)
        if ml > L + 10 or ms > S + 8:
            continue
        r = math.hypot(w, d) / 2
        if any(math.dist((p['x'], p['y']), (x, y)) < r + rr - 4 for x, y, rr in placed + keep):
            continue
        chosen = (m, w, d, r); break
    if not chosen:
        print('KAVKAZ не влезло', p['m'], L, S, flush=True); continue
    m, w, d, r = chosen
    if m in HOMES: turn += 1
    # длинная сторона нашего дома — вдоль длинной стороны участка
    yaw = 0.0 if ((w >= d) == long_x) else 90.0
    placed.append((p['x'], p['y'], r))
    ents.append({'m': m, 'x': round(p['x'], 2), 'y': round(p['y'], 2), 'z': round(p['z'] - 0.3, 2), 'yaw': yaw, 'was': p['m']})
    print(f"KAVKAZ {p['m']:24} {L:5.1f}x{S:4.1f} -> {m} поворот {yaw}", flush=True)

ymap = AssetMapData(name=NAME)
mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
for e in ents:
    q = Quaternion((0, 0, 1), math.radians(e['yaw']))
    en = dataclasses.replace(TEMPLATE, archetype_name=e['m'], position=Vector((e['x'], e['y'], e['z'])), rotation=q,
                             parent_index=-1, lod_dist=1500.0, child_lod_dist=0.0, num_children=0,
                             lod_level=EntityLodLevel.HD, guid=0, extensions=[])
    ymap.entities.append(en)
    w, d = M[e['m']]; r = math.hypot(w, d) / 2
    mn = Vector((min(mn.x, e['x'] - r), min(mn.y, e['y'] - r), min(mn.z, e['z'] - 5)))
    mx = Vector((max(mx.x, e['x'] + r), max(mx.y, e['y'] + r), max(mx.z, e['z'] + 60)))
ymap.entities_extents = (mn.copy(), mx.copy())
ymap.streaming_extents = (mn - Vector((1500, 1500, 0)), mx + Vector((1500, 1500, 0)))
OUT.mkdir(parents=True, exist_ok=True)
save_asset(ymap, [AssetTarget(AssetFormat.NATIVE, AssetVersion.GEN8)], OUT, NAME)
json.dump(ents, open(OUT / f'{NAME}.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('KAVKAZ поставлено', len(ents), 'из', len(places), 'ymap', OUT / f'{NAME}.ymap', flush=True)
