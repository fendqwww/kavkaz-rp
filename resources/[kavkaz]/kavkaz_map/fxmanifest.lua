fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_map'
description 'KAVKAZ RP: Нагорье поверх карты GTA — русские названия районов, метки ведомств, входы в здания, скрытие стандартных зданий, свои ymap'
version '0.1.0'

this_is_a_map 'yes'

-- свои файлы карты из CodeWalker (.ymap, .ydr, .ytd, .ybn) кладутся в stream/ и грузятся сами.
-- для .ytyp допиши строку: data_file 'DLC_ITYP_REQUEST' 'stream/имя.ytyp'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'places.lua',
}

client_scripts { 'client.lua', 'client_places.lua' }

files { 'data/*.json' }
server_script 'server.lua'

dependencies {
    'ox_lib',
    'qbx_core',
    'ox_target',
}
