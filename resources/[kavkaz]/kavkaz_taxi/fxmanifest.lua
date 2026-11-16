fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_taxi'
description 'KAVKAZ RP: работа таксиста — NPC голосуют у тротуара, вызовы диспетчера, счётчик, характеры пассажиров, чаевые, рейтинг'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua',
    'phrases.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

client_script 'client.lua'

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'ox_target',
    'qbx_vehiclekeys',
}
