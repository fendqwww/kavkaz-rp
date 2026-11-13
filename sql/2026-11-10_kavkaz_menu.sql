-- KAVKAZ RP: меню игрока (kavkaz_menu) — время в игре и промокоды
CREATE TABLE IF NOT EXISTS kavkaz_playtime (
    citizenid VARCHAR(50) NOT NULL PRIMARY KEY,
    license VARCHAR(80) NULL,
    minutes INT NOT NULL DEFAULT 0,
    first_seen TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL
);
CREATE TABLE IF NOT EXISTS kavkaz_promo (
    code VARCHAR(24) NOT NULL PRIMARY KEY,
    reward VARCHAR(64) NOT NULL,
    amount INT NOT NULL DEFAULT 0,
    uses_left INT NOT NULL DEFAULT 1,
    created_by VARCHAR(64) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS kavkaz_promo_used (
    code VARCHAR(24) NOT NULL,
    license VARCHAR(80) NOT NULL,
    citizenid VARCHAR(50) NULL,
    used_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (code, license)
);
