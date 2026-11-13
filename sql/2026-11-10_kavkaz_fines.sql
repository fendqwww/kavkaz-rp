-- KAVKAZ RP: штрафы (ресурс kavkaz_fines создаёт таблицу сам)
CREATE TABLE IF NOT EXISTS `kavkaz_fines` (
    `id`          INT          NOT NULL AUTO_INCREMENT,
    `citizenid`   VARCHAR(50)  NOT NULL,
    `name`        VARCHAR(64)  NOT NULL DEFAULT '',
    `officer`     VARCHAR(64)  NOT NULL DEFAULT '',
    `officer_cid` VARCHAR(50)  NULL DEFAULT NULL,
    `article`     VARCHAR(16)  NOT NULL,
    `note`        VARCHAR(160) NULL DEFAULT NULL,
    `amount`      INT          NOT NULL,
    `doubled`     TINYINT      NOT NULL DEFAULT 0,
    `paid`        TINYINT      NOT NULL DEFAULT 0,
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `paid_at`     TIMESTAMP    NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_cid` (`citizenid`, `paid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
