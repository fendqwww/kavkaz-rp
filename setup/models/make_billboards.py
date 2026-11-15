"""KAVKAZ RP: свои рекламные щиты (15.11) — американские убраны целиком, наши стоят точечно у главных дорог.
6 макетов в стиле бренда (графит, белый, зелёный #3dcc5c, Montserrat Black/Italic — OFL), щит 6 x 3 м на опоре, двусторонний.
шаг 1 (макеты, PIL):  python -I setup/models/make_billboards.py -- <папка моделей> <папка шрифтов>
шаг 2 (модели):       blender -b --factory-startup -P setup/models/make_billboards.py -- <папка моделей> <папка шрифтов>
дальше обычный конвейер props_prep.py + props_blender.py (kv_p_bb_<id>), расстановка — setup/maps/billboards_place.py.
"""
import math, os, sys
try:
    import bpy
except ImportError:
    bpy = None

a = sys.argv[sys.argv.index('--') + 1:]
OUT, FONTS = a[0], a[1]
TMP = os.path.join(OUT, '_bb_tex')
GREEN, GRAPHITE, WHITE, DIM = (0x3d, 0xcc, 0x5c), (0x16, 0x18, 0x1d), (0xf4, 0xf5, 0xf2), (0x9a, 0xa0, 0xa8)
# id: (крупно, мелко, сноска)
ADS = {
    'nagorsk': ('НАГОРСК', 'дорога домой начинается здесь', ''),
    'taxi':    ('ТАКСИ «ШАШКИ»', 'довезём быстрее, чем передумаешь', '07-07'),
    'school':  ('АВТОШКОЛА', 'права за 6 вопросов*', '*и одну поездку'),
    'pelmeni': ('ПЕЛЬМЕНИ «ДЕДОВСКИЕ»', 'лепим с 1987 года', ''),
    'dps':     ('ДПС НАПОМИНАЕТ', 'тонировка «в ноль» — штраф и снятие', 'береги номера смолоду'),
    'job':     ('ИЩЕШЬ РАБОТУ?', 'автовокзал — там подскажут', 'доставка · такси · автобус'),
}


def draw(key, big, small, note):
    from PIL import Image, ImageDraw, ImageFont
    W, H, S = 1024, 512, 2
    im = Image.new('RGB', (W * S, H * S), GRAPHITE); d = ImageDraw.Draw(im)
    w, h = W * S, H * S
    f = lambda name, size: ImageFont.truetype(os.path.join(FONTS, name), size)
    d.rectangle([0, h - 34, w, h], fill=GREEN)                          # полоса бренда снизу
    # горы с флага Нагорска — маленький знак в углу
    bx, by, s = w - 210, 70, 1.0
    d.polygon([(bx, by + 90), (bx + 50, by + 35), (bx + 80, by + 62), (bx + 120, by), (bx + 175, by + 90)], fill=GREEN)
    size = 230
    while d.textlength(big, font=f('Montserrat-BlackItalic.ttf', size)) > w - 260 and size > 90:
        size -= 8
    d.text((90, h * 0.40), big, font=f('Montserrat-BlackItalic.ttf', size), fill=WHITE, anchor='lm')
    d.text((96, h * 0.66), small, font=f('Montserrat-Black.ttf', 84), fill=GREEN if key != 'nagorsk' else WHITE, anchor='lm')
    if note:
        d.text((98, h * 0.83), note, font=f('Montserrat-Black.ttf', 54), fill=DIM, anchor='lm')
    im = im.resize((W, H), Image.LANCZOS)
    im.save(os.path.join(TMP, f'bb_{key}.png'))


if bpy is None:
    os.makedirs(TMP, exist_ok=True)
    for k, v in ADS.items():
        draw(k, *v)
    print('макеты готовы', TMP); sys.exit(0)


def mat(name, rgba, image=None):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    if image:
        t = m.node_tree.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(image)
        m.node_tree.links.new(t.outputs['Color'], b.inputs['Base Color'])
    else:
        b.inputs['Base Color'].default_value = rgba
    return m


BW, BH, POLE = 6.0, 3.0, 6.0
for k in ADS:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    face = mat(f'bb_{k}', (1, 1, 1, 1), os.path.join(TMP, f'bb_{k}.png'))
    for y, rz in ((0.16, 180), (-0.16, 0)):                              # лицо +Y и -Y (двусторонний)
        bpy.ops.mesh.primitive_plane_add(size=1, location=(0, y, POLE + BH / 2))
        p = bpy.context.object; p.scale = (BW, BH, 1)
        p.rotation_euler = (math.radians(90), 0, math.radians(rz))
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        p.data.materials.append(face)
    steel = mat('steel', (0.32, 0.34, 0.37, 1))
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, POLE + BH / 2)); fr = bpy.context.object
    fr.scale = (BW + 0.25, 0.3, BH + 0.25); bpy.ops.object.transform_apply(scale=True); fr.data.materials.append(steel)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.22, depth=POLE + 0.2, location=(0, 0, POLE / 2)); bpy.context.object.data.materials.append(steel)
    d = os.path.join(OUT, f'bb_{k}'); os.makedirs(d, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(d, 'scene.gltf'), export_format='GLTF_SEPARATE')
    open(os.path.join(d, 'license.txt'), 'w', encoding='utf-8').write(
        f'Model Information:\n* title:\tЩит «{ADS[k][0]}»\n* source:\tKAVKAZ RP (setup/models/make_billboards.py)\n* author:\tKAVKAZ RP\n\n'
        'Model License:\n* license type:\tсвоя; шрифт Montserrat — SIL OFL 1.1\n')
    print('KAVKAZ щит', k, flush=True)
