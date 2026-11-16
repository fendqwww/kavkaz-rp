"""облегчить машину по уровням детализации (LOD): very_high (_hi.yft), high, medium — каждый своей долей.
кузов мягче, салон и колёса сильнее, стёкла не трогаем; нормали переносим с оригинала (вид поверхности не меняется).
medium упрощаем, только если он — почти копия high (у части модов так).
аргументы: src out "vh=кузов,салон,колёса" "h=кузов,салон,колёса" "m=доля"
"""
import addon_utils, bpy, sys, os, re
addon_utils.enable('Sollumz', default_set=True)
args = sys.argv[sys.argv.index('--') + 1:]
src, out = args[0], args[1]
cfg = dict(a.split('=') for a in args[2:])
R = {'sollumz_veryhigh': [float(x) for x in cfg.get('vh', '1,1,1').split(',')],
     'sollumz_high': [float(x) for x in cfg.get('h', '1,1,1').split(',')]}
r_med = float(cfg.get('m', '1'))
for o in list(bpy.data.objects): bpy.data.objects.remove(o)
bpy.ops.sollumz.import_assets(directory=os.path.dirname(src), files=[{'name': os.path.basename(src)}], textures_mode='PACK')
EXT = re.compile(r'body|door|boot|bonnet|hood|bumper|bumpdder|wing|misc|spoiler|light|lamp|mirror|chassis|trunk|panel|skirt|grill|exhaust|window', re.I)
GLASS = re.compile(r'glass|window|windscreen|windshield', re.I)
models = [o for o in bpy.data.objects if o.type == 'MESH' and getattr(o, 'sollum_type', '') == 'sollumz_drawable_model']


PROTECT = float(cfg.get('protect', '0'))   # м: вершины, у которых ближе этого лежит ДРУГОЙ слой (не связанный кусок), не упрощать
NTM = {'1': 'POLYINTERP_NEAREST', '2': 'NEAREST_POLYNOR', '3': 'POLYINTERP_LNORPROJ'}.get(cfg.get('nt', '2'))
NT = NTM is not None             # 1 — переносить нормали с оригинала, 0 — пересчитать по углу (сглаживание 40°)


def layer_guard(o):
    """группа kv_keep: вес 1 — можно упрощать, 0 — рядом другой слой панели (внутренняя сторона, подложка)"""
    import bmesh, mathutils
    bm = bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
    isl = [-1] * len(bm.verts); cur = 0
    for v in bm.verts:
        if isl[v.index] >= 0: continue
        st = [v]; isl[v.index] = cur
        while st:
            x = st.pop()
            for e in x.link_edges:
                y = e.other_vert(x)
                if isl[y.index] < 0: isl[y.index] = cur; st.append(y)
        cur += 1
    kd = mathutils.kdtree.KDTree(len(bm.verts))
    for v in bm.verts: kd.insert(v.co, v.index)
    kd.balance()
    keep = []
    for v in bm.verts:
        near = any(isl[i] != isl[v.index] for _, i, _ in kd.find_range(v.co, PROTECT))
        if not near: keep.append(v.index)
    bm.free()
    vg = o.vertex_groups.new(name='kv_keep'); vg.add(keep, 1.0, 'REPLACE')
    return vg, len(o.data.vertices) - len(keep)


def decimate(o, ratio):
    ref = o.copy(); ref.data = o.data.copy(); bpy.context.scene.collection.objects.link(ref)
    for m in list(ref.modifiers): ref.modifiers.remove(m)
    arm = [m for m in o.modifiers if m.type == 'ARMATURE']
    for m in arm: m.show_viewport = False
    vg, prot = layer_guard(o) if PROTECT > 0 else (None, 0)
    # 15.11: сначала сшить совпадающие вершины (Sollumz режет модель по швам UV/нормалей на тысячи кусков —
    # упрощение двигало вершину в одном куске, а её копию в соседнем нет: щели и шипы на кузове LC300)
    import bmesh
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=float(cfg.get('weld', '0.0005')))
    # края (кромки дверей, проёмы, рейлинги) и неманифолд — не упрощать: на них упрощение растягивало треугольники через щели
    bm.verts.ensure_lookup_table()
    edge_keep = [v.index for v in bm.verts if not (v.is_boundary or not v.is_manifold)]
    bm.to_mesh(o.data); bm.free(); o.data.update()
    if cfg.get('edges', '1') == '1':
        if 'kv_keep' in o.vertex_groups: o.vertex_groups.remove(o.vertex_groups['kv_keep'])
        vg = o.vertex_groups.new(name='kv_keep'); vg.add(edge_keep, 1.0, 'REPLACE')
    dec = o.modifiers.new('dec', 'DECIMATE'); dec.ratio = ratio; dec.use_collapse_triangulate = True
    if cfg.get('sym', '1') == '1': dec.use_symmetry = True; dec.symmetry_axis = 'X'  # машина симметрична: лево = право
    if 'kv_keep' in o.vertex_groups: dec.vertex_group = 'kv_keep'; dec.vertex_group_factor = float(cfg.get('vgf', '10'))
    with bpy.context.temp_override(object=o, active_object=o):
        bpy.ops.object.modifier_move_to_index(modifier='dec', index=0)
        bpy.ops.object.modifier_apply(modifier='dec')
    if NT:
        dt = o.modifiers.new('nrm', 'DATA_TRANSFER'); dt.object = ref; dt.use_loop_data = True
        dt.data_types_loops = {'CUSTOM_NORMAL'}; dt.loop_mapping = NTM
        dt.use_max_distance = True; dt.max_distance = 0.02
        with bpy.context.temp_override(object=o, active_object=o):
            bpy.ops.object.modifier_move_to_index(modifier='nrm', index=0)
            bpy.ops.object.modifier_apply(modifier='nrm')
    else:
        with bpy.context.temp_override(object=o, active_object=o, selected_editable_objects=[o], selected_objects=[o]):
            if o.data.has_custom_normals: bpy.ops.mesh.customdata_custom_splitnormals_clear()
            bpy.ops.object.shade_smooth_by_angle(angle=0.70)
    if 'kv_keep' in o.vertex_groups: o.vertex_groups.remove(o.vertex_groups['kv_keep'])  # не должна уйти в экспорт как «кость»
    if prot: print('KV слой', o.name, 'защищено вершин', prot)
    for m in arm: m.show_viewport = True
    me = ref.data; bpy.data.objects.remove(ref); bpy.data.meshes.remove(me)


def tris(o, lv):
    m = o.sz_lods.get_lod(lv).mesh
    return len(m.polygons) if m else 0


high_tris = {o.name: tris(o, 'sollumz_high') for o in models}
# 15.11: снаружи или салон — по материалу и габариту, а не по имени. у LC300 куски кузова с краской назывались
# «chundero», «black.001», «hjkhkui» — по имени попадали в «салон» и ужимались до 6 %: рваные крылья и крыша
import mathutils
OUTER = ('vehicle_paint', 'vehicle_badges')  # резина и подсветка бывают и в салоне (руль, торпедо LC300)
def shaders(o):
    return {(getattr(m, 'shader_properties', None) and m.shader_properties.filename or m.name).lower() for m in o.data.materials if m}
for o in models:
    o.sz_lods.active_lod_level = 'sollumz_high'
gmn = mathutils.Vector((1e9,) * 3); gmx = mathutils.Vector((-1e9,) * 3)
box = {}
for o in models:
    if o.sz_lods.get_lod('sollumz_high').mesh is None: continue
    pts = [o.matrix_world @ mathutils.Vector(c) for c in o.bound_box]
    mn = mathutils.Vector(map(min, *pts)); mx = mathutils.Vector(map(max, *pts)); box[o.name] = (mn, mx)
    gmn = mathutils.Vector(map(min, gmn, mn)); gmx = mathutils.Vector(map(max, gmx, mx))
tol = (gmx - gmn) * 0.03
def outer(o):
    if any(sh.startswith(OUTER) for sh in shaders(o)): return True
    mn, mx = box.get(o.name, (gmn, gmn))
    return any(mn[i] <= gmn[i] + tol[i] or mx[i] >= gmx[i] - tol[i] for i in range(3))
OUT_SET = {o.name for o in models if o.name in box and outer(o)}
print('KV снаружи:', sorted(OUT_SET), flush=True)
print('KV салон:', sorted(n for n in box if n not in OUT_SET), flush=True)
for lv in ('sollumz_veryhigh', 'sollumz_high', 'sollumz_medium'):
    before = after = 0
    for o in models:
        o.sz_lods.active_lod_level = lv
        if o.sz_lods.get_lod(lv).mesh is None: continue
        if o.name not in bpy.context.view_layer.objects: continue
        o.hide_set(False)
        n = len(o.data.polygons); before += n
        mats = ' '.join(m.name for m in o.data.materials if m)
        if lv == 'sollumz_medium':
            ratio = r_med if (n > 3000 and n > 0.5 * high_tris[o.name]) else 1.0
        else:
            rb, ri, rw = R[lv]
            if n < 3000 or GLASS.search(o.name): ratio = 1.0  # стекло — только по имени объекта: у кузова/дверей среди материалов тоже есть стекло
            elif re.search(r'wheel', o.name, re.I) and not re.search(r'steer', o.name, re.I): ratio = rw
            elif EXT.search(o.name) or o.name in OUT_SET: ratio = rb
            else: ratio = ri
        if ratio < 0.999: decimate(o, ratio)
        after += len(o.data.polygons)
    print('KV', lv, 'tris', before, '->', after)
for o in models: o.sz_lods.active_lod_level = 'sollumz_high'
for o in bpy.data.objects: o.select_set(True)
os.makedirs(out, exist_ok=True)
print('KV export', bpy.ops.sollumz.export_assets(directory=out, direct_export=True, limit_to_selected=False, target_formats={'NATIVE'}, target_versions={'GEN8'}))

