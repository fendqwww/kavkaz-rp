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
# --wide (13.11): все словари загородных районов (cs*, ch*, lr_cs*, hei_cs*) и их дальние версии (*lod*) — песок, видный
# издалека, лежит в LOD-словарях, прошлый проход их пропускал. --skip-done <папка>: словари, которые уже есть в степи
WIDE = '--wide' in argv
YTD_WIDE = re.compile(r'^(hei_|lr_)?(cs[1-6]|ch[1-3])_', re.I)
LODTEX = re.compile(r'_n$|_nrm|_normal|_s$|_spec|mask|msk', re.I)
BUILDING = re.compile(r'wall|brick|wood|roof|door|window|metal|plaster|concrete|tile|sign|decal|graff|paint|plank|fence|pipe|rust', re.I)
DONE = set()
if '--skip-done' in argv:
    DONE = {f.split('.')[0].lower() for f in os.listdir(argv[argv.index('--skip-done') + 1]) if f.endswith('.ytd')}

gf = GameFiles(GAME)
idx = gf.read_asset_filelist()
ytd = idx.get(('.ytd',), {})
listing = {}
for n, paths in ytd.items():
    name = str(n)
    p = paths[0] if isinstance(paths, (list, tuple)) else paths
    is_lod = 'lod' in name.lower()
    if ONLY is not None:
        if name not in ONLY:
            continue
    elif WIDE:
        if not YTD_WIDE.match(name) or name.lower() in DONE:
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
        if WIDE and is_lod:  # в дальних словарях земля — запечённые картинки без «говорящих» имён: берём все цветные
            ok = not LODTEX.search(tname)
        elif WIDE:  # ближние словари: только земля, не стены домов с «грязью» в имени
            ok = DESERT.search(tname) and not SKIP.search(tname) and not BUILDING.search(tname)
        else:
            ok = DESERT.search(tname) and not SKIP.search(tname)
        if ok and t.data is not None:
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
