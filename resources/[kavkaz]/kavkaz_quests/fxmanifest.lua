fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_quests'
description 'KAVKAZ RP: старт — 50 000 ₽, три сюжетные линии (закон, бизнес, криминал) с выбором роли, прокат скутеров, доставка обедов, автошкола'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua',
    'story.lua',
}

server_scripts {
    'server/main.lua',
    'server/story.lua',
    'server/npcs.lua',
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
