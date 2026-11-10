fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_quests'
description 'KAVKAZ RP: первый час — Румиса Халвовна и линия «Порог», базар, Иса Медович, Ислам, доставка обедов, автошкола и права'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua',
}

server_scripts {
    'server/main.lua',
    'server/porog.lua',
    'server/jobs.lua',
    'server/school.lua',
}

client_script 'client/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/fonts/*.woff2',
    'html/fonts/fonts.css',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'ox_target',
    'ox_inventory',
}
