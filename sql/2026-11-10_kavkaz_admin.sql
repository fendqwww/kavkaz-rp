-- KAVKAZ RP: таблицы админки (ресурс kavkaz_admin).
-- ресурс сам создаёт их при старте (CREATE TABLE IF NOT EXISTS), этот файл — для ручного наката и истории схемы.

CREATE TABLE IF NOT EXISTS `kavkaz_admins` (
    `license`      VARCHAR(60)  NOT NULL,
    `name`         VARCHAR(64)  NOT NULL DEFAULT '',
    `level`        TINYINT      NOT NULL DEFAULT 0,
    `pin_hash`     VARCHAR(100) NULL DEFAULT NULL,
    `pin_fails`    TINYINT      NOT NULL DEFAULT 0,
    `locked_until` INT          NOT NULL DEFAULT 0,
    `duty_seconds` INT          NOT NULL DEFAULT 0,
    `reports_done` INT          NOT NULL DEFAULT 0,
    `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `kavkaz_admin_log` (
    `id`           INT          NOT NULL AUTO_INCREMENT,
    `admin`        VARCHAR(64)  NOT NULL DEFAULT '',
    `admin_license` VARCHAR(60) NULL DEFAULT NULL,
    `action`       VARCHAR(32)  NOT NULL,
    `target`       VARCHAR(64)  NULL DEFAULT NULL,
    `target_license` VARCHAR(60) NULL DEFAULT NULL,
    `details`      VARCHAR(512) NULL DEFAULT NULL,
    `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_admin` (`admin_license`),
    KEY `idx_target` (`target_license`),
    KEY `idx_action` (`action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `kavkaz_bans` (
    `id`           INT          NOT NULL AUTO_INCREMENT,
    `name`         VARCHAR(64)  NOT NULL DEFAULT '',
    `license`      VARCHAR(60)  NULL DEFAULT NULL,
    `fivem`        VARCHAR(60)  NULL DEFAULT NULL,
    `discord`      VARCHAR(60)  NULL DEFAULT NULL,
    `reason`       VARCHAR(255) NOT NULL DEFAULT '',
    `admin`        VARCHAR(64)  NOT NULL DEFAULT '',
    `expires`      INT          NOT NULL DEFAULT 0, -- unix-время, 0 = навсегда
    `active`       TINYINT      NOT NULL DEFAULT 1,
    `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_license` (`license`),
    KEY `idx_fivem` (`fivem`),
    KEY `idx_discord` (`discord`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `kavkaz_warns` (
    `id`           INT          NOT NULL AUTO_INCREMENT,
    `license`      VARCHAR(60)  NOT NULL,
    `reason`       VARCHAR(255) NOT NULL DEFAULT '',
    `admin`        VARCHAR(64)  NOT NULL DEFAULT '',
    `active`       TINYINT      NOT NULL DEFAULT 1,
    `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- мут и админ-тюрьма переживают перезаход: остаток времени хранится здесь
CREATE TABLE IF NOT EXISTS `kavkaz_punish` (
    `license`      VARCHAR(60)  NOT NULL,
    `kind`         VARCHAR(8)   NOT NULL, -- 'mute' / 'jail'
    `until_ts`     INT          NOT NULL DEFAULT 0, -- для мута: unix-время конца
    `seconds_left` INT          NOT NULL DEFAULT 0, -- для тюрьмы: сколько осталось отсидеть в игре
    `reason`       VARCHAR(255) NOT NULL DEFAULT '',
    `admin`        VARCHAR(64)  NOT NULL DEFAULT '',
    PRIMARY KEY (`license`, `kind`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
