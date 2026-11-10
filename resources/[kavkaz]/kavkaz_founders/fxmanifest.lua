fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_founders'
description 'KAVKAZ RP — усадьбы основателей в деревне «Газна»: гараж со всеми машинами (СГУ «Хазард Про»), деньги, метки'
author 'KAVKAZ RP'
version '1.0.0'

shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
server_scripts { '@oxmysql/lib/MySQL.lua', 'server.lua' }

dependencies { 'ox_lib', 'oxmysql', 'qbx_core', 'qbx_vehicles', 'qbx_garages', 'kavkaz_cars' }
