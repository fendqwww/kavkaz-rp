"""из чего состоит память машины (.yft): геометрия по уровням LOD (ближний/средний/дальний), коллизия, прочее.
blender -b --factory-startup -P car_mem.py -- <файл.yft> ..."""
import addon_utils, sys
from collections import defaultdict
addon_utils.enable('Sollumz', default_set=True)
from szio.gta5 import try_load_asset
import numpy as np
MB = 1048576
for p in sys.argv[sys.argv.index('--') + 1:]:
    a = try_load_asset(p)
    print('KAVKAZ ===', p, type(a).__name__, [f for f in getattr(a, '__dataclass_fields__', {})], flush=True)
    per = defaultdict(float); tris = defaultdict(int)
    def drw(d, tag):
        if d is None: return
        for lod, models in d.models.items():
            for m in models:
                for g in m.geometries:
                    vb = np.asarray(g.vertex_buffer); ib = np.asarray(g.index_buffer)
                    per[f'{tag}:{lod.name}'] += (vb.nbytes + len(ib) * 2) / MB
                    tris[f'{tag}:{lod.name}'] += len(ib) // 3
    drw(getattr(a, 'drawable', None), 'main')
    for i, d in enumerate(getattr(a, 'extra_drawables', None) or []): drw(d, 'extra')
    phys = getattr(a, 'physics', None)
    bverts = bprims = 0
    if phys:
        for ch in phys.lod1.children:
            drw(ch.drawable, 'child'); drw(ch.damaged_drawable, 'child_dmg')
        def walk(b):
            nonlocal_v = [0, 0]
            if b is None: return (0, 0)
            v = len(getattr(b, 'geometry_vertices', []) or []); pr = len(getattr(b, 'geometry_primitives', []) or [])
            for c in getattr(b, 'children', []) or []:
                cv, cp = walk(c); v += cv; pr += cp
            return v, pr
        bverts, bprims = walk(phys.lod1.archetype.bounds)
    for k in sorted(per): print(f'KAVKAZ   {k:28s} {per[k]:7.2f} МБ  тр {tris[k]}', flush=True)
    print(f'KAVKAZ   коллизия: вершин {bverts}, примитивов {bprims} (~{(bverts*6 + bprims*16)/MB:.2f} МБ)', flush=True)
