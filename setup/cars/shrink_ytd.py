"""KAVKAZ RP: ужать текстуры .ytd больше 2K до 2K без пересжатия — отрезать верхний уровень mip.
python -I setup/cars/shrink_ytd.py file.ytd [...] [--max 2048]

как работает: у текстуры 4096 с mip-уровнями следующий уровень — готовая 2048. сдвигаем указатель данных на него,
делим ширину/высоту/строку пополам, уровней на один меньше. байты старого уровня зануляем — после сжатия
архива они почти ничего не весят, поэтому файл для скачивания становится меньше. раскладка страниц не меняется.
оригинал не сохраняется (он есть в скачанном архиве) — в папке stream лишние файлы не нужны.
"""
import os
import struct
import sys
import zlib

BLOCK = {b'DXT1', b'DXT3', b'DXT5', b'ATI1', b'ATI2', b'BC7\0'}


def page_size(flags):
    counts = (((flags >> 27) & 1) << 0) + (((flags >> 26) & 1) << 1) + (((flags >> 25) & 1) << 2) + \
             (((flags >> 24) & 1) << 3) + (((flags >> 17) & 0x7F) << 4) + (((flags >> 11) & 0x3F) << 5) + \
             (((flags >> 7) & 0xF) << 6) + (((flags >> 5) & 0x3) << 7) + (((flags >> 4) & 1) << 8)
    return (0x200 << (flags & 0xF)) * counts


def shrink(path, limit=2048):
    raw = open(path, 'rb').read()
    if raw[:4] != b'RSC7':
        return 0, 'не RSC7'
    _, sysf, gfxf = struct.unpack_from('<III', raw, 4)
    d = bytearray(zlib.decompress(raw[16:], -15))
    vsize = page_size(sysf)
    if vsize + page_size(gfxf) != len(d):
        return 0, 'размер страниц не сходится (%d + %d != %d), не трогаю' % (vsize, page_size(gfxf), len(d))

    def virt(p):
        return p & 0x0FFFFFFF if (p >> 28) == 5 else None

    tp, cnt = struct.unpack_from('<QH', d, 0x30)
    o = virt(tp)
    changed = 0
    for i in range(cnt):
        to = virt(struct.unpack_from('<Q', d, o + i * 8)[0])
        while True:
            w, h, depth, stride = struct.unpack_from('<HHHH', d, to + 0x50)
            fmt = bytes(d[to + 0x58:to + 0x5C])
            levels = d[to + 0x5D]
            dp = struct.unpack_from('<Q', d, to + 0x70)[0]
            if max(w, h) <= limit or (dp >> 28) != 6 or min(w, h) < 8:
                break
            if levels < 2:
                # одна картинка без mip (стёкла, таблички): берём каждый второй блок 4x4 по обеим осям
                start = vsize + (dp & 0x0FFFFFFF)
                if fmt not in BLOCK:
                    # несжатая (A8R8G8B8 и т.п.): берём каждый второй пиксель
                    bpp = stride // w if w else 0
                    if bpp < 1 or stride != bpp * w:
                        break
                    src = bytes(d[start:start + stride * h])
                    out = bytearray()
                    for y in range(0, h, 2):
                        row = src[y * stride:(y + 1) * stride]
                        for x in range(0, w, 2):
                            out += row[x * bpp:(x + 1) * bpp]
                    d[start:start + len(src)] = bytes(out) + bytes(len(src) - len(out))
                    struct.pack_into('<HHHH', d, to + 0x50, w // 2, h // 2, depth, stride // 2)
                    changed += 1
                    continue
                bs = 8 if fmt in (b'DXT1', b'ATI1') else 16
                bw, bh = w // 4, h // 4
                src = bytes(d[start:start + bw * bh * bs])
                out = bytearray()
                for by in range(0, bh, 2):
                    row = src[by * bw * bs:(by + 1) * bw * bs]
                    for bx in range(0, bw, 2):
                        out += row[bx * bs:(bx + 1) * bs]
                d[start:start + len(src)] = bytes(out) + bytes(len(src) - len(out))
                struct.pack_into('<HHHH', d, to + 0x50, w // 2, h // 2, depth, stride // 2)
                changed += 1
                continue
            rows = (h + 3) // 4 if fmt in BLOCK else h
            mip0 = stride * rows * max(1, depth)
            start = vsize + (dp & 0x0FFFFFFF)
            d[start:start + mip0] = bytes(mip0)  # старый уровень больше не нужен
            struct.pack_into('<HHHH', d, to + 0x50, w // 2, h // 2, depth, stride // 2)
            d[to + 0x5D] = levels - 1
            struct.pack_into('<Q', d, to + 0x70, dp + mip0)
            changed += 1
    if not changed:
        return 0, 'нечего ужимать'
    comp = zlib.compressobj(9, zlib.DEFLATED, -15)
    with open(path, 'wb') as f:
        f.write(raw[:16] + comp.compress(bytes(d)) + comp.flush())
    return changed, 'ок'


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    lim = 2048
    if '--max' in sys.argv:
        lim = int(sys.argv[sys.argv.index('--max') + 1])
        args = [a for a in args if a != str(lim)]
    for p in args:
        before = os.path.getsize(p)
        n, msg = shrink(p, lim)
        print('%s: уровней срезано %d, %s, %.1f -> %.1f МБ' % (os.path.basename(p), n, msg, before / 1048576, os.path.getsize(p) / 1048576))
