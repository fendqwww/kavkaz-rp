"""KAVKAZ RP: подмена картинок там, где игра реально рисует их вблизи — внутри моделей (.ydr, встроенные текстуры)
и в словарях (.ytd, в т. ч. +hi/+hidr). Подмена «на лету» (AddReplaceTexture) на встроенные текстуры карты не действует,
поэтому файлы пересобираются целиком и стримятся ресурсом (как пустыня kv_map_steppe).

blender -b --factory-startup -P setup/maps/retex_build_blender.py -- <job.json> <папка вывода>
job.json: [{"kind": "ydr" | "ytd", "name": "dt1_09_billboards", "tex": {"имя_текстуры": "путь/к/картинке.dds"}}, ...]
имя без расширения, как в игре; для ytd можно с суффиксом (+hi, +hidr). отсутствующие в файле текстуры пропускаются.
"""
import addon_utils
import json
import sys
from pathlib import Path

argv = sys.argv[sys.argv.index('--') + 1:]
JOB, OUT = Path(argv[0]), Path(argv[1])
# --base <папка>: если там есть файл с тем же именем (уже перекрашенный другим нашим ресурсом — дороги, пустыня),
# собираем поверх него, а не поверх оригинала игры. иначе два ресурса стримят один файл и в игре виден только один.
BASE = Path(argv[argv.index('--base') + 1]) if '--base' in argv else None
OUT.mkdir(parents=True, exist_ok=True)
addon_utils.enable('Sollumz', default_set=True)
from Sollumz.shared.game_assets.game_files import GameFiles  # noqa: E402
from szio.gta5 import try_load_asset, save_asset, AssetTarget, AssetFormat, AssetVersion  # noqa: E402
from szio.types import DataSource  # noqa: E402

GAME = r'D:\gta enhansed\GTAV'
target = [AssetTarget(AssetFormat.NATIVE, AssetVersion.GEN8)]
idx = GameFiles(GAME).read_asset_filelist()
look = {}
for ext in ('.ydr', '.ytd', '.ydd'):
    for k, v in idx.get((ext,), {}).items():
        look[(ext[1:], str(k).lower())] = v[0] if isinstance(v, (list, tuple)) else v

jobs = json.load(open(JOB, encoding='utf-8'))
done = skipped = 0
for j in jobs:
    kind, name = j['kind'], j['name']
    p = look.get((kind, name.lower()))
    if BASE and (BASE / f'{name}.{kind}').exists():
        p = str(BASE / f'{name}.{kind}')
        print('KAVKAZ основа', p, flush=True)
    if not p:
        print('KAVKAZ нет в игре', kind, name, flush=True)
        skipped += 1
        continue
    try:
        a = try_load_asset(p)
        if kind == 'ytd':
            groups = [a.textures]
        elif kind == 'ydd':  # набор моделей: у каждой свои встроенные текстуры
            groups = [d.shader_group.embedded_textures for d in a.drawables.values() if d.shader_group]
        else:
            groups = [a.shader_group.embedded_textures]
        n = 0
        for g in groups:
            texs = {str(k).lower(): (k, v) for k, v in (g or {}).items()}
            for t, dds in j['tex'].items():
                hit = texs.get(t.lower())
                if hit:
                    hit[1].data = DataSource.create(dds, hit[0] + '.dds')
                    n += 1
        if not n:
            print('KAVKAZ нет текстур', kind, name, list(j['tex'])[:3], flush=True)
            skipped += 1
            continue
        for sg in ([a.shader_group] if kind == 'ydr' else [d.shader_group for d in a.drawables.values() if d.shader_group] if kind == 'ydd' else []):
            # у части шейдеров карты имя пресета не распознаётся (None) — Sollumz такое не сохраняет (AssertionError);
            # берём пресет у шейдера с тем же именем (hw1_15_build2: default → default.sps)
            known = {s.name: s.preset_filename for s in sg.shaders if s.preset_filename}
            for s in sg.shaders:
                if not s.preset_filename and s.name in known:
                    s.preset_filename = known[s.name]
        save_asset(a, target, OUT, name)
        done += 1
        print('KAVKAZ ok', kind, name, n, flush=True)
    except Exception as e:  # noqa
        print('KAVKAZ ERR', kind, name, repr(e)[:200], flush=True)
        skipped += 1
print('KAVKAZ итог: собрано', done, 'пропущено', skipped, flush=True)
