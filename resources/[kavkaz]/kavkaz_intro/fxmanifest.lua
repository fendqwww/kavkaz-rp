fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_intro'
description 'KAVKAZ RP: пролог «Домой» — посадка самолёта, дядя Хамзат встречает в аэропорту, дорога через город, двор, коробка деда (docs/vision/23-story-jobs-economy.md)'
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

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/fonts/*.woff2',
    'html/fonts/fonts.css',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'oxmysql',
}
