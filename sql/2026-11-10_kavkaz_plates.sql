-- KAVKAZ RP: номера (ресурс kavkaz_plates). ресурс создаёт таблицы сам; этот файл — для ручного наката и истории схемы.

CREATE TABLE IF NOT EXISTS `kavkaz_plates` (
    `plate`      VARCHAR(8)  NOT NULL,              -- латиницей без пробелов: A777AA95
    `citizenid`  VARCHAR(50) NOT NULL,              -- владелец (персонаж)
    `vehicle_id` INT         NULL DEFAULT NULL,     -- player_vehicles.id; NULL = «в кармане»
    `tier`       VARCHAR(16) NULL DEFAULT NULL,     -- красивый номер: blat / zero / region / triple / letters
    `source`     VARCHAR(16) NOT NULL DEFAULT 'window', -- window / choose / dps / admin / event / auction
    `created_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`plate`),
    KEY `idx_owner` (`citizenid`),
    KEY `idx_vehicle` (`vehicle_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `kavkaz_plate_history` (
    `id`         INT         NOT NULL AUTO_INCREMENT,
    `plate`      VARCHAR(8)  NOT NULL,
    `from_cid`   VARCHAR(50) NULL DEFAULT NULL,
    `to_cid`     VARCHAR(50) NULL DEFAULT NULL,
    `action`     VARCHAR(16) NOT NULL,              -- window / choose / dps / admin / attach / detach / sell
    `price`      INT         NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
