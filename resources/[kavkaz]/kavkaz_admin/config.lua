Config = {}

-- уровни администрации (docs/vision/01-admin.md)
Config.Levels = {
    [1] = 'Хелпер',
    [2] = 'Модератор',
    [3] = 'Администратор',
    [4] = 'Старший администратор',
    [5] = 'Главный администратор',
    [6] = 'Основатель',
}
Config.MaxLevel = 6

-- основатели определяются ACE-правом (см. overrides/kavkaz.cfg):
--   add_ace group.admin kavkaz.founder allow
-- у кого это право есть — тот уровень 6, даже если его нет в базе.
Config.FounderAce = 'kavkaz.founder'

-- минимальный уровень для каждого действия. команда работает только на смене (/alogin).
Config.Perms = {
    -- игроки
    tpto = 1, bring = 1, spec = 1, reports = 1, adminchat = 1, admins = 1,
    kick = 2, mute = 2, ajail = 2, warn = 2, revive = 2, freeze = 2, check = 2,
    afix = 2, adv = 2, aflip = 2, heal = 2, feed = 2,
    skin = 3, armor = 3, ban = 3, noclip = 3, clicktp = 3, atpm = 3, tpc = 3, invis = 3, aveh = 3, disarm = 3,
    healall = 4, weather = 4, time = 4, sgu = 4, giveweapon = 4,
    unban = 4, giveitem = 4, givecar = 4, setjob = 4, setgang = 4, setleader = 4, announce = 4,
    givemoney = 5, setmoney = 5, setadmin = 5, banforever = 5, logs = 5,
    resetpin = 6,
}

-- лимиты наказаний по уровню (в минутах / днях)
Config.JailMaxMinutes = { [2] = 60, [3] = 180, [4] = 720, [5] = 100000, [6] = 100000 }
Config.BanMaxDays = { [3] = 7, [4] = 30, [5] = 0, [6] = 0 } -- 0 = можно навсегда
Config.MuteMaxMinutes = 1440

-- 3 активных предупреждения = бан на 3 дня
Config.WarnsToBan = 3
Config.WarnBanDays = 3

-- выдача денег больше этой суммы требует подтверждения второго админа 5+ (/aconfirm)
Config.MoneyConfirmLimit = 1000000

-- PIN: 6 цифр, 3 ошибки = блок на 15 минут
Config.PinLength = 6
Config.PinMaxFails = 3
Config.PinLockMinutes = 15

-- админ-тюрьма: двор тюрьмы Болингброк. выйти за радиус нельзя — вернёт обратно.
Config.Jail = {
    coords = vec4(1642.0, 2571.0, 45.56, 0.0),
    radius = 25.0,
    release = vec4(1847.0, 2586.0, 45.67, 270.0), -- у ворот тюрьмы
}

-- гараж, куда падает машина из /agivecar (имя гаража qbx_garages)
Config.GiveCarGarage = 'motelgarage'

-- клавиши (игрок может переназначить в настройках GTA → Привязка клавиш → FiveM)
Config.Keys = {
    panel = 'F10',
    noclip = 'F2',
    clicktp = 'F3', -- режим телепорта мышкой: курсор, клик ЛКМ — ТП. ALT занят ox_target.
}

-- noclip: скорости (SHIFT — быстрее, CTRL — медленнее)
Config.NoclipSpeed = { normal = 1.0, fast = 5.0, slow = 0.2 }

-- сколько последних записей лога показывать в панели
Config.LogsInPanel = 40
