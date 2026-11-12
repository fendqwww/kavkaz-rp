"""KAVKAZ RP: «убрать пустыню» — шаг 1: выгрузить из GTA текстуры земли пустынных районов (Blender + Sollumz, без окна).
blender -b --factory-startup -P setup/maps/terrain_extract_blender.py -- "<папка GTA>" <выходная папка>
берём словари *_terrain*.ytd из районов country_* и desert (Сэнди-Шорс, Гранд-Сенора, Хармони, Палето-хиллз),
внутри — текстуры с песком/сухой травой по ключевым словам. каждая текстура -> <ytd>/<имя>.dds + список list.json.
"""
import addon_utils
import json
import os
import re
import sys

argv = sys.argv[sys.argv.index('--') + 1:]
GAME, OUT = argv[0], os.path.abspath(argv[1])
addon_utils.enable('Sollumz', default_set=True)
from Sollumz.shared.game_assets.game_files import GameFiles  # noqa: E402
from szio.gta5 import try_load_asset  # noqa: E402

DESERT = re.compile(r'dune|deshill|desert|desgr|sand(?!bag)|_dry|dryg|scrub|redgrass|dirt|gravel|mntscrub|hillsmsk|tf_des|grassshale', re.I)
# --only a,b — взять эти словари по имени, без фильтра районов (12.11: земля у шоссе 68 и обочины фривея — в *_land, *_roads*)
ONLY = set(argv[argv.index('--only') + 1].split(',')) if '--only' in argv else None
SKIP = re.compile(r'_n$|_nrm|_normal|_s$|_spec|_lod|_slod|mask|msk', re.I)
AREAS = re.compile(r'/(country_0\d|_hills/country|desert)', re.I)

gf = GameFiles(GAME)
idx = gf.read_asset_filelist()
ytd = idx.get(('.ytd',), {})
listing = {}
for n, paths in ytd.items():
    name = str(n)
    p = paths[0] if isinstance(paths, (list, tuple)) else paths
    if ONLY is not None:
        if name not in ONLY:
            continue
    elif 'terrain' not in name.lower() or not AREAS.search(str(p).replace('\\', '/')):
        continue
    try:
        a = try_load_asset(p)
    except Exception as e:  # noqa
        print('ERR', name, e, flush=True)
        continue
    picked = []
    for tname, t in a.textures.items():
        if DESERT.search(tname) and not SKIP.search(tname) and t.data is not None:
            d = os.path.join(OUT, name)
            os.makedirs(d, exist_ok=True)
            raw = t.data.read_bytes()
            with open(os.path.join(d, tname + '.dds'), 'wb') as f:
                f.write(raw)
            picked.append(tname)
    if picked:
        listing[name] = {'path': str(p), 'textures': picked, 'all': list(a.textures.keys())}
        print('YTD', name, len(picked), '/', len(a.textures), flush=True)
json.dump(listing, open(os.path.join(OUT, 'list.json'), 'w'), indent=1)
print('KAVKAZ словарей:', len(listing), 'текстур:', sum(len(v['textures']) for v in listing.values()), flush=True)
