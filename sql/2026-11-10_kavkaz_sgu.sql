-- KAVKAZ RP: СГУ «Хазард 7007», установленные на машины (kavkaz_sgu)
-- vkey: 'id:<player_vehicles.id>' для своих машин; модель: mini / std / pro
CREATE TABLE IF NOT EXISTS kavkaz_sgu (
    vkey VARCHAR(32) NOT NULL PRIMARY KEY,
    model VARCHAR(16) NOT NULL,
    citizenid VARCHAR(50) NULL,
    installed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
