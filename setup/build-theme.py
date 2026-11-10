"""KAVKAZ RP: собрать тему ox_inventory = overrides/theme/inventory.css + шрифт Onest внутри (base64).
ox_inventory отдаёт из web/build/assets только *.css и *.js, поэтому шрифт вшиваем в сам css.
запуск из корня репозитория: python setup/build-theme.py"""
import base64, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
fonts = root / 'resources' / '[kavkaz]' / 'kavkaz_start' / 'html' / 'fonts'
src = (root / 'overrides' / 'theme' / 'inventory.css').read_text(encoding='utf-8')
out = root / 'overrides' / 'resources' / '[ox]' / 'ox_inventory' / 'web' / 'build' / 'assets' / 'kavkaz-theme.css'

RANGES = {
    'cyrillic': 'U+0301, U+0400-045F, U+0490-0491, U+04B0-04B1, U+2116',
    'latin': 'U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+0304, U+0308, U+0329, U+2000-206F, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD',
}
faces = []
for part, rng in RANGES.items():
    data = base64.b64encode((fonts / f'onest-{part}-normal.woff2').read_bytes()).decode()
    faces.append("@font-face{font-family:'Onest';font-style:normal;font-weight:500 800;font-display:swap;"
                 f"src:url(data:font/woff2;base64,{data}) format('woff2');unicode-range:{rng};}}")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text('/* собрано setup/build-theme.py — правь overrides/theme/inventory.css */\n' + '\n'.join(faces) + '\n' + src, encoding='utf-8')
print(f'готово: {out.relative_to(root)} ({out.stat().st_size // 1024} КБ)')
