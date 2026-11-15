"""облегчить машину БЕЗ сдвига поверхности: убрать только почти плоские треугольники (planar dissolve).
15.11: упрощение схлопыванием (car_slim2/3) рвало кузов — вершины уезжали через щели между панелями.
здесь вершины не двигаются: соседние грани, лежащие в одной плоскости (угол < angle), сливаются в многоугольник,
швы UV и границы материалов не трогаются (delimit), потом многоугольники режутся обратно на треугольники.
нормали пересчитываются по углу (перенос с оригинала давал тёмные пятна на двойных панелях).
салон (детали без краски/эмблем, не касающиеся габарита машины) и колесо после этого ещё и схлопываются (in=, wheel=):
их видно только через стекло или в движении.
blender -b --factory-startup -P car_planar.py -- src.yft out_dir angle_deg [in=0.25] [wheel=0.5] [weld=0.0005]
"""
import addon_utils, bpy, bmesh, sys, os, math
addon_utils.enable('Sollumz', default_set=True)
args = sys.argv[sys.argv.index('--') + 1:]
src, out, angle = args[0], args[1], math.radians(float(args[2]))
cfg = dict(a.split('=') for a in args[3:])
weld = float(cfg.get('weld', '0.0005'))
R_IN, R_WHEEL = float(cfg.get('in', '1')), float(cfg.get('wheel', '1'))
for o in list(bpy.data.objects): bpy.data.objects.remove(o)
bpy.ops.sollumz.import_assets(directory=os.path.dirname(src), files=[{'name': os.path.basename(src)}], textures_mode='PACK')
models = [o for o in bpy.data.objects if o.type == 'MESH' and getattr(o, 'sollum_type', '') == 'sollumz_drawable_model']


# салон или снаружи — по материалу и габариту (как car_slim3): имена деталей у модов случайные («chundero», «juyu»)
import mathutils, re
OUTER = ('vehicle_paint', 'vehicle_badges')
GLASS = re.compile(r'glass|window|windscreen|windshield', re.I)
def shaders(o):
    return {(getattr(m, 'shader_properties', None) and m.shader_properties.filename or m.name).lower() for m in o.data.materials if m}
for o in models: o.sz_lods.active_lod_level = 'sollumz_high'
box = {}
gmn = mathutils.Vector((1e9,) * 3); gmx = mathutils.Vector((-1e9,) * 3)
for o in models:
    if o.sz_lods.get_lod('sollumz_high').mesh is None: continue
    pts = [o.matrix_world @ mathutils.Vector(c) for c in o.bound_box]
    mn = mathutils.Vector(map(min, *pts)); mx = mathutils.Vector(map(max, *pts)); box[o.name] = (mn, mx)
    gmn = mathutils.Vector(map(min, gmn, mn)); gmx = mathutils.Vector(map(max, gmx, mx))
tol = (gmx - gmn) * 0.03
def outer(o):
    if any(sh.startswith(OUTER) for sh in shaders(o)): return True
    mn, mx = box[o.name]
    return any(mn[i] <= gmn[i] + tol[i] or mx[i] >= gmx[i] - tol[i] for i in range(3))
INNER = {o.name for o in models if o.name in box and not outer(o) and not GLASS.search(o.name)}
WHEEL = {o.name for o in models if re.search(r'wheel', o.name, re.I) and not re.search(r'steer', o.name, re.I)}
INNER -= WHEEL
print('KV салон:', sorted(INNER), 'колёса:', sorted(WHEEL), flush=True)


def collapse(o, ratio):
    arm = [m for m in o.modifiers if m.type == 'ARMATURE']
    for m in arm: m.show_viewport = False
    m = o.modifiers.new('dec', 'DECIMATE'); m.ratio = ratio; m.use_collapse_triangulate = True
    with bpy.context.temp_override(object=o, active_object=o):
        bpy.ops.object.modifier_move_to_index(modifier='dec', index=0)
        bpy.ops.object.modifier_apply(modifier='dec')
    with bpy.context.temp_override(object=o, active_object=o, selected_editable_objects=[o], selected_objects=[o]):
        bpy.ops.object.shade_smooth_by_angle(angle=0.70)
    for m in arm: m.show_viewport = True


def planar(o):
    arm = [m for m in o.modifiers if m.type == 'ARMATURE']
    for m in arm: m.show_viewport = False
    bm = bmesh.new(); bm.from_mesh(o.data)
    # Sollumz режет модель по швам UV/нормалей: без сварки соседние грани не связаны и сливаться не могут
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=weld)
    bm.to_mesh(o.data); bm.free(); o.data.update()
    for mod, kw in (('DECIMATE', dict(decimate_type='DISSOLVE', angle_limit=angle, delimit={'UV', 'MATERIAL', 'SEAM'},
                                      use_dissolve_boundaries=False)),
                    ('TRIANGULATE', dict(quad_method='BEAUTY', ngon_method='BEAUTY', min_vertices=4))):
        m = o.modifiers.new(mod.lower(), mod)
        for k, v in kw.items(): setattr(m, k, v)
        with bpy.context.temp_override(object=o, active_object=o):
            bpy.ops.object.modifier_move_to_index(modifier=m.name, index=0)
            bpy.ops.object.modifier_apply(modifier=m.name)
    with bpy.context.temp_override(object=o, active_object=o, selected_editable_objects=[o], selected_objects=[o]):
        if o.data.has_custom_normals: bpy.ops.mesh.customdata_custom_splitnormals_clear()
        bpy.ops.object.shade_smooth_by_angle(angle=0.70)
    for m in arm: m.show_viewport = True


for lv in ('sollumz_veryhigh', 'sollumz_high', 'sollumz_medium', 'sollumz_low'):
    before = after = 0
    for o in models:
        if o.sz_lods.get_lod(lv).mesh is None: continue
        o.sz_lods.active_lod_level = lv
        if o.name not in bpy.context.view_layer.objects: continue
        o.hide_set(False)
        n = len(o.data.polygons); before += n
        if n >= 200: planar(o)
        if lv != 'sollumz_medium' and lv != 'sollumz_low' and len(o.data.polygons) >= 2000:
            r = R_IN if o.name in INNER else R_WHEEL if o.name in WHEEL else 1.0
            if r < 0.999: collapse(o, r)
        a = len(o.data.polygons); after += a
        if n >= 3000: print(f'KV {lv} {o.name}: {n} -> {a}', flush=True)
    print('KV', lv, 'tris', before, '->', after, flush=True)
for o in models: o.sz_lods.active_lod_level = 'sollumz_high'
for o in bpy.data.objects: o.select_set(True)
os.makedirs(out, exist_ok=True)
print('KV export', bpy.ops.sollumz.export_assets(directory=out, direct_export=True, limit_to_selected=False,
                                                 target_formats={'NATIVE'}, target_versions={'GEN8'}), flush=True)
