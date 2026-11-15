fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_help'
description 'KAVKAZ RP: все команды в одном списке — подсказки в чате, окно /help, вкладка «Команды» в админ-панели'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/logo.svg',
    'html/fonts/*.woff2',
    'html/fonts/fonts.css',
}

dependencies {
    'ox_lib',
    'kavkaz_admin',
}
