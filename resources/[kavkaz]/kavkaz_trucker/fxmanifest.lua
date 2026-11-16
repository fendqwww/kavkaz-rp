fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_trucker'
description 'KAVKAZ RP: дальнобой — рейсы с прицепом по всей карте, сроки, целость груза, посты ДПС, поломки, «левый» груз, уровень водителя'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@qbx_core/modules/lib.lua',
    'server.lua',
}

client_script 'client.lua'

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'ox_target',
}
