-- KAVKAZ RP: 3D-пульт «Хазард 7007» на торпеде (модель: setup/models, файлы: stream/).
-- пульт видят все в радиусе Config.Dash.range у машин с СГУ (state bag sgu_model ставит сервер). объекты не сетевые.
-- от первого лица: наведи взгляд на ручку — колесо мыши крутит (мелодии / громкость), клик по кнопкам — кряк, ручной тон.
-- место на торпеде: по умолчанию от руля (кость steeringwheel), для своей машины — Config.Dash.cars или /sgupos.

local PARTS = { 'kv_hazard_knob_vol', 'kv_hazard_knob_sel', 'kv_hazard_btn_pa', 'kv_hazard_btn_horn', 'kv_hazard_led_l1', 'kv_hazard_led_l2' }
-- смещения деталей от центра корпуса (setup/models/export_hazard_blender.py -> offsets.json)
local OFF = {
    kv_hazard_knob_vol = vec3(-0.04875, -0.0309, 0.02063),
    kv_hazard_knob_sel = vec3(0.03075, -0.0324, 0.01856),
    kv_hazard_btn_pa = vec3(0.02475, -0.0254, -0.03661),
    kv_hazard_btn_horn = vec3(0.05325, -0.0254, -0.03661),
    kv_hazard_led_l1 = vec3(0.02475, -0.0237, -0.01392),
    kv_hazard_led_l2 = vec3(0.05325, -0.0237, -0.01392),
}
local HIT = { kv_hazard_knob_vol = 0.018, kv_hazard_knob_sel = 0.026, kv_hazard_btn_pa = 0.013, kv_hazard_btn_horn = 0.013 }

local dash = {} -- veh -> { body, parts = {name = obj}, pos, rot }
local custom = json.decode(GetResourceKvpString('dash_custom') or '{}') or {}

local function placement(veh)
    local mdl = GetEntityModel(veh)
    local name = Config.Dash.cars[mdl] and mdl or nil
    for k, v in pairs(Config.Dash.cars) do
        if type(k) == 'string' and joaat(k) == mdl then name = k; break end
    end
    local c = custom[tostring(mdl)]
    if c then return vec3(c[1], c[2], c[3]), vec3(c[4], c[5], c[6]) end
    if name then return Config.Dash.cars[name].offset, Config.Dash.cars[name].rot end
    local bone = GetEntityBoneIndexByName(veh, 'steeringwheel')
    local d = Config.Dash.default
    if bone ~= -1 then
        local w = GetOffsetFromEntityGivenWorldCoords(veh, GetWorldPositionOfEntityBone(veh, bone))
        return w + d.fromWheel, d.rot
    end
    return d.fallback, d.rot
end

local function spawnObj(name, at)
    local hash = joaat(name)
    if not IsModelInCdimage(hash) then return nil end
    lib.requestModel(hash, 5000)
    local o = CreateObjectNoOffset(hash, at.x, at.y, at.z, false, false, false)
    SetEntityCollision(o, false, false)
    SetEntityCanBeDamaged(o, false)
    SetModelAsNoLongerNeeded(hash)
    return o
end

local function attachPart(d, name, push, spin)
    local o = d.parts[name]
    if not o then return end
    local off = OFF[name] + vec3(0.0, push or 0.0, 0.0)
    AttachEntityToEntity(o, d.body, 0, off.x, off.y, off.z, 0.0, spin or 0.0, 0.0, false, false, false, false, 2, true)
end

local function create(veh)
    local pos, rot = placement(veh)
    local at = GetEntityCoords(veh)
    local body = spawnObj('kv_hazard7007', at)
    if not body then return end
    local d = { body = body, parts = {}, pos = pos, rot = rot, sel = -1, vol = -1, pressed = {} }
    AttachEntityToEntity(body, veh, 0, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, false, false, false, false, 2, true)
    for _, n in ipairs(PARTS) do
        d.parts[n] = spawnObj(n, at)
        attachPart(d, n)
    end
    dash[veh] = d
end

local function destroy(veh)
    local d = dash[veh]
    if not d then return end
    for _, o in pairs(d.parts) do if DoesEntityExist(o) then DeleteEntity(o) end end
    if DoesEntityExist(d.body) then DeleteEntity(d.body) end
    dash[veh] = nil
end

local function reattach(veh)
    destroy(veh)
    create(veh)
end

-- какие машины рядом с СГУ
CreateThread(function()
    while true do
        local me = GetEntityCoords(cache.ped)
        local seen = {}
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if Entity(veh).state.sgu_model and #(GetEntityCoords(veh) - me) < Config.Dash.range then
                seen[veh] = true
                if not dash[veh] then create(veh) end
            end
        end
        for veh in pairs(dash) do
            if not seen[veh] or not DoesEntityExist(veh) then destroy(veh) end
        end
        Wait(1000)
    end
end)

---------------------------------------------------------------------------
-- состояние: ручки, светодиоды, кнопки
---------------------------------------------------------------------------

-- угол ручки выбора: 0 — STANDBY, дальше мелодии по часовой (в градусах)
local function selAngle(pos) return Config.Dash.selStart + pos * Config.Dash.selStep end
local function volAngle(v) return -135.0 + v / 100.0 * 270.0 end

CreateThread(function()
    while true do
        local sleep = 500
        for veh, d in pairs(dash) do
            if DoesEntityExist(veh) and DoesEntityExist(d.body) then
                local st = Entity(veh).state
                local pos = 0
                if st.sgu_tone then
                    local m = Config.Models[st.sgu_model]
                    for i, t in ipairs(m and m.tones or {}) do if t == st.sgu_tone then pos = i end end
                end
                local myVeh, myModel, idx = SGU.get()
                if veh == myVeh and not st.sgu_tone then pos = 0 end
                if pos ~= d.sel then d.sel = pos; attachPart(d, 'kv_hazard_knob_sel', 0.0, selAngle(pos)) end
                local vol = veh == myVeh and exports.kavkaz_sgu:GetVolume() or 70
                if vol ~= d.vol then d.vol = vol; attachPart(d, 'kv_hazard_knob_vol', 0.0, volAngle(vol)) end
                local l1, l2 = st.sgu_tone and true or false, st.sgu_strobe and true or false
                if d.parts.kv_hazard_led_l1 then SetEntityVisible(d.parts.kv_hazard_led_l1, l1, false) end
                if d.parts.kv_hazard_led_l2 then SetEntityVisible(d.parts.kv_hazard_led_l2, l2, false) end
                d.l1, d.l2 = l1, l2
                local man = st.sgu_man and true or false
                if man ~= (d.pressed.kv_hazard_btn_pa or false) then
                    d.pressed.kv_hazard_btn_pa = man
                    attachPart(d, 'kv_hazard_btn_pa', man and 0.002 or 0.0)
                end
                if d.l1 or d.l2 then sleep = 0 end
            end
        end
        -- огоньки светодиодов
        if sleep == 0 then
            local t0 = GetGameTimer() + 400
            while GetGameTimer() < t0 do
                for _, d in pairs(dash) do
                    for key, on in pairs({ kv_hazard_led_l1 = d.l1, kv_hazard_led_l2 = d.l2 }) do
                        local o = d.parts[key]
                        if on and o then
                            local p = GetEntityCoords(o)
                            DrawLightWithRange(p.x, p.y, p.z, 255, 150, 30, 0.12, 2.0)
                        end
                    end
                end
                Wait(0)
            end
        else
            Wait(sleep)
        end
    end
end)

-- кнопку «нажать» на 150 мс (кряк)
local function press(veh, name)
    local d = dash[veh]
    if not d then return end
    attachPart(d, name, 0.002)
    SetTimeout(150, function() if dash[veh] == d then attachPart(d, name, 0.0) end end)
end
RegisterNetEvent('kavkaz_sgu:client:quack', function(net)
    local veh = NetToVeh(net)
    if dash[veh] then press(veh, 'kv_hazard_btn_horn') end
end)

---------------------------------------------------------------------------
-- мышь: от первого лица наводишь взгляд — колесо крутит, клик нажимает
---------------------------------------------------------------------------

local BLOCK = { 14, 15, 16, 17, 24, 25, 68, 69, 70, 81, 82, 91, 92, 99, 100, 241, 242, 257, 261, 262, 330, 331 }

local function camDir()
    local r = GetFinalRenderedCamRot(2)
    local x, z = math.rad(r.x), math.rad(r.z)
    return vec3(-math.sin(z) * math.cos(x), math.cos(z) * math.cos(x), math.sin(x))
end

local function aimed(d)
    local c, dir = GetFinalRenderedCamCoord(), camDir()
    local best, bestT
    for name, r in pairs(HIT) do
        local o = d.parts[name]
        if o then
            local v = GetEntityCoords(o) - c
            local t = v.x * dir.x + v.y * dir.y + v.z * dir.z
            if t > 0 and t < 1.5 and #(v - dir * t) < r and (not bestT or t < bestT) then best, bestT = name, t end
        end
    end
    return best
end

local HINT = {
    kv_hazard_knob_sel = 'колесо мыши — мелодия',
    kv_hazard_knob_vol = 'колесо мыши — громкость',
    kv_hazard_btn_pa = 'ЛКМ — ручной тон (держать)',
    kv_hazard_btn_horn = 'ЛКМ — кряк',
}

CreateThread(function()
    local hover, shown, manHeld
    while true do
        local sleep = 300
        local myVeh, myModel = SGU.get()
        local d = myVeh ~= 0 and dash[myVeh]
        local target
        if d and myModel and GetFollowVehicleCamViewMode() == 4 and not IsNuiFocused() and not IsPauseMenuActive() then
            sleep = 0
            target = aimed(d)
        end
        if target ~= hover then
            if hover and d and d.parts[hover] then SetEntityDrawOutline(d.parts[hover], false) end
            hover = target
            if hover then
                SetEntityDrawOutline(d.parts[hover], true)
                SetEntityDrawOutlineColor(255, 196, 60, 255)
                lib.showTextUI(HINT[hover], { position = 'right-center' })
                shown = true
            elseif shown then
                lib.hideTextUI()
                shown = false
            end
        end
        if hover then
            for _, c in ipairs(BLOCK) do DisableControlAction(0, c, true) end
            local up = IsDisabledControlJustPressed(0, 241) or IsDisabledControlJustPressed(0, 15)
            local down = IsDisabledControlJustPressed(0, 242) or IsDisabledControlJustPressed(0, 14)
            local step = up and 1 or (down and -1 or 0)
            if step ~= 0 and hover == 'kv_hazard_knob_sel' then
                SGU.turn(step)
            elseif step ~= 0 and hover == 'kv_hazard_knob_vol' then
                exports.kavkaz_sgu:SetVolume(exports.kavkaz_sgu:GetVolume() + step * 10)
            end
            if IsDisabledControlJustPressed(0, 24) then
                if hover == 'kv_hazard_btn_horn' then
                    SGU.quack()
                elseif hover == 'kv_hazard_btn_pa' then
                    if not SGU.manual(true) then SGU.quack() else manHeld = true end
                end
            end
        end
        if manHeld and not IsDisabledControlPressed(0, 24) then
            manHeld = false
            SGU.manual(false)
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- /sgupos — подобрать место пульта в своей машине (стрелки, PgUp/PgDn, Shift — поворот, Enter — сохранить)
---------------------------------------------------------------------------

RegisterCommand('sgupos', function()
    local veh = cache.vehicle
    if not veh or not dash[veh] then return lib.notify({ title = 'СГУ', description = 'сядь в машину с СГУ', type = 'error' }) end
    local d = dash[veh]
    local pos, rot = d.pos, d.rot
    lib.showTextUI('стрелки, PgUp/PgDn — сдвиг · Shift + стрелки — наклон/поворот · Enter — сохранить · Backspace — выход')
    CreateThread(function()
        while true do
            for _, c in ipairs({ 10, 11, 172, 173, 174, 175, 21, 191, 194, 71, 72, 59, 60, 61, 62, 63, 64 }) do DisableControlAction(0, c, true) end
            local shift = IsDisabledControlPressed(0, 21)
            local s = 0.002
            local moved = false
            local function k(c) return IsDisabledControlPressed(0, c) end
            if shift then
                if k(172) then rot = rot + vec3(0.5, 0, 0) moved = true end
                if k(173) then rot = rot - vec3(0.5, 0, 0) moved = true end
                if k(174) then rot = rot + vec3(0, 0, 0.5) moved = true end
                if k(175) then rot = rot - vec3(0, 0, 0.5) moved = true end
            else
                if k(172) then pos = pos + vec3(0, s, 0) moved = true end
                if k(173) then pos = pos - vec3(0, s, 0) moved = true end
                if k(174) then pos = pos - vec3(s, 0, 0) moved = true end
                if k(175) then pos = pos + vec3(s, 0, 0) moved = true end
                if k(10) then pos = pos + vec3(0, 0, s) moved = true end
                if k(11) then pos = pos - vec3(0, 0, s) moved = true end
            end
            if moved then
                d.pos, d.rot = pos, rot
                AttachEntityToEntity(d.body, veh, 0, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, false, false, false, false, 2, true)
            end
            if IsDisabledControlJustPressed(0, 191) then
                local mdl = GetEntityModel(veh)
                custom[tostring(mdl)] = { pos.x, pos.y, pos.z, rot.x, rot.y, rot.z }
                SetResourceKvp('dash_custom', json.encode(custom))
                local line = ("['%s'] = { offset = vec3(%.3f, %.3f, %.3f), rot = vec3(%.1f, %.1f, %.1f) },")
                    :format(GetDisplayNameFromVehicleModel(mdl):lower(), pos.x, pos.y, pos.z, rot.x, rot.y, rot.z)
                lib.setClipboard(line)
                lib.notify({ title = 'СГУ', description = 'место сохранено, строка для config.lua скопирована', type = 'success' })
                break
            end
            if IsDisabledControlJustPressed(0, 194) then break end
            Wait(0)
        end
        lib.hideTextUI()
    end)
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for veh in pairs(dash) do destroy(veh) end
end)
