import struct, sys
sys.path.insert(0, r'C:\kavkaz\kavkaz-repo\setup\cars')
import repack_ytd as R
def mem(p):
    b = open(p, 'rb').read(16); v, s, g = struct.unpack_from('<III', b, 4)
    size = lambda f: sum(((0x200 << (f & 0xF)) << (8 - k)) * R.page_counts(f)[k] for k in range(9))
    return round(size(s) / 1048576, 1), round(size(g) / 1048576, 1)
if __name__ == '__main__':
    for p in sys.argv[1:]: print(p, mem(p))
