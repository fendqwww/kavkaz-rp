-- проверка доступа к служебным входам (клиенту не доверяем)

local byId = {}
for _, e in ipairs(Config.Entrances) do byId[e.id] = e end

lib.callback.register('kavkaz_map:canEnter', function(src, id)
    local e = byId[id]
    if not e then return false, 'вход не найден' end
    if not e.jobs then return true end

    -- админ на смене проходит везде
    local ok, level = pcall(function() return exports.kavkaz_admin:GetDutyLevel(src) end)
    if ok and (level or 0) > 0 then return true end

    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job
    local min = job and e.jobs[job.name]
    if min == nil or (job.grade.level or 0) < min then return false, 'вход только для сотрудников' end

    -- стоять нужно у двери
    local pos = GetEntityCoords(GetPlayerPed(src))
    if #(pos - e.outside.xyz) > 5.0 and #(pos - e.inside.xyz) > 5.0 then return false, 'подойди к двери' end
    return true
end)
