-- KAVKAZ RP: рейтинг таксистов (kavkaz_taxi). ресурс создаёт таблицу и сам при старте; файл — для deploy-vps.sh.
CREATE TABLE IF NOT EXISTS `kavkaz_taxi` (
    `citizenid` VARCHAR(50) NOT NULL,
    `rides` INT NOT NULL DEFAULT 0,
    `votes` INT NOT NULL DEFAULT 0,
    `score_sum` INT NOT NULL DEFAULT 0,
    `earned` INT NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
