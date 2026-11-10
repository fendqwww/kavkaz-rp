-- KAVKAZ RP: единый список команд. отсюда берутся подсказки в чате («/»), окно /help и вкладка «Команды» в F10.
-- новая команда = одна строка C{ ... }. поля:
--   tab   — вкладка: general, chats, work, plates, admin
--   cmd   — имя команды без «/»  (или key = 'F10' — клавиша, в чат-подсказки не идёт)
--   p     — параметры: { 'имя', 'подсказка' }; необязательный — в квадратных скобках: { '[ID]', '…' }
--   ex    — пример, desc — одна строка пояснения
--   кто видит (если ничего не указано — все игроки):
--     perm  = ключ Config.Perms из kavkaz_admin (уровень берётся оттуда), видно только на смене с этим уровнем
--     level = число — то же, но уровень задан здесь (для ресурсов вне kavkaz_admin)
--     rank  = true — видно любому админу, даже не на смене (/alogin, /apin)
--     ace   = 'command.x' — видно, если есть ACE-право (основатели)
--   side  = 'client' — команда объявлена на клиенте (для проверки, что она существует)
--   src   = 'qbox' — команда из Qbox, не из наших ресурсов

Config = {}

Config.Tabs = {
    { id = 'general', label = 'Общие' },
    { id = 'chats',   label = 'Чаты' },
    { id = 'work',    label = 'Работа и штрафы' },
    { id = 'plates',  label = 'Номера' },
    { id = 'admin',   label = 'Админ' }, -- вкладка видна только на админ-смене
}

Config.Commands = {}
local function C(t) Config.Commands[#Config.Commands + 1] = t end

-- общие
C{ tab = 'general', cmd = 'help', alias = 'команды', side = 'client', ex = '/help', desc = 'это окно: все команды сервера' }
C{ tab = 'general', cmd = 'gaid', side = 'client', ex = '/gaid', desc = 'памятка новичка: с чего начать и какие кнопки' }
C{ tab = 'general', cmd = 'id', src = 'qbox', ex = '/id', desc = 'узнать свой ID' }
C{ tab = 'general', cmd = 'report', p = { { 'текст', 'что случилось' } }, ex = '/report застрял в стене у мэрии', desc = 'написать администрации, не чаще раза в минуту' }
C{ tab = 'general', cmd = 'pay', p = { { 'ID', 'кому' }, { 'сумма', 'в рублях' } }, ex = '/pay 12 5000', desc = 'передать наличные игроку рядом (до 3 м)' }
C{ tab = 'general', key = 'F4', cmd = 'menu', side = 'client', ex = '/menu', desc = 'меню игрока: профиль, статистика, безопасность, промокод, настройки, помощь' }
C{ tab = 'general', key = 'F5', cmd = 'gps', side = 'client', ex = '/gps', desc = 'навигатор: с чего начать, работа, госучреждения, ближайший магазин или заправка — ставит метку на карте' }
C{ tab = 'general', cmd = 'hud', side = 'client', ex = '/hud', desc = 'спрятать или показать интерфейс (для скриншотов)' }
C{ tab = 'general', key = 'G', title = 'СГУ: кряк', ex = 'G в машине', desc = 'если стоит СГУ «Хазард 7007» или служебное. J — мелодия вкл/выкл, U — сменить мелодию, O — стробоскоп (Про)' }

-- чаты
C{ tab = 'chats', key = 'T', title = 'обычный текст', ex = 'Салам, брат', desc = 'речь персонажа, слышно рядом (15 м)' }
C{ tab = 'chats', cmd = 'me', src = 'qbox', p = { { 'текст', 'действие' } }, ex = '/me достал паспорт', desc = 'действие персонажа' }
C{ tab = 'chats', cmd = 'do', p = { { 'текст', 'обстановка' } }, ex = '/do Паспорт в руке.', desc = 'описание обстановки или результата' }
C{ tab = 'chats', cmd = 'try', p = { { 'текст', 'что пытаешься' } }, ex = '/try открыть дверь', desc = 'попытка: «удачно» или «неудачно», 50 на 50' }
C{ tab = 'chats', cmd = 'todo', p = { { 'фраза*действие', '' } }, ex = '/todo Салам*пожимая руку', desc = 'фраза с действием: «Салам», — сказал Ахмед, пожимая руку' }
C{ tab = 'chats', cmd = 's', p = { { 'текст', 'что кричишь' } }, ex = '/s Стой, полиция!', desc = 'крик, слышно на 40 м' }
C{ tab = 'chats', cmd = 'w', p = { { 'ID', 'кому' }, { 'текст', '' } }, ex = '/w 12 тише, сзади ДПС', desc = 'шёпот вплотную, слышит один игрок' }
C{ tab = 'chats', cmd = 'b', p = { { 'текст', '' } }, ex = '/b у меня лагает', desc = 'нон-РП рядом (вне роли)' }
C{ tab = 'chats', cmd = 'pm', p = { { 'ID', 'кому' }, { 'текст', '' } }, ex = '/pm 12 давай в дискорд', desc = 'личное нон-РП сообщение' }
C{ tab = 'chats', cmd = 'ooc', src = 'qbox', p = { { 'текст', '' } }, ex = '/ooc всем привет', desc = 'общий нон-РП чат' }
C{ tab = 'chats', cmd = 'r', p = { { 'текст', '' } }, ex = '/r 10-4, выезжаю', desc = 'рация своей организации (госструктуры — только на смене)' }
C{ tab = 'chats', cmd = 'rn', p = { { 'текст', '' } }, ex = '/rn через 5 минут рестарт?', desc = 'рация организации, нон-РП' }
C{ tab = 'chats', cmd = 'd', p = { { 'текст', '' } }, ex = '/d МВД — больнице: нужна скорая', desc = 'департамент: МВД, ФСБ, больница, МЧС на смене' }
C{ tab = 'chats', cmd = 'f', p = { { 'текст', '' } }, ex = '/f сбор у гаража', desc = 'чат семьи или банды' }
C{ tab = 'chats', cmd = 'fn', p = { { 'текст', '' } }, ex = '/fn кто онлайн?', desc = 'чат семьи или банды, нон-РП' }
C{ tab = 'chats', cmd = 'gov', p = { { 'текст', '' } }, ex = '/gov Открыт набор в МВД', desc = 'госновости на весь сервер (лидеры госструктур)' }

-- работа и штрафы
C{ tab = 'work', cmd = 'fines', side = 'client', ex = '/fines', desc = 'мои неоплаченные штрафы, оплата с карты' }
C{ tab = 'work', cmd = 'fine', side = 'client', p = { { '[ID]', 'нарушитель, пусто — ближайший' }, { '[статья]', 'tint4, fake… — подставляет пробивка номера' } }, ex = '/fine 12', desc = 'полиция и ДПС на смене: выписать штраф (до 6 м)' }
C{ tab = 'work', cmd = 'checkplate', side = 'client', ex = '/checkplate', desc = 'полиция и ДПС: пробить номер ближайшей машины' }

-- номера
C{ tab = 'plates', key = 'ALT', title = 'окно МРЭО', ex = 'ALT на сотрудника МРЭО', desc = 'получить или сменить номер (по паспорту)' }
C{ tab = 'plates', cmd = 'issueplate', p = { { 'ID', 'водитель за рулём' } }, ex = '/issueplate 12', desc = 'ДПС на смене: поставить машину водителя на учёт' }
C{ tab = 'plates', cmd = 'setplate', level = 4, p = { { 'ID', 'игрок' }, { 'вид', 'ru, ru_taxi, ru_police, ru_army, kz, by, am, ge, az' }, { 'номер', 'например К 013 РА 95' } }, ex = '/setplate 12 ru К 013 РА 95', desc = 'выдать номер игроку в карман (повесить — в МРЭО)' }
C{ tab = 'plates', cmd = 'setframe', level = 4, p = { { 'номер', 'без пробелов' }, { '[текст]', 'пусто — снять' } }, ex = '/setframe К013РА95 ФСО РОССИИ', desc = 'своя надпись на рамке номера' }

-- админ: вход
C{ tab = 'admin', key = 'F10', perm = 'tpto', title = 'админ-панель', ex = 'F10', desc = 'игроки, репорты, инструменты, команды' }
C{ tab = 'admin', cmd = 'alogin', rank = true, side = 'client', ex = '/alogin', desc = 'заступить на смену по PIN (первый раз — придумать PIN)' }
C{ tab = 'admin', cmd = 'alogout', rank = true, ex = '/alogout', desc = 'сдать смену' }
C{ tab = 'admin', cmd = 'apin', rank = true, side = 'client', ex = '/apin', desc = 'сменить PIN' }
C{ tab = 'admin', cmd = 'apanel', perm = 'tpto', side = 'client', ex = '/apanel', desc = 'админ-панель (то же, что F10)' }
-- уровень 1
C{ tab = 'admin', cmd = 'goto', perm = 'tpto', p = { { 'ID', 'к кому' } }, ex = '/goto 12', desc = 'телепорт к игроку' }
C{ tab = 'admin', cmd = 'bring', perm = 'bring', p = { { 'ID', 'кого' } }, ex = '/bring 12', desc = 'телепорт игрока к себе' }
C{ tab = 'admin', cmd = 'spec', perm = 'spec', p = { { '[ID]', 'за кем' } }, ex = '/spec 12', desc = 'наблюдать за игроком; повторно или BACKSPACE — выйти' }
C{ tab = 'admin', cmd = 'a', perm = 'adminchat', p = { { 'текст', '' } }, ex = '/a беру репорт №3', desc = 'админ-чат' }
C{ tab = 'admin', cmd = 'admins', perm = 'admins', ex = '/admins', desc = 'кто из админов на смене' }
C{ tab = 'admin', cmd = 'mypos', perm = 'tpto', side = 'client', ex = '/mypos', desc = 'скопировать свои координаты (для настройки карты)' }
-- уровень 2
C{ tab = 'admin', cmd = 'kick', perm = 'kick', p = { { 'ID', '' }, { 'причина', '' } }, ex = '/kick 12 оскорбления', desc = 'кикнуть игрока' }
C{ tab = 'admin', cmd = 'mute', perm = 'mute', p = { { 'ID', '' }, { 'минуты', '' }, { 'причина', '' } }, ex = '/mute 12 30 флуд', desc = 'мут чата и голоса' }
C{ tab = 'admin', cmd = 'unmute', perm = 'mute', p = { { 'ID', '' } }, ex = '/unmute 12', desc = 'снять мут' }
C{ tab = 'admin', cmd = 'ajail', perm = 'ajail', p = { { 'ID', '' }, { 'минуты', '' }, { 'причина', '' } }, ex = '/ajail 12 15 ДМ', desc = 'админ-тюрьма' }
C{ tab = 'admin', cmd = 'unjail', perm = 'ajail', p = { { 'ID', '' } }, ex = '/unjail 12', desc = 'выпустить из админ-тюрьмы' }
C{ tab = 'admin', cmd = 'warn', perm = 'warn', p = { { 'ID', '' }, { 'причина', '' } }, ex = '/warn 12 нон-РП', desc = 'предупреждение; три — бан на 3 дня' }
C{ tab = 'admin', cmd = 'arevive', perm = 'revive', p = { { '[ID]', 'пусто — себя' } }, ex = '/arevive 12', desc = 'поднять и вылечить' }
C{ tab = 'admin', cmd = 'apromo', perm = 'givemoney', p = { { 'код', 'латиница и цифры' }, { 'тип', 'cash, bank, item:название, car:kv_модель' }, { 'сумма', 'или количество' }, { '[раз]', 'сколько активаций, по умолчанию 1' } }, ex = '/apromo START cash 50000 100', desc = 'создать промокод (игроки вводят в F4 → Промокод)' }
C{ tab = 'admin', cmd = 'aweapon', perm = 'giveweapon', p = { { 'ID', 'кому (свой ID — себе)' }, { 'оружие', 'пистолет, автомат, карабин, дробовик, снайперка, нож, бита, шокер …' }, { '[патроны]', 'по умолчанию 60' } }, ex = '/aweapon 12 пистолет 60', desc = 'выдать оружие с патронами (то же — F10 → игрок)' }
C{ tab = 'admin', cmd = 'aheal', perm = 'heal', p = { { '[ID]', 'пусто — себя' } }, ex = '/aheal 12', desc = 'вылечить: здоровье 100% (без поднятия)' }
C{ tab = 'admin', cmd = 'afeed', perm = 'feed', p = { { '[ID]', 'пусто — себя' } }, ex = '/afeed 12', desc = 'накормить и напоить: еда и вода 100%, стресс 0' }
C{ tab = 'admin', cmd = 'aarmor', perm = 'armor', p = { { '[ID]', 'пусто — себя' }, { '[броня]', '0–100, по умолчанию 100' } }, ex = '/aarmor 12 50', desc = 'выдать броню' }
C{ tab = 'admin', cmd = 'ahealall', perm = 'healall', ex = '/ahealall', desc = 'поднять, вылечить и накормить всех на сервере (мероприятия)' }
C{ tab = 'admin', cmd = 'aweather', perm = 'weather', p = { { 'погода', 'солнце, ясно, облачно, пасмурно, дождь, гроза, туман, снег, метель, зима' }, { '[минут]', 'по умолчанию 60' } }, ex = '/aweather дождь 30', desc = 'сменить погоду в республике' }
C{ tab = 'admin', cmd = 'atime', perm = 'time', p = { { 'час', '0–23' }, { '[минуты]', '' } }, ex = '/atime 21', desc = 'поставить время суток' }
C{ tab = 'admin', cmd = 'freeze', perm = 'freeze', p = { { 'ID', '' } }, ex = '/freeze 12', desc = 'заморозить или разморозить игрока' }
C{ tab = 'admin', cmd = 'check', perm = 'check', p = { { 'ID', '' } }, ex = '/check 12', desc = 'карточка игрока: деньги, работа, наказания' }
C{ tab = 'admin', cmd = 'afix', perm = 'afix', side = 'client', ex = '/afix', desc = 'починить и заправить машину' }
C{ tab = 'admin', cmd = 'aflip', perm = 'aflip', side = 'client', ex = '/aflip', desc = 'перевернуть машину' }
C{ tab = 'admin', cmd = 'adv', perm = 'adv', p = { { '[радиус]', 'метров, до 100' } }, ex = '/adv 20', desc = 'удалить свою машину или пустые в радиусе' }
-- уровень 3
C{ tab = 'admin', cmd = 'ban', perm = 'ban', p = { { 'ID', '' }, { 'дни', '0 — навсегда (с 5 ур.)' }, { 'причина', '' } }, ex = '/ban 12 3 читы', desc = 'бан: 3 ур. до 7 дней, 4 ур. до 30' }
C{ tab = 'admin', key = 'F2', cmd = 'noclip', perm = 'noclip', side = 'client', ex = '/noclip', desc = 'полёт: WASD, Q/E вверх-вниз, SHIFT быстрее' }
C{ tab = 'admin', key = 'F3', cmd = 'clicktp', perm = 'clicktp', side = 'client', ex = '/clicktp', desc = 'телепорт мышкой: ЛКМ — перенестись, ПКМ — выйти' }
C{ tab = 'admin', cmd = 'invis', perm = 'invis', side = 'client', ex = '/invis', desc = 'невидимость вкл/выкл' }
C{ tab = 'admin', cmd = 'atpm', perm = 'atpm', side = 'client', ex = '/atpm', desc = 'телепорт на метку на карте' }
C{ tab = 'admin', cmd = 'tpc', perm = 'tpc', side = 'client', p = { { 'x', '' }, { 'y', '' }, { 'z', '' } }, ex = '/tpc 215.7 -810.1 30.7', desc = 'телепорт по координатам' }
C{ tab = 'admin', cmd = 'aveh', perm = 'aveh', p = { { 'модель', 'kv_camry80 (автопарк) или модель GTA' } }, ex = '/aveh kv_g63', desc = 'заспавнить машину' }
C{ tab = 'admin', cmd = 'disarm', perm = 'disarm', p = { { 'ID', '' }, { 'причина', '' } }, ex = '/disarm 12 оружие в мэрии', desc = 'забрать всё оружие' }
-- уровень 4
C{ tab = 'admin', cmd = 'unban', perm = 'unban', p = { { 'номер или ник', '' } }, ex = '/unban 17', desc = 'разбанить по номеру бана или нику' }
C{ tab = 'admin', cmd = 'agiveitem', perm = 'giveitem', p = { { 'ID', '' }, { 'предмет', 'например water' }, { 'число', '' }, { 'причина', '' } }, ex = '/agiveitem 12 water 2 компенсация', desc = 'выдать предмет' }
C{ tab = 'admin', cmd = 'agivecar', perm = 'givecar', p = { { 'ID', '' }, { 'модель', '' }, { 'причина', '' } }, ex = '/agivecar 12 kv_priora компенсация', desc = 'выдать машину в гараж (номер — транзит от kavkaz_plates)' }
C{ tab = 'admin', cmd = 'kavkaz_cars', ace = 'command.kavkaz_cars', ex = 'kavkaz_cars', desc = 'консоль сервера: автопарк — какие машины настоящие, какие на заглушках, вес' }
C{ tab = 'admin', cmd = 'kavkaz_cars_migrate', ace = 'command.kavkaz_cars_migrate', p = { { '[apply]', 'без apply — только показать' } }, ex = 'kavkaz_cars_migrate apply', desc = 'консоль: перевести купленные машины с заглушки на настоящую модель' }
C{ tab = 'admin', cmd = 'asgu', perm = 'sgu', p = { { 'ID', 'игрок за рулём своей машины' }, { 'модель', 'mini, std, pro или off' } }, ex = '/asgu 12 pro', desc = 'поставить или снять СГУ «Хазард 7007» (то же — F10 → игрок → СГУ)' }
C{ tab = 'admin', cmd = 'asetjob', perm = 'setjob', p = { { 'ID', '' }, { 'работа', 'например police' }, { 'ранг', '' }, { 'причина', '' } }, ex = '/asetjob 12 police 0 набор', desc = 'назначить работу и ранг' }
C{ tab = 'admin', cmd = 'asetgang', perm = 'setgang', p = { { 'ID', '' }, { 'банда', '' }, { 'ранг', '' }, { 'причина', '' } }, ex = '/asetgang 12 ballas 0 заявка', desc = 'назначить банду и ранг' }
C{ tab = 'admin', cmd = 'setleader', perm = 'setleader', p = { { 'ID', '' }, { 'организация', 'работа или банда' }, { 'причина', '' } }, ex = '/setleader 12 police выборы', desc = 'назначить лидера организации' }
C{ tab = 'admin', cmd = 'announce', perm = 'announce', p = { { 'текст', '' } }, ex = '/announce рестарт через 10 минут', desc = 'объявление на весь сервер' }
-- уровень 5
C{ tab = 'admin', cmd = 'agivemoney', perm = 'givemoney', p = { { 'ID', '' }, { 'счёт', 'cash или bank' }, { 'сумма', '₽' }, { 'причина', '' } }, ex = '/agivemoney 12 bank 50000 компенсация', desc = 'выдать рубли; больше 1 000 000 ₽ — нужен /aconfirm второго админа' }
C{ tab = 'admin', cmd = 'asetmoney', perm = 'setmoney', p = { { 'ID', '' }, { 'счёт', 'cash или bank' }, { 'сумма', '₽' }, { 'причина', '' } }, ex = '/asetmoney 12 cash 0 багоюз', desc = 'установить точную сумму' }
C{ tab = 'admin', cmd = 'aconfirm', perm = 'givemoney', p = { { 'номер', 'номер заявки' } }, ex = '/aconfirm 4', desc = 'подтвердить крупную выдачу денег другого админа' }
C{ tab = 'admin', cmd = 'setadmin', perm = 'setadmin', p = { { 'ID', '' }, { 'уровень', '0 — снять, 1–6' } }, ex = '/setadmin 12 2', desc = 'назначить или снять админа' }
-- уровень 6 и основатели
C{ tab = 'admin', cmd = 'aresetpin', perm = 'resetpin', p = { { 'ID', '' } }, ex = '/aresetpin 12', desc = 'сбросить PIN админу' }
C{ tab = 'admin', cmd = 'rename', ace = 'command.rename', p = { { 'Имя', '' }, { 'Фамилия', '' } }, ex = '/rename Ахмед Исаев', desc = 'сменить имя своему персонажу (основатели)' }
C{ tab = 'admin', cmd = 'setname', ace = 'command.setname', p = { { 'ID', '' }, { 'Имя', '' }, { 'Фамилия', '' } }, ex = '/setname 12 Ахмед Исаев', desc = 'сменить имя персонажу игрока (основатели)' }
