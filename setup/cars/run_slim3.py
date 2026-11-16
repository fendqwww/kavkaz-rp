"""третий проход: машины без рваного кузова. car_slim3.py (сварка, края не трогаем, симметрия, снаружи/салон по материалу).
доли кузова от 1.0 вниз, пока .yft <= 15.5 МиБ; салон 0.15, колёса 0.3. итог C:/kavkaz/cars-slim/out4/<машина>/ + рендер
python -I run_slim3.py kv_lc300 ..."""
import subprocess, sys, os, glob, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rscmem import mem
B = r'C:\kavkaz\tools\blender-4.2.3-windows-x64\blender.exe'
HERE = os.path.dirname(os.path.abspath(__file__))
S = os.path.join(HERE, 'car_slim3.py')
R = os.path.join(HERE, 'car_render.py')
ROOT = r'C:\kavkaz\cars-slim'
LIMIT = 15.5
STEPS = [(1.0, 1.0), (0.85, 0.9), (0.72, 0.8), (0.6, 0.7), (0.5, 0.6), (0.42, 0.5)]
log = open(os.path.join(ROOT, 'run_slim3.log'), 'a', encoding='utf-8')
for car in sys.argv[1:]:
    src = os.path.join(ROOT, 'orig', car, car + '.yft')
    dst = os.path.join(ROOT, 'out4', car)
    ok = False
    for hb, vb in STEPS:
        shutil.rmtree(dst, ignore_errors=True); os.makedirs(dst)
        with open(os.path.join(dst, 'blender.log'), 'w', encoding='utf-8') as f:
            subprocess.run([B, '-b', '--factory-startup', '-P', S, '--', src, dst,
                            f'vh={vb},0.15,0.3', f'h={hb},0.15,0.3', 'm=0.2', 'nt=0'], stdout=f, stderr=subprocess.STDOUT)
        outs = sorted(glob.glob(os.path.join(dst, '*.yft')))
        sizes = {os.path.basename(p): mem(p)[0] for p in outs}
        ok = bool(outs) and all(v <= LIMIT for v in sizes.values())
        line = f'{car} кузов {hb}/{vb}: {sizes} {"OK" if ok else "мало"}'
        print(line, flush=True); log.write(line + '\n'); log.flush()
        if ok: break
    if ok:
        for t in glob.glob(os.path.join(ROOT, 'orig', car, '*.ytd')): shutil.copy(t, dst)
        main = os.path.join(dst, car + '.yft')
        subprocess.run([B, '-b', '--factory-startup', '-P', R, '--', main, os.path.join(ROOT, 'render', f'{car}_v5.png')],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
print('ГОТОВО', flush=True); log.write('ГОТОВО\n')
