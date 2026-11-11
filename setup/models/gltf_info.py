"""KAVKAZ RP: что внутри скачанных моделей Sketchfab (glTF): лицензия, треугольники, текстуры.
python -I setup/models/gltf_info.py <папка с распакованными моделями>
"""
import json
import os
import re
import sys
from PIL import Image

root = sys.argv[1]
for name in sorted(os.listdir(root)):
    d = os.path.join(root, name)
    if not os.path.isdir(d):
        continue
    lic = ''
    for f in ('license.txt', 'LICENSE.txt'):
        p = os.path.join(d, f)
        if os.path.exists(p):
            t = open(p, encoding='utf-8', errors='replace').read()
            m = re.search(r'License type:\s*(.+)', t) or re.search(r'(CC[\w\- .]+|CC0[^\n]*)', t)
            a = re.search(r'Author:\s*(.+)', t)
            lic = (m.group(1).strip() if m else '?') + ' | ' + (a.group(1).strip() if a else '?')
    tris, texs = 0, []
    g = os.path.join(d, 'scene.gltf')
    if os.path.exists(g):
        j = json.load(open(g, encoding='utf-8'))
        acc = j.get('accessors', [])
        for mesh in j.get('meshes', []):
            for prim in mesh.get('primitives', []):
                if 'indices' in prim:
                    tris += acc[prim['indices']]['count'] // 3
                else:
                    tris += acc[prim['attributes']['POSITION']]['count'] // 3
        for im in j.get('images', []):
            p = os.path.join(d, im.get('uri', ''))
            if os.path.exists(p):
                with Image.open(p) as i:
                    texs.append('%dx%d' % i.size)
    print('%-42s tris=%-7d tex=%-2d %-30s %s' % (name, tris, len(texs), ','.join(sorted(set(texs))), lic))
