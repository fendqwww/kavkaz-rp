"""KAVKAZ RP: разметка на асфальте по-русски — шаг 1: выгрузить текстуры разметки из всех мест, где игра их рисует.
blender -b --factory-startup -P setup/maps/roadmarks_extract_blender.py -- <marks_ytd.json> <marks_ydr.json> <папка_основ> <выход>

marks_ytd.json / marks_ydr.json — сканы (словари .ytd и модели .ydr/.ydd со встроенными текстурами, где в имени есть roadmark).
папка_основ — плоская папка с НАШИМИ версиями файлов (уже переделанными kv_map_roads/kv_map_signs/степью, скачаны с VPS):
если файл там есть, текстуры берём из него, иначе из игры. так правка ляжет поверх наших прошлых правок, а не затрёт их.
на выходе: <выход>/<имя.расширение>/<текстура>.dds и <выход>/manifest.json
"""
import addon_utils
import json
import os
import sys

argv = sys.argv[sys.argv.index('--') + 1:]
YTD_SCAN, YDR_SCAN, BASE, OUT = argv[:4]
addon_utils.enable('Sollumz', default_set=True)
from Sollumz.shared.game_assets.game_files import GameFiles  # noqa: E402
from szio.gta5 import try_load_asset  # noqa: E402

GAME = r'D:\gta enhansed\GTAV'
idx = GameFiles(GAME).read_asset_filelist()
look = {}
for ext in ('.ydr', '.ytd', '.ydd'):
    for k, v in idx.get((ext,), {}).items():
        look[str(k).lower() + ext] = str(v[0] if isinstance(v, (list, tuple)) else v)
base = {f.lower(): os.path.join(BASE, f) for f in os.listdir(BASE)} if os.path.isdir(BASE) else {}

conts = [n + '.ytd' for n in json.load(open(YTD_SCAN))] + list(json.load(open(YDR_SCAN)))
manifest = []
for c in sorted(set(conts)):
    src = base.get(c) or look.get(c)
    if not src:
        print('KAVKAZ нет', c, flush=True)
        continue
    try:
        a = try_load_asset(src)
    except Exception as e:  # noqa
        print('KAVKAZ ERR', c, repr(e)[:150], flush=True)
        continue
    if c.endswith('.ytd'):
        groups = [a.textures]
    elif c.endswith('.ydd'):
        groups = [d.shader_group.embedded_textures for d in a.drawables.values() if d.shader_group]
    else:
        groups = [a.shader_group.embedded_textures] if a.shader_group else []
    n = 0
    for g in groups:
        for t, tx in (g or {}).items():
            t = str(t)
            if 'roadmark' not in t.lower() or tx.data is None:
                continue
            d = os.path.join(OUT, c)
            os.makedirs(d, exist_ok=True)
            p = os.path.join(d, t + '.dds')
            with open(p, 'wb') as f:
                f.write(tx.data.read_bytes())
            manifest.append({'container': c, 'tex': t, 'dds': p.replace('\\', '/'), 'from_base': c in base})
            n += 1
    print('KAVKAZ', c, n, 'основа' if c in base else 'игра', flush=True)
json.dump(manifest, open(os.path.join(OUT, 'manifest.json'), 'w'), indent=1)
print('KAVKAZ итог текстур', len(manifest), flush=True)
