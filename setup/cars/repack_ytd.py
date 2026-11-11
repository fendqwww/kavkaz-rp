"""KAVKAZ RP: перепаковать .ytd так, чтобы он реально занимал меньше видеопамяти.
python -I setup/cars/repack_ytd.py file.ytd [...] [--budget 16] [--min 512] [--info]

почему нужен: FiveM не грузит машину, если словарь текстур весит в «физической» (графической) памяти слишком много
(«Oversized assets»). shrink_ytd.py только обнулял лишние mip — страницы оставались прежнего размера.
здесь графический сегмент собирается заново: у самых тяжёлых текстур отбрасываются верхние mip-уровни
(4K -> 2K -> 1K, картинка та же, только меньше), данные раскладываются по новым страницам RSC7,
указатели и флаги страниц пишутся заново. виртуальная часть (имена, заголовки текстур) не двигается.
--budget  — сколько МБ графики оставить на файл (по умолчанию 16), --min — меньше этой стороны не ужимать.
--info    — только показать размеры, ничего не менять.
"""
import os
import struct
import sys
import zlib

BLOCK8 = {b'DXT1', b'ATI1'}
BLOCK16 = {b'DXT3', b'DXT5', b'ATI2', b'BC7 ', b'BC7\0', b'BC6H'}
# несжатые форматы D3D: байт на пиксель
RAW_BPP = {21: 4, 22: 4, 32: 4, 25: 2, 23: 2, 26: 2, 28: 1, 50: 1, 51: 2, 36: 8, 113: 8, 114: 4, 116: 16, 111: 2}
MAXCNT = [1, 3, 15, 63, 127, 1, 1, 1, 1]  # число страниц размера base<<8 ... base<<0
ALIGN = 256
CAP = 0  # --cap N: ограничить сторону каждой текстуры


def page_size(flags):
    counts = (((flags >> 27) & 1) << 0) + (((flags >> 26) & 1) << 1) + (((flags >> 25) & 1) << 2) + \
             (((flags >> 24) & 1) << 3) + (((flags >> 17) & 0x7F) << 4) + (((flags >> 11) & 0x3F) << 5) + \
             (((flags >> 7) & 0xF) << 6) + (((flags >> 5) & 0x3) << 7) + (((flags >> 4) & 1) << 8)
    return (0x200 << (flags & 0xF)) * counts


def page_counts(flags):
    return [(flags >> 4) & 1, (flags >> 5) & 3, (flags >> 7) & 0xF, (flags >> 11) & 0x3F, (flags >> 17) & 0x7F,
            (flags >> 24) & 1, (flags >> 25) & 1, (flags >> 26) & 1, (flags >> 27) & 1]


def make_flags(shift, counts, top):
    v = shift | (counts[0] << 4) | (counts[1] << 5) | (counts[2] << 7) | (counts[3] << 11) | (counts[4] << 17)
    v |= (counts[5] << 24) | (counts[6] << 25) | (counts[7] << 26) | (counts[8] << 27)
    return v | (top & 0xF0000000)


def mip_size(fmt, w, h):
    if fmt in BLOCK8:
        return max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * 8
    if fmt in BLOCK16:
        return max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * 16
    bpp = RAW_BPP.get(struct.unpack('<I', fmt)[0])
    return None if bpp is None else w * h * bpp


def align(n):
    return (n + ALIGN - 1) // ALIGN * ALIGN


def pack(blocks, limit_pages):
    """blocks: [(key, size)] -> (shift, counts, {key: offset}, total) или None. блок не пересекает границу страницы."""
    best = None
    total_need = sum(align(s) for _, s in blocks)
    order = sorted(blocks, key=lambda b: -b[1])
    for shift in range(0, 16):
        base = 0x200 << shift
        sizes = [base << (8 - k) for k in range(9)]
        if order and align(order[0][1]) > sizes[0]:
            continue
        for strategy in ('fit', 'fill'):
            pages = []  # [level, used, [(key, off)]]
            used_cnt = [0] * 9
            remaining = total_need
            ok = True
            for key, size in order:
                sz = align(size)
                cand = [p for p in pages if sizes[p[0]] - p[1] >= sz]
                if cand:
                    p = min(cand, key=lambda p: sizes[p[0]] - p[1])
                else:
                    want = sz if strategy == 'fit' else max(sz, min(remaining, sizes[0]))
                    lvl = None
                    for k in range(8, -1, -1):  # от маленьких к большим
                        if sizes[k] >= want and used_cnt[k] < MAXCNT[k]:
                            lvl = k
                            break
                    if lvl is None:
                        ok = False
                        break
                    used_cnt[lvl] += 1
                    p = [lvl, 0, []]
                    pages.append(p)
                p[2].append((key, p[1]))
                p[1] += sz
                remaining -= sz
            if not ok or len(pages) > limit_pages:
                continue
            total = sum(sizes[p[0]] for p in pages)
            if best is None or total < best[3]:
                pages.sort(key=lambda p: p[0])  # в файле страницы идут от больших к маленьким
                offs, pos = {}, 0
                for p in pages:
                    for key, o in p[2]:
                        offs[key] = pos + o
                    pos += sizes[p[0]]
                best = (shift, used_cnt[:], offs, total)
    return best


def read(path):
    raw = open(path, 'rb').read()
    if raw[:4] != b'RSC7':
        raise ValueError('не RSC7')
    ver, sysf, gfxf = struct.unpack_from('<III', raw, 4)
    d = bytearray(zlib.decompress(raw[16:], -15))
    vs, ps = page_size(sysf), page_size(gfxf)
    if vs + ps != len(d):
        raise ValueError('страницы не сходятся (%d + %d != %d)' % (vs, ps, len(d)))
    return ver, sysf, gfxf, d, vs, ps


def textures(d):
    def virt(p):
        return p & 0x0FFFFFFF if (p >> 28) == 5 else None
    tp, cnt = struct.unpack_from('<QH', d, 0x30)
    o = virt(tp)
    out = []
    for i in range(cnt):
        to = virt(struct.unpack_from('<Q', d, o + i * 8)[0])
        w, h, depth, stride = struct.unpack_from('<HHHH', d, to + 0x50)
        fmt = bytes(d[to + 0x58:to + 0x5C])
        levels = d[to + 0x5D]
        dp = struct.unpack_from('<Q', d, to + 0x70)[0]
        np_ = struct.unpack_from('<Q', d, to + 0x28)[0]
        name = ''
        if virt(np_) is not None:
            s = virt(np_)
            name = bytes(d[s:d.index(b'\0', s)]).decode('ascii', 'replace')
        out.append(dict(off=to, w=w, h=h, depth=max(1, depth), stride=stride, fmt=fmt, levels=max(1, levels), dp=dp, name=name))
    return out


def chain(t, drop):
    """размер данных текстуры, если отбросить drop верхних уровней"""
    w, h, tot = t['w'], t['h'], 0
    for lv in range(t['levels']):
        m = mip_size(t['fmt'], w, h)
        if m is None:
            return None
        if lv >= drop:
            tot += m
        w, h = max(1, w // 2), max(1, h // 2)
    return tot * t['depth']


def stride_of(fmt, w):
    # 11.11: GTA хранит для DXT «байт на строку пикселей»: DXT1 — w/2, DXT5 — w (раньше тут было в 4 раза больше —
    # у текстур нестандартной ширины выходили полосы). сверено по 2560 текстурам оригинальных модов
    if fmt in BLOCK8:
        return max(1, w // 2)
    if fmt in BLOCK16:
        return max(1, w)
    return w * RAW_BPP[struct.unpack('<I', fmt)[0]]


def fix_strides(path):
    """починить только поле stride (данные не трогаются). возвращает число исправленных текстур"""
    ver, sysf, gfxf, d, vs, ps = read(path)
    n = 0
    for t in textures(d):
        try:
            good = stride_of(t['fmt'], t['w'])
        except KeyError:
            continue
        if t['stride'] != good:
            struct.pack_into('<H', d, t['off'] + 0x56, good)
            n += 1
    if n:
        comp = zlib.compressobj(9, zlib.DEFLATED, -15)
        with open(path, 'wb') as f:
            f.write(b'RSC7' + struct.pack('<III', ver, sysf, gfxf) + comp.compress(bytes(d)) + comp.flush())
    return n


def halve(t):
    """текстура без mip: уменьшить вдвое. DXT — каждый второй блок 4x4, несжатые — Pillow (честное сглаживание)"""
    w, h, fmt, data = t['w'], t['h'], t['fmt'], t['data']
    if fmt in BLOCK8 or fmt in BLOCK16:
        bs = 8 if fmt in BLOCK8 else 16
        bw, bh = max(1, (w + 3) // 4), max(1, (h + 3) // 4)
        out = bytearray()
        for by in range(0, bh, 2):
            row = data[by * bw * bs:(by + 1) * bw * bs]
            for bx in range(0, bw, 2):
                out += row[bx * bs:(bx + 1) * bs]
        nw, nh = ((bw + 1) // 2) * 4, ((bh + 1) // 2) * 4
        return nw, nh, bytes(out)
    code = struct.unpack('<I', fmt)[0]
    bpp = RAW_BPP[code]
    nw, nh = max(1, w // 2), max(1, h // 2)
    mode = {4: 'RGBA', 1: 'L'}.get(bpp)
    if mode:
        from PIL import Image
        img = Image.frombytes(mode, (w, h), bytes(data[:w * h * bpp]))
        return nw, nh, img.resize((nw, nh), Image.LANCZOS).tobytes()
    out = bytearray()
    for y in range(0, nh * 2, 2):
        row = data[y * w * bpp:(y + 1) * w * bpp]
        for x in range(0, nw * 2, 2):
            out += row[x * bpp:(x + 1) * bpp]
    return nw, nh, bytes(out)


def reduce(t):
    """сделать текстуру вдвое меньше по сторонам: отбросить верхний mip или уменьшить картинку"""
    if t['levels'] > 1:
        m = mip_size(t['fmt'], t['w'], t['h']) * t['depth']
        t['data'] = t['data'][m:]
        t['w'], t['h'] = max(1, t['w'] // 2), max(1, t['h'] // 2)
        t['levels'] -= 1
    else:
        t['w'], t['h'], t['data'] = halve(t)
    t['size'] = len(t['data'])
    t['cut'] += 1


def page_room(d, sysf, gfxf):
    """сколько графических страниц можно записать: игра держит по 8 байт на страницу после заголовка ResourcePagesInfo"""
    pi = struct.unpack_from('<Q', d, 0x08)[0]
    if (pi >> 28) != 5:
        return None, sum(page_counts(gfxf))
    pio = pi & 0x0FFFFFFF
    sys_pages = sum(page_counts(sysf))
    reserved = d[pio + 8] + d[pio + 9]
    # свободное (нулевое) место за заголовком — туда игра пишет адреса страниц
    z = pio + 16
    while z < len(d) and z < pio + 16 + 8 * 256 and d[z] == 0:
        z += 1
    room = max(reserved, (z - (pio + 20)) // 8)
    return pio, max(1, min(room - sys_pages, 127))


def repack(path, budget_mb=16, min_side=512, info=False):
    ver, sysf, gfxf, d, vs, ps = read(path)
    tex = textures(d)
    for t in tex:
        t['size'] = chain(t, 0)
        t['cut'] = 0
    bad = [t['name'] for t in tex if t['size'] is None or (t['dp'] >> 28) != 6]
    if info:
        return ps, ps, len(tex), 'инфо'
    if bad:
        return ps, ps, 0, 'неизвестный формат: %s' % bad[:3]
    for t in tex:
        src = vs + (t['dp'] & 0x0FFFFFFF)
        t['data'] = bytes(d[src:src + t['size']])
    budget = budget_mb * 1048576
    # --cap: каждая текстура не больше cap по большей стороне (для карт: дороги, здания)
    if CAP:
        for t in tex:
            n = t['name'].lower()
            # рельеф и блеск видно хуже цвета — им вдвое меньше
            cap = CAP // 2 if n.endswith(('_n', '_nm', '_normal', '_s', '_spec', '_sp', '_nrm')) else CAP
            while t['depth'] == 1 and max(t['w'], t['h']) > cap and min(t['w'], t['h']) >= 16:
                reduce(t)
    # уменьшаем самую тяжёлую текстуру, пока не влезем в бюджет; меньше min_side по большей стороне не трогаем
    while sum(t['size'] for t in tex) > budget:
        cand = [t for t in tex if t['depth'] == 1 and max(t['w'], t['h']) > min_side and min(t['w'], t['h']) >= 16]
        if not cand:
            break
        reduce(max(cand, key=lambda t: t['size']))
    pio, limit = page_room(d, sysf, gfxf)
    res = pack([(i, t['size']) for i, t in enumerate(tex)], limit)
    if res is None:
        return ps, ps, 0, 'не удалось разложить страницы'
    shift, counts, offs, total = res
    if total >= ps:
        return ps, ps, 0, 'уже компактно'
    phys = bytearray(total)
    for i, t in enumerate(tex):
        phys[offs[i]:offs[i] + t['size']] = t['data']
        o = t['off']
        struct.pack_into('<HHHH', d, o + 0x50, t['w'], t['h'], struct.unpack_from('<H', d, o + 0x54)[0], stride_of(t['fmt'], t['w']))
        d[o + 0x5D] = t['levels']
        struct.pack_into('<Q', d, o + 0x70, 0x60000000 + offs[i])
    newg = make_flags(shift, counts, gfxf)
    if pio is not None:
        d[pio + 9] = sum(counts)
    body = bytes(d[:vs]) + bytes(phys)
    comp = zlib.compressobj(9, zlib.DEFLATED, -15)
    with open(path, 'wb') as f:
        f.write(b'RSC7' + struct.pack('<III', ver, sysf, newg) + comp.compress(body) + comp.flush())
    return ps, total, sum(1 for t in tex if t['cut']), 'ок'


if __name__ == '__main__':
    argv = sys.argv[1:]
    budget, mn, info = 16, 512, '--info' in argv
    if '--budget' in argv:
        budget = float(argv[argv.index('--budget') + 1])
    if '--min' in argv:
        mn = int(argv[argv.index('--min') + 1])
    if '--cap' in argv:
        CAP = int(argv[argv.index('--cap') + 1])
    skip = set()
    for k in ('--budget', '--min', '--cap'):
        if k in argv:
            skip.add(argv.index(k) + 1)
    files = [a for i, a in enumerate(argv) if not a.startswith('--') and i not in skip]
    if '--fix-stride' in argv:
        for p in files:
            try:
                print('%-34s stride исправлено: %d' % (os.path.basename(p), fix_strides(p)))
            except Exception as e:  # noqa
                print('%-34s ошибка: %s' % (os.path.basename(p), e))
        sys.exit(0)
    for p in files:
        try:
            before, after, n, msg = repack(p, budget, mn, info)
            print('%-34s %6.1f -> %6.1f МБ графики, ужато текстур: %d, %s' % (os.path.basename(p), before / 1048576, after / 1048576, n, msg))
        except Exception as e:  # noqa
            print('%-34s ошибка: %s' % (os.path.basename(p), e))
