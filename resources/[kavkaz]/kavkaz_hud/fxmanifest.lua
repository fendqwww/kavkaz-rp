fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_hud'
description 'KAVKAZ RP — HUD: спидометр (км/ч, передачи, обороты, топливо), здоровье, еда, вода, голос, деньги'
author 'KAVKAZ RP'
version '1.0.0'

shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/golos-text.woff2',
    'html/saira-italic-latin.woff2',
    'html/unbounded-cyrillic.woff2',
    'html/unbounded-latin.woff2',
}
