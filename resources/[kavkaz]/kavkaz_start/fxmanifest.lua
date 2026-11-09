fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_start'
description 'KAVKAZ RP: приветствие новичка, памятка (/gaid), смена имени персонажа для админов'
version '0.2.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/fonts/*.woff2',
    'html/fonts/fonts.css',
}

dependencies {
    'ox_lib',
    'qbx_core',
}
