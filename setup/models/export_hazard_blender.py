"""KAVKAZ RP: экспорт пульта «Хазард 7007» в формат игры (Sollumz, без окна).
blender -b setup/models/hazard/kv_hazard7007.blend -P setup/models/export_hazard_blender.py -- <папка stream>
на выходе: kv_hazard7007.ydr, kv_hazard_knob_vol.ydr, kv_hazard_knob_sel.ydr, kv_hazard_btn_pa.ydr, kv_hazard_btn_horn.ydr,
kv_hazard_led_l1.ydr, kv_hazard_led_l2.ydr (текстуры встроены), kavkaz_sgu.ytyp и offsets.json —
смещения деталей от центра корпуса (их берёт client.lua, чтобы прикрепить ручки и кнопки на свои места).
"""
import addon_utils
import bpy
import json
import math
import os
import shutil
import sys

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(argv[0])
os.makedirs(OUT, exist_ok=True)
TMP = os.path.join(OUT, '_sz')
SRC = os.path.dirname(bpy.data.filepath)
os.makedirs(TMP, exist_ok=True)

addon_utils.enable('Sollumz', default_set=True, persistent=True)
from Sollumz.ydr.operators.materials import MaterialConverter  # noqa: E402
from Sollumz.tools.drawablehelper import convert_obj_to_drawable  # noqa: E402
from Sollumz.sollumz_preferences import get_export_settings  # noqa: E402

print('STEP addon', flush=True)
scene = bpy.context.scene
PARTS = ['kv_hazard7007', 'kv_hazard_knob_vol', 'kv_hazard_knob_sel', 'kv_hazard_btn_pa', 'kv_hazard_btn_horn',
         'kv_hazard_led_l1', 'kv_hazard_led_l2']

# одноцветные материалы -> маленькая текстура того же цвета (шейдеру default.sps нужна картинка)
for m in bpy.data.materials:
    if not m.use_nodes:
        continue
    nt = m.node_tree
    bsdf = nt.nodes.get('Principled BSDF')
    if not bsdf or bsdf.inputs['Base Color'].is_linked:
        continue
    # образцы цвета в DDS готовит hazard_face.py (лежат рядом с .blend)
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(os.path.join(SRC, m.name + '_c.dds'))
    tex.image.pack()
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])

# лицевая: рельеф (bump) Sollumz не понимает — связь убираем, картинку меняем на DDS с mip
for m in bpy.data.materials:
    if m.use_nodes and m.name == 'hz_face':
        nt = m.node_tree
        for n in nt.nodes:
            if n.type == 'BUMP':
                for l in list(n.outputs['Normal'].links):
                    nt.links.remove(l)
            if n.type == 'TEX_IMAGE' and n.image and n.image.name.startswith('kv_hazard7007_face.'):
                n.image = bpy.data.images.load(os.path.join(SRC, 'hz_face.dds'))
                n.image.pack()

# шейдерам GTA нужны UV «UVMap 0» и цвет вершин «Color 1» (белый)
for name in PARTS:
    me = bpy.data.objects[name].data
    if not me.uv_layers:
        me.uv_layers.new(name='UVMap 0')
    me.uv_layers[0].name = 'UVMap 0'
    if 'Color 1' not in me.color_attributes:
        ca = me.color_attributes.new('Color 1', 'BYTE_COLOR', 'CORNER')
        for d in ca.data:
            d.color = (1, 1, 1, 1)

print('STEP textures', flush=True)
body = bpy.data.objects['kv_hazard7007']
offsets = {}
for name in PARTS:
    ob = bpy.data.objects[name]
    # ручки: убрать поворот вокруг оси (его даёт игра), оставить «лицом наружу»; повернуть геометрию в сетку
    if 'knob' in name:
        ob.rotation_euler.y = 0
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    offsets[name] = [round(v, 5) for v in (ob.location - body.location)]
    for slot in ob.material_slots:
        if slot.material and slot.material.sollum_type != 'sollumz_material_shader':
            new = MaterialConverter(ob, slot.material).auto_convert()
            if new:
                slot.material = new
    for slot in ob.material_slots:
        for n in slot.material.node_tree.nodes:
            if isinstance(n, bpy.types.ShaderNodeTexImage) and hasattr(n, 'texture_properties'):
                n.texture_properties.embedded = True
    print('STEP convert', name, flush=True)
    drawable = convert_obj_to_drawable(ob)
    drawable.location = (0, 0, 0)  # каждая деталь — своя модель с центром в своей точке

settings = get_export_settings(bpy.context)
settings.target_formats = {'NATIVE'}
settings.target_versions = {'GEN8'}
settings.limit_to_selected = True

bpy.ops.object.select_all(action='DESELECT')
for name in PARTS:
    bpy.data.objects[name].select_set(True)
print('STEP export', flush=True)
bpy.ops.sollumz.export_assets(directory=TMP)
print('STEP ytyp', flush=True)

# ytyp: по архетипу на каждую деталь
from Sollumz.sollumz_properties import AssetType  # noqa: E402
ytyp = scene.ytyps.add()
ytyp.name = 'kavkaz_sgu'
print('STEP ytyp add', flush=True)
for i, name in enumerate(PARTS):
    item = ytyp.archetypes.add()
    print('STEP arch', name, flush=True)
    item.id = i + 1
    item.name = name
    item.asset_name = name
    item.asset_type = AssetType.DRAWABLE
    item.texture_dictionary = name
    item.lod_dist = 30.0
    ob = bpy.data.objects[name]
    lo = [min(v[k] for v in ob.bound_box) for k in range(3)]
    hi = [max(v[k] for v in ob.bound_box) for k in range(3)]
    if hasattr(item, 'bb_min'):
        item.bb_min, item.bb_max = lo, hi
        item.bs_center = [(a + b) / 2 for a, b in zip(lo, hi)]
        item.bs_radius = max(b - a for a, b in zip(lo, hi))
scene.ytyp_index = len(scene.ytyps) - 1
print('STEP ytyp export', flush=True)
bpy.ops.sollumz.export_ytyp_io(directory=TMP)

n = 0
for root, _, files in os.walk(TMP):
    for f in files:
        if f.endswith(('.ydr', '.ytyp')):
            shutil.copy(os.path.join(root, f), os.path.join(OUT, f))
            n += 1
            print('KAVKAZ файл:', f, os.path.getsize(os.path.join(root, f)))
shutil.rmtree(TMP, ignore_errors=True)
with open(os.path.join(OUT, 'offsets.json'), 'w') as fp:
    json.dump(offsets, fp, indent=1)
print('KAVKAZ готово, файлов:', n, offsets)
