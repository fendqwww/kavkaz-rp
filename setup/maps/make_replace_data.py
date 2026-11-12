"""KAVKAZ RP: entities.json (scan_entities_blender.py) -> resources/[kavkaz]/kavkaz_replace/data.lua
python -I setup/maps/make_replace_data.py <entities.json> [--only <regex>] [--out <файл.lua>] [--var <имя таблицы>]
12.11: --only prop_traffic_03 --out data_lights.lua --var LightsData — американские П-образные светофоры из скана us_props.json
каждая строка: { модель, x, y, z, heading }. heading — из кватерниона ymap (в ymap он записан обратным, поэтому знак минус).
"""
import json
import math
import os
import sys

import re  # noqa: E402
src = json.load(open(sys.argv[1]))
arg = lambda k, d: sys.argv[sys.argv.index(k) + 1] if k in sys.argv else d  # noqa: E731
ONLY = re.compile(arg('--only', '.'))
VAR = arg('--var', 'ReplaceData')
out = os.path.join(os.path.dirname(__file__), '..', '..', 'resources', '[kavkaz]', 'kavkaz_replace', arg('--out', 'data.lua'))
seen, rows = set(), []
for e in src:
    if e['model'].startswith('prop_veg_crop_tr') or not ONLY.search(e['model']):  # фруктовые сады оставляем
        continue
    x, y, z, w = e['q']
    yaw = math.degrees(math.atan2(2 * (w * z + x * y), 1 - 2 * (y * y + z * z)))
    heading = (-yaw) % 360
    key = (e['model'], round(e['x']), round(e['y']))
    if key in seen:  # одна и та же точка в нескольких ymap (основной и DLC)
        continue
    seen.add(key)
    rows.append("{'%s',%.2f,%.2f,%.2f,%.1f}" % (e['model'], e['x'], e['y'], e['z'], heading))
with open(out, 'w', encoding='utf-8') as f:
    f.write('-- KAVKAZ RP: места американских объектов из карты игры (setup/maps/make_replace_data.py). не править руками.\n')
    f.write(VAR + ' = {\n' + ',\n'.join(rows) + '\n}\n')
print('мест:', len(rows), '->', os.path.abspath(out))
