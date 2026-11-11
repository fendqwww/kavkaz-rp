"""KAVKAZ RP: entities.json (scan_entities_blender.py) -> resources/[kavkaz]/kavkaz_replace/data.lua
python -I setup/maps/make_replace_data.py <entities.json>
каждая строка: { модель, x, y, z, heading }. heading — из кватерниона ymap (в ymap он записан обратным, поэтому знак минус).
"""
import json
import math
import os
import sys

src = json.load(open(sys.argv[1]))
out = os.path.join(os.path.dirname(__file__), '..', '..', 'resources', '[kavkaz]', 'kavkaz_replace', 'data.lua')
seen, rows = set(), []
for e in src:
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
    f.write('ReplaceData = {\n' + ',\n'.join(rows) + '\n}\n')
print('мест:', len(rows), '->', os.path.abspath(out))
