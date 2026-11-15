"""KAVKAZ RP: убрать объект карты на ЛЮБОМ расстоянии — и ближнюю модель, и дальние (lod/slod).
CreateModelHide прячет только ближнюю модель: дальняя версия — другой объект, и он остаётся («отошёл — появилось,
подошёл — исчезло», колесо обозрения 15.11). здесь треугольники делаются вырожденными (три одинаковых индекса):
игра такие не рисует, а структура файла не меняется (те же буферы, шейдеры, текстуры) — файл стримится вместо оригинала.

blender -b --factory-startup -P setup/maps/hide_geom_blender.py -- <job.json> <папка вывода> [--dry] [--base <папка>]
job.json — список файлов:
  {"kind": "ydr", "name": "p_ferris_wheel_amo_l", "mode": "all"}
  {"kind": "ydd", "name": "sm_22_slod1b_children", "drawables": {"hash_6BF530F0": {"mode": "all"},
       "hash_98EF9DE5": {"mode": "box", "origin": [x, y, z]}}, "boxes": [[[x0, y0, z0], [x1, y1, z1]], ...]}
  all — убрать модель целиком; box — только треугольники, у которых ВСЕ три вершины внутри одной из коробок
  (мировые координаты; origin — позиция объекта на карте, у lod/slod поворота нет); "vertical": 0.5 — из них только
  крутые (|nz| < 0.5: буквы и щиты, а не склон под ними). модели набора, которых нет в
  "drawables", не трогаются. --dry — только посчитать. --base: брать наш файл с тем же именем, если он там есть.
"""
import addon_utils
import json
import sys
from pathlib import Path

import numpy as np

argv = sys.argv[sys.argv.index('--') + 1:]
JOB, OUT = Path(argv[0]), Path(argv[1])
DRY = '--dry' in argv
BASE = Path(argv[argv.index('--base') + 1]) if '--base' in argv else None
addon_utils.enable('Sollumz', default_set=True)
from Sollumz.shared.game_assets.game_files import GameFiles  # noqa: E402
from szio.gta5 import try_load_asset, save_asset, AssetTarget, AssetFormat, AssetVersion  # noqa: E402

GAME = r'D:\gta enhansed\GTAV'
target = [AssetTarget(AssetFormat.NATIVE, AssetVersion.GEN8)]
idx = GameFiles(GAME).read_asset_filelist()
look = {}
for ext in ('.ydr', '.ydd'):
    for k, v in idx.get((ext,), {}).items():
        look[(ext[1:], str(k).lower())] = v[0] if isinstance(v, (list, tuple)) else v


def strip(d, label, spec, boxes):
    """вырождает треугольники одной модели, возвращает (всего, убрано)"""
    mode = spec.get('mode', 'all')
    origin = np.array(spec.get('origin', [0, 0, 0])[:3], dtype=np.float32)
    local = [np.array(b, dtype=np.float32) - origin for b in boxes]
    total = removed = 0
    for lod, models in d.models.items():
        for m in models:
            for g in m.geometries:
                ib = np.asarray(g.index_buffer).reshape(-1, 3).copy()
                tri = g.vertex_buffer['Position'][ib]  # (n, 3, xyz)
                if mode == 'all':
                    kill = np.ones(len(ib), dtype=bool)
                else:
                    kill = np.zeros(len(ib), dtype=bool)
                    for b in local:
                        kill |= np.all((tri >= b[0]) & (tri <= b[1]), axis=(1, 2))
                    if spec.get('vertical'):  # только стенки (буквы, щиты), а не склон/землю под ними
                        n = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
                        nz = np.abs(n[:, 2]) / np.maximum(np.linalg.norm(n, axis=1), 1e-9)
                        kill &= nz < float(spec['vertical'])
                total += len(ib)
                n = int(kill.sum())
                removed += n
                if n:
                    gone = tri[kill].reshape(-1, 3) + origin
                    print(f'KAVKAZ   {label} {lod.name}: убрано {n} из {len(ib)}, область '
                          f'{np.round(gone.min(0), 1).tolist()}..{np.round(gone.max(0), 1).tolist()}', flush=True)
                    ib[kill, 1] = ib[kill, 0]
                    ib[kill, 2] = ib[kill, 0]
                    g.index_buffer = ib.reshape(-1).astype(np.asarray(g.index_buffer).dtype)
    return total, removed


def fix_presets(sg):
    # у части шейдеров карты имя пресета не распознаётся (None) — Sollumz такое не сохраняет
    if not sg:
        return
    known = {s.name: s.preset_filename for s in sg.shaders if s.preset_filename}
    for s in sg.shaders:
        if not s.preset_filename and s.name in known:
            s.preset_filename = known[s.name]


OUT.mkdir(parents=True, exist_ok=True)
for j in json.load(open(JOB, encoding='utf-8')):
    kind, name = j.get('kind', 'ydr'), j['name']
    p = look.get((kind, name.lower()))
    if BASE and (BASE / f'{name}.{kind}').exists():
        p = str(BASE / f'{name}.{kind}')
        print('KAVKAZ основа', p, flush=True)
    if not p:
        print('KAVKAZ нет в игре', kind, name, flush=True)
        continue
    a = try_load_asset(p)
    boxes = j.get('boxes', [])
    total = removed = 0
    if kind == 'ydd':
        for key, d in a.drawables.items():
            spec = j['drawables'].get(str(key))
            if spec is None:
                continue
            t, r = strip(d, str(key), spec, boxes)
            total, removed = total + t, removed + r
    else:
        total, removed = strip(a, name, j, boxes)
    print(f'KAVKAZ итог {kind} {name}: треугольников {total}, убрано {removed}', flush=True)
    if DRY or not removed:
        continue
    for d in (a.drawables.values() if kind == 'ydd' else [a]):
        fix_presets(d.shader_group)
    save_asset(a, target, OUT, name)
    print('KAVKAZ сохранено', name, flush=True)
