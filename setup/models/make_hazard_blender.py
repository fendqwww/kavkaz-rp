"""KAVKAZ RP: 3D-пульт «Хазард 7007» для салона. запуск без окна:
blender -b -P setup/models/make_hazard_blender.py -- <папка с face.png/layout.json> <папка для рендеров>
сначала: python -I setup/models/hazard_face.py setup/models/hazard
объекты: kv_hazard7007 (корпус+лицо), kv_hazard_knob_vol, kv_hazard_knob_sel, kv_hazard_btn_pa, kv_hazard_btn_horn,
kv_hazard_led_l1, kv_hazard_led_l2. размеры настоящего блока: 160 x 110 x 45 мм. лимит — 3000 треугольников.
"""
import bmesh
import bpy
import json
import math
import os
import sys
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
SRC, OUT = os.path.abspath(argv[0]), os.path.abspath(argv[1])
os.makedirs(OUT, exist_ok=True)
L = json.load(open(os.path.join(SRC, 'layout.json')))

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

BW, BH, BD = 0.160, 0.110, 0.045          # корпус: ширина, высота, глубина
FW, FH = 0.150, 0.150 / (L['W'] / L['H'])  # лицевая панель
FY = -BD / 2 - 0.0004                      # плоскость лица (смотрит в -Y)


def face_xy(u, v):
    return (u - 0.5) * FW, (0.5 - v) * FH


def mat(name, color, rough=0.5, metal=0.0, emit=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1)
        b.inputs['Emission Strength'].default_value = strength
    return m


M_BODY = mat('hz_body', (0.022, 0.022, 0.024), 0.62)
M_KNOB = mat('hz_knob', (0.012, 0.012, 0.013), 0.38)
M_WHITE = mat('hz_white', (0.85, 0.83, 0.74), 0.32)
M_MARK = mat('hz_mark', (0.9, 0.9, 0.9), 0.4, emit=(1, 1, 1), strength=0.3)
M_LED = mat('hz_led', (0.6, 0.35, 0.02), 0.3, emit=(1.0, 0.55, 0.05), strength=6.0)

# лицо: текстура + рельеф
M_FACE = bpy.data.materials.new('hz_face')
M_FACE.use_nodes = True
nt = M_FACE.node_tree
bsdf = nt.nodes['Principled BSDF']
tex = nt.nodes.new('ShaderNodeTexImage')
tex.image = bpy.data.images.load(os.path.join(SRC, 'kv_hazard7007_face.png'))
hgt = nt.nodes.new('ShaderNodeTexImage')
hgt.image = bpy.data.images.load(os.path.join(SRC, 'kv_hazard7007_face_h.png'))
hgt.image.colorspace_settings.name = 'Non-Color'
bump = nt.nodes.new('ShaderNodeBump')
bump.inputs['Strength'].default_value = 0.35
bump.inputs['Distance'].default_value = 0.0015
nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
nt.links.new(hgt.outputs['Color'], bump.inputs['Height'])
nt.links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
bsdf.inputs['Roughness'].default_value = 0.55


def obj_from_bm(name, bm, material):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    ob.data.materials.append(material)
    return ob


def apply_mods(ob):
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def rounded_box(name, sx, sy, sz, bevel, segs, material, loc=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
    ob = obj_from_bm(name, bm, material)
    ob.location = loc
    md = ob.modifiers.new('bev', 'BEVEL')
    md.width, md.segments, md.limit_method = bevel, segs, 'ANGLE'
    apply_mods(ob)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


# корпус
body = rounded_box('kv_hazard7007', BW, BD, BH, 0.007, 3, M_BODY)
# «уши» с отверстиями — плоские фланцы у задней стенки
for side in (-1, 1):
    ear = rounded_box('ear', 0.026, 0.004, 0.034, 0.0015, 1, M_BODY, (side * (BW / 2 + 0.011), BD / 2 - 0.004, 0))
    hole = bpy.data.objects.new('hole', bpy.data.meshes.new('hole'))
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.004, radius2=0.004, depth=0.02)
    bm.to_mesh(hole.data)
    bm.free()
    scene.collection.objects.link(hole)
    hole.location = (side * (BW / 2 + 0.015), BD / 2 - 0.004, 0)
    hole.rotation_euler = (math.radians(90), 0, 0)
    md = ear.modifiers.new('cut', 'BOOLEAN')
    md.object, md.operation = hole, 'DIFFERENCE'
    apply_mods(ear)
    bpy.data.objects.remove(hole)
    ear.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    bpy.ops.object.select_all(action='DESELECT')

# лицевая панель (плоскость с UV на всю текстуру), чуть утоплена в рамку корпуса
bm = bmesh.new()
uvl = bm.loops.layers.uv.new('UVMap')
vs = [bm.verts.new((-FW / 2, FY, -FH / 2)), bm.verts.new((FW / 2, FY, -FH / 2)),
      bm.verts.new((FW / 2, FY, FH / 2)), bm.verts.new((-FW / 2, FY, FH / 2))]
f = bm.faces.new(vs)
for loop, uv in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
    loop[uvl].uv = uv
face = obj_from_bm('kv_hazard7007_face', bm, M_FACE)
face.data.polygons[0].normal_flip() if face.data.polygons[0].normal.y > 0 else None
face.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
bpy.ops.object.select_all(action='DESELECT')


def knob(name, u, v, r, height, ribs, rib_depth, marker):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=ribs * 2, radius1=r, radius2=r * 0.94, depth=height)
    for vert in bm.verts:
        a = math.atan2(vert.co.y, vert.co.x)
        idx = round((a % (2 * math.pi)) / (2 * math.pi) * ribs * 2)
        if idx % 2:
            vert.co.x *= (1 - rib_depth)
            vert.co.y *= (1 - rib_depth)
    ob = obj_from_bm(name, bm, M_KNOB)
    md = ob.modifiers.new('bev', 'BEVEL')
    md.width, md.segments, md.limit_method, md.angle_limit = 0.0012, 2, 'ANGLE', math.radians(60)
    apply_mods(ob)
    for p in ob.data.polygons:
        p.use_smooth = True
    # метка: белая полоса или риска на торце
    mk = rounded_box(name + '_mark', marker[0], marker[1], 0.0006, 0.0002, 1, M_MARK, (marker[2], 0, height / 2 + 0.0002))
    mk.select_set(True)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.join()
    bpy.ops.object.select_all(action='DESELECT')
    x, z = face_xy(u, v)
    ob.rotation_euler = (math.radians(90), 0, 0)
    ob.location = (x, FY - height / 2, z)
    return ob


vx, vy, vr = L['knob_vol']
sx, sy, sr = L['knob_sel']
knob_vol = knob('kv_hazard_knob_vol', vx, vy, vr * FW, 0.016, 18, 0.06, (0.0016, vr * FW * 0.9, 0))
knob_sel = knob('kv_hazard_knob_sel', sx, sy, sr * FW * 0.82, 0.019, 22, 0.035, (sr * FW * 1.45, 0.0034, 0))
knob_vol.rotation_euler.y = math.radians(-40)
knob_sel.rotation_euler.y = math.radians(30)

for key in ('btn_pa', 'btn_horn'):
    u, v, hw = L[key]
    x, z = face_xy(u, v)
    s = hw * FW * 2
    rounded_box('kv_hazard_' + key, s, 0.007, s, 0.0022, 2, M_WHITE, (x, FY - 0.0025, z))

for key in ('led_l1', 'led_l2'):
    u, v, r = L[key]
    x, z = face_xy(u, v)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=r * FW * 1.5, radius2=r * FW * 1.2, depth=0.0016)
    ob = obj_from_bm('kv_hazard_' + key, bm, M_LED)
    ob.rotation_euler = (math.radians(90), 0, 0)
    ob.location = (x, FY - 0.0008, z)

tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in scene.objects if o.type == 'MESH')
print('KAVKAZ треугольников:', tris)

# свет и камера: «студия», тёмный фон
world = bpy.data.worlds.new('w')
scene.world = world
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.045, 0.047, 0.05, 1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.25


def light(name, loc, power, size):
    ld = bpy.data.lights.new(name, 'AREA')
    ld.energy, ld.size = power, size
    lo = bpy.data.objects.new(name, ld)
    scene.collection.objects.link(lo)
    lo.location = loc
    d = Vector((0, 0, 0)) - Vector(loc)
    lo.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()


light('key', (0.25, -0.35, 0.30), 3.5, 0.3)
light('fill', (-0.35, -0.25, 0.05), 1.2, 0.5)
light('rim', (0.0, 0.3, 0.35), 4, 0.3)

cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.lens = 85

try:
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
except TypeError:
    scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x, scene.render.resolution_y = 1600, 1100
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'Medium High Contrast'


def shot(name, loc, target=(0, 0, 0)):
    cam.location = loc
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)


shot('hazard_34.png', (0.23, -0.52, 0.17), (0.0, 0.0, -0.004))
shot('hazard_front.png', (0.0, -0.62, 0.0), (0, 0, 0))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, 'kv_hazard7007.blend'))
