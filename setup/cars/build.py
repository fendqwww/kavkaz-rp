"""KAVKAZ RP: сборка ресурса машины FiveM из скачанного мода.
python -I setup/cars/build.py <распакованный мод> <имя_спавна> --old <имя модели в моде> [опции] --out resources/[cars]

что делает:
  - берёт .yft/.ytd/.ycd/.ydr и meta-файлы мода (распакованные из dlc.rpf: setup/cars/rpf.py);
  - переименовывает модель в наше имя спавна (файлы и modelName/txdName/handlingId/gameName), детали тюнинга — с префиксом спавна;
  - выдаёт уникальные id набора тюнинга (kits), фар (lights) и сирен, чтобы машины не ломали друг другу тюнинг;
  - выкидывает _hi.yft, если он байт в байт совпадает с основным (половина веса у многих модов);
  - правит handling (масса, мощность, скорость, привод, подвеска) по классу машины;
  - пишет fxmanifest.lua, проверяет вес и размер текстур (лимит 30 МБ, 2K).
модели в git не идут: resources/[cars]/ в .gitignore.
"""
import argparse
import filecmp
import os
import re
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ytdinfo  # noqa: E402

STREAM_EXT = ('.yft', '.ytd', '.ycd', '.ydr', '.ydd', '.ytf')
META = ('vehicles.meta', 'handling.meta', 'carvariations.meta', 'carcols.meta', 'vehiclelayouts.meta')
DATA_FILE = {
    'handling.meta': 'HANDLING_FILE', 'vehicles.meta': 'VEHICLE_METADATA_FILE', 'carcols.meta': 'CARCOLS_FILE',
    'carvariations.meta': 'VEHICLE_VARIATION_FILE', 'vehiclelayouts.meta': 'VEHICLE_LAYOUTS_FILE',
}
HANDLING_FIELDS = {
    'mass': 'fMass', 'force': 'fInitialDriveForce', 'vmax': 'fInitialDriveMaxFlatVel', 'bias': 'fDriveBiasFront',
    'susp': 'fSuspensionForce', 'antiroll': 'fAntiRollBarForce', 'brake': 'fBrakeForce', 'inertia': 'fDriveInertia',
    'traction': 'fTractionCurveMax', 'raise': 'fSuspensionRaise',
}


def find_files(root, names):
    found = {}
    for dp, _, fs in os.walk(root):
        for f in fs:
            if f.lower() in names and f.lower() not in found:
                found[f.lower()] = os.path.join(dp, f)
    return found


def read(p):
    with open(p, 'rb') as f:
        b = f.read()
    return b.decode('utf-8-sig', 'replace')


def write(p, s):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, 'w', encoding='utf-8', newline='\n') as f:
        f.write(s)


def set_tag(s, tag, value):
    return re.sub(r'(<%s>)[^<]*(</%s>)' % (tag, tag), lambda m: m.group(1) + value + m.group(2), s, flags=re.I)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('src')
    ap.add_argument('spawn')
    ap.add_argument('--old', required=True, help='имя модели в моде (asea, g63trg …)')
    ap.add_argument('--out', required=True)
    ap.add_argument('--meta-from', help='папка с meta другой машины (для Replace-модов без своих meta)')
    ap.add_argument('--meta-old', help='имя модели в --meta-from')
    ap.add_argument('--drop', action='append', default=[], help='подстрока имени файла, который не берём (детали тюнинга)')
    ap.add_argument('--no-parts', action='store_true', help='не брать детали тюнинга (файлы не с именем модели)')
    ap.add_argument('--no-hi', action='store_true', help='не брать _hi.yft, даже если он отличается (вторая полная модель того же веса)')
    ap.add_argument('--id', type=int, required=True, help='база уникальных id (kits, lights, sirens)')
    ap.add_argument('--colors', help='цвета по умолчанию: "0,111" — основной цвет каждого варианта')
    ap.add_argument('--sirens', help='кости сирен через запятую: siren1,siren2 … (синий/красный по очереди)')
    ap.add_argument('--law', action='store_true', help='служебная машина полиции (флаг FLAG_LAW_ENFORCEMENT, класс VC_EMERGENCY)')
    for k in HANDLING_FIELDS:
        ap.add_argument('--' + k, type=float)
    a = ap.parse_args()

    spawn, old = a.spawn.lower(), a.old.lower()
    game = spawn.upper()
    out = os.path.join(a.out, spawn)
    if os.path.isdir(out):
        shutil.rmtree(out)
    stream = os.path.join(out, 'stream')
    os.makedirs(stream)

    # 1) файлы модели
    files = []
    for dp, _, fs in os.walk(a.src):
        for f in fs:
            if f.lower().endswith(STREAM_EXT) and not any(d in f.lower() for d in a.drop):
                files.append(os.path.join(dp, f))
    base_of = {}
    for p in files:
        name = os.path.basename(p)
        stem, ext = os.path.splitext(name)
        ls = stem.lower()
        is_main = ls in (old, old + '_hi', old + '+hi') or ls.startswith(old + '_') or ls.startswith(old + '+')
        if not is_main and a.no_parts:
            continue
        if ls == old + '_hi' and ext.lower() == '.yft' and a.no_hi:
            print('  _hi.yft не берём (--no-hi)')
            continue
        if ls == old + '_hi' and ext.lower() == '.yft':
            main = [q for q in files if os.path.basename(q).lower() == old + '.yft']
            if main and filecmp.cmp(main[0], p, shallow=False):
                print('  _hi.yft = копия основного, не берём')
                continue
        if ls == old or ls.startswith(old + '_') or ls.startswith(old + '+'):
            new = spawn + stem[len(old):]
        elif ls.startswith('va_' + old):
            new = 'va_' + spawn + stem[len(old) + 3:]
        else:
            new = spawn + '_' + stem  # детали тюнинга с общими именами (bumper_cu1) — свой префикс, чтобы не столкнуться с другими модами
        target = os.path.join(stream, new.lower() + ext.lower())
        if os.path.exists(target):
            continue  # тот же файл в другой папке мода
        base_of[ls] = new.lower()
        shutil.copyfile(p, target)

    # 2) meta
    metas = find_files(a.src, META)
    tmpl_old = old
    if a.meta_from:
        tm = find_files(a.meta_from, META)
        for k in ('vehicles.meta', 'handling.meta', 'carvariations.meta'):
            if k not in metas and k in tm:
                metas[k] = tm[k]
        tmpl_old = (a.meta_old or old).lower()
    texts = {k: read(p) for k, p in metas.items()}

    def rename_tokens(s, src_name):
        return re.sub(r'(?<![\w+])%s(?![\w+])' % re.escape(src_name), spawn, s, flags=re.I)

    for k in list(texts):
        s = texts[k]
        src_name = tmpl_old if (a.meta_from and metas[k].startswith(a.meta_from)) else old
        if k != 'vehiclelayouts.meta':
            s = rename_tokens(s, src_name)
            # словарь анимаций va_<модель> (двери, капот) переименован вместе с файлом .ycd
            s = re.sub(r'(?<![\w+])va_%s(?![\w+])' % re.escape(src_name), 'va_' + spawn, s, flags=re.I)
        texts[k] = s
    # шаблон meta от другой машины: его наборы тюнинга к этой модели не относятся -> стандартный набор
    if a.meta_from and 'carvariations.meta' in texts and not metas['carvariations.meta'].startswith(a.src):
        texts['carvariations.meta'] = re.sub(r'<Item>\d+_[^<]*_modkit</Item>', '<Item>0_default_modkit</Item>', texts['carvariations.meta'])

    vm = texts.get('vehicles.meta')
    if not vm:
        sys.exit('нет vehicles.meta — укажи --meta-from')
    vm = set_tag(vm, 'modelName', spawn)
    vm = set_tag(vm, 'txdName', spawn)
    vm = set_tag(vm, 'handlingId', game)
    vm = set_tag(vm, 'gameName', game)
    if a.law:
        vm = re.sub(r'<flags>([^<]*)</flags>', lambda m: '<flags>' + (m.group(1) if 'FLAG_LAW_ENFORCEMENT' in m.group(1) else m.group(1).rstrip() + ' FLAG_LAW_ENFORCEMENT FLAG_EMERGENCY_SERVICE') + '</flags>', vm, count=1)
        vm = set_tag(vm, 'vehicleClass', 'VC_EMERGENCY')
    texts['vehicles.meta'] = vm

    hm = texts.get('handling.meta')
    if hm:
        hm = set_tag(hm, 'handlingName', game)
        for k, field in HANDLING_FIELDS.items():
            v = getattr(a, k)
            if v is not None:
                hm = re.sub(r'(<%s value=")[^"]*(")' % field, lambda m: m.group(1) + ('%.6f' % v) + m.group(2), hm, count=1)
        texts['handling.meta'] = hm

    # 3) уникальные id: kits, lights
    cc, cv = texts.get('carcols.meta', ''), texts.get('carvariations.meta', '')
    kit_map, light_map = {}, {}
    n = 0
    for m in re.finditer(r'<kitName>([^<]+)</kitName>\s*<id value="(\d+)"', cc):
        new_id = a.id + n
        n += 1
        kit_map[m.group(1)] = ('%d_%s_modkit' % (new_id, spawn), m.group(2), str(new_id))
    for oldname, (newname, oldid, newid) in kit_map.items():
        cc = cc.replace('<kitName>%s</kitName>' % oldname, '<kitName>%s</kitName>' % newname)
        cc = re.sub(r'(<kitName>%s</kitName>\s*<id value=")%s(")' % (re.escape(newname), oldid), r'\g<1>%s\g<2>' % newid, cc)
        cv = cv.replace('<Item>%s</Item>' % oldname, '<Item>%s</Item>' % newname)
    lights = re.search(r'<Lights>(.*?)</Lights>', cc, flags=re.S)
    if lights:
        body = lights.group(1)
        for i, m in enumerate(re.finditer(r'<id value="(\d+)"', body)):
            light_map[m.group(1)] = str(a.id + 50 + i)
        body2 = re.sub(r'<id value="(\d+)"', lambda m: '<id value="%s"' % light_map[m.group(1)], body)
        cc = cc.replace(body, body2)
        cv = re.sub(r'<lightSettings value="(\d+)"', lambda m: '<lightSettings value="%s"' % light_map.get(m.group(1), m.group(1)), cv)
    # детали тюнинга с новыми именами
    for ls, new in base_of.items():
        if ls != new:
            cc = re.sub(r'>\s*%s\s*<' % re.escape(ls), '>%s<' % new, cc, flags=re.I)

    # 4) сирены (служебные)
    if a.sirens:
        bones = [b.strip() for b in a.sirens.split(',') if b.strip()]
        siren_id = a.id + 90
        cc = add_sirens(cc, siren_id, spawn, bones)
        cv = re.sub(r'<sirenSettings value="\d+"', '<sirenSettings value="%d"' % siren_id, cv)
    if a.colors and cv:
        cv = set_colors(cv, [int(c) for c in a.colors.split(',')])
    if cc:
        texts['carcols.meta'] = cc
    if cv:
        texts['carvariations.meta'] = cv

    for k, s in texts.items():
        write(os.path.join(out, 'data', k), s)

    # 5) манифест
    lines = ["-- собрано setup/cars/build.py: %s (из «%s»)" % (spawn, os.path.basename(os.path.normpath(a.src))),
             "fx_version 'cerulean'", "game 'gta5'", "lua54 'yes'", '', 'files {']
    lines += ["    'data/%s'," % k for k in sorted(texts)]
    lines += ['}', '']
    order = ['vehiclelayouts.meta', 'handling.meta', 'vehicles.meta', 'carcols.meta', 'carvariations.meta']
    lines += ["data_file '%s' 'data/%s'" % (DATA_FILE[k], k) for k in order if k in texts]
    write(os.path.join(out, 'fxmanifest.lua'), '\n'.join(lines) + '\n')

    # 6) вес и текстуры
    total, biggest = 0, 0
    for f in os.listdir(stream):
        p = os.path.join(stream, f)
        total += os.path.getsize(p)
        if f.endswith('.ytd'):
            for t in ytdinfo.info(p) or []:
                biggest = max(biggest, t[1], t[2])
    mb = total / 1048576
    flag = 'OK' if mb <= 30 and biggest <= 2048 else 'ПРЕВЫШЕН ЛИМИТ'
    print('%s: %.1f МБ, файлов %d, макс. текстура %d — %s' % (spawn, mb, len(os.listdir(stream)), biggest, flag))


def set_colors(cv, primaries):
    m = re.search(r'(<colors>)(.*?)(</colors>)', cv, flags=re.S)
    if not m:
        return cv
    first = re.search(r'<Item>\s*<indices.*?</Item>', m.group(2), flags=re.S)
    if not first:
        return cv
    items = []
    for c in primaries:
        it = re.sub(r'(<indices content="char_array">\s*)(\d+)(\s+)(\d+)',
                    lambda q: q.group(1) + str(c) + q.group(3) + str(c), first.group(0), count=1)
        items.append(it)
    return cv[:m.start(2)] + '\n        ' + '\n        '.join(items) + '\n      ' + cv[m.end(2):]


SIREN_ITEM = '''        <Item>
          <rotation><delta value="0.00000000"/><start value="0.00000000"/><speed value="3.00000000"/><sequencer value="0"/><multiples value="1"/><direction value="false"/><syncToBpm value="true"/></rotation>
          <flashiness><delta value="0.00000000"/><start value="0.00000000"/><speed value="0.00000000"/><sequencer value="{seq}"/><multiples value="1"/><direction value="false"/><syncToBpm value="true"/></flashiness>
          <corona><intensity value="50.00000000"/><size value="0.80000000"/><pull value="0.15000000"/><faceCamera value="false"/></corona>
          <color value="{color}"/>
          <intensity value="1.00000000"/>
          <lightGroup value="0"/>
          <rotate value="false"/>
          <scale value="true"/>
          <scaleFactor value="2"/>
          <flash value="true"/>
          <light value="{light}"/>
          <spotLight value="true"/>
          <castShadows value="false"/>
        </Item>'''


def add_sirens(cc, sid, spawn, bones):
    # сирены идут по номеру кости: siren1 -> 1-й элемент. синий и красный попеременно, «волной»
    nums = sorted(int(b.replace('siren', '')) for b in bones if re.fullmatch(r'siren\d+', b))
    items = []
    for i in range(1, max(nums) + 1):
        blue = i % 2 == 1
        on = i in nums
        items.append(SIREN_ITEM.format(
            seq=(2863311530 if blue else 1431655765) if on else 0,
            color='0xFF0A3CFF' if blue else '0xFFFF1010',
            light='true' if on and i <= 4 else 'false'))
    block = '''  <Sirens>
    <Item>
      <id value="{sid}"/>
      <name>{spawn}</name>
      <timeMultiplier value="1.00000000"/>
      <lightFalloffMax value="40.00000000"/>
      <lightFalloffExponent value="55.00000000"/>
      <lightInnerConeAngle value="2.29061000"/>
      <lightOuterConeAngle value="70.00000000"/>
      <lightOffset value="0.00000000"/>
      <textureName>VehicleLight_sirenlight</textureName>
      <sequencerBpm value="600"/>
      <leftHeadLight><sequencer value="0"/></leftHeadLight>
      <rightHeadLight><sequencer value="0"/></rightHeadLight>
      <leftTailLight><sequencer value="0"/></leftTailLight>
      <rightTailLight><sequencer value="0"/></rightTailLight>
      <leftHeadLightMultiples value="1"/>
      <rightHeadLightMultiples value="1"/>
      <leftTailLightMultiples value="1"/>
      <rightTailLightMultiples value="1"/>
      <useRealLights value="true"/>
      <sirens>
{items}
      </sirens>
    </Item>
  </Sirens>
'''.format(sid=sid, spawn=spawn, items='\n'.join(items))
    if not cc.strip():
        return '<?xml version="1.0" encoding="UTF-8"?>\n<CVehicleModelInfoVarGlobal>\n' + block + '</CVehicleModelInfoVarGlobal>\n'
    return re.sub(r'</CVehicleModelInfoVarGlobal>', block + '</CVehicleModelInfoVarGlobal>', cc, count=1)


if __name__ == '__main__':
    main()
