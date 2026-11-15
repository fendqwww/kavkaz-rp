"""KAVKAZ RP: запись DDS (DXT1/DXT5) с полной цепочкой mip через Pillow."""
import io
import struct
from PIL import Image


def save_dds(img, path, alpha):
    fmt = 'DXT5' if alpha else 'DXT1'
    bs = 16 if alpha else 8
    mode = 'RGBA' if alpha else 'RGB'
    cur = img.convert(mode)
    levels, w, h = [], cur.width, cur.height
    while True:
        b = io.BytesIO()
        cur.save(b, 'DDS', pixel_format=fmt)
        levels.append(b.getvalue())
        if w <= 4 or h <= 4:
            break
        w, h = max(4, w // 2), max(4, h // 2)
        cur = cur.resize((w, h), Image.LANCZOS)
    head = bytearray(levels[0][:128])
    struct.pack_into('<I', head, 8, struct.unpack_from('<I', head, 8)[0] | 0x20000)
    struct.pack_into('<I', head, 20, max(1, (img.width + 3) // 4) * max(1, (img.height + 3) // 4) * bs)
    struct.pack_into('<I', head, 28, len(levels))
    struct.pack_into('<I', head, 108, struct.unpack_from('<I', head, 108)[0] | 0x8 | 0x400000)
    with open(path, 'wb') as f:
        f.write(bytes(head) + b''.join(l[128:] for l in levels))
