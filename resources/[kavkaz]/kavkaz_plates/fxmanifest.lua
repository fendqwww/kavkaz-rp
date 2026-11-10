fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_plates'
description 'KAVKAZ RP: номера А 777 АА 95 — МРЭО, выдача ДПС, перевес, карман, продажа игроку, пробивка по базе'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/format.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_script 'client/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/plate.js',
    'html/fonts/*.woff2',
    'html/fonts/fonts.css',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'ox_target',
}
