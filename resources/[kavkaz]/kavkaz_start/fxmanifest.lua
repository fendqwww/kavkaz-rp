fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_start'
description 'KAVKAZ RP: приветствие новичка, гайд (/gaid), смена имени персонажа для админов'
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
}
