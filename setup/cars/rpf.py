"""Минимальный распаковщик RPF7 (GTA V) для модов: только незашифрованные (OPEN/NONE) архивы.
python -I rpf.py <file.rpf> <out_dir>   — распаковать всё (вложенные .rpf тоже, в папку <name>.rpf/)
"""
import os
import struct
import sys
import zlib

OPEN = 0x4E45504F


def parse(data, out, depth=0):
    magic, count, names_len, enc = struct.unpack_from('<4I', data, 0)
    if magic != 0x52504637:
        raise ValueError('не RPF7')
    if enc not in (0, OPEN):
        raise ValueError('зашифрованный RPF (enc=%08X) — не поддерживается' % enc)
    ent_off = 16
    names_off = 16 + count * 16
    names = data[names_off:names_off + names_len]

    def name_at(o):
        e = names.index(b'\0', o)
        return names[o:e].decode('utf-8', 'replace')

    entries = []
    for i in range(count):
        raw = data[ent_off + i * 16: ent_off + i * 16 + 16]
        x, y = struct.unpack_from('<II', raw, 0)
        if y == 0x7FFFFF00:
            name_off, _, idx, cnt = struct.unpack_from('<4I', raw, 0)
            entries.append(('dir', name_at(name_off), idx, cnt))
        else:
            buf = struct.unpack_from('<Q', raw, 0)[0]
            name_off = buf & 0xFFFF
            size = (buf >> 16) & 0xFFFFFF
            offset = (buf >> 40) & 0x7FFFFF
            a, b = struct.unpack_from('<II', raw, 8)
            if (y & 0x80000000) == 0:
                entries.append(('bin', name_at(name_off), size, offset * 512, a, b))
            else:
                entries.append(('res', name_at(name_off), size, (offset & 0x7FFFFF) * 512, a, b))

    def walk(i, path):
        e = entries[i]
        if e[0] == 'dir':
            p = os.path.join(path, e[1]) if e[1] else path
            os.makedirs(p, exist_ok=True)
            for j in range(e[2], e[2] + e[3]):
                walk(j, p)
            return
        target = os.path.join(path, e[1])
        if e[0] == 'bin':
            _, name, size, off, usize, encflag = e
            if encflag:
                print('  ! зашифрованный файл пропущен:', target)
                return
            blob = data[off:off + (size if size else usize)]
            if size:
                blob = zlib.decompress(blob, -15)
            if name.lower().endswith('.rpf'):
                parse(blob, target, depth + 1)
                return
            with open(target, 'wb') as f:
                f.write(blob)
        else:
            _, name, size, off, sysf, gfxf = e
            if size == 0xFFFFFF:
                h = data[off:off + 16]
                size = h[7] | (h[14] << 8) | (h[5] << 16) | (h[2] << 24)
            with open(target, 'wb') as f:
                f.write(data[off:off + size])

    os.makedirs(out, exist_ok=True)
    walk(0, out)


if __name__ == '__main__':
    with open(sys.argv[1], 'rb') as f:
        parse(f.read(), sys.argv[2])
