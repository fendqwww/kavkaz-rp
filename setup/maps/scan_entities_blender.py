"""KAVKAZ RP: найти по всей карте игры объекты нужных моделей (место + поворот) — для замены американских на свои.
blender -b --factory-startup -P setup/maps/scan_entities_blender.py -- "<папка GTA>" <out.json> "<regex моделей>"
читает все .ymap игры (Sollumz/szio), пишет [{model, x, y, z, qx, qy, qz, qw, ymap}] для совпавших.
"""
import addon_utils
import json
import re
import sys
import time

argv = sys.argv[sys.argv.index('--') + 1:]
GAME, OUT, RX = argv[0], argv[1], re.compile(argv[2], re.I)
addon_utils.enable('Sollumz', default_set=True)
from Sollumz.shared.game_assets.game_files import GameFiles  # noqa: E402
from szio.gta5 import try_load_asset  # noqa: E402

gf = GameFiles(GAME)
idx = gf.read_asset_filelist()
ym = idx.get(('.ymap',), {})
found, t0, n = [], time.time(), 0
for name, paths in ym.items():
    p = paths[0] if isinstance(paths, (list, tuple)) else paths
    n += 1
    if n % 1000 == 0:
        print('PROGRESS', n, len(ym), len(found), int(time.time() - t0), flush=True)
    try:
        a = try_load_asset(p)
    except Exception:  # noqa
        continue
    for e in (getattr(a, 'entities', None) or []):
        arch = str(getattr(e, 'archetype_name', ''))
        if not RX.search(arch):
            continue
        pos = e.position
        rot = getattr(e, 'rotation', None)
        q = [float(rot.x), float(rot.y), float(rot.z), float(rot.w)] if rot is not None else [0, 0, 0, 1]
        found.append({'model': arch, 'x': round(float(pos[0]), 2), 'y': round(float(pos[1]), 2), 'z': round(float(pos[2]), 2),
                      'q': [round(v, 4) for v in q], 'ymap': str(name)})
json.dump(found, open(OUT, 'w'))
print('KAVKAZ найдено:', len(found), 'за', int(time.time() - t0), 'с', flush=True)
