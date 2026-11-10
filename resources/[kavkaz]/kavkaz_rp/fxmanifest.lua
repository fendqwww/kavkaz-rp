fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_rp'
description 'KAVKAZ RP: локальный IC-чат и RP-команды (/do /try /todo /s /w /b /pm /r /rn /d /f /gov), передача денег /pay'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

server_script 'server.lua'
client_script 'client.lua'

dependencies {
    'ox_lib',
    'qbx_core',
}
