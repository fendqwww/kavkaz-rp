"""KAVKAZ RP: убрать рекламу по всей карте (щиты, неон, постеры, баннеры, логотипы) — вблизи и вдали (15.11, основатель:
«убери рекламные щиты и всю рекламу, если это легче, чем ставить своё»).
blender -b --factory-startup -P setup/maps/ads_hide_job.py -- <job.json> <review.txt> <keep.txt> <scan1.json> [scan2.json …]
15.11 позже: + дорожные знаки и указатели («убираем все знаки на дорогах, съездах, таблички»), + отдельные вывески магазинов,
кроме уже переведённых на русский (keep.txt — имена файлов наших ресурсов kv_map_signs).
- ближние (HD/ORPHANHD) по имени (billboard, bboard, neon, poster, flyer, banner, logo, advert…) — только если модель
  тонкая (толщина <= 6 м) или небольшая (<= 12 м во все стороны): так не уберём целое здание, у которого «billboard» в имени.
  крупное — в review.txt (смотреть глазами);
- дальние LOD/SLOD1 тех же имён: отдельные .ydr или модели в `*_children.ydd` тайлов (по joaat имени).
"""
import addon_utils, json, re, sys
from pathlib import Path
import numpy as np
addon_utils.enable('Sollumz', default_set=True)
from Sollumz.shared.game_assets.game_files import GameFiles  # noqa: E402
from szio.gta5 import try_load_asset  # noqa: E402

a = sys.argv[sys.argv.index('--') + 1:]
JOB, REVIEW, KEEP, SCANS = Path(a[0]), Path(a[1]), Path(a[2]), [Path(x) for x in a[3:]]
RU = {l.split()[0].rsplit('.', 1)[0] for l in KEEP.read_text(encoding='utf-8').splitlines() if 'kv_map_signs' in l}
AD = re.compile(r'billboard|billbrd|bboard|bilbrd|bllbrd|blbrd|_ads?\b|_ad_|advert|poster|flyer|banner|neon|logo|hoarding')
ROAD = re.compile(r'rd|road|fwy|frwy|freeway|hwy|hway|interstate|route|exit|gantry|street|junc|crossrd')
SIGN = re.compile(r'sign(?!al)')  # знак, но не светофор/сигнал
NOT = re.compile(r'traffic|signal|_rail_sig|gnd|grnd|ground|glue|terrain|land')  # земля и стыки тайлов — никогда


def cat(m):
    """A — реклама, B — дорожный знак, C — отдельная вывеска магазина (если ещё не русская), None — не трогать"""
    if NOT.search(m):
        return None
    if AD.search(m):
        return 'A'
    if SIGN.search(m) and (m.startswith('prop_') or ROAD.search(m)):
        return 'B'
    if SIGN.search(m) and re.sub(r'_?(s?lod|slod\d?)\d*$', '', m) not in RU:
        return 'C'
    return None


def joaat(s):
    h = 0
    for c in s.lower().encode():
        h = (h + c) & 0xFFFFFFFF; h = (h + (h << 10)) & 0xFFFFFFFF; h ^= h >> 6
    h = (h + (h << 3)) & 0xFFFFFFFF; h ^= h >> 11; h = (h + (h << 15)) & 0xFFFFFFFF
    return h


hd, far = set(), set()
for s in SCANS:
    for e in json.load(open(s)):
        m = e['m'].lower()
        if not cat(m):
            continue
        lv = e.get('lod', '')
        (hd if 'HD' in lv else far).add(m)
print('KAVKAZ ближних', len(hd), 'дальних', len(far), flush=True)

idx = GameFiles(r'D:\gta enhansed\GTAV').read_asset_filelist()
look = {}
for ext in ('.ydr', '.ydd'):
    for k, v in idx.get((ext,), {}).items():
        look[(ext[1:], str(k).lower())] = v[0] if isinstance(v, (list, tuple)) else v

job, review = [], []
for m in sorted(hd):
    if ('ydr', m) not in look:
        review.append(f'{m}\tнет ydr'); continue
    try:
        d = try_load_asset(look[('ydr', m)])
        ps = np.concatenate([np.asarray(g.vertex_buffer['Position']) for ms in d.models.values() for mm in ms for g in mm.geometries])
    except Exception as ex:  # noqa
        review.append(f'{m}\tне читается {ex}'); continue
    size = ps.max(0) - ps.min(0)
    # 15.11: реклама — отдельная накладка, если рекламное слово в КОНЦЕ имени (…_neon, …_billboard, …_poster2, …_banner_pole_03);
    # «…_bannerbld» (здание с баннером) и всё больше 60 м — не трогаем (review)
    tail = re.sub(r'([_\d]+[a-z]?|_s|_lod|_slod\d?)+$', '', m).split('_')[-1]
    tail2 = '_'.join(re.sub(r'(_\d+[a-z]?|_s)+$', '', m).split('_')[-2:])
    c = cat(m)
    if c == 'A':
        is_part = bool(AD.search(tail) or AD.search(tail2)) and not re.search(r'bld|build|bulid|blg\d*$', tail)
    else:  # знаки: само слово sign в имени, без «здания» в хвосте; вывеска магазина — небольшая
        is_part = not re.search(r'bld|build|bulid|house', tail) and (c == 'B' or max(size) <= 25.0)
    # явная вывеска/логотип/неон в конце имени — можно и шире (вывеска LifeInvader 103 м, вывески молла 46 м)
    clear = re.search(r'(signs?|emsign|emissivesigns?|logos?|neon|billboards?|posters?|flyers?)\d*[a-z]?$', re.sub(r'(_\d+[a-z]?|_s)+$', '', m))
    if is_part and (max(size) <= 60.0 or (clear and max(size) <= 150.0)):
        job.append({'kind': 'ydr', 'name': m, 'mode': 'all'})
    else:
        review.append(f'{m}\t{np.round(size, 1).tolist()}')
kept = {j['name'] for j in job}
# дальние: только если ближняя пара убирается (или у дальней нет ближней в списке, но имя рекламное и модель мелкая)
want = {}
for m in far:
    stem = re.sub(r'_?(s?lod|slod\d?)\d*$', '', m)
    if stem in kept or not any(stem == k for k in hd):
        want[joaat(m)] = m
found = set()
for h, m in list(want.items()):
    if ('ydr', m) in look:
        job.append({'kind': 'ydr', 'name': m, 'mode': 'all'}); found.add(m)
tiles = sorted({re.match(r'^([a-z]+\d*_\d+[a-z]?)', m).group(1) for m in want.values() if re.match(r'^([a-z]+\d*_\d+[a-z]?)', m)})
for (kind, n), p in sorted(look.items()):
    if kind != 'ydd' or not n.endswith('_children') or not n.startswith(tuple(t[:6] for t in tiles)):
        continue
    try:
        dd = try_load_asset(p)
    except Exception:  # noqa
        continue
    spec = {}
    for key in dd.drawables:
        k = str(key).lower()
        h = int(k[5:], 16) if k.startswith('hash_') else joaat(k)
        if h in want and want[h] not in found:
            spec[str(key)] = {'mode': 'all', 'model': want[h]}; found.add(want[h])
    if spec:
        job.append({'kind': 'ydd', 'name': n, 'drawables': spec})
print('KAVKAZ ближних в задании', len(kept), 'на проверку', len(review), 'дальних найдено', len(found), 'из', len(want), flush=True)
json.dump(job, open(JOB, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
REVIEW.write_text('\n'.join(review) + '\n\nдальние не найдены:\n' + '\n'.join(sorted(set(want.values()) - found)), encoding='utf-8')
print('KAVKAZ задание', JOB, len(job), flush=True)
