-- KAVKAZ RP: пневмоподвеска на машинах (kavkaz_air). vkey: 'id:<player_vehicles.id>'
CREATE TABLE IF NOT EXISTS kavkaz_air (
    vkey VARCHAR(32) NOT NULL PRIMARY KEY,
    citizenid VARCHAR(50) NULL,
    installed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
