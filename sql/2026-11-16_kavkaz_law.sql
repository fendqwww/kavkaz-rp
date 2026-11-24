-- KAVKAZ RP: звания и счётчики силовиков (kavkaz_law). ресурс создаёт таблицу и сам, файл — для чистой установки
CREATE TABLE IF NOT EXISTS `kavkaz_law_officers` (
    `citizenid` VARCHAR(50) NOT NULL,
    `org` VARCHAR(10) NOT NULL,
    `xp` INT NOT NULL DEFAULT 0,
    `checks` INT NOT NULL DEFAULT 0,
    `fines` INT NOT NULL DEFAULT 0,
    `detains` INT NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `org`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
