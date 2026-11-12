fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_menu'
description 'KAVKAZ RP — меню игрока (F4): профиль, статистика, безопасность, промокод, рефералка, настройки, помощь'
author 'KAVKAZ RP'
version '1.0.0'

shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
server_scripts { '@oxmysql/lib/MySQL.lua', 'server.lua' }

ui_page 'html/index.html'
files { 'html/index.html', 'html/logo.svg', 'html/style.css', 'html/app.js', 'html/fonts/*.woff2', 'html/fonts/fonts.css' }

dependencies { 'ox_lib', 'oxmysql', 'qbx_core' }
