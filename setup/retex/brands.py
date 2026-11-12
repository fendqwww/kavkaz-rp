"""KAVKAZ RP: узнаваемые вывески GTA (Burger Shot, Cluckin' Bell, Bean Machine, Fleeca, LSPD, 24/7) → наши.
python setup/retex/brands.py <папка с оригиналами .dds>
оригиналы выгружены из игры скриптом Blender + Sollumz (в git их нет); здесь берётся только их размер и где на них
непрозрачное (туда кладём нашу вывеску), чтобы раскладка текстуры не поехала. картинки — images/retex/brand_*.png,
список подмен — kavkaz_world/brands_list.lua (Config.BrandImages, Config.Brands: txd, txn, image).
"""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

root = pathlib.Path(__file__).resolve().parents[2]
world = root / 'resources' / '[kavkaz]' / 'kavkaz_world'
img = world / 'images'
out = img / 'retex'
FD = pathlib.Path(__file__).resolve().parent / 'fonts'
SRC = pathlib.Path(sys.argv[1])

# словарь (без +hi / +hidr — обе версии заменяем), текстура, что ставим, как
# 12.11: стиль — минимализм (ориентир Majestic RP), без этники: ровная плашка, крупное слово, строка помельче
MIN = {
    'burger': ((214, 64, 36), 'БУРГЕР ГРИЛЬ', 'сочно · быстро · рядом'),
    'chicken': ((242, 178, 26), 'КУРОЧКА ГРИЛЬ', 'крылья · стрипсы · комбо'),
    'coffee': ((74, 50, 36), 'КОФЕЙНЯ', 'кофе с собой'),
    'bank': ((24, 120, 84), 'НАРОДНЫЙ БАНК', 'вклады · кредиты · переводы'),
    'shop': ((30, 30, 32), 'ПРОДУКТЫ 24', 'круглосуточно'),
}
B = [
    ('dt1_16_build', 'burgershot_meatshavings_billboard_final_short', 'min:burger', 'full'),
    ('kt1_15_shop_06', 'kt1_15_cluckinbellsign_01_d', 'min:chicken', 'bbox'),
    ('dt1_15_steetdetailb', 'dt1_15_rsn_cmk_beanmachinedt1_15_rsn_cmk_beanmachine_a', 'min:coffee', 'bbox'),
    ('kt1_07', 'kt1_07_beanmachine_01_d', 'coffee_round', 'full'),
    ('cs2_01_shop_dec3', 'cs2_01_rsl_vc_bank_fleecasign02cs2_01_rsl_vc_bank_fleecasign02_a', 'min:bank', 'bbox'),
    ('v_20_policehtxd', 'xj_v_lspd_logoxj_v_lspd_logo_a', 'retex/emb_mvd', 'bbox_keep'),
    ('v_ret_247_win1', 'gz_v_247_winglass01gz_v_247_winglass01_a', 'min:shop', 'bbox'),
    ('v_ret_247_win2', 'gz_v_247_winglass02gz_v_247_winglass02_a', 'min:shop', 'bbox'),
]


def minimal(kind, w, h):
    bg, title, sub = MIN[kind]
    K = 2
    im = Image.new('RGBA', (w * K, h * K), bg + (255,))
    d = ImageDraw.Draw(im)
    dark = sum(bg) < 300
    fg = (250, 250, 250, 255) if dark or kind != 'chicken' else (30, 30, 32, 255)
    title_f = ImageFont.truetype(str(FD / 'Rubik-Black.ttf'), 10)
    size = int(h * K * 0.42)
    while size > 8:
        title_f = ImageFont.truetype(str(FD / 'Rubik-Black.ttf'), size)
        if d.textlength(title, font=title_f) <= w * K * 0.86:
            break
        size -= 2
    sub_f = ImageFont.truetype(str(FD / 'Oswald-SemiBold.ttf'), max(8, int(size * 0.34)))
    d.text((w * K / 2, h * K * 0.44), title, font=title_f, fill=fg, anchor='mm')
    d.text((w * K / 2, h * K * 0.44 + size * 0.62), sub.upper(), font=sub_f, fill=fg[:3] + (200,), anchor='mt')
    return im.resize((w, h), Image.LANCZOS)
SUFFIX = ('', '+hi', '+hidr', '+hifr')


def original(txd, txn):
    for suf in SUFFIX:
        p = SRC / f'{txd}{suf}__{txn}.dds'
        if p.exists():
            return Image.open(p).convert('RGBA')
    return None


def coffee_round(w, h):
    """круглый знак кофейни на бежевом, как был у Bean Machine — но свой"""
    im = Image.new('RGBA', (w, h), (226, 214, 190, 255))
    d = ImageDraw.Draw(im)
    r = min(w, h) * 0.42
    cx, cy = w / 2, h / 2
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(92, 58, 30, 255))
    d.ellipse([cx - r * 0.86, cy - r * 0.86, cx + r * 0.86, cy + r * 0.86], fill=(226, 214, 190, 255))
    f1 = ImageFont.truetype(str(FD / 'RussoOne-Regular.ttf'), int(r * 0.42))
    f2 = ImageFont.truetype(str(FD / 'Oswald-SemiBold.ttf'), int(r * 0.22))
    d.text((cx, cy - r * 0.12), 'КОФЕ', font=f1, fill=(92, 58, 30, 255), anchor='mm')
    d.text((cx, cy + r * 0.38), 'КОФЕЙНЯ', font=f2, fill=(92, 58, 30, 255), anchor='mm')
    return im


def main():
    names, rows = [], []
    for txd, txn, src, how in B:
        o = original(txd, txn)
        if o is None:
            print('нет оригинала', txd, txn)
            continue
        w, h = o.size
        if src == 'coffee_round':
            res = coffee_round(w, h)
        else:
            if src.startswith('min:') and how == 'full':
                art = minimal(src[4:], w, h)
            elif src.startswith('min:'):
                a = o.getchannel('A').point(lambda v: 255 if v > 24 else 0).getbbox() or (0, 0, w, h)
                art = minimal(src[4:], a[2] - a[0], a[3] - a[1])
            else:
                art = Image.open(img / f'{src}.png').convert('RGBA')
            if how == 'full':
                res = art.resize((w, h), Image.LANCZOS)
            else:
                a = o.getchannel('A')
                box = a.point(lambda v: 255 if v > 24 else 0).getbbox() or (0, 0, w, h)
                bw, bh = box[2] - box[0], box[3] - box[1]
                if how == 'bbox_keep':  # герб — без растяжения, по центру
                    k = min(bw / art.width, bh / art.height)
                    art = art.resize((max(1, int(art.width * k)), max(1, int(art.height * k))), Image.LANCZOS)
                    pos = (box[0] + (bw - art.width) // 2, box[1] + (bh - art.height) // 2)
                else:
                    art = art.resize((bw, bh), Image.LANCZOS)
                    pos = (box[0], box[1])
                res = Image.new('RGBA', (w, h), (0, 0, 0, 0))
                res.paste(art, pos)
        name = 'brand_' + txn[:40].lower()
        res.save(out / f'{name}.png', optimize=True)
        names.append(name)
        for suf in SUFFIX:
            rows.append((txd + suf, txn, name))
        print('done', txd, src)
    lua = ['-- собрано setup/retex/brands.py — не править руками. вывески GTA → наши (txd с +hi/+hidr — HD-версии тех же словарей)',
           'Config.BrandImages = {'] + [f"    '{n}'," for n in names] + ['}', '', 'Config.Brands = {']
    lua += [f"    {{ txd = '{a}', txn = '{b}', image = '{c}' }}," for a, b, c in rows]
    lua += ['}', '']
    (world / 'brands_list.lua').write_text('\n'.join(lua), encoding='utf-8')


if __name__ == '__main__':
    main()
