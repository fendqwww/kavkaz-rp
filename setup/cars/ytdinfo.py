"""Список текстур в .ytd (RSC7, PC): имя, размер, формат, уровни mip. python -I ytdinfo.py file.ytd [...]"""
import struct
import sys
import zlib


def info(path):
    raw = open(path, 'rb').read()
    if raw[:4] != b'RSC7':
        return None
    d = zlib.decompress(raw[16:], -15)

    def off(p):
        return p & 0x0FFFFFFF if (p >> 28) == 5 else None

    tp, cnt = struct.unpack_from('<QH', d, 0x30)
    o = off(tp)
    res = []
    for i in range(cnt):
        to = off(struct.unpack_from('<Q', d, o + i * 8)[0])
        np = off(struct.unpack_from('<Q', d, to + 0x28)[0])
        name = d[np:d.index(b'\0', np)].decode('ascii', 'replace') if np is not None else '?'
        w, h = struct.unpack_from('<HH', d, to + 0x50)
        fmt = d[to + 0x58:to + 0x5C]
        lv = d[to + 0x5D]
        res.append((name, w, h, fmt.decode('ascii', 'replace').strip('\0') or str(struct.unpack('<I', fmt)[0]), lv))
    return res


if __name__ == '__main__':
    for p in sys.argv[1:]:
        r = info(p)
        if r is None:
            print(p, 'не RSC7')
            continue
        big = [t for t in r if max(t[1], t[2]) > 2048]
        print('%s: текстур %d, больше 2K: %d, макс %d' % (p.split('/')[-1], len(r), len(big), max([max(t[1], t[2]) for t in r] or [0])))
        for t in sorted(r, key=lambda t: -t[1] * t[2])[:6]:
            print('    %-28s %5dx%-5d %-5s mip %d' % t)
