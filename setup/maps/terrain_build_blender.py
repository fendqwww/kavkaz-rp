"""KAVKAZ RP: «убрать пустыню» — шаг 3: собрать словари текстур земли для FiveM (gen8) с перекрашенными текстурами.
blender -b --factory-startup -P setup/maps/terrain_build_blender.py -- <папка из шагов 1-2> <resources/[maps]/kv_map_steppe/stream>
словарь игры читается целиком (все текстуры), перекрашенные (<имя>.new.dds) подменяются, сохраняется под тем же именем.
"""
import addon_utils
import json
import os
import sys
from pathlib import Path

argv = sys.argv[sys.argv.index('--') + 1:]
SRC, OUT = os.path.abspath(argv[0]), Path(os.path.abspath(argv[1]))
OUT.mkdir(parents=True, exist_ok=True)
addon_utils.enable('Sollumz', default_set=True)
from szio.gta5 import try_load_asset, save_asset, AssetTarget, AssetFormat, AssetVersion  # noqa: E402
from szio.types import DataSource  # noqa: E402

listing = json.load(open(os.path.join(SRC, 'list.json')))
target = [AssetTarget(AssetFormat.NATIVE, AssetVersion.GEN8)]
n_ytd = n_tex = 0
for name, info in listing.items():
    new = {t: os.path.join(SRC, name, t + '.new.dds') for t in info['textures']}
    new = {t: p for t, p in new.items() if os.path.exists(p)}
    if not new:
        continue
    a = try_load_asset(info['path'])
    for t, p in new.items():
        if t in a.textures:
            a.textures[t].data = DataSource.create(p, t + '.dds')
            n_tex += 1
    try:
        save_asset(a, target, OUT, name)
        n_ytd += 1
        print('YTD', name, len(new), flush=True)
    except Exception as e:  # noqa
        print('ERR', name, e, flush=True)
print('KAVKAZ словарей:', n_ytd, 'текстур:', n_tex, flush=True)
