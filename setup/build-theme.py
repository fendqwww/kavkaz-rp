"""KAVKAZ RP: собрать темы ox_inventory и ox_lib = overrides/theme/*.css + шрифт Golos Text внутри (base64).
ресурсы отдают из web/build только перечисленные в своих fxmanifest типы файлов, поэтому шрифт вшиваем в css.
запуск из корня репозитория: python setup/build-theme.py"""
import base64, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
fonts = root / 'resources' / '[kavkaz]' / 'kavkaz_plates' / 'html' / 'fonts'
CYR = 'U+0301, U+0400-045F, U+0490-0491, U+04B0-04B1, U+2116'
LAT = 'U+0000-00FF, U+0131, U+0152-0153, U+2000-206F, U+20AC, U+20BD, U+2116, U+FEFF, U+FFFD'
# единый шрифт Manrope (OFL, близок к Gilroy как у Majestic) под именем 'Golos Text' — так его уже ждут темы
face = ''.join(
    "@font-face{font-family:'Golos Text';font-style:normal;font-weight:100 900;font-display:swap;"
    f"src:url(data:font/woff2;base64,{base64.b64encode((fonts / f'manrope-{sub}.woff2').read_bytes()).decode()}) format('woff2');unicode-range:{rng};}}"
    for sub, rng in (('cyrillic', CYR), ('latin', LAT)))

targets = {
    'inventory.css': root / 'overrides' / 'resources' / '[ox]' / 'ox_inventory' / 'web' / 'build' / 'assets' / 'kavkaz-theme.css',
    'ox_lib.css': root / 'overrides' / 'resources' / '[ox]' / 'ox_lib' / 'web' / 'build' / 'kavkaz-theme.css',
}
for src_name, out in targets.items():
    src = (root / 'overrides' / 'theme' / src_name).read_text(encoding='utf-8')
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(f'/* собрано setup/build-theme.py — правь overrides/theme/{src_name} */\n{face}\n{src}', encoding='utf-8')
    print(f'готово: {out.relative_to(root)} ({out.stat().st_size // 1024} КБ)')
