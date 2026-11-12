"""KAVKAZ RP: собрать темы ox_inventory и ox_lib = overrides/theme/*.css + шрифты Golos Text и Unbounded внутри (base64).
ресурсы отдают из web/build только перечисленные в своих fxmanifest типы файлов, поэтому шрифт вшиваем в css.
запуск из корня репозитория: python setup/build-theme.py"""
import base64, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
fonts = root / 'resources' / '[kavkaz]' / 'kavkaz_hud' / 'html'
CYR = 'U+0301, U+0400-045F, U+0490-0491, U+04B0-04B1, U+2116'
LAT = 'U+0000-00FF, U+0131, U+0152-0153, U+2000-206F, U+20AC, U+20BD, U+2116, U+FEFF, U+FFFD'
# шрифты скилла kavkaz-ui (OFL): Golos Text — текст, Unbounded — заголовки капсом
def face_css(family, file, rng=None):
    data = base64.b64encode((fonts / file).read_bytes()).decode()
    r = f'unicode-range:{rng};' if rng else ''
    return (f"@font-face{{font-family:'{family}';font-style:normal;font-weight:100 900;font-display:swap;"
            f"src:url(data:font/woff2;base64,{data}) format('woff2');{r}}}")

face = face_css('Golos Text', 'golos-text.woff2') + face_css('Unbounded', 'unbounded-cyrillic.woff2', CYR) + face_css('Unbounded', 'unbounded-latin.woff2', LAT)

targets = {
    'inventory.css': root / 'overrides' / 'resources' / '[ox]' / 'ox_inventory' / 'web' / 'build' / 'assets' / 'kavkaz-theme.css',
    'ox_lib.css': root / 'overrides' / 'resources' / '[ox]' / 'ox_lib' / 'web' / 'build' / 'kavkaz-theme.css',
}
for src_name, out in targets.items():
    src = (root / 'overrides' / 'theme' / src_name).read_text(encoding='utf-8')
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(f'/* собрано setup/build-theme.py — правь overrides/theme/{src_name} */\n{face}\n{src}', encoding='utf-8')
    print(f'готово: {out.relative_to(root)} ({out.stat().st_size // 1024} КБ)')
