"""KAVKAZ RP: проверка .ytd после repack_ytd.py — обязательна перед заливкой (13.11: вылет «Invalid fixup» в cs6_04_lod.ytd).
python -I setup/cars/check_ytd.py file.ytd [...]
в зону pio+16 … pio+16+8*страниц (размеры страниц) не должен вести ни один указатель и там должны быть нули.
итог «плохих 0» — можно заливать.
"""
import sys, struct, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import repack_ytd as R
def zone(p):
    ver, sysf, gfxf, d, vs, ps = R.read(p)
    pio = struct.unpack_from('<Q', d, 8)[0] & 0x0FFFFFFF
    n = sum(R.page_counts(sysf)) + sum(R.page_counts(gfxf))
    a, b = pio + 16, pio + 16 + 8 * n
    hits = set()
    for o in range(0, vs - 7, 8):
        v = struct.unpack_from('<Q', d, o)[0]
        if v >> 32 == 0 and v >> 28 == 5 and a <= (v & 0x0FFFFFFF) < b: hits.add(v & 0x0FFFFFFF)
    nz = any(d[a:b])
    return pio, n, a, b, sorted(hits), nz
bad = 0
for p in sys.argv[1:]:
    pio, n, a, b, hits, nz = zone(p)
    if hits or nz:
        bad += 1
        if bad <= 10: print(os.path.basename(p), 'pio', pio, 'страниц', n, 'зона', a, b, 'указатели внутрь', hits[:4], 'не нули' if nz else '')
print('файлов', len(sys.argv) - 1, 'плохих', bad)
