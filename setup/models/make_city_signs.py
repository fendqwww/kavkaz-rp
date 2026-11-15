"""KAVKAZ RP: стела «НАГОРСК» на въезде и дорожный знак населённого пункта (въезд / перечёркнутый выезд) -> glTF
в папку моделей, дальше обычный конвейер props_prep.py + props_blender.py.
шаг 1 (таблички, PIL): python -I setup/models/make_city_signs.py -- <папка моделей> <шрифт.ttf> [НАЗВАНИЕ]
шаг 2 (модели):       blender -b --factory-startup -P setup/models/make_city_signs.py -- <папка моделей> <шрифт.ttf> [НАЗВАНИЕ]
лицо моделей — +Y (в kavkaz_world «вперёд» — к дороге). шрифт — Montserrat Black Italic (OFL), как логотип KAVKAZ.
"""
import math, os, sys
try:
    import bpy
except ImportError:  # обычный Python: только картинки табличек
    bpy = None

a = sys.argv[sys.argv.index('--') + 1:]
OUT, FONT = a[0], a[1]
NAME = a[2] if len(a) > 2 else 'НАГОРСК'
GREEN = (0x3d / 255, 0xcc / 255, 0x5c / 255, 1.0)
TMP = os.path.join(OUT, '_city_sign_tex')


def plate_png(path, crossed):
    from PIL import Image, ImageDraw, ImageFont
    W, H = 1024, 400
    im = Image.new('RGB', (W, H), 'white'); dr = ImageDraw.Draw(im)
    dr.rectangle([10, 10, W - 11, H - 11], outline='black', width=14)
    f = ImageFont.truetype(FONT.replace('BlackItalic', 'Black'), 190)
    tw = dr.textlength(NAME, font=f)
    while tw > W - 120:
        f = ImageFont.truetype(FONT.replace('BlackItalic', 'Black'), f.size - 8); tw = dr.textlength(NAME, font=f)
    dr.text(((W - tw) / 2, H / 2), NAME, font=f, fill='black', anchor='lm')
    if crossed:  # красная полоса из левого нижнего в правый верхний угол
        dr.line([(40, H - 40), (W - 40, 40)], fill=(200, 20, 30), width=44)
    im.save(path)



if bpy is None:
    os.makedirs(TMP, exist_ok=True)
    plate_png(os.path.join(TMP, 'sign_in.png'), False); plate_png(os.path.join(TMP, 'sign_out.png'), True)
    print('таблички готовы', TMP); sys.exit(0)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgba, image=None, emis=False):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    if image:
        t = m.node_tree.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(image)
        m.node_tree.links.new(t.outputs['Color'], b.inputs['Base Color'])
    else:
        b.inputs['Base Color'].default_value = rgba
    b.inputs['Roughness'].default_value = 0.8
    return m


def box(name, size, loc, m):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object; o.name = name; o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(m)
    return o


def export(folder, title):
    d = os.path.join(OUT, folder); os.makedirs(d, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(d, 'scene.gltf'), export_format='GLTF_SEPARATE')
    open(os.path.join(d, 'license.txt'), 'w', encoding='utf-8').write(
        f'Model Information:\n* title:\t{title}\n* source:\tKAVKAZ RP (своя модель, setup/models/make_city_signs.py)\n'
        f'* author:\tKAVKAZ RP\n\nModel License:\n* license type:\tсвоя; шрифт Montserrat — SIL OFL 1.1\n')
    print('KAVKAZ модель', folder, flush=True)


# ---------- 1. стела: светящиеся буквы на графитовом постаменте с зелёной полосой ----------
reset()
bpy.ops.object.text_add()
t = bpy.context.object
t.data.body = NAME
t.data.font = bpy.data.fonts.load(FONT)
t.data.size = 7.0                 # заглавные ~5 м
t.data.extrude = 0.35             # толщина букв 0,7 м
t.data.bevel_depth = 0.03
t.data.align_x = 'CENTER'
t.data.space_character = 1.05
bpy.ops.object.convert(target='MESH')
letters = bpy.context.object; letters.name = 'letters'
letters.rotation_euler = (math.radians(90), 0, math.radians(180))   # встаёт, лицом к +Y
bpy.ops.object.transform_apply(rotation=True)
bb = [letters.matrix_world @ v.co for v in letters.data.vertices]
w = max(v.x for v in bb) - min(v.x for v in bb)
zmin = min(v.z for v in bb)
PL_H, SINK = 1.4, 1.0               # постамент 1,4 м над землёй + 1 м в земле (на склоне без щели)
letters.location = (-(max(v.x for v in bb) + min(v.x for v in bb)) / 2, 0, PL_H - zmin + 0.05)
bpy.ops.object.transform_apply(location=True)
letters.data.materials.append(mat('kv_emis_letters', (1, 1, 1, 1)))
base = box('base', (w + 4.0, 2.4, PL_H + SINK), (0, 0, (PL_H - SINK) / 2), mat('graphite', (0.07, 0.075, 0.085, 1)))
box('stripe', (w + 4.02, 0.06, 0.28), (0, 1.22, PL_H - 0.3), mat('kv_emis_green', GREEN))
box('stripe_b', (w + 4.02, 0.06, 0.28), (0, -1.22, PL_H - 0.3), mat('kv_emis_green_b', GREEN))
export('stela_nagorsk', f'Стела {NAME}')

# ---------- 2. знак населённого пункта (5.23.1 / 5.24): одна табличка, с обратной стороны — перечёркнутая ----------
reset()
front, back = os.path.join(TMP, 'sign_in.png'), os.path.join(TMP, 'sign_out.png')
PW, PH, POST = 2.0, 0.78, 2.3
for nm, png, y, rot in (('face_in', front, 0.025, 0), ('face_out', back, -0.025, 180)):
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, y, POST + PH / 2))
    p = bpy.context.object; p.name = nm; p.scale = (PW, PH, 1)
    p.rotation_euler = (math.radians(90), 0, math.radians(180 + rot))  # лицо +Y (въезд) и -Y (выезд)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    p.data.materials.append(mat(nm, (1, 1, 1, 1), image=png))
box('edge', (PW + 0.02, 0.04, PH + 0.02), (0, 0, POST + PH / 2), mat('metal', (0.55, 0.57, 0.6, 1)))
for x in (-0.7, 0.7):
    bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=POST + PH + 0.6, location=(x, -0.06, (POST + PH - 0.6) / 2))
    bpy.context.object.data.materials.append(bpy.data.materials['metal'])
export('sign_city_nagorsk', f'Знак населённого пункта {NAME}')
