"""KAVKAZ RP: атлас вывесок → однотонные таблички с русскими словами (вариант Б, выбран основателем 14.11.2026).

python setup/retex/sign_grid.py <папка оригиналов .dds> <atlas_labels.json> <папка вывода .png> [--sheet лист.png]
(без -I: нужен numpy из user site — pip install --user numpy)

atlas_labels.json: {"имя_текстуры": "S" | "W" | "A" | "H" | "K"} — проставлено глазами по листам превью:
  (с цифрой 2 — грубая нарезка) S — вывески магазинов и заведений, W — предупреждения и служебные таблички, A — реклама и плакаты,
  H — рукописные картонки, P — указатели мест (парки, тропы, «добро пожаловать»), K — английского нет (окна, фактуры, пиктограммы, атласы букв) → не трогаем.
как работает: атлас режется по прямым границам табличек (XY-cut по перепадам цвета), каждая табличка заливается
своим основным цветом с лёгкой фактурой оригинала (без букв), на табличке — русское слово цветом её прежних букв.
"""
import json
import os
import random
import re
import sys
import zlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

FD = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'fonts')
F_TITLE = os.path.join(FD, 'Rubik-Black.ttf')
F_NARROW = os.path.join(FD, 'PTSansNarrow-Bold.ttf')
F_SUB = os.path.join(FD, 'Oswald-SemiBold.ttf')
F_HAND = os.path.join(FD, 'Lobster-Regular.ttf')

S_WORDS = [
    ('ПРОДУКТЫ', 'круглосуточно'), ('ОДЕЖДА', 'мужская · женская'), ('ОБУВЬ', 'большой выбор'), ('ТКАНИ', 'фурнитура'),
    ('АВТОЗАПЧАСТИ', 'в наличии и под заказ'), ('ШИНОМОНТАЖ', 'балансировка'), ('ХОЗТОВАРЫ', 'всё для дома'),
    ('АПТЕКА', 'круглосуточно'), ('ЦВЕТЫ', 'букеты на заказ'), ('ХЛЕБ', 'свежая выпечка'), ('КАФЕ', 'обеды'),
    ('СТОЛОВАЯ', 'комплексные обеды'), ('ПИЦЦА', 'доставка'), ('КОФЕ', 'с собой'), ('ПАРИКМАХЕРСКАЯ', 'без записи'),
    ('ЧАСЫ', 'ремонт'), ('ОПТИКА', 'проверка зрения'), ('ЛОМБАРД', 'золото · техника'), ('ЮВЕЛИР', 'ремонт украшений'),
    ('ЭЛЕКТРОНИКА', 'в рассрочку'), ('СВЯЗЬ', 'телефоны · сим-карты'), ('РЕМОНТ ОБУВИ', 'изготовление ключей'),
    ('ФОТО', 'на документы'), ('КНИГИ', 'канцтовары'), ('ИГРУШКИ', 'детский мир'), ('МЕБЕЛЬ', 'кухни на заказ'),
    ('ХИМЧИСТКА', 'прачечная'), ('СТРОЙМАТЕРИАЛЫ', 'доставка'), ('РЫБАЛКА', 'охота · туризм'), ('СУВЕНИРЫ', 'подарки'),
    ('СПОРТ', 'одежда · инвентарь'), ('ЗООТОВАРЫ', 'корма'), ('МЯСО', 'фермерское'), ('ОВОЩИ ФРУКТЫ', 'свежие'),
    ('МОРОЖЕНОЕ', 'пломбир'), ('ГОСТИНИЦА', 'номера'), ('АВТОСЕРВИС', 'ремонт · диагностика'), ('МАГАЗИН', 'у дома'),
    ('УНИВЕРМАГ', 'всё для семьи'), ('КАНЦТОВАРЫ', 'для школы и офиса'), ('ТАБАК', 'пресса'), ('МОЛОКО', 'с фермы'),
    ('КОНДИТЕРСКАЯ', 'торты на заказ'), ('РЕСТОРАН', 'банкеты'), ('АВТОМОЙКА', 'круглосуточно'), ('ОБМЕН ВАЛЮТ', 'выгодный курс'),
]
W_WORDS = [
    ('ОСТОРОЖНО', ''), ('ВНИМАНИЕ', ''), ('ВХОД ВОСПРЕЩЁН', 'посторонним'), ('НЕ ПАРКОВАТЬСЯ', 'работает эвакуатор'),
    ('ПАРКОВКА', 'только для клиентов'), ('ВЫХОД', ''), ('ВХОД', ''), ('ЗАПАСНЫЙ ВЫХОД', ''), ('ОПАСНО', ''),
    ('ВЫСОКОЕ НАПРЯЖЕНИЕ', ''), ('ВИДЕОНАБЛЮДЕНИЕ', 'ведётся круглосуточно'), ('ЧАСТНАЯ ТЕРРИТОРИЯ', ''),
    ('ОХРАНА', ''), ('НЕ КУРИТЬ', ''), ('СЛУЖЕБНЫЙ ВХОД', ''), ('КАССА', ''), ('РЕГИСТРАТУРА', ''),
    ('ПРОЕЗД ЗАКРЫТ', ''), ('ЗЛАЯ СОБАКА', ''), ('РАБОТАЕТ КРАН', 'не стоять'), ('КАСКА ОБЯЗАТЕЛЬНА', ''),
    ('НЕ ВХОДИТЬ', ''), ('ТОЛЬКО ПЕРСОНАЛ', ''), ('ПРОХОД ЗАКРЫТ', ''), ('ЗАКРЫТО', ''), ('ОТКРЫТО', ''),
]
A_WORDS = [
    ('КИНО', 'премьеры каждую неделю'), ('КВАРТИРЫ', 'аренда и продажа'), ('ФИТНЕС', 'первая неделя бесплатно'),
    ('ТУРЫ НА МОРЕ', 'горящие путёвки'), ('МОРОЖЕНОЕ', 'пломбир · эскимо'), ('МЕБЕЛЬ', 'кухни на заказ'),
    ('ЕСТЬ РАБОТА', 'водители · курьеры'), ('ЭЛЕКТРОНИКА', 'смартфоны в рассрочку'), ('ПЕКАРНЯ', 'горячая выпечка'),
    ('ПИТЬЕВАЯ ВОДА', 'доставка 19 л'), ('ДОМАШНИЙ ИНТЕРНЕТ', 'от 450 ₽ в месяц'), ('СТОМАТОЛОГИЯ', 'лечим без боли'),
    ('АВТОСАЛОН', 'новые и с пробегом'), ('МОБИЛЬНАЯ СВЯЗЬ', 'безлимит за 300 ₽'), ('НАРОДНЫЙ БАНК', 'вклады · переводы'),
    ('ЮРИСТ', 'консультация бесплатно'), ('СДАЮ', 'квартиру посуточно'), ('ПРОДАЁТСЯ', 'тел. 8 900 555-01-23'),
    ('КОНЦЕРТ', 'в субботу'), ('ЦИРК', 'только неделю'), ('АВТОШКОЛА', 'права за 2 месяца'), ('ТАКСИ', 'быстро · недорого'),
]
H_WORDS = [('Помогите', 'на еду'), ('Добрые люди', 'помогите'), ('Спасибо', ''), ('На билет домой', ''),
           ('Ищу работу', ''), ('Продам', 'недорого')]
P_WORDS = [('ОЗЕРО', ''), ('ПОСЁЛОК', ''), ('ТУРБАЗА', ''), ('СМОТРОВАЯ ПЛОЩАДКА', ''), ('ЗАПОВЕДНИК', ''),
           ('ЛЕСНИЧЕСТВО', ''), ('ПРИСТАНЬ', ''), ('ТРОПА', 'к вершине'), ('ПЛЯЖ', ''), ('ДОБРО ПОЖАЛОВАТЬ', '')]
POOLS = {'S': S_WORDS, 'W': W_WORDS, 'A': A_WORDS, 'H': H_WORDS, 'P': P_WORDS}

# смысл по имени текстуры — главной (самой большой) табличке атласа
HINTS = [
    (r'dog', ('ЗЛАЯ СОБАКА', '')), (r'smok', ('НЕ КУРИТЬ', '')), (r'trespass|restrict|private', ('ВХОД ВОСПРЕЩЁН', 'посторонним')),
    (r'voltage|power|electr', ('ВЫСОКОЕ НАПРЯЖЕНИЕ', '')), (r'danger|caution|warn', ('ОПАСНО', '')),
    (r'park', ('ПАРКОВКА', '')), (r'exit|escape', ('ВЫХОД', '')),
    (r'hospital|medic|clinic|pillbox|zonah', ('БОЛЬНИЦА', 'приёмное отделение')), (r'police|lspd|sheriff|cop', ('ПОЛИЦИЯ', '')),
    (r'pharm|drug', ('АПТЕКА', 'круглосуточно')), (r'ammu|gun', ('ОРУЖИЕ', 'охота · рыбалка')),
    (r'liquor|beer|wine', ('ПРОДУКТЫ', 'напитки · закуски')), (r'bank|fleeca|maze', ('БАНК', 'вклады · кредиты')),
    (r'xero|globe_?oil|gas|fuel|ltd', ('АЗС', 'АИ-92 · АИ-95 · ДТ')), (r'motel|hotel', ('ГОСТИНИЦА', 'номера')),
    (r'tattoo', ('ТАТУ', 'салон')), (r'barber|hair', ('ПАРИКМАХЕРСКАЯ', '')), (r'cinema|theat|movie', ('КИНОТЕАТР', '')),
    (r'burger|cluck|taco|pizza|donut|diner|cafe|coffee|bean|food', ('КАФЕ', 'обеды · кофе с собой')),
    (r'auto|garage|mechanic|muffler|tyre|tire|repair', ('АВТОСЕРВИС', 'ремонт · шиномонтаж')),
    (r'247|24_7|market|grocer|store|shop', ('ПРОДУКТЫ', 'круглосуточно')), (r'pier|boat|fish', ('РЫБАЛКА', 'лодки напрокат')),
]
HINTS = [(re.compile(p, re.I), v) for p, v in HINTS]


def _cut(e, axis, lo, hi, a0, a1, minseg, thr=0.6):
    sub = e[lo:hi, a0:a1] if axis == 0 else e[a0:a1, lo:hi].T
    prof = sub.mean(axis=1)
    best = None
    for i in range(minseg, len(prof) - minseg):
        if prof[i] > thr and (best is None or prof[i] > prof[best]):
            best = i
    return None if best is None else lo + best


def _segment(e, x0, y0, x1, y1, minseg, out, depth=0, thr=0.6):
    # мелкие куски дальше не режем: иначе внутренние линии одной вывески дают «лоскутное одеяло»
    if depth < 10 and max(x1 - x0, y1 - y0) >= 3 * minseg:
        r = _cut(e, 0, y0, y1, x0, x1, minseg, thr)
        c = _cut(e, 1, x0, x1, y0, y1, minseg, thr)
        if r is not None and (c is None or e[r, x0:x1].mean() >= e[y0:y1, c].mean()):
            _segment(e, x0, y0, x1, r, minseg, out, depth + 1, thr)
            _segment(e, x0, r + 1, x1, y1, minseg, out, depth + 1, thr)
            return
        if c is not None:
            _segment(e, x0, y0, c, y1, minseg, out, depth + 1, thr)
            _segment(e, c + 1, y0, x1, y1, minseg, out, depth + 1, thr)
            return
    out.append((x0, y0, x1, y1))


def _lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def _two_colors(px):
    q = (px // 32).astype(np.int32)
    key = q[:, 0] * 64 + q[:, 1] * 8 + q[:, 2]
    vals, cnt = np.unique(key, return_counts=True)
    order = np.argsort(-cnt)
    def col(k):
        return tuple(int(v) for v in px[key == vals[k]].mean(axis=0))
    bg = col(order[0])
    fg = None
    for k in order[1:6]:
        c = col(k)
        if abs(_lum(c) - _lum(bg)) > 95:
            fg = c
            break
    if fg is None:
        fg = (245, 245, 245) if _lum(bg) < 128 else (28, 28, 30)
    return bg, fg


def _fit(d, lines, font_path, max_w, max_h):
    size = int(max_h / max(1, len(lines)) * 0.92)
    while size > 6:
        f = ImageFont.truetype(font_path, size)
        if max(d.textlength(t, font=f) for t in lines) <= max_w and size * len(lines) * 1.08 <= max_h:
            return f, size
        size -= 1
    return None, 0


def _text(d, box, title, sub, fg, hand=False, img=None):
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    pad_w, pad_h = w * 0.1, h * 0.14
    if img is not None and h > w * 1.6 and (' ' in title or len(title) > 8 or hand):
        # высокая узкая табличка с длинной надписью — текст повёрнут на 90° (читается снизу вверх, как у дорожных знаков GTA)
        tmp = Image.new('RGBA', (h, w), (0, 0, 0, 0))
        _text(ImageDraw.Draw(tmp), (0, 0, h, w), title, sub, fg, hand)
        tmp = tmp.rotate(90, expand=True)
        img.paste(tmp, (x0, y0), tmp)
        return
    if h > w * 1.6 and ' ' not in title and len(title) <= 12 and not hand:
        # вертикальная табличка — буквы столбиком
        letters = list(title)
        f, size = _fit(d, ['Ш'], F_TITLE, w - 2 * pad_w, (h - 2 * pad_h) / len(letters) * 1.0)
        if not f or size < 7:
            return
        step = (h - 2 * pad_h) / len(letters)
        for i, ch in enumerate(letters):
            d.text((x0 + w / 2, y0 + pad_h + step * (i + 0.5)), ch, font=f, fill=fg, anchor='mm')
        return
    lines = title.split(' ') if (' ' in title and h > w * 0.45) else [title]
    has_sub = bool(sub) and h >= 40 and w >= 120
    title_h = (h - 2 * pad_h) * (0.72 if has_sub else 1.0)
    f, size = _fit(d, lines, F_HAND if hand else (F_TITLE if w / max(1, len(title)) > h * 0.35 else F_NARROW),
                   w - 2 * pad_w, title_h)
    if not f or size < 8:
        return
    block = size * 1.08 * len(lines)
    sub_size = max(7, int(size * 0.36))
    total = block + (sub_size * 1.4 if has_sub else 0)
    y = y0 + (h - total) / 2
    for t in lines:
        d.text((x0 + w / 2, y + size * 0.54), t, font=f, fill=fg, anchor='mm')
        y += size * 1.08
    if has_sub:
        sf = ImageFont.truetype(F_SUB, sub_size)
        if d.textlength(sub.upper(), font=sf) <= w - 2 * pad_w:
            d.text((x0 + w / 2, y + sub_size * 0.3), sub.upper(), font=sf, fill=fg, anchor='mt')


def rebuild(im, name, label):
    # метка с «2» (S2, W2…) — грубая нарезка: высокие знаки и мелкие атласы иначе дробятся на пустые квадратики
    coarse = label.endswith('2')
    label = label.rstrip('2')
    w, h = im.size
    s = max(1, max(w, h) // 512)
    sm = im.convert('RGB').resize((max(8, w // s), max(8, h // s)), Image.BOX)
    a = np.asarray(sm).astype(np.int16)
    dy = np.abs(np.diff(a, axis=0)).sum(axis=2) > 90
    dx = np.abs(np.diff(a, axis=1)).sum(axis=2) > 90
    e = np.zeros(a.shape[:2], float)
    e[1:, :] += dy
    e[:, 1:] += dx
    e = np.clip(e, 0, 1)
    cells = []
    if coarse:
        _segment(e, 0, 0, a.shape[1], a.shape[0], max(16, min(a.shape[:2]) // 5), cells, thr=0.75)
    else:
        _segment(e, 0, 0, a.shape[1], a.shape[0], max(10, min(a.shape[:2]) // 16), cells)

    K = 2
    W, H = a.shape[1] * K, a.shape[0] * K
    # фактура: крупные пятна и потёртости оригинала без букв (сильно уменьшенный и размытый) — чтобы не «пластик»
    grain_src = sm.convert('L').resize((max(2, sm.width // 40), max(2, sm.height // 40)), Image.BOX)
    grain = np.asarray(grain_src.resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(8)), dtype=np.float32)
    canvas = np.zeros((H, W, 3), np.float32)
    texts = []
    rnd = random.Random(zlib.crc32(name.encode()))
    pool = POOLS[label][:]
    rnd.shuffle(pool)
    hint = next((v for r, v in HINTS if r.search(name)), None) if label in ('S', 'W') else None
    order = sorted(range(len(cells)), key=lambda i: -(cells[i][2] - cells[i][0]) * (cells[i][3] - cells[i][1]))
    for rank, i in enumerate(order):
        x0, y0, x1, y1 = cells[i]
        bg, fg = _two_colors(a[y0:y1, x0:x1].reshape(-1, 3))
        g = grain[y0 * K:y1 * K, x0 * K:x1 * K]
        dev = (g - g.mean()) * 0.2
        canvas[y0 * K:y1 * K, x0 * K:x1 * K] = np.clip(np.array(bg, np.float32)[None, None, :] + dev[..., None], 0, 255)
        cw, ch = (x1 - x0) * K, (y1 - y0) * K
        if max(cw, ch) >= 48 and min(cw, ch) >= 22:
            word = hint if (rank == 0 and hint) else pool[len(texts) % len(pool)]
            texts.append(((x0 * K, y0 * K, x1 * K, y1 * K), word, fg))
    out = Image.fromarray(canvas.astype(np.uint8), 'RGB')
    d = ImageDraw.Draw(out)
    for box, (title, sub), fg in texts:
        _text(d, box, title, sub, fg, hand=(label == 'H'), img=out)
    res = out.resize((w, h), Image.LANCZOS).convert('RGBA')
    res.putalpha(im.getchannel('A'))
    return res, len(cells)


def main():
    src, labels, out = sys.argv[1], json.load(open(sys.argv[2])), sys.argv[3]
    os.makedirs(out, exist_ok=True)
    n = 0
    for t, lab in sorted(labels.items()):
        if lab == 'K':
            continue
        im = Image.open(os.path.join(src, t + '.dds')).convert('RGBA')
        res, _ = rebuild(im, t, lab)
        res.save(os.path.join(out, t + '.png'))
        n += 1
    print('табличек:', n)


if __name__ == '__main__':
    main()
