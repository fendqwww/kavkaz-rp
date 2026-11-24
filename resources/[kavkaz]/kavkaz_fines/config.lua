Config = {}

-- кто выписывает штрафы: работа = минимальный ранг (на смене)
Config.Jobs = { police = 0, sheriff = 0, sasp = 0 } -- sasp = ГИБДД / полк ДПС
Config.Distance = 6.0
Config.OfficerShare = 0.10  -- доля инспектору после оплаты
Config.DoubleAfterDays = 3  -- неоплаченный штраф удваивается (один раз)

-- статьи (docs/vision/04-cars.md, 07-mechanics.md). max — потолок суммы, инспектор может выписать меньше
Config.Articles = {
    { id = 'speed',   label = 'Превышение скорости',                 amount = 1500,   max = 5000 },
    { id = 'redlight',label = 'Проезд на красный',                   amount = 1000,   max = 1000 },
    { id = 'tint3',   label = 'Тонировка 25% по кругу',              amount = 500,    max = 500 },
    { id = 'tint4',   label = 'Тонировка «в ноль»',                  amount = 1500,   max = 1500 },
    { id = 'dirty',   label = 'Грязный или закрытый номер, плёнка',  amount = 5000,   max = 5000 },
    { id = 'noplate', label = 'Езда без номера (транзит истёк)',     amount = 5000,   max = 5000 },
    { id = 'fake',    label = 'Подложный номер',                     amount = 100000, max = 100000 },
    { id = 'sgu',     label = 'СГУ без разрешения',                  amount = 5000,   max = 30000 },
    { id = 'nolic',   label = 'Езда без прав',                       amount = 10000,  max = 10000 },
    { id = 'parking', label = 'Неправильная парковка',               amount = 500,    max = 2000 },
    { id = 'cortege', label = 'Кортеж без разрешения МВД',           amount = 10000,  max = 30000 },
    { id = 'other',   label = 'Другое (указать в описании)',         amount = 1000,   max = 50000 },
}
