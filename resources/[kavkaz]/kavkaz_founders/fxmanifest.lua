fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_founders'
description 'KAVKAZ RP — дома основателей (Норт-Конкер 2044 и 2045): появление дома, вход и выход, гараж со всеми машинами (СГУ «Хазард Про»), деньги'
author 'KAVKAZ RP'
version '1.0.0'

shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
server_scripts { '@oxmysql/lib/MySQL.lua', 'server.lua' }

-- KAVKAZ: только то, что есть и у игрока: qbx_vehicles работает лишь на сервере (server_only), из-за него вход обрывался
dependencies { 'ox_lib', 'oxmysql', 'qbx_core', 'qbx_garages' }
