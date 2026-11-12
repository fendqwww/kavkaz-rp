"""KAVKAZ RP: фоны номеров GTA (vehshare: plate01…plate05) → русские номера ГОСТ Р 50577 вместо «San Andreas».
python setup/retex/plates.py → resources/[kavkaz]/kavkaz_plates/html/tex/*.png (подмена — kavkaz_plates/client/main.lua)
символы номера рисует сама GTA (её шрифт и цвет у каждого фона свой), поэтому:
  plate01 (index 0) — белый «Россия»: тёмные символы на белом, рамка, отсек региона с флагом и RUS
  plate02 (index 1) — чёрный «военный» (символы у GTA светлые)
  plate03 (index 2) — синий «полиция» (символы у GTA светлые)
  plate04 (index 3) — жёлтый «такси» (символы у GTA тёмные)
  plate05 (index 4) — белый без флага (иностранные и транзит)
*_n — ровная карта нормалей: у американских выдавлено «San Andreas».
"""
import pathlib

from PIL import Image, ImageDraw, ImageFont

root = pathlib.Path(__file__).resolve().parents[2]
out = root / 'resources' / '[kavkaz]' / 'kavkaz_plates' / 'html' / 'tex'
out.mkdir(parents=True, exist_ok=True)
FONT = str(pathlib.Path(__file__).resolve().parent / 'fonts' / 'PTSans-Bold.ttf')
W, H, K = 256, 128, 4
DIV = 0.765  # граница отсека региона (последние две цифры номера GTA рисует правее)


def plate(name, bg, line, flag=True, rus_color=(20, 20, 20)):
    im = Image.new('RGBA', (W * K, H * K), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # пластина с закруглёнными углами, как у GTA (поля 2–3 px)
    d.rounded_rectangle([6 * K, 6 * K, (W - 6) * K, (H - 6) * K], radius=10 * K, fill=bg + (255,))
    # рамка
    d.rounded_rectangle([10 * K, 10 * K, (W - 10) * K, (H - 10) * K], radius=8 * K, outline=line + (255,), width=3 * K)
    # отсек региона
    x = int(DIV * W * K)
    d.line([x, 10 * K, x, (H - 10) * K], fill=line + (255,), width=3 * K)
    if flag:
        # RUS и флаг — вверху отсека: цифры региона GTA рисует в середине и снизу
        fx0, fy0, fw, fh = x + 26 * K, 16 * K, 22 * K, 14 * K
        for i, c in enumerate(((250, 250, 250), (0, 57, 166), (213, 43, 30))):
            d.rectangle([fx0, fy0 + i * fh // 3, fx0 + fw, fy0 + (i + 1) * fh // 3], fill=c + (255,))
        d.rectangle([fx0, fy0, fx0 + fw, fy0 + fh], outline=(90, 90, 90, 255), width=K)
        f = ImageFont.truetype(FONT, 13 * K)
        d.text((x + 5 * K, fy0 + fh // 2), 'RUS', font=f, fill=rus_color + (255,), anchor='lm')
    # болты
    for bx in (0.2, 0.8):
        d.ellipse([bx * W * K - 3 * K, 0.86 * H * K - 3 * K, bx * W * K + 3 * K, 0.86 * H * K + 3 * K], fill=(70, 70, 70, 255))
    im.resize((W, H), Image.LANCZOS).save(out / f'{name}.png', optimize=True)


plate('plate01', (246, 246, 244), (25, 25, 25))
plate('plate02', (22, 22, 24), (230, 230, 230), rus_color=(235, 235, 235))
plate('plate03', (20, 66, 150), (240, 240, 240), rus_color=(240, 240, 240))
plate('plate04', (247, 200, 40), (25, 25, 25))
plate('plate05', (246, 246, 244), (25, 25, 25), flag=False)
Image.new('RGBA', (W, H), (128, 128, 255, 255)).save(out / 'flat_n.png', optimize=True)
print('готово:', out)
