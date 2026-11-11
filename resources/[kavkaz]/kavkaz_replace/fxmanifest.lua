fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_replace'
description 'KAVKAZ RP — замена американских объектов карты на наши (остановки, пальмы) на тех же местах, что в игре'
author 'KAVKAZ RP'

shared_script '@ox_lib/init.lua'
client_scripts { 'config.lua', 'data.lua', 'client.lua' }
dependency 'ox_lib'
