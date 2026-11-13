"""KAVKAZ RP: модели Sketchfab (glTF) -> .ydr + .ytyp для FiveM — шаг 2 (Blender без окна, Sollumz).
blender -b --factory-startup -P setup/models/props_blender.py -- <папка моделей> <папка stream> <превью.png>
каждая модель: одна деталь kv_p_<имя>, текстуры DDS (шаг 1) встроены, коллизия из той же сетки, общий kavkaz_props.ytyp.
"""
import addon_utils
import bpy
import math
import os
import sys
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
SRC, OUT, PREVIEW = [os.path.abspath(a) for a in argv[:3]]
TMP = os.path.join(OUT, '_sz')
os.makedirs(TMP, exist_ok=True)
addon_utils.enable('Sollumz', default_set=True, persistent=True)  # даёт путь к szio; после сброса включаем ещё раз

import struct  # noqa: E402
from Sollumz.sollumz_preferences import get_export_settings  # noqa: E402
from Sollumz.sollumz_properties import AssetType  # noqa: E402

bpy.ops.wm.read_factory_settings(use_empty=True)
addon_utils.enable('Sollumz', default_set=True, persistent=True)
from Sollumz.ydr.operators.materials import MaterialConverter  # noqa: E402
scene = bpy.context.scene
built = []


def solid_dds(rgb):
    """одноцветная DXT1 4x4 для материалов без текстуры"""
    r, g, b = [max(0, min(255, int(round((12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055) * 255)))) for c in rgb[:3]]
    c565 = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)
    head = bytearray(128)
    head[0:4] = b'DDS '
    struct.pack_into('<7I', head, 4, 124, 0x1 | 0x2 | 0x4 | 0x1000 | 0x80000, 4, 4, 8, 0, 1)
    struct.pack_into('<2I4s', head, 76, 32, 0x4, b'DXT1')
    struct.pack_into('<I', head, 108, 0x1000)
    path = os.path.join(SRC, '_c%02x%02x%02x.dds' % (r, g, b))
    with open(path, 'wb') as f:
        f.write(bytes(head) + struct.pack('<HHI', c565, c565, 0))
    return path

# хрущёвка скачана в масштабе ~1:2.3 (5 этажей должны быть ~15 м); пачки сигарет и фасад — не для улиц
SCALE = {'khrushchevka': 2.3}
SKIP = {'ussr_props', 'soviet_panel_building_facade_psx_style'}

for name in sorted(os.listdir(SRC)):
    g = os.path.join(SRC, name, 'scene.gltf')
    if not os.path.exists(g) or name in SKIP:
        continue
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=g)
    meshes = [o for o in bpy.data.objects if o not in before and o.type == 'MESH']
    if not meshes:
        continue
    # всё в одну сетку, трансформации в геометрию
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    for o in meshes:
        o.matrix_world = o.matrix_world.copy()
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in [o for o in bpy.data.objects if o not in before and o != ob]:
        bpy.data.objects.remove(o)
    # центр: по X/Y середина, низ на земле (Z=0)
    bb = [Vector(v) for v in ob.bound_box]
    lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    shift = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    k = SCALE.get(name, 1.0)  # модели в «неправильных» единицах — к настоящему размеру
    for v in ob.data.vertices:
        v.co = (v.co - shift) * k
    pid = 'kv_p_' + name.replace('_psx_style', '').replace('_psx', '').replace('__', '_')[:40]
    ob.name = pid
    size = (hi - lo) * k
    # UV / цвет вершин для шейдеров GTA
    me = ob.data
    if not me.uv_layers:
        me.uv_layers.new(name='UVMap 0')
    me.uv_layers[0].name = 'UVMap 0'
    if 'Color 1' not in me.color_attributes:
        ca = me.color_attributes.new('Color 1', 'BYTE_COLOR', 'CORNER')
        for c in ca.data:
            c.color = (1, 1, 1, 1)
    # текстуры -> DDS из шага 1, материалы -> шейдеры Sollumz
    for slot in ob.material_slots:
        m = slot.material
        if not m or not m.use_nodes:
            continue
        alpha = False
        for n in m.node_tree.nodes:
            if n.type == 'TEX_IMAGE' and n.image:
                p = bpy.path.abspath(n.image.filepath)
                dds = os.path.splitext(p)[0] + '.dds'
                if os.path.exists(dds):
                    n.image = bpy.data.images.load(dds)
                    n.image.pack()
                if any(l.to_socket.name == 'Alpha' for l in n.outputs['Alpha'].links):
                    alpha = True
        bsdf0 = m.node_tree.nodes.get('Principled BSDF')
        if bsdf0 and not bsdf0.inputs['Base Color'].is_linked:
            tn = m.node_tree.nodes.new('ShaderNodeTexImage')
            tn.image = bpy.data.images.load(solid_dds(bsdf0.inputs['Base Color'].default_value))
            tn.image.pack()
            m.node_tree.links.new(tn.outputs['Color'], bsdf0.inputs['Base Color'])
        # металл/шероховатость GTA не понимает — отцепляем, остаются цвет и нормали
        bsdf = m.node_tree.nodes.get('Principled BSDF')
        if bsdf:
            for sock in ('Metallic', 'Roughness', 'Emission Color'):
                if sock in bsdf.inputs:
                    for l in list(bsdf.inputs[sock].links):
                        m.node_tree.links.remove(l)
        try:
            conv = MaterialConverter(ob, m)
            new = conv.convert('cutout.sps') if alpha else conv.auto_convert()
        except Exception as e:  # noqa
            print('KAVKAZ материал не сконвертирован', pid, m.name, e)
            new = None
        if new:
            slot.material = new
    for slot in ob.material_slots:
        if slot.material and slot.material.use_nodes:
            for n in slot.material.node_tree.nodes:
                if isinstance(n, bpy.types.ShaderNodeTexImage) and hasattr(n, 'texture_properties'):
                    n.texture_properties.embedded = True
    # в Drawable + встроенная коллизия
    scene.auto_create_embedded_col = True
    scene.create_seperate_drawables = True
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.sollumz.converttodrawable()
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    built.append((pid, size, tris))
    print('KAVKAZ модель %s: %.1f x %.1f x %.1f м, %d треуг.' % (pid, size.x, size.y, size.z, tris), flush=True)

settings = get_export_settings(bpy.context)
settings.target_formats = {'NATIVE'}
settings.target_versions = {'GEN8'}
settings.limit_to_selected = True
bpy.ops.object.select_all(action='DESELECT')
for pid, _, _ in built:
    bpy.data.objects[pid].select_set(True)
bpy.ops.sollumz.export_assets(directory=TMP)

ytyp = scene.ytyps.add()
ytyp.name = 'kavkaz_props'
for i, (pid, size, _) in enumerate(built):
    a = ytyp.archetypes.add()
    a.id = i + 1
    a.name = pid
    a.asset_name = pid
    a.asset_type = AssetType.DRAWABLE
    a.texture_dictionary = pid
    a.physics_dictionary = pid
    a.lod_dist = 400.0 if size.z > 8 else 120.0
    # 12.11: габариты обязательны — с нулевыми игра прячет большой дом, как только его центр уходит из кадра
    a.bb_min = (-size.x / 2, -size.y / 2, 0.0)
    a.bb_max = (size.x / 2, size.y / 2, size.z)
    a.bs_center = (0.0, 0.0, size.z / 2)
    a.bs_radius = (size.x ** 2 + size.y ** 2 + size.z ** 2) ** 0.5 / 2
scene.ytyp_index = len(scene.ytyps) - 1
bpy.ops.sollumz.export_ytyp_io(directory=TMP)

import shutil  # noqa: E402
for dp, _, fs in os.walk(TMP):
    for f in fs:
        if f.endswith(('.ydr', '.ytyp')):
            shutil.copy(os.path.join(dp, f), os.path.join(OUT, f))
shutil.rmtree(TMP, ignore_errors=True)

# превью: все модели в ряд, вид 3/4
x = 0.0
for pid, size, _ in built:
    o = bpy.data.objects[pid]
    o.location = (x + size.x / 2, 0, 0)
    x += size.x + 4.0
world = bpy.data.worlds.new('w')
scene.world = world
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.55, 0.62, 0.7, 1)
sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
sun.data.energy = 3.5
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.type = 'ORTHO'
cam.data.ortho_scale = x * 1.05
cam.location = (x / 2 + x * 0.35, -x * 0.9, x * 0.45)
d = Vector((x / 2, 0, 6)) - cam.location
cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
try:
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
except TypeError:
    scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x, scene.render.resolution_y = 2400, 1000
scene.render.filepath = PREVIEW
bpy.ops.render.render(write_still=True)
print('KAVKAZ готово:', len(built), flush=True)
