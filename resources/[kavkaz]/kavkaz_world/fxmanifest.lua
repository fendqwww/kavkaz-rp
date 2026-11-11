fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_world'
description 'KAVKAZ RP: облик Нагорья — русские знаки и рекламные щиты, посты ДПС, без американских флагов'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'retex_list.lua',
    'signs_list.lua',
    'signs2_list.lua',
}

client_script 'client.lua'

files {
    'images/*.png',
    'images/retex/*.png',
    'images/local/*.png', -- куски текстур игры с нашими вывесками: не в git, копируются на сервер скриптом
}

dependencies {
    'ox_lib',
}
