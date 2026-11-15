import addon_utils, bpy, sys, os
addon_utils.enable('Sollumz', default_set=True)
src = sys.argv[sys.argv.index('--') + 1]
for o in list(bpy.data.objects): bpy.data.objects.remove(o)
bpy.ops.sollumz.import_assets(directory=os.path.dirname(src), files=[{'name': os.path.basename(src)}], textures_mode='PACK')
rows = []
for o in bpy.data.objects:
    if o.type == 'MESH' and getattr(o, 'sollum_type', '') == 'sollumz_drawable_model':
        if o.sz_lods.get_lod('sollumz_high').mesh is None: continue
        o.sz_lods.active_lod_level = 'sollumz_high'
        mats = sorted({(getattr(m, 'shader_properties', None) and m.shader_properties.filename or m.name) for m in o.data.materials if m})
        rows.append((len(o.data.polygons), o.name, ' '.join(mats)[:120]))
for n, name, mats in sorted(rows, reverse=True)[:30]: print(f'KAVKAZ {n:7d} {name:24s} {mats}', flush=True)
