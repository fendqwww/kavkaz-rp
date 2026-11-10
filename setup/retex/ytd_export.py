"""KAVKAZ RP: достать картинки из .ytd (RSC7, PC) — чтобы увидеть, какие текстуры у здания и что на них нарисовано.
python -I setup/retex/ytd_export.py <file.ytd | папка> <out_dir>
на выходе: <out_dir>/<ytd>/<текстура>.png (первый уровень mip), list.txt (имя, размер, формат) и sheet.html — все картинки с подписями.
читает только незашифрованные .ytd: из модов (gta5-mods, форум cfx) или выгруженные CodeWalker'ом. файлы игры в git не класть.
"""
import html
import io
import os
import struct
import sys
import zlib

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'cars'))
from shrink_ytd import page_size  # noqa: E402  (тот же расчёт страниц RSC7, проверен на машинах)

FOURCC = {b'DXT1': b'DXT1', b'DXT3': b'DXT3', b'DXT5': b'DXT5', b'ATI1': b'ATI1', b'ATI2': b'ATI2'}
BLOCK8 = {b'DXT1', b'ATI1'}
BLOCK16 = {b'DXT3', b'DXT5', b'ATI2', b'BC7\0'}
# несжатые форматы D3D (число в поле формата): бит на пиксель и маски R G B A
PLAIN = {
    21: (32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000),  # A8R8G8B8
    22: (32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0),           # X8R8G8B8
    32: (32, 0x000000FF, 0x0000FF00, 0x00FF0000, 0xFF000000),  # A8B8G8R8
    28: (8, 0, 0, 0, 0xFF),                                    # A8
    50: (8, 0xFF, 0, 0, 0),                                    # L8
}


def dds(w, h, fmt, data):
    """собрать файл DDS вокруг сырых данных, чтобы его открыл Pillow"""
    flags = 0x1 | 0x2 | 0x4 | 0x1000
    if fmt in FOURCC or fmt == b'BC7\0':
        pf = struct.pack('<II4s5I', 32, 0x4, b'DX10' if fmt == b'BC7\0' else FOURCC[fmt], 0, 0, 0, 0, 0)
        pitch = len(data)
        flags |= 0x80000
    else:
        bpp, r, g, b, a = PLAIN[struct.unpack('<I', fmt)[0]]
        pff = (0x40 if (r or g or b) else 0) | (0x1 if a else 0)
        if bpp == 8 and r and not g:
            pff = 0x20000  # luminance
        pf = struct.pack('<II4s5I', 32, pff, b'\0\0\0\0', bpp, r, g, b, a)
        pitch = w * bpp // 8
        flags |= 0x8
    head = b'DDS ' + struct.pack('<7I', 124, flags, h, w, pitch, 1, 1) + b'\0' * 44 + pf + struct.pack('<5I', 0x1000, 0, 0, 0, 0)
    if fmt == b'BC7\0':
        head += struct.pack('<5I', 98, 3, 0, 1, 0)  # DXGI_FORMAT_BC7_UNORM, текстура 2D
    return head + data


def mip0_size(w, h, fmt, stride):
    if fmt in BLOCK8:
        return max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * 8
    if fmt in BLOCK16:
        return max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * 16
    return stride * h


def export(path, out):
    raw = open(path, 'rb').read()
    if raw[:4] != b'RSC7':
        print(path, ': не RSC7 (зашифрован или не .ytd)')
        return []
    _, sysf, _ = struct.unpack_from('<III', raw, 4)
    d = zlib.decompress(raw[16:], -15)
    vsize = page_size(sysf)

    def virt(p):
        return p & 0x0FFFFFFF if (p >> 28) == 5 else None

    tp, cnt = struct.unpack_from('<QH', d, 0x30)
    o = virt(tp)
    name_ytd = os.path.splitext(os.path.basename(path))[0]
    dst = os.path.join(out, name_ytd)
    os.makedirs(dst, exist_ok=True)
    rows = []
    for i in range(cnt):
        to = virt(struct.unpack_from('<Q', d, o + i * 8)[0])
        np_ = virt(struct.unpack_from('<Q', d, to + 0x28)[0])
        name = d[np_:d.index(b'\0', np_)].decode('ascii', 'replace') if np_ is not None else 'tex%d' % i
        w, h, _, stride = struct.unpack_from('<HHHH', d, to + 0x50)
        fmt = bytes(d[to + 0x58:to + 0x5C])
        dp = struct.unpack_from('<Q', d, to + 0x70)[0]
        fmt_txt = fmt.decode('ascii', 'replace').strip('\0') if fmt[:1].isalpha() else str(struct.unpack('<I', fmt)[0])
        note = ''
        try:
            if (dp >> 28) != 6:
                raise ValueError('данные не в графическом сегменте')
            start = vsize + (dp & 0x0FFFFFFF)
            data = d[start:start + mip0_size(w, h, fmt, stride)]
            img = Image.open(io.BytesIO(dds(w, h, fmt, data)))
            img.load()
            img.save(os.path.join(dst, name + '.png'))
        except Exception as e:  # формат, который не умеем, просто отмечаем в списке
            note = 'не выгружена: %s' % e
        rows.append((name, w, h, fmt_txt, note))
    with open(os.path.join(dst, 'list.txt'), 'w', encoding='utf-8') as f:
        for r in rows:
            f.write('%-32s %5dx%-5d %-6s %s\n' % r)
    with open(os.path.join(dst, 'sheet.html'), 'w', encoding='utf-8') as f:
        f.write('<!doctype html><meta charset="utf-8"><title>%s</title><style>body{background:#222;color:#eee;font:14px sans-serif}'
                'div{display:inline-block;margin:8px;vertical-align:top;width:260px}img{max-width:256px;max-height:256px;background:'
                'repeating-conic-gradient(#555 0 25%%,#333 0 50%%) 0 0/16px 16px}</style><h2>%s</h2>' % (name_ytd, name_ytd))
        for name, w, h, fmt_txt, note in rows:
            f.write('<div><img src="%s.png"><br><b>%s</b><br>%dx%d %s %s</div>' % (html.escape(name), html.escape(name), w, h, fmt_txt, html.escape(note)))
    print('%s: текстур %d -> %s' % (os.path.basename(path), len(rows), dst))
    return rows


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    src, out = sys.argv[1], sys.argv[2]
    files = [src] if os.path.isfile(src) else [os.path.join(r, n) for r, _, fs in os.walk(src) for n in fs if n.lower().endswith('.ytd')]
    for p in files:
        export(p, out)
