"""KAVKAZ RP: разрезать тяжёлые куски острова Criminal Russia (kv_map_cr) на части <= ~15 МиБ БЕЗ упрощения.
15.11: 8 кусков (Batyrevo1/3/4/5, Sopki3/4/5/6) занимали 17–32 МиБ — клиент FiveM не грузит модели > 16 МиБ, на острове дыры.
простое пересохранение через szio уже ужимает (32 → 16–26 МиБ: у порта была неудачная раскладка страниц), остальное —
резка: геометрии каждого уровня LOD и дочерние коллизии раскладываются по частям; часть 0 сохраняет имя, части 1.. —
новые архетипы <имя>_b, _c … (копия архетипа: те же габариты и словарь текстур) и новые сущности в ymap на том же месте.
blender -b --factory-startup -P setup/maps/cr_split.py -- <папка оригиналов ydr> <crim_russia.ytyp> <cruss.ymap> <папка вывода> Batyrevo1 Sopki3 ...
"""
import addon_utils, sys, os, copy, math
from pathlib import Path
addon_utils.enable('Sollumz', default_set=True)
from szio.gta5 import try_load_asset, save_asset, AssetTarget, AssetFormat, AssetVersion
sys.path.insert(0, r'C:\kavkaz\kavkaz-repo\setup\cars')
from rscmem import mem

args = sys.argv[sys.argv.index('--') + 1:]
SRC, YTYP, YMAP, OUT = Path(args[0]), Path(args[1]), Path(args[2]), Path(args[3])
NAMES = args[4:]
TARGET = [AssetTarget(AssetFormat.NATIVE, AssetVersion.GEN8)]
LIMIT = 15.5
OUT.mkdir(parents=True, exist_ok=True)
SUFFIX = 'bcdefgh'


def split_list(xs, n):
    """поровну по весу (байтам), сохраняя порядок"""
    w = [x[1] for x in xs]; tot = sum(w) or 1
    parts = [[] for _ in range(n)]; acc = 0
    for item, wt in xs:
        k = min(n - 1, int(acc / tot * n)); parts[k].append(item); acc += wt
    return parts


def geo_bytes(g):
    import numpy as np
    return np.asarray(g.vertex_buffer).nbytes + np.asarray(g.index_buffer).nbytes


def make_part(a, k, n, name):
    b = copy.deepcopy(a)
    b.name = name
    for lod, models in b.models.items():
        for m in models:
            gs = [(g, geo_bytes(g)) for g in m.geometries]
            m.geometries = split_list(gs, n)[k]
        b.models[lod] = [m for m in models if m.geometries]
    b.models = {lod: ms for lod, ms in b.models.items() if ms}
    bd = b.bounds
    if bd is not None and getattr(bd, 'children', None):
        ch = list(bd.children)
        cw = [(c, len(getattr(c, 'primitives', None) or getattr(c, 'geometry_primitives', None) or []) + 1) for c in ch]
        keep = split_list(cw, n)[k]
        bd.children = keep
    return b


ytyp = try_load_asset(str(YTYP)); ymap = try_load_asset(str(YMAP))
arch = {x.name.lower(): x for x in ytyp.archetypes}
ents = {e.archetype_name.lower(): e for e in ymap.entities}
report = []
for nm in NAMES:
    a = try_load_asset(str(SRC / f'{nm}.ydr'))
    for n in range(2, 6):
        names = [nm] + [f'{nm}_{SUFFIX[i]}' for i in range(n - 1)]
        sizes = []
        tmp = OUT / f'_try_{nm}'; tmp.mkdir(exist_ok=True)
        for k, pn in enumerate(names):
            part = make_part(a, k, n, pn.lower())
            save_asset(part, TARGET, tmp, pn)
            sizes.append(mem(str(tmp / f'{pn}.ydr'))[0])
        print('KAVKAZ', nm, 'частей', n, sizes, flush=True)
        if max(sizes) <= LIMIT:
            for pn in names: os.replace(tmp / f'{pn}.ydr', OUT / f'{pn}.ydr')
            break
    for f in tmp.iterdir(): f.unlink()
    tmp.rmdir()
    report.append((nm, n, sizes))
    base_a = arch[nm.lower()]; base_e = ents[nm.lower()]
    for pn in names[1:]:
        na = copy.deepcopy(base_a); na.name = pn.lower(); ytyp.archetypes.append(na)
        ne = copy.deepcopy(base_e); ne.archetype_name = pn.lower(); ymap.entities.append(ne)

save_asset(ytyp, TARGET, OUT, YTYP.stem)
save_asset(ymap, TARGET, OUT, YMAP.stem)
for r in report: print('KAVKAZ ИТОГ', r, flush=True)
print('KAVKAZ архетипов', len(ytyp.archetypes), 'сущностей', len(ymap.entities), flush=True)
