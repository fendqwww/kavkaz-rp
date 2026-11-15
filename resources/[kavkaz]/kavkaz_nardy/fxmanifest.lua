fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_nardy'
description 'KAVKAZ RP: длинные нарды между игроками — на интерес или на наличные, правила и кости на сервере'
version '0.1.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/fonts/*.woff2',
    'html/fonts/fonts.css',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'rules.lua',
}

client_script 'client.lua'
server_script 'server.lua'

dependencies {
    'ox_lib',
    'qbx_core',
    'ox_target',
}
