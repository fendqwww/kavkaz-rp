fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_loadscreen'
description 'KAVKAZ RP: экран загрузки в фирменном стиле'
version '0.1.0'

files {
    'html/index.html',
    'html/fonts/*.woff2',
    'html/fonts/fonts.css',
    -- фоновые кадры из игры (по antr5-skill: только настоящие скриншоты): положить html/bg/1.jpg … 5.jpg
    -- и раскомментировать строку ниже (пока кадров нет, FiveM ругается на пустую маску)
    -- 'html/bg/*.jpg',
}

loadscreen 'html/index.html'
loadscreen_cursor 'no'
-- экран закрывает qbx_core, когда готово меню персонажей (ShutdownLoadingScreenNui)
loadscreen_manual_shutdown 'yes'

client_script 'client.lua'
