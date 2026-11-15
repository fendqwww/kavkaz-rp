"""KAVKAZ RP: расстановка «Рублёвка 1.1» (Map Editor XML, бесплатный мод) -> resources/[kavkaz]/kavkaz_replace/data_rublevka.lua
python -I setup/maps/make_rublevka.py "<путь к Rublevka 1.1.xml>"
берём только объекты (Prop), без людей и машин. строка: { хэш, x, y, z, rx, ry, rz }. RemoveFromWorld — что спрятать.
"""
import os
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
out = os.path.join(os.path.dirname(__file__), '..', '..', 'resources', '[kavkaz]', 'kavkaz_replace', 'data_rublevka.lua')
f = lambda e, p: float(e.findtext(p))
rows, hide = [], []
for o in root.find('Objects'):
    if o.findtext('Type') != 'Prop':
        continue
    rows.append('{%d,%.3f,%.3f,%.3f,%.2f,%.2f,%.2f}' % (int(o.findtext('Hash')), f(o, 'Position/X'), f(o, 'Position/Y'), f(o, 'Position/Z'),
                                                      f(o, 'Rotation/X'), f(o, 'Rotation/Y'), f(o, 'Rotation/Z')))
for r in root.find('RemoveFromWorld') or []:
    hide.append('{%d,%.2f,%.2f,%.2f}' % (int(r.findtext('Hash')), f(r, 'Position/X'), f(r, 'Position/Y'), f(r, 'Position/Z')))
with open(out, 'w', encoding='utf-8') as w:
    w.write('-- KAVKAZ RP: «Рублёвка» у Песчаного (Map Editor, бесплатный мод). генерирует setup/maps/make_rublevka.py, руками не править.\n')
    w.write('RublevkaData = {\n' + ',\n'.join(rows) + '\n}\n')
    w.write('RublevkaHide = {\n' + ',\n'.join(hide) + '\n}\n')
print('объектов:', len(rows), 'спрятать:', len(hide))
