"""KAVKAZ RP: «убрать пустыню» — шаг 2: перекрасить песок и сухую траву в зелень предгорий (обычный Python + Pillow).
python -I setup/maps/terrain_recolor.py <папка из шага 1> [--preview out.png]
жёлтые/рыжие оттенки (песок, сухая трава) сдвигаются к зелёному, серые (камень, асфальт) почти не меняются.
пишет <ytd>/<имя>.new.dds рядом с оригиналом (тот же размер, DXT1/DXT5, полная цепочка mip).
"""
import io
import json
import os
import struct
import sys
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'models'))
from dds import save_dds  # noqa: E402

root = sys.argv[1]
PREVIEW = sys.argv[sys.argv.index('--preview') + 1] if '--preview' in sys.argv else None

# оттенки Pillow HSV: 0..255 (0 красный, ~21 оранжевый, ~32 жёлтый, ~64 жёлто-зелёный, ~85 зелёный)
LUT_H = []
for h in range(256):
    if 6 <= h <= 48:  # песок/охра/сухая трава
        k = 1.0 if 12 <= h <= 42 else 0.5
        LUT_H.append(int(h + (68 - h) * 0.85 * k) % 256)
    else:
        LUT_H.append(h)
LUT_S = [min(255, int(s * 1.25 + 8)) for s in range(256)]
LUT_V = [int(v * 0.78) for v in range(256)]


def recolor(img):
    alpha = img.getchannel('A') if 'A' in img.getbands() else None
    hsv = img.convert('RGB').convert('HSV')
    h, s, v = hsv.split()
    # насыщенность поднимаем только там, где был тёплый оттенок
    warm = h.point(lambda x: 255 if 6 <= x <= 48 else 0)
    s2 = Image.composite(s.point(LUT_S), s, warm)
    v2 = Image.composite(v.point(LUT_V), v, warm)
    out = Image.merge('HSV', (h.point(LUT_H), s2, v2)).convert('RGB')
    if alpha is not None:
        out.putalpha(alpha)
    return out


import re  # noqa: E402
# камень, скалы и грунтовые дороги остаются как есть (на Кавказе скалы серые, грунтовки коричневые)
KEEP = re.compile(r'rock|cliff|stone|boulder|dirt|track|gravel|road|path|mud|concrete|tarmac'
                  # 13.11: nxg_*_h и маски смешивания (msk/mask) — карты данных, не картинки; их перекраска
                  # дала розово-красные пятна земли у Форта Занкудо (старый kv_map_steppe, исправлен)
                  r'|^nxg_.*_h$|msk|mask', re.I)


def is_mask(im):
    """служебные карты смешивания (в превью — фиолетовые): цвет-«краска», а не картинка"""
    r, g, b = [sum(c.resize((16, 16)).getdata()) / 256 for c in im.convert('RGB').split()]
    return (r + b) / 2 > g * 1.35 and min(r, b) > 60


listing = json.load(open(os.path.join(root, 'list.json')))
done, previews = 0, []
for ytd, info in listing.items():
    for t in info['textures']:
        src = os.path.join(root, ytd, t + '.dds')
        newp = os.path.join(root, ytd, t + '.new.dds')
        if os.path.exists(newp):
            os.remove(newp)  # пересборка: старый результат не нужен
        if KEEP.search(t):
            continue
        try:
            with Image.open(src) as im:
                im.load()
                fourcc = open(src, 'rb').read(88)[84:88]
                if fourcc not in (b'DXT1', b'DXT3', b'DXT5') or is_mask(im):
                    continue
                alpha = fourcc in (b'DXT5', b'DXT3') or im.mode == 'RGBA' and im.getchannel('A').getextrema()[0] < 250
                new = recolor(im.convert('RGBA'))
                save_dds(new, os.path.join(root, ytd, t + '.new.dds'), alpha)
                done += 1
                if PREVIEW and len(previews) < 8 and ytd.endswith('+hi') is False and im.width >= 256:
                    previews.append((im.convert('RGB').resize((256, 256)), new.convert('RGB').resize((256, 256))))
        except Exception as e:  # noqa
            print('пропуск', ytd, t, e)
print('перекрашено текстур:', done)
if PREVIEW and previews:
    sheet = Image.new('RGB', (256 * len(previews), 512), (0, 0, 0))
    for i, (a, b) in enumerate(previews):
        sheet.paste(a, (i * 256, 0))
        sheet.paste(b, (i * 256, 256))
    sheet.save(PREVIEW)
