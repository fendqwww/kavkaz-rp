"""KAVKAZ RP: разметка на асфальте по-русски — шаг 2: правка картинок и задание на пересборку.
python -I setup/maps/roadmarks_ru.py <выход шага 1 (manifest.json)> <папка_работы>

что делаем (в России на асфальте нет слов, осевая белая, жёлтым — только запрет остановки у бордюра):
  - надписи STOP, KEEP CLEAR / NO PARKING, STAY IN LANE, EXIT / IN, WAIT HERE / PED XING, ONLY, круглый знак порта —
    прозрачными (где альфа — прозрачность) или закрашиваем фоном (где альфы нет). стрелки, стоп-линии, крест, велосипед,
    значок инвалида остаются — такие есть и у нас;
  - жёлтые линии и знаки -> белые (только в самих атласах разметки; полосатые жёлто-чёрные у порта не трогаем).
области надписей заданы долями ширины/высоты на семейство атласа: у семейства раскладка одна при любом размере
(проверено листом session-2026-11-16/marks_grid.png). карты нормалей и бликов не трогаем: под прозрачностью их не видно.
на выходе: <папка_работы>/dds/*.dds, job.json для retex_build_blender.py, preview.png (до/после) — смотреть глазами до сборки.
"""
import hashlib
import json
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'models'))
from dds import save_dds  # noqa: E402

# семейство (подстрока имени текстуры) -> области надписей (x0, y0, x1, y1) в долях
ERASE = [
    ('im_roadmarkings07', [(0, 0, 1, 0.49)]),                      # STOP (крест и велосипед ниже — оставить)
    ('im_roadmarkings08', [(0, 0, 1, 1)]),                         # WAIT HERE / PED XING
    ('im_roadmarkings09', [(0, 0, 1, 1)]),                         # ONLY
    ('im_roadmarkings10', [(0, 0, 1, 1)]),                         # STAY IN LANE A / LANE 1
    ('im_roadmarkings11', [(0, 0, 1, 1)]),                         # KEEP CLEAR / NO PARKING (жёлтое)
    ('rnos_roadmarkings_002', [(0.36, 0, 1, 0.255), (0.66, 0.255, 1, 0.655), (0, 0.655, 1, 1)]),  # EXIT, IN, KEEP CLEAR
    ('rnos_roadmarkings_001', [(0.38, 0, 1, 0.32), (0.71, 0.32, 1, 1)]),                      # EXIT, IN
    ('sc1_32_cmk_roadmarkings_001', [(0.33, 0, 1, 0.47), (0.66, 0.47, 1, 1)]),                # EXIT, IN
    ('ggroadmarkings01', [(0.515, 0.48, 0.86, 0.675), (0.69, 0.675, 0.88, 0.89)]),            # EXIT, UP (парковки)
    ('po1_08_ggroadmarkings', [(0.67, 0, 1, 0.31)]),               # круглый знак «NO DUMPING / DRAINS TO OCEAN»
    ('bh1_13_roadmarkings', [(0.235, 0.49, 0.425, 1)]),            # вертикальное EXIT у стрелки (переулок)
    ('im_roadmarkings02b_lod', [(0, 0, 0.5, 1)]),                  # повёрнутые WAIT HERE / PED XING вдали
]
NO_RECOLOR = ('po1_08_ggroadmarkings', 'mc_', 'cs_rsn', 'scrn_')  # жёлто-чёрные полосы порта, стены, грязь, рисунки мелом
HEAD = re.compile(r'^(.*?roadmarkings_?\d+[a-z]?)(.*)$')


def role(name):
    """diffuse | skip (нормали, блики). и что в альфе: 'opacity' | 'spec' | None"""
    n = name.lower()
    m = HEAD.match(n)
    rest = m.group(2) if m else ''
    if (m and (rest.startswith('_n') or rest.startswith('_s') or rest.startswith('_lod_s'))) or n.endswith('_n') or (not m and n.endswith('_s')):
        return 'skip', None
    if re.search(r'_a(_lod)?$|_alpha$|_a_lod$', n):
        return 'diffuse', 'opacity'
    if re.search(r'_s$', n):
        return 'diffuse', 'spec'
    return 'diffuse', None


def yellow_to_white(rgb):
    """жёлтая/оранжевая краска -> белая той же яркости; мягкий переход по насыщенности и оттенку"""
    f = rgb.astype(np.float32) / 255.0
    mx, mn = f.max(axis=2), f.min(axis=2)
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = f[..., 0], f[..., 1], f[..., 2]
    d = np.maximum(mx - mn, 1e-6)
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    wh = np.clip(1 - np.maximum(0, np.maximum(28 - h, h - 62)) / 8, 0, 1)   # 28..62° полностью, ±8° на спад
    ws = np.clip((s - 0.22) / 0.16, 0, 1)
    wv = np.clip((mx - 0.15) / 0.1, 0, 1)
    w = (wh * ws * wv)[..., None]
    white = np.stack([mx * 0.95, mx * 0.95, mx * 0.92], axis=2)
    out = f * (1 - w) + white * w
    return (out * 255).clip(0, 255).astype(np.uint8), float((w > 0.5).mean())


def bg_color(a, opacity):
    rgb = a[..., :3].reshape(-1, 3).astype(np.float32)
    if opacity:
        tr = a[..., 3].reshape(-1) < 30
        if tr.mean() > 0.05:
            return np.median(rgb[tr], axis=0)
    lum = rgb.mean(axis=1)
    return np.median(rgb[lum <= np.percentile(lum, 30)], axis=0)


def main():
    src, work = sys.argv[1], sys.argv[2]
    man = json.load(open(os.path.join(src, 'manifest.json')))
    os.makedirs(os.path.join(work, 'dds'), exist_ok=True)
    jobs, done, prev, stat = {}, {}, [], {'erase': 0, 'yellow': 0, 'same': 0, 'skip': 0}
    for m in man:
        tex, cont = m['tex'], m['container']
        kind_role, alpha_kind = role(tex)
        if kind_role == 'skip':
            stat['skip'] += 1
            continue
        raw = open(m['dds'], 'rb').read()
        key = hashlib.md5(raw).hexdigest()
        if key not in done:
            im = Image.open(m['dds']).convert('RGBA')
            a = np.array(im)
            orig = a.copy()
            W, H = im.size
            low = tex.lower()
            rects = next((r for fam, r in ERASE if fam in low), [])
            has_alpha = a[..., 3].min() < 250
            if rects:
                bg = bg_color(a, alpha_kind == 'opacity' and has_alpha)
                for x0, y0, x1, y1 in rects:
                    X0, Y0, X1, Y1 = int(x0 * W), int(y0 * H), int(np.ceil(x1 * W)), int(np.ceil(y1 * H))
                    a[Y0:Y1, X0:X1, :3] = bg.astype(np.uint8)
                    if alpha_kind == 'opacity' and has_alpha:
                        a[Y0:Y1, X0:X1, 3] = 0
            yfrac = 0.0
            if not low.startswith(NO_RECOLOR) and not any(low.startswith(p) for p in NO_RECOLOR):
                a[..., :3], yfrac = yellow_to_white(a[..., :3])
            changed = np.abs(a.astype(np.int16) - orig.astype(np.int16)).max() > 8
            out = None
            if changed:
                out = os.path.join(work, 'dds', f'{tex}_{key[:8]}.dds')
                save_dds(Image.fromarray(a, 'RGBA'), out, has_alpha)
                prev.append((tex, cont, orig, a, bool(rects), yfrac))
            done[key] = (out, bool(rects), yfrac)
        out, er, yf = done[key]
        if not out:
            stat['same'] += 1
            continue
        stat['erase' if er else 'yellow'] += 1
        name, ext = cont.rsplit('.', 1)
        jobs.setdefault((ext, name), {})[tex] = out.replace('\\', '/')
    res = [{'kind': k, 'name': n, 'tex': t} for (k, n), t in sorted(jobs.items())]
    json.dump(res, open(os.path.join(work, 'job.json'), 'w'), indent=1)
    # лист до/после: каждая уникальная правленая картинка, слева оригинал, справа результат (на красно-буром фоне видна прозрачность)
    C = 180
    cols = 4
    rows = (len(prev) + cols - 1) // cols
    sheet = Image.new('RGB', (cols * (2 * C + 10), max(1, rows) * (C + 14)), (30, 30, 30))
    dr = ImageDraw.Draw(sheet)
    for i, (tex, cont, o, n, er, yf) in enumerate(prev):
        x, y = (i % cols) * (2 * C + 10), (i // cols) * (C + 14)
        for j, arr in enumerate((o, n)):
            im = Image.fromarray(arr, 'RGBA')
            bg = Image.new('RGBA', im.size, (110, 60, 60, 255))
            bg.alpha_composite(im)
            t = bg.convert('RGB')
            t.thumbnail((C, C))
            sheet.paste(t, (x + j * C, y))
        dr.text((x + 2, y + C), f"{'E' if er else 'Y'} {tex[:40]}", fill=(255, 255, 0))
    sheet.save(os.path.join(work, 'preview.png'))
    print('KAVKAZ', stat, 'файлов к пересборке', len(res), 'картинок', len(prev))


if __name__ == '__main__':
    main()
