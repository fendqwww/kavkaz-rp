"""KAVKAZ RP: подготовка моделей Sketchfab (glTF) к игре — шаг 1 (обычный Python).
python -I setup/models/props_prep.py <папка с распакованными моделями> [--max 1024]
для каждой текстуры рядом пишет <имя>.dds: DXT1 (без прозрачности) или DXT5 (с прозрачностью), с mip, не больше --max.
собирает docs/credits-models.md — авторы и лицензии (CC BY требует указать автора).
"""
import io
import os
import re
import struct
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

root = sys.argv[1]
MAX = int(sys.argv[sys.argv.index('--max') + 1]) if '--max' in sys.argv else 1024
CREDITS = os.path.join(os.path.dirname(__file__), '..', '..', 'docs', 'credits-models.md')


from dds import save_dds  # noqa: E402


credits = []
for name in sorted(os.listdir(root)):
    d = os.path.join(root, name)
    if not os.path.isdir(d):
        continue
    lic = os.path.join(d, 'license.txt')
    if os.path.exists(lic):
        t = open(lic, encoding='utf-8', errors='replace').read()
        title = re.search(r'title:\s*(.+)', t)
        src = re.search(r'source:\s*(\S+)', t)
        author = re.search(r'author:\s*(.+)', t)
        ltype = re.search(r'license type:\s*(.+)', t)
        credits.append('| %s | %s | %s | %s |' % (name, title.group(1).strip() if title else '', author.group(1).strip() if author else '',
                                                    (ltype.group(1).strip() if ltype else '') + (' ' + src.group(1) if src else '')))
    n = 0
    for dp, _, fs in os.walk(d):
        for f in fs:
            if f.lower().endswith(('.png', '.jpg', '.jpeg')):
                p = os.path.join(dp, f)
                with Image.open(p) as im:
                    im.load()
                    alpha = im.mode in ('RGBA', 'LA', 'P') and im.convert('RGBA').getextrema()[3][0] < 250
                    if max(im.size) > MAX:
                        k = MAX / max(im.size)
                        im = im.resize((max(4, int(im.width * k) // 4 * 4), max(4, int(im.height * k) // 4 * 4)), Image.LANCZOS)
                    elif im.width % 4 or im.height % 4:
                        im = im.resize((max(4, im.width // 4 * 4), max(4, im.height // 4 * 4)), Image.LANCZOS)
                    save_dds(im, os.path.splitext(p)[0] + '.dds', alpha)
                    n += 1
    print('%-42s текстур -> DDS: %d' % (name, n))

with open(CREDITS, 'w', encoding='utf-8') as f:
    f.write('# Авторы 3D-моделей (Sketchfab)\n\nмодели переделаны под игру (setup/models/props_*.py). файлы моделей в git не кладём.\n\n')
    f.write('| модель | название | автор | лицензия и источник |\n|---|---|---|---|\n')
    f.write('\n'.join(credits) + '\n')
print('авторы ->', os.path.abspath(CREDITS))
