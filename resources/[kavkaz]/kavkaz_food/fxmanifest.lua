fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_food'
description 'KAVKAZ RP: забегаловки Нагорья — шаурма, чайхана, шашлычная; продавцы-NPC, меню в ₽, покупка на сервере'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_script 'client.lua'
server_script 'server.lua'

dependencies {
    'ox_lib',
    'qbx_core',
    'ox_target',
    'ox_inventory',
}
