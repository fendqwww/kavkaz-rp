"""KAVKAZ RP: собрать темы ox_inventory и ox_lib = overrides/theme/*.css + шрифт Golos Text внутри (base64).
ресурсы отдают из web/build только перечисленные в своих fxmanifest типы файлов, поэтому шрифт вшиваем в css.
запуск из корня репозитория: python setup/build-theme.py"""
import base64, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
font = root / 'resources' / '[kavkaz]' / 'kavkaz_plates' / 'html' / 'fonts' / 'golos-text.woff2'
face = ("@font-face{font-family:'Golos Text';font-style:normal;font-weight:400 900;font-display:swap;"
        f"src:url(data:font/woff2;base64,{base64.b64encode(font.read_bytes()).decode()}) format('woff2');}}")

targets = {
    'inventory.css': root / 'overrides' / 'resources' / '[ox]' / 'ox_inventory' / 'web' / 'build' / 'assets' / 'kavkaz-theme.css',
    'ox_lib.css': root / 'overrides' / 'resources' / '[ox]' / 'ox_lib' / 'web' / 'build' / 'kavkaz-theme.css',
}
for src_name, out in targets.items():
    src = (root / 'overrides' / 'theme' / src_name).read_text(encoding='utf-8')
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(f'/* собрано setup/build-theme.py — правь overrides/theme/{src_name} */\n{face}\n{src}', encoding='utf-8')
    print(f'готово: {out.relative_to(root)} ({out.stat().st_size // 1024} КБ)')
