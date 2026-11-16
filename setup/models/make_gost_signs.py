"""KAVKAZ RP: дорожные знаки ГОСТ как модели (16.11) — ставятся на места убранных американских знаков (setup/maps/gost_place.py).
картинки — setup/retex/road_signs.py (kavkaz_world/images/retex/gost_*.png). табличка повторяет контур знака (выпуклая оболочка
непрозрачных пикселей), лицо смотрит в -Y (как у знаков GTA), изнанка серая, оцинкованная стойка Ø 76 мм позади.
+ сигнальный столбик С3 (белый, чёрная полоса, катафот) для обочин.
blender -b --factory-startup -P setup/models/make_gost_signs.py -- <папка картинок gost_*.png> <папка моделей>
дальше: python -I setup/models/props_prep.py <папка моделей> --max 512
        blender -b --factory-startup -P setup/models/props_blender.py -- <папка моделей> <stream> <превью.png> --ytyp kavkaz_signs
"""
import math, os, sys
import bpy
import numpy as np

a = sys.argv[sys.argv.index('--') + 1:]
SRC, OUT = a[0], a[1]
os.makedirs(OUT, exist_ok=True)

# код знака: (ширина квадрата картинки в метрах, высота низа таблички над землёй)
TRI, STD, WIDE = 1.0, 0.78, 1.5
SIGNS = {
    '2_1': (STD, 2.0), '2_4': (TRI, 2.0), '2_5': (STD, 2.0), '3_1': (STD, 2.0), '3_2': (STD, 2.0),
    '3_24_20': (STD, 2.0), '3_24_40': (STD, 2.0), '3_24_60': (STD, 2.0), '3_24_90': (STD, 2.0),
    '3_27': (STD, 2.0), '3_28': (STD, 2.0), '4_1_1': (STD, 2.0), '4_1_2': (STD, 2.0), '4_2_1': (STD, 2.0),
    '5_19_1': (STD, 2.2), '6_4': (STD, 2.0), '1_11_1': (TRI, 2.0), '1_11_2': (TRI, 2.0), '1_22': (TRI, 2.0),
    '1_34_1': (1.1, 1.0), '1_34_2': (1.1, 1.0), '5_1': (1.0, 2.0), '5_5': (STD, 2.0), '7_12_dps': (1.0, 2.0),
    '5_23_nagorsk': (WIDE, 1.6),
}


def mat(name, rgba=None, image=None):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Roughness'].default_value = 0.55
    if image:
        t = m.node_tree.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(image)
        m.node_tree.links.new(t.outputs['Color'], b.inputs['Base Color'])
    else:
        b.inputs['Base Color'].default_value = rgba
    return m


def hull(png):
    """контур знака: выпуклая оболочка непрозрачных пикселей, ≤ 40 вершин, в долях картинки (0..1, y вниз)"""
    img = bpy.data.images.load(png)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]  # Blender хранит снизу вверх
    ys, xs = np.nonzero(px[..., 3] > 0.5)
    pts = sorted(set(zip((xs / w).round(4), (ys / h).round(4))))

    def cross(o, p, q):
        return (p[0] - o[0]) * (q[1] - o[1]) - (p[1] - o[1]) * (q[0] - o[0])
    lo, hi = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(hi) >= 2 and cross(hi[-2], hi[-1], p) <= 0:
            hi.pop()
        hi.append(p)
    ring = lo[:-1] + hi[:-1]
    # упростить (Висвалингам): по одной убираем вершину с самым маленьким треугольником, пока не останется 40
    while len(ring) > 40:
        n = len(ring)
        i = min(range(n), key=lambda i: abs(cross(ring[i - 1], ring[i], ring[(i + 1) % n])))
        ring.pop(i)
    # прозрачная картинка на белом — DXT1 без альфы, края не чёрные
    flat = px.copy()
    al = flat[..., 3:4]
    flat[..., :3] = flat[..., :3] * al + (1 - al)
    flat[..., 3] = 1
    out = bpy.data.images.new('flat', w, h)
    out.pixels = flat[::-1].ravel()
    bpy.data.images.remove(img)
    return ring, out


def plate(name, ring, size, z0, face_mat, back_mat):
    """лицевая (-Y) и тыльная (+Y) таблички по контуру; z0 — низ таблички"""
    ys = [p[1] for p in ring]
    ymax = max(ys)
    verts, faces, uvs = [], [], []
    for side, y in (('face', -0.025), ('back', 0.0)):
        base = len(verts)
        for u, v in ring:
            verts.append(((u - 0.5) * size, y, z0 + (ymax - v) * size))
        idx = list(range(base, base + len(ring)))
        # оболочка обходится против часовой в координатах картинки (y вниз) → в мире (z вверх) по часовой, если смотреть с -Y
        faces.append(idx[::-1] if side == 'face' else idx)
        uvs.append([(u, 1 - v) for u, v in ring][::-1] if side == 'face' else [(0.5, 0.5)] * len(ring))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    uv = me.uv_layers.new(name='UVMap')
    for f, fu in zip(me.polygons, uvs):
        for li, (u, v) in zip(f.loop_indices, fu):
            uv.data[li].uv = (u, v)
    me.materials.append(face_mat); me.materials.append(back_mat)
    me.polygons[1].material_index = 1
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob, z0 + (ymax - min(ys)) * size


def export(folder, title):
    d = os.path.join(OUT, folder); os.makedirs(d, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(d, 'scene.gltf'), export_format='GLTF_SEPARATE')
    open(os.path.join(d, 'license.txt'), 'w', encoding='utf-8').write(
        f'Model Information:\n* title:\t{title}\n* source:\tKAVKAZ RP (setup/models/make_gost_signs.py)\n* author:\tKAVKAZ RP\n\n'
        'Model License:\n* license type:\tсвоя\n')


for code, (size, z0) in SIGNS.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    png = os.path.join(SRC, f'gost_{code}.png')
    ring, flat = hull(png)
    tex = os.path.join(OUT, f'_tex_gost_{code}.png')
    flat.filepath_raw = tex; flat.file_format = 'PNG'; flat.save()
    zinc = mat('zinc', (0.55, 0.57, 0.58, 1))
    ob, ztop = plate(f'gost_{code}', ring, size, z0, mat(f'gost_{code}', image=tex), zinc)
    # стойка Ø 76 мм позади таблички, чуть выше её верха
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.038, depth=ztop + 0.05, location=(0, 0.045, (ztop + 0.05) / 2))
    bpy.context.object.data.materials.append(zinc)
    if code.startswith('5_23') or code.startswith('1_34'):  # широкие таблички — на двух стойках
        for x in (-0.38 * size, 0.38 * size):
            bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.038, depth=ztop + 0.05, location=(x, 0.045, (ztop + 0.05) / 2))
            bpy.context.object.data.materials.append(zinc)
    export(f'gost_{code}', f'знак {code.replace("_", ".")}')
    print('KAVKAZ знак', code, 'вершин контура', len(ring), flush=True)

# сигнальный столбик С3: белый, чёрная косая полоса сверху, красный катафот
bpy.ops.wm.read_factory_settings(use_empty=True)
white, black, red = mat('white', (0.9, 0.9, 0.88, 1)), mat('black', (0.02, 0.02, 0.02, 1)), mat('refl', (0.8, 0.05, 0.03, 1))
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.6)); o = bpy.context.object
o.scale = (0.12, 0.12, 1.2); bpy.ops.object.transform_apply(scale=True); o.data.materials.append(white)
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 1.0)); o = bpy.context.object
o.scale = (0.125, 0.125, 0.2); o.rotation_euler = (math.radians(18), 0, 0)
bpy.ops.object.transform_apply(scale=True, rotation=True); o.data.materials.append(black)
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.064, 1.0)); o = bpy.context.object
o.scale = (0.06, 0.01, 0.12); bpy.ops.object.transform_apply(scale=True); o.data.materials.append(red)
export('stolbik', 'сигнальный столбик С3')
print('KAVKAZ столбик', flush=True)
