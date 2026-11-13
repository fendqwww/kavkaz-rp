"""KAVKAZ RP: все английские вывески карты → русские или без текста (основатель 13.11: «ни одной вывески на английском»).
python -I setup/retex/russify.py <папка оригиналов .dds> <папка вывода .png>

по имени текстуры и по самой картинке:
- одиночный щит/плакат (billboard, poster…) — русская плашка: по смыслу (больница, полиция, аптека…) или реклама из списка;
- в основном прозрачная (вырезанные буквы, неон, наклейки) — убирается: полностью прозрачная;
- остальное (атласы с кучей вывесок, указатели) — буквы стираются, цвета и форма вывесок остаются.
стиль плашек — как в brands.py (минимализм, ориентир Majestic, без этники).
"""
import os
import re
import sys
import zlib

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FD = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'fonts')
SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)

# смысл по имени текстуры -> (фон, заголовок, подпись)
CATS = [
    (r'hospital|emergen|pillbox|medic|clinic|zonah', ((240, 242, 245), 'ГОРОДСКАЯ БОЛЬНИЦА', 'приёмное отделение')),
    (r'police|lspd|sheriff|sapd|cop', ((24, 52, 110), 'ПОЛИЦИЯ', 'телефон 102')),
    (r'pharm|pill|drug', ((30, 140, 90), 'АПТЕКА', 'круглосуточно')),
    (r'ammu|gun', ((34, 34, 36), 'ОРУЖИЕ', 'охота · рыбалка')),
    (r'liquor|beer|wine|pisswass|logger|patriot|benedict', ((176, 110, 24), 'ПРОДУКТЫ', 'напитки · закуски')),
    (r'bank|fleeca|maze|lombank|money|monetary', ((24, 120, 84), 'БАНК', 'вклады · кредиты')),
    (r'xero|ron_|globe_oil|gas|fuel|ltd', ((200, 40, 30), 'АЗС', 'АИ-92 · АИ-95 · ДТ')),
    (r'motel|hotel|casino|diamond', ((40, 52, 70), 'ГОСТИНИЦА', 'номера посуточно')),
    (r'tattoo', ((22, 22, 26), 'ТАТУ', 'салон')),
    (r'barber|hair|kutz', ((44, 40, 34), 'ПАРИКМАХЕРСКАЯ', 'мужской и женский зал')),
    (r'theat|cinema|movie|film', ((26, 26, 30), 'КИНОТЕАТР', 'премьеры каждую неделю')),
    (r'burger|cluck|taco|pizza|donut|diner|cafe|bean|coffee|food|chicken', ((214, 64, 36), 'КАФЕ', 'обеды · кофе с собой')),
    (r'custom|garage|mechanic|motor|auto|tyre|tire', ((20, 20, 22), 'АВТОСЕРВИС', 'ремонт · шиномонтаж')),
    (r'unicorn|club|strip|hookah|bar', ((22, 22, 26), 'РЕСТОРАН', 'кухня · банкеты')),
    (r'weazel|news|tv', ((36, 36, 40), 'ГОРОД ТВ', 'новости каждый час')),
    (r'store|shop|market|mall|24', ((30, 30, 32), 'ПРОДУКТЫ 24', 'круглосуточно')),
]
CATS = [(re.compile(p, re.I), v) for p, v in CATS]
ADS = [
    ((26, 26, 30), 'КИНО', 'премьеры каждую неделю'), ((48, 64, 84), 'КВАРТИРЫ', 'аренда и продажа'),
    ((214, 64, 40), 'ФИТНЕС-КЛУБ', 'первая неделя бесплатно'), ((24, 118, 178), 'ТУРЫ НА МОРЕ', 'горящие путёвки'),
    ((236, 128, 166), 'МОРОЖЕНОЕ', 'пломбир · эскимо'), ((196, 160, 112), 'МЕБЕЛЬ', 'кухни на заказ'),
    ((34, 110, 200), 'ЕСТЬ РАБОТА', 'водители · курьеры'), ((88, 44, 150), 'ЭЛЕКТРОНИКА', 'смартфоны в рассрочку'),
    ((232, 150, 60), 'ПЕКАРНЯ', 'горячая выпечка'), ((40, 140, 200), 'ПИТЬЕВАЯ ВОДА', 'доставка 19 л'),
    ((236, 236, 238), 'ДОМАШНИЙ ИНТЕРНЕТ', 'от 450 ₽ в месяц'), ((244, 246, 248), 'СТОМАТОЛОГИЯ', 'лечим без боли'),
    ((20, 20, 22), 'АВТОСАЛОН', 'новые и с пробегом'), ((110, 40, 160), 'МОБИЛЬНАЯ СВЯЗЬ', 'безлимит за 300 ₽'),
    ((24, 120, 84), 'НАРОДНЫЙ БАНК', 'вклады · переводы'), ((40, 52, 70), 'ЮРИСТ', 'консультация бесплатно'),
]
SINGLE = re.compile(r'billb|bboard|poster|advert|_ad_|ad_wall|movie', re.I)
ATLAS = re.compile(r'signs|bboards|billboards|posters|combo|set|atlas|multi|_\d{2}rsn', re.I)


def plate(bg, title, sub, w, h):
    K = 2
    im = Image.new('RGBA', (w * K, h * K), bg + (255,))
    d = ImageDraw.Draw(im)
    light = 0.299 * bg[0] + 0.587 * bg[1] + 0.114 * bg[2] > 160
    fg = (30, 30, 32, 255) if light else (250, 250, 250, 255)
    lines = title.split(' ') if h > w * 1.2 else [title]
    size = int(h * K * (0.42 if len(lines) == 1 else 0.6 / len(lines)))
    while size > 8:
        tf = ImageFont.truetype(os.path.join(FD, 'Rubik-Black.ttf'), size)
        if max(d.textlength(t, font=tf) for t in lines) <= w * K * 0.86:
            break
        size -= 2
    sf = ImageFont.truetype(os.path.join(FD, 'Oswald-SemiBold.ttf'), max(8, int(size * 0.34)))
    step = size * 1.05
    y0 = h * K * 0.44 - step * (len(lines) - 1) / 2
    for i, t in enumerate(lines):
        d.text((w * K / 2, y0 + i * step), t, font=tf, fill=fg, anchor='mm')
    d.text((w * K / 2, y0 + (len(lines) - 1) * step + size * 0.62), sub.upper(), font=sf, fill=fg[:3] + (200,), anchor='mt')
    return im.resize((w, h), Image.LANCZOS)


def erase(im):
    """стереть буквы: мелкие детали уходят, крупные цветные плашки остаются"""
    w, h = im.size
    k = max(4, min(w, h) // 32)  # у узких атласов (128 px) буквы иначе угадываются
    small = im.convert('RGB').resize((max(4, w // k), max(4, h // k)), Image.BOX)
    small = small.filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.GaussianBlur(1.2))
    rgb = small.resize((w, h), Image.BICUBIC)
    out = rgb.convert('RGBA')
    out.putalpha(im.getchannel('A'))
    return out


def main():
    stat = {'plate': 0, 'ad': 0, 'clear': 0, 'erase': 0, 'err': 0}
    for f in sorted(os.listdir(SRC)):
        if not f.lower().endswith('.dds'):
            continue
        t = f[:-4].lower()
        try:
            im = Image.open(os.path.join(SRC, f)).convert('RGBA')
        except Exception:  # noqa
            stat['err'] += 1
            continue
        w, h = im.size
        a = im.getchannel('A')
        opaque = sum(1 for v in a.resize((32, 32)).tobytes() if v > 200) / 1024
        cat = next((v for r, v in CATS if r.search(t)), None)
        if opaque < 0.6:
            res = Image.new('RGBA', (w, h), (0, 0, 0, 0))
            stat['clear'] += 1
        elif SINGLE.search(t) and not ATLAS.search(t):
            bg, title, sub = cat or ADS[zlib.crc32(t.encode()) % len(ADS)]
            res = plate(bg, title, sub, w, h)
            stat['ad' if not cat else 'plate'] += 1
        else:
            res = erase(im)
            stat['erase'] += 1
        res.save(os.path.join(OUT, t + '.png'))
    print(stat)


if __name__ == '__main__':
    main()
