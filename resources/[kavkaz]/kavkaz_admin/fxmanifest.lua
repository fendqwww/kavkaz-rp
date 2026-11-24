fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_admin'
description 'KAVKAZ RP: админка — уровни 1–6, смена по PIN (/alogin), команды, панель F10, репорты, наказания, логи'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/punish.lua',
    'server/commands.lua',
    'server/reports.lua',
}

client_scripts {
    'client/main.lua',
    'client/tools.lua',
    'client/panel.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'ox_inventory',
}
