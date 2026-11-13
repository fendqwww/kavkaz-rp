fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kavkaz_cars'
description 'KAVKAZ RP: автопарк — список машин (cars.lua) для салона, гаражей и номеров, выдача машин, лимит редких машин'
version '0.1.0'

-- cars.lua читают qbx_core, qbx_vehicleshop, qbx_police, qbx_ambulancejob (через LoadResourceFile), поэтому он в files.
-- ресурс стартует раньше qbx_core (строка ensure kavkaz_cars в server.cfg перед ensure qbx_core — её ставит setup/apply-overrides).
files {
    'cars.lua',
}

client_script 'client.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

dependencies {
    'oxmysql',
}
