fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_world'
description 'KAVKAZ RP: облик Нагорья — русские знаки и рекламные щиты, посты ДПС, без американских флагов'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_script 'client.lua'

files {
    'images/*.png',
}

dependencies {
    'ox_lib',
}
