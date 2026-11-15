"""KAVKAZ RP: задание для retex_build_blender.py — где в игре реально лежит каждая подменяемая картинка.
python -I setup/maps/retex_job.py <texmap_ytd.json> <texmap_ydr.json> <папка с картинками .png> <job.json> [--min 0]

картинки: <имя_текстуры_игры>.png (как назвать — имя текстуры GTA, регистр не важен). для каждой находятся все
контейнеры: модели с этой встроенной текстурой (.ydr/.ydd) и словари (.ytd, в т. ч. +hi/+hidr). картинка
переводится в .dds под размер оригинала в каждом контейнере (DXT5, если есть прозрачность, иначе DXT1)
и кладётся рядом с job.json в папку dds/.
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'models'))
from dds import save_dds  # noqa: E402

ytd_map = json.load(open(sys.argv[1]))
ydr_map = json.load(open(sys.argv[2]))
src, job_path = sys.argv[3], sys.argv[4]
dds_dir = os.path.join(os.path.dirname(os.path.abspath(job_path)), 'dds')
os.makedirs(dds_dir, exist_ok=True)

jobs = {}  # (kind, name) -> {tex: dds}
miss = []
for f in sorted(os.listdir(src)):
    if not f.lower().endswith('.png'):
        continue
    t = f[:-4].lower()
    img = Image.open(os.path.join(src, f)).convert('RGBA')
    alpha = img.getchannel('A').getextrema()[0] < 250
    where = [('ytd', n, w, h) for n, w, h in ytd_map.get(t, [])] + [(k, n, w, h) for k, n, w, h in ydr_map.get(t, [])]
    if not where:
        miss.append(t)
        continue
    for kind, name, w, h in where:
        # не меньше оригинала, но и не больше 1024 по стороне (у основателя слабая видеокарта)
        k = min(1.0, 1024 / max(w, h)) if max(w, h) > 1024 else 1.0
        size = (max(4, int(w * k)) // 4 * 4, max(4, int(h * k)) // 4 * 4)
        out = os.path.join(dds_dir, f'{t}_{size[0]}x{size[1]}.dds')
        if not os.path.exists(out):
            save_dds(img.resize(size, Image.LANCZOS), out, alpha)
        jobs.setdefault((kind, name), {})[t] = out.replace('\\', '/')
res = [{'kind': k, 'name': n, 'tex': tex} for (k, n), tex in sorted(jobs.items())]
json.dump(res, open(job_path, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('файлов к пересборке:', len(res), '| картинок без места в игре:', len(miss), miss[:10])
