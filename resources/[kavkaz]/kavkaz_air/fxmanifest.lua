fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_air'
description 'KAVKAZ RP: пневмоподвеска — ставится в гараже Бислана, кнопками машина опускается и поднимается, видят все'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}
client_script 'client.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}
