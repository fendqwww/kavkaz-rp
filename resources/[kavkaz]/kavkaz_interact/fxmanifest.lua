fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_interact'
description 'KAVKAZ RP: меню взаимодействия — удержание G: капот, багажник, двери, ремень, замок, зажигание, фары; пешком — руки вверх, паспорт, навигатор'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}
client_script 'client.lua'

ui_page 'html/index.html'
files { 'html/index.html', 'html/golos-text.woff2', 'html/LICENSE-icons.txt' }

dependencies { 'ox_lib' }
