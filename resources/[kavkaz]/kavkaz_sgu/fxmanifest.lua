fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_sgu'
description 'KAVKAZ RP — СГУ «Хазард 7007»: крякалка и мелодии (звук синтезируется в игре), гараж Бислана, служебные СГУ, изъятие ДПС'
author 'KAVKAZ RP'
version '1.0.0'

shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_scripts { 'client.lua', 'dash.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server.lua' }

ui_page 'html/index.html'
files { 'html/index.html', 'html/golos-text.woff2', 'html/manrope-*.woff2', 'html/unit.png', 'html/sounds/*.ogg', 'html/sounds/*.wav' }

data_file 'DLC_ITYP_REQUEST' 'stream/kavkaz_sgu.ytyp'

dependencies { 'ox_lib', 'oxmysql', 'qbx_core' }
