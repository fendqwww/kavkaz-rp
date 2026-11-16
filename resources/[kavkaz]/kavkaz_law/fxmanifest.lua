fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_law'
description 'KAVKAZ RP: ДПС и ФСБ с NPC — посты, остановка NPC-машин, погони, задержания, режимы города, наряды'
author 'KAVKAZ RP'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/util.lua',
    'client/phrases.lua',
    'client/posts.lua',
    'client/stop.lua',
    'client/units.lua',
    'client/duty.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'ox_target',
    'oxmysql',
    'qbx_core',
}
