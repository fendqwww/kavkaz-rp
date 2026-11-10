"""KAVKAZ RP: подогнать нашу вывеску под текстуру GTA.
python -I setup/retex/fit.py <оригинал.png> <наша_картинка.png> <x> <y> <w> <h> <выход.png> [--contain]

у зданий GTA вывеска часто лежит не на всей текстуре, а на её части (одна текстура = несколько надписей и кусков стены).
поэтому берём выгруженный оригинал (setup/retex/ytd_export.py), в прямоугольник x,y,w,h вставляем нашу картинку
(по умолчанию «заполнить с обрезкой краёв», --contain — «вписать целиком» с полями цвета фона картинки),
остальное оставляем как было. выход кладём в resources/[kavkaz]/kavkaz_world/images/local/ — эта папка НЕ в git
(в ней куски текстур игры), на сервер её копирует скрипт выкладки вместе с ресурсом.
если вывеска занимает всю текстуру — x=0 y=0 w,h = размер оригинала.
"""
import sys

from PIL import Image


def fit(orig, art, x, y, w, h, out, contain=False):
    base = Image.open(orig).convert('RGBA')
    pic = Image.open(art).convert('RGBA')
    k = (min if contain else max)(w / pic.width, h / pic.height)
    pic = pic.resize((max(1, round(pic.width * k)), max(1, round(pic.height * k))), Image.LANCZOS)
    box = Image.new('RGBA', (w, h), pic.getpixel((2, 2)))  # поля — цветом фона нашей картинки
    box.alpha_composite(pic, ((w - pic.width) // 2, (h - pic.height) // 2)) if contain else \
        box.paste(pic.crop(((pic.width - w) // 2, (pic.height - h) // 2, (pic.width - w) // 2 + w, (pic.height - h) // 2 + h)), (0, 0))
    base.paste(box, (x, y))
    base.save(out)
    print('готово:', out, base.size)


if __name__ == '__main__':
    a = [s for s in sys.argv[1:] if not s.startswith('--')]
    if len(a) != 7:
        print(__doc__)
        sys.exit(1)
    fit(a[0], a[1], int(a[2]), int(a[3]), int(a[4]), int(a[5]), a[6], '--contain' in sys.argv)
