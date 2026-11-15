"""KAVKAZ RP: флаг Нагорска (15.11, основатель: «РФ флаги развешай и нам свой флаг придумай»).
рисунок: белое поле (небо, снег), две зелёные вершины бренда #3dcc5c (правая выше), графитовая полоса — земля. без этники.
флаг — настоящий тканевый флаг GTA (развевается): берём модель prop_flag_scotland (шотландский, у нас всё равно спрятан)
и подменяем её встроенную текстуру 512x256.
шаг 1 (картинка):  python -I setup/models/make_flag.py -- <папка вывода>
шаг 2 (модель):    blender -b --factory-startup -P setup/models/make_flag.py -- <папка вывода>
"""
import os, sys
try:
    import bpy  # noqa: F401
except ImportError:
    bpy = None

OUT = sys.argv[sys.argv.index('--') + 1]
os.makedirs(OUT, exist_ok=True)
PNG, DDS = os.path.join(OUT, 'flag_nagorsk.png'), os.path.join(OUT, 'flag_nagorsk.dds')
W, H = 512, 256
GREEN, GRAPHITE, WHITE = (0x3d, 0xcc, 0x5c), (0x1c, 0x1e, 0x24), (0xf4, 0xf5, 0xf2)

if bpy is None:
    from PIL import Image, ImageDraw
    S = 4  # рисуем крупно и уменьшаем — ровные края
    im = Image.new('RGB', (W * S, H * S), WHITE); d = ImageDraw.Draw(im)
    w, h = W * S, H * S
    base = int(h * 0.78)                      # линия земли
    d.rectangle([0, base, w, h], fill=GRAPHITE)
    # две вершины: левая ниже, правая выше; снежные шапки — белый «зубец» в каждой
    left = [(0, base), (int(w * 0.30), int(h * 0.36)), (int(w * 0.47), int(h * 0.58)), (int(w * 0.66), int(h * 0.20)), (w, base)]
    d.polygon(left, fill=GREEN)
    for (cx, cy), k in (((int(w * 0.30), int(h * 0.36)), 0.09), ((int(w * 0.66), int(h * 0.20)), 0.11)):
        dx, dy = int(w * k * 0.55), int(h * k * 1.25)
        d.polygon([(cx, cy), (cx - dx, cy + dy), (cx - dx // 3, cy + dy - dy // 4), (cx, cy + dy), (cx + dx // 3, cy + dy - dy // 4), (cx + dx, cy + dy)], fill=WHITE)
    d.rectangle([0, base - int(h * 0.025), w, base], fill=WHITE)  # тонкая белая черта над землёй
    im = im.resize((W, H), Image.LANCZOS)
    im.save(PNG)
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from dds import save_dds
    save_dds(im, DDS, False)
    print('флаг нарисован', PNG)
    sys.exit(0)

import addon_utils  # noqa: E402
addon_utils.enable('Sollumz', default_set=True)
from Sollumz.shared.game_assets.game_files import GameFiles  # noqa: E402
from szio.gta5 import try_load_asset, save_asset, AssetTarget, AssetFormat, AssetVersion  # noqa: E402
from szio.types import DataSource  # noqa: E402

idx = GameFiles(r'D:\gta enhansed\GTAV').read_asset_filelist()
yft = {str(k).lower(): (v[0] if isinstance(v, (list, tuple)) else v) for k, v in idx.get(('.yft',), {}).items()}
for name in ('prop_flag_scotland', 'prop_flag_scotland_s'):
    a = try_load_asset(yft[name])
    n = 0
    for c in a.cloths or []:
        for k, t in (c.drawable.shader_group.embedded_textures or {}).items():
            if str(k).lower().startswith('prop_flag_scotland'):
                t.data = DataSource.create(DDS, str(k) + '.dds'); n += 1
    save_asset(a, [AssetTarget(AssetFormat.NATIVE, AssetVersion.GEN8)], __import__('pathlib').Path(OUT), name)
    print('KAVKAZ флаг', name, 'текстур подменено', n, flush=True)
