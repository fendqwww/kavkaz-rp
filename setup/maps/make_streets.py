"""KAVKAZ RP: русские названия всех улиц GTA (16.11, основатель: «названия улиц переделай, нас ничего не должно связывать с их картой»).
список хэшей улиц — github.com/jgscripts/gtav-street-zone-hashes (streets.txt, 237 строк «0xHASH = Name»).
python -I setup/maps/make_streets.py <streets.txt> resources/[kavkaz]/kavkaz_map/streets.lua
кольцо фривеев вокруг центра — НКАД, трасса на север — «Кавказ», остальное — обычные русские улицы и немного пасхалок
(Петровка у МВД, Тверская у бутиков, Мясницкая у бойни, СНТ «Мечта», улица Безымянная).
"""
import re, sys

RU = {
    # трассы
    'Los Santos Freeway': 'НКАД', 'Olympic Fwy': 'НКАД', 'Del Perro Fwy': 'НКАД',
    'Senora Fwy': 'трасса «Кавказ»', 'Great Ocean Hwy': 'Приморское шоссе', 'La Puerta Fwy': 'Аэропортовское шоссе',
    'Elysian Fields Fwy': 'Портовое шоссе', 'Palomino Fwy': 'Восточное шоссе', 'Palomino Freeway': 'Восточное шоссе',
    'Route 68': 'Степное шоссе', 'Route 68 Approach': 'подъезд к Степному шоссе', 'Miriam Turner Overpass': 'Северный путепровод',
    'Runway1': 'взлётная полоса', 'Senora Rd': 'Старая дорога', 'Senora Way': 'Объездная дорога', 'Joshua Rd': 'Песчаный тракт',
    'East Joshua Road': 'Восточный тракт', 'Calafia Rd': 'Калинов мост', 'North Calafia Way': 'Мостовой проезд',
    'Raton Pass': 'Волчий перевал', 'Chianski Passage': 'Горный проезд', 'Ineseno Road': 'дорога к маяку',
    'Fort Zancudo Approach Rd': 'подъезд к воинской части', 'Hillcrest Ridge Access Rd': 'подъезд к хребту',
    'Cassidy Trail': 'Лесная тропа', 'Baytree Canyon Rd': 'Лавровая дорога', 'Banham Canyon Dr': 'ул. Ущельная',
    # центр, госквартал
    'Vespucci Blvd': 'проспект Победы', 'Vinewood Blvd': 'проспект Мира', 'Lindsay Circus': 'площадь Ленина',
    'Sinner St': 'ул. Петровка', 'Sinners Passage': 'Петровский переулок', 'Atlee St': 'ул. Гоголя', 'Elgin Ave': 'ул. Чехова',
    'Power St': 'ул. Энергетиков', 'Alta St': 'ул. Высотная', 'Alta Pl': 'Высотный переулок', 'Peaceful St': 'ул. Мирная',
    'Swiss St': 'ул. Банковская', 'Capital Blvd': 'ул. Столичная', 'Integrity Way': 'ул. Правды', 'Liberty St': 'ул. Свободы',
    'Equality Way': 'ул. Дружбы', 'Occupation Ave': 'ул. Труда', 'Labor Pl': 'Трудовой переулок', 'Glory Way': 'ул. Славы',
    'Heritage Way': 'ул. Наследия', 'Prosperity St': 'ул. Изобилия', 'Prosperity Street Promenade': 'бульвар Изобилия',
    'Rockford Dr': 'ул. Правительственная', 'North Rockford Dr': 'Рублёвское шоссе', 'South Rockford Dr': 'ул. Правительственная',
    'Portola Dr': 'ул. Тверская', 'Richman St': 'ул. Купеческая', 'Movie Star Way': 'ул. Кинематографистов',
    'Marathon Ave': 'ул. Спортивная', 'Hawick Ave': 'ул. Гагарина', 'Clinton Ave': 'ул. Пушкина', 'Carson Ave': 'ул. Карла Маркса',
    'Innocence Blvd': 'ул. Кирова', 'Macdonald St': 'ул. Комсомольская', 'Little Bighorn Ave': 'ул. Лермонтова',
    'Adam\'s Apple Blvd': 'ул. Яблоневая', 'San Andreas Ave': 'ул. Республиканская', 'Calais Ave': 'ул. Калинина',
    'Strawberry Ave': 'ул. Строителей', 'Forum Dr': 'ул. Молодёжная', 'Grove St': 'ул. Рощинская', 'Davis Ave': 'ул. Дачная',
    'Roy Lowenstein Blvd': 'ул. Шоссейная', 'Jamestown St': 'ул. Ивановская', 'Brouge Ave': 'ул. Брусничная',
    'Covenant Ave': 'ул. Заветная', 'Popular St': 'ул. Народная', 'El Rancho Blvd': 'ул. Заводская', 'Supply St': 'ул. Складская',
    'Tower Way': 'ул. Башенная', 'Signal St': 'ул. Связистов', 'Low Power St': 'ул. Трансформаторная', 'Abattoir Ave': 'ул. Мясницкая',
    'Decker St': 'ул. Дегтярная', 'Dutch London St': 'ул. Портовая', 'South Shambles St': 'ул. Барачная', 'Shank St': 'ул. Острожная',
    'Rub St': 'ул. Банная', 'Steele Way': 'ул. Сталеваров', 'Pyrite Ave': 'ул. Рудная', 'York St': 'ул. Ярославская',
    'Mutiny Rd': 'ул. Восстания', 'Union Rd': 'ул. Союзная', 'South Arsenal St': 'ул. Арсенальная', 'Carcer Way': 'ул. Конвойная',
    'Hangman Ave': 'ул. Каторжная', 'Voodoo Place': 'Знахарский переулок', 'Mad Wayne Thunder Dr': 'ул. Громова',
    'Ace Jones Dr': 'ул. Тузова', 'Sam Austin Dr': 'ул. Самойлова', 'Strangeways Dr': 'ул. Кривая', 'Nowhere Rd': 'ул. Безымянная',
    'Cockingend Dr': 'ул. Окраинная', 'Spanish Ave': 'ул. Лесная', 'Lesbos Ln': 'Лесной переулок', 'Lolita Ave': 'ул. Липовая',
    'Americano Way': 'ул. Кофейная', 'Alhambra Dr': 'ул. Дворцовая', 'Caesars Place': 'Царская площадь', 'Autopia Pkwy': 'ул. Автомобилистов',
    'Kortz Dr': 'ул. Музейная', 'Utopia Gardens': 'СНТ «Мечта»', 'Imagination Court': 'переулок Изобретателей',
    'Imagination Ct': 'переулок Изобретателей', 'Invention Court': 'переулок Рационализаторов', 'Invention Ct': 'переулок Рационализаторов',
    'Fantastic Pl': 'ул. Сказочная', 'Fenwell Pl': 'Фонтанный переулок', 'Gentry Lane': 'Дворянский переулок', 'Goma St': 'ул. Шинная',
    'Hardy Way': 'ул. Твардовского', 'Joad Ln': 'Ждановский переулок', 'Perth St': 'ул. Пермская', 'O\'Neil Way': 'ул. Нилова',
    'North Archer Ave': 'ул. Стрелецкая', 'North Conker Ave': 'ул. Каштановая', 'North Sheldon Ave': 'ул. Шолохова',
    'Nikola Ave': 'ул. Николаевская', 'Nikola Pl': 'Николаевский переулок', 'Niland Ave': 'ул. Полевая', 'Picture Perfect Drive': 'ул. Живописная',
    'Procopio Dr': 'ул. Прокопьевская', 'Procopio Promenade': 'Прокопьевский бульвар', 'San Vitus Blvd': 'Витебский бульвар',
    'Vitus St': 'ул. Витебская', 'Sustancia Rd': 'ул. Сущёвская', 'Whispymound Dr': 'ул. Курганная', 'Wild Oats Dr': 'ул. Овсяная',
    'Smoke Tree Rd': 'ул. Ясеневая', 'Melanoma St': 'ул. Солнцепёка', 'Edwood Way': 'ул. Еловая', 'Duluoz Ave': 'ул. Дубовая',
    'Dunstable Dr': 'ул. Дубравная', 'Dunstable Ln': 'Дубравный переулок', 'Dorset Dr': 'ул. Дорожная', 'Dorset Pl': 'Дорожный переулок',
    'Didion Dr': 'ул. Горная', 'Hillcrest Ave': 'ул. Холмовая', 'Normandy Dr': 'ул. Нагорная', 'Kimble Hill Dr': 'ул. Подгорная',
    'Mt Haan Dr': 'ул. Высокогорная', 'Mt Haan Rd': 'Высокогорная дорога', 'Mt Vinewood Dr': 'ул. Перевальная',
    'Mountain View Dr': 'ул. Видовая', 'Marlowe Dr': 'ул. Марьинская', 'Milton Rd': 'ул. Мельничная', 'Abe Milton Pkwy': 'Мельничный проезд',
    'South Mo Milton Dr': 'ул. Мельникова', 'Galileo Park': 'парк Обсерватории', 'Galileo Rd': 'ул. Обсерваторная',
    'East Galileo Ave': 'ул. Звёздная', 'West Galileo Ave': 'ул. Космонавтов', 'Meteor St': 'ул. Космическая',
    'Lake Vinewood Dr': 'ул. Водохранилищная', 'Lake Vinewood Est': 'посёлок Водохранилище', 'Vinewood Park Dr': 'ул. Парковая',
    'Mirror Park Blvd': 'ул. Зеркальная', 'East Mirror Dr': 'Зеркальный проезд', 'West Mirror Drive': 'ул. Прудовая',
    'Mirror Pl': 'Зеркальный переулок', 'Fudge Ln': 'ул. Кондитерская', 'Ginger St': 'ул. Пряничная', 'Meringue Ln': 'Зефирный переулок',
    'Tangerine St': 'ул. Мандариновая', 'Eclipse Blvd': 'ул. Солнечная', 'West Eclipse Blvd': 'ул. Солнечная',
    'Morningwood Blvd': 'ул. Утренняя', 'Bridge St': 'ул. Мостовая', 'Eastbourne Way': 'ул. Восточная',
    'El Burro Blvd': 'ул. Нефтяников', 'Amarillo Vista': 'ул. Подсолнечная', 'Amarillo Way': 'Подсолнечный переулок',
    'Cavalry Blvd': 'ул. Кавалерийская', 'Crusade Rd': 'ул. Походная', 'Conquistador St': 'ул. Покорителей', 'Cortes St': 'ул. Покровская',
    'Cougar Ave': 'ул. Рысья', 'Cascabel Ave': 'ул. Бубенцова', 'Cox Way': 'ул. Шахтёрская', 'Chupacabra St': 'ул. Лешего', 'Cat-Claw Ave': 'ул. Кошкина',
    # набережная, порт, пляж
    'Boulevard Del Perro': 'Приморский бульвар', 'South Boulevard Del Perro': 'ул. Приморская', 'Bay City Ave': 'ул. Курортная',
    'Bay City Incline': 'Пляжный спуск', 'Playa Vista': 'ул. Пляжная', 'Magellan Ave': 'ул. Мореходная', 'Aguja St': 'ул. Рыбацкая',
    'Seaview Rd': 'ул. Морская', 'Sandcastle Way': 'ул. Песочная', 'Buccaneer Way': 'ул. Матросская', 'Dry Dock St': 'ул. Доковая',
    'Tug St': 'ул. Буксирная', 'Chum St': 'ул. Корабельная', 'Plaice Pl': 'Причальный переулок', 'Bait St': 'ул. Якорная',
    'Tackle St': 'ул. Сетевая', 'Las Lagunas Blvd': 'Озёрный бульвар', 'Laguna Pl': 'Озёрный переулок', 'Marina Dr': 'ул. Причальная',
    'Catfish View': 'ул. Озёрная', 'Barbareno Rd': 'ул. Береговая', 'El Gordo Dr': 'ул. Маячная',
    # аэропорт
    'Exceptionalists Way': 'ул. Авиаторов', 'New Empire Way': 'ул. Лётчиков', 'Hanger Way': 'ул. Ангарная',
    'Greenwich Pkwy': 'ул. Аэродромная', 'Greenwich Way': 'Аэродромный проезд', 'Greenwich Pl': 'Аэродромный переулок',
    # сёла и природа
    'Algonquin Blvd': 'ул. Центральная', 'Paleto Blvd': 'ул. Ленина', 'Grapeseed Main St': 'ул. Ленина', 'Grapeseed Ave': 'ул. Колхозная',
    'Orchardville Ave': 'ул. Садовая', 'Buen Vino Rd': 'ул. Виноградная', 'Tongva Dr': 'ул. Холмистая', 'Palomino Ave': 'ул. Конная',
    'Panorama Dr': 'ул. Панорамная', 'Red Desert Ave': 'ул. Красная Степь', 'Armadillo Ave': 'ул. Броненосцев',
    'Cholla Rd': 'ул. Колючая', 'Cholla Springs Ave': 'ул. Родниковая', 'Zancudo Ave': 'ул. Военная', 'Zancudo Rd': 'Военная дорога',
    'Zancudo Barranca': 'ул. Овражная', 'Zancudo Grande Valley': 'ул. Долинная',
}

src, out = sys.argv[1], sys.argv[2]
rows, miss = [], []
for line in open(src, encoding='utf-8'):
    m = re.match(r'\s*(0x[0-9A-Fa-f]+)\s*=\s*(.+?)\s*$', line)
    if not m:
        continue
    h, en = m.group(1), m.group(2)
    ru = RU.get(en)
    if not ru:
        miss.append(en); continue
    rows.append(f"    [{h.upper().replace('0X', '0x')}] = '{ru}', -- {en}")
if miss:
    sys.exit('нет перевода: ' + ', '.join(miss))
with open(out, 'w', encoding='utf-8', newline='\n') as f:
    f.write('-- русские названия улиц: хэш улицы GTA -> название (setup/maps/make_streets.py, не править руками)\n')
    f.write('Config.Streets = {\n' + '\n'.join(rows) + '\n}\n')
print('улиц', len(rows))
