"""четвёртый проход машин (15.11): car_planar.py — без сдвига поверхности кузова, салон и колёса схлопываются.
лестница настроек, пока каждый .yft <= 15.5 МиБ; итог C:/kavkaz/cars-slim/out5/<машина>/ + лист рендеров
render/<машина>_cmp5.jpg (оригинал | результат, общий план и крупно) — смотреть глазами ДО выкладки.
python -I run_planar.py kv_lc300 kv_chiron ...   (машины параллельно по 3)"""
import subprocess, sys, os, glob, shutil
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rscmem import mem
B = r'C:\kavkaz\tools\blender-4.2.3-windows-x64\blender.exe'
HERE = os.path.dirname(os.path.abspath(__file__))
S, R = os.path.join(HERE, 'car_planar.py'), os.path.join(HERE, 'car_render.py')
ROOT = r'C:\kavkaz\cars-slim'
LIMIT = 15.5
STEPS = [('3', 'in=0.25', 'wheel=0.5'), ('6', 'in=0.15', 'wheel=0.4'), ('9', 'in=0.1', 'wheel=0.35')]


def render(yft, png):
    if not os.path.exists(png):
        subprocess.run([B, '-b', '--factory-startup', '-P', R, '--', yft, png], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def sheet(car):
    from PIL import Image
    r = os.path.join(ROOT, 'render')
    fs = [os.path.join(r, f) for f in (f'{car}_orig5.png', f'{car}_p5.png', f'{car}_orig5_close.png', f'{car}_p5_close.png')]
    if not all(os.path.exists(f) for f in fs): return
    ims = [Image.open(f).convert('RGB') for f in fs]
    w, h = ims[0].size; s = Image.new('RGB', (w * 2, h * 2))
    for i, im in enumerate(ims): s.paste(im, ((i % 2) * w, (i // 2) * h))
    s.save(os.path.join(r, f'{car}_cmp5.jpg'), quality=88)


def one(car):
    src_dir = os.path.join(ROOT, 'orig', car)
    dst = os.path.join(ROOT, 'out5', car)
    yfts = sorted(glob.glob(os.path.join(src_dir, '*.yft')))
    res = []
    for step in STEPS:
        shutil.rmtree(dst, ignore_errors=True); os.makedirs(dst)
        for y in yfts:  # _hi.yft — отдельная модель (вблизи), упрощаем так же
            with open(os.path.join(dst, os.path.basename(y) + '.log'), 'w', encoding='utf-8') as f:
                subprocess.run([B, '-b', '--factory-startup', '-P', S, '--', y, dst, *step], stdout=f, stderr=subprocess.STDOUT)
        sizes = {os.path.basename(p): mem(p)[0] for p in sorted(glob.glob(os.path.join(dst, '*.yft')))}
        ok = len(sizes) == len(yfts) and all(v <= LIMIT for v in sizes.values())
        res.append(f'{car} угол {step[0]} {step[1]} {step[2]}: {sizes} {"OK" if ok else "мало"}')
        print(res[-1], flush=True)
        if ok: break
    if ok:
        for t in glob.glob(os.path.join(src_dir, '*.ytd')): shutil.copy(t, dst)
        r = os.path.join(ROOT, 'render')
        render(os.path.join(src_dir, car + '.yft'), os.path.join(r, f'{car}_orig5.png'))
        render(os.path.join(dst, car + '.yft'), os.path.join(r, f'{car}_p5.png'))
        sheet(car)
    return res


with open(os.path.join(ROOT, 'run_planar.log'), 'a', encoding='utf-8') as log:
    with ThreadPoolExecutor(3) as ex:
        for res in ex.map(one, sys.argv[1:]):
            log.write('\n'.join(res) + '\n'); log.flush()
    log.write('ГОТОВО\n')
print('ГОТОВО', flush=True)
