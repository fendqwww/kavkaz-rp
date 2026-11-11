-- вход на смену, уведомления, тюрьма, заморозка, объявления, карточка игрока, оценка репорта.

function MyLevel()
    return LocalPlayer.state.kavkazAdmin or 0
end

function Can(perm)
    return MyLevel() >= (Config.Perms[perm] or Config.MaxLevel)
end

-- спросить сервер: можно ли (он проверит смену и уровень и запишет лог)
function Allowed(action, details)
    return lib.callback.await('kavkaz_admin:allowed', false, action, details)
end

---------------------------------------------------------------------------
-- /alogin, /apin
---------------------------------------------------------------------------

RegisterCommand('alogin', function()
    local status = lib.callback.await('kavkaz_admin:pinStatus', false)
    if not status or status.error then
        return lib.notify({ description = status and status.error or 'ошибка', type = 'error' })
    end

    local pin, repeatPin
    if status.hasPin then
        local input = lib.inputDialog(('Вход на смену — %s'):format(status.levelName), {
            { type = 'input', label = 'PIN', description = ('%d цифр'):format(Config.PinLength), password = true, required = true },
        })
        if not input then return end
        pin = input[1]
    else
        local input = lib.inputDialog('Придумай личный PIN', {
            { type = 'input', label = 'новый PIN', description = ('ровно %d цифр, никому не говори'):format(Config.PinLength), password = true, required = true },
            { type = 'input', label = 'повтори PIN', password = true, required = true },
        })
        if not input then return end
        pin, repeatPin = input[1], input[2]
    end

    local ok, err = lib.callback.await('kavkaz_admin:login', false, pin, repeatPin)
    if ok then
        lib.notify({ title = 'KAVKAZ админка', description = ('ты на смене: %s. панель — %s'):format(status.levelName, Config.Keys.panel), type = 'success' })
    else
        lib.notify({ description = err or 'не получилось', type = 'error' })
    end
end, false)

RegisterCommand('apin', function()
    local input = lib.inputDialog('Смена PIN', {
        { type = 'input', label = 'старый PIN', password = true, required = true },
        { type = 'input', label = 'новый PIN', description = ('%d цифр'):format(Config.PinLength), password = true, required = true },
        { type = 'input', label = 'повтори новый', password = true, required = true },
    })
    if not input then return end
    if input[2] ~= input[3] then return lib.notify({ description = 'новые PIN не совпадают', type = 'error' }) end
    local ok, err = lib.callback.await('kavkaz_admin:changePin', false, input[1], input[2])
    lib.notify({ description = ok and 'PIN изменён' or err, type = ok and 'success' or 'error' })
end, false)

-- подсказки в чате для всех команд — в kavkaz_help/config.lua (один список на весь сервер)

-- уровень, нужный для действия: kavkaz_help берёт его отсюда, чтобы не дублировать Config.Perms
exports('PermLevel', function(perm) return Config.Perms[perm] or Config.MaxLevel end)

---------------------------------------------------------------------------
-- объявления, репорты, карточка
---------------------------------------------------------------------------

RegisterNetEvent('kavkaz_admin:client:announce', function(text)
    PlaySoundFrontend(-1, 'CHALLENGE_UNLOCKED', 'HUD_AWARDS', true)
    lib.notify({ id = 'kavkaz_announce', title = 'ОБЪЯВЛЕНИЕ АДМИНИСТРАЦИИ', description = text, type = 'warning', position = 'top', duration = 15000 })
    TriggerEvent('chat:addMessage', { color = { 255, 200, 60 }, multiline = true, args = { 'ОБЪЯВЛЕНИЕ', text } })
end)

RegisterNetEvent('kavkaz_admin:client:newReport', function(id, from, text)
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
    lib.notify({ title = ('Репорт №%d — %s'):format(id, from), description = text .. '\n\n' .. Config.Keys.panel .. ' → Репорты', type = 'inform', duration = 10000 })
end)

RegisterNetEvent('kavkaz_admin:client:rateReport', function(id, adminName)
    Wait(1500)
    local input = lib.inputDialog(('Репорт №%d закрыт (%s)'):format(id, adminName), {
        { type = 'select', label = 'Оцени помощь администратора', required = true, default = '5', options = {
            { value = '5', label = '5 — отлично' }, { value = '4', label = '4 — хорошо' }, { value = '3', label = '3 — нормально' },
            { value = '2', label = '2 — плохо' }, { value = '1', label = '1 — ужасно' },
        } },
    })
    if input then TriggerServerEvent('kavkaz_admin:server:rate', id, tonumber(input[1])) end
end)

local function money(v) return lib.math.groupdigits(v or 0, ' ') .. ' ₽' end

function ShowCard(c)
    if not c then return end
    local lines = {
        ('**%s** · ID %d · пинг %d'):format(c.name, c.id, c.ping),
        c.char and ('Персонаж: **%s** (`%s`)'):format(c.char, c.citizenid) or 'Персонаж не выбран',
    }
    if c.char then
        lines[#lines + 1] = ('Наличные: %s · Банк: %s'):format(money(c.cash), money(c.bank))
        lines[#lines + 1] = ('Работа: %s · Банда: %s'):format(c.job, c.gang)
        lines[#lines + 1] = ('Машин: %d'):format(c.vehicles or 0)
    end
    lines[#lines + 1] = ('Предупреждений: **%d/%d** · банов за всё время: %d'):format(c.warns, Config.WarnsToBan, c.bans)
    if c.jailed then lines[#lines + 1] = '⚠ сейчас в админ-тюрьме' end
    if c.muted then lines[#lines + 1] = '⚠ сейчас в муте' end
    if c.level > 0 then lines[#lines + 1] = ('Админ: %s%s'):format(Config.Levels[c.level], c.onDuty and ' (на смене)' or '') end
    if #c.sameIp > 0 then lines[#lines + 1] = ('⚠ тот же IP: %s'):format(table.concat(c.sameIp, ', ')) end
    lines[#lines + 1] = ('`%s`'):format(c.ids.license or '-')
    if c.ids.discord then lines[#lines + 1] = ('`%s`'):format(c.ids.discord) end
    lib.alertDialog({ header = 'Карточка игрока', content = table.concat(lines, '  \n'), centered = true, size = 'lg' })
end
RegisterNetEvent('kavkaz_admin:client:card', ShowCard)

---------------------------------------------------------------------------
-- заморозка и админ-тюрьма
---------------------------------------------------------------------------

local frozen = false
RegisterNetEvent('kavkaz_admin:client:freeze', function(state)
    frozen = state
    FreezeEntityPosition(cache.ped, state)
    if not state then return end
    CreateThread(function()
        while frozen do
            DisableAllControlActions(0)
            EnableControlAction(0, 245, true) -- чат
            EnableControlAction(0, 249, true) -- голос
            EnableControlAction(0, 1, true) EnableControlAction(0, 2, true) -- камера
            Wait(0)
        end
    end)
end)

local jailLeft = 0
RegisterNetEvent('kavkaz_admin:client:jail', function(seconds)
    local first = jailLeft <= 0
    jailLeft = seconds
    local c = Config.Jail.coords
    DoScreenFadeOut(300) Wait(400)
    SetEntityCoords(cache.ped, c.x, c.y, c.z, false, false, false, false)
    SetEntityHeading(cache.ped, c.w)
    DoScreenFadeIn(500)
    if not first then return end
    CreateThread(function()
        local lastSecond = GetGameTimer()
        while jailLeft > 0 do
            if GetGameTimer() - lastSecond >= 1000 then
                lastSecond = GetGameTimer()
                jailLeft = jailLeft - 1
                lib.showTextUI(('Админ-тюрьма: %02d:%02d'):format(jailLeft // 60, jailLeft % 60), { position = 'top-center', icon = 'lock' })
                if #(GetEntityCoords(cache.ped) - c.xyz) > Config.Jail.radius then
                    SetEntityCoords(cache.ped, c.x, c.y, c.z, false, false, false, false)
                end
            end
            DisablePlayerFiring(cache.playerId, true)
            DisableControlAction(0, 140, true) DisableControlAction(0, 141, true) DisableControlAction(0, 142, true)
            DisableControlAction(0, 23, true) -- сесть в машину
            Wait(0)
        end
        lib.hideTextUI()
    end)
end)

RegisterNetEvent('kavkaz_admin:client:unjail', function()
    jailLeft = 0
end)

-- /aheal: здоровье до максимума и смыть кровь (qbx_medical лечит раны, а полоску здоровья ставим здесь)
RegisterNetEvent('kavkaz_admin:client:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
end)

-- /aveh: скачать модель до спавна (сервер ждёт машину всего несколько секунд, а модель 10–20 МБ качается до минуты)
lib.callback.register('kavkaz_admin:preloadModel', function(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return false end
    local deadline = GetGameTimer() + 120000
    RequestModel(hash)
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do
        Wait(250)
        RequestModel(hash)
    end
    return HasModelLoaded(hash)
end)
