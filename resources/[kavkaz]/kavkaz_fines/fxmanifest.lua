fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_fines'
description 'KAVKAZ RP: штрафы — /fine для полиции и ДПС, /fines для игрока, удвоение через 3 дня, 10% инспектору'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
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
}
