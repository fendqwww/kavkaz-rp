-- KAVKAZ RP: дальнобой (kavkaz_trucker) — опыт и статистика водителя по персонажу.
-- ресурс создаёт таблицу и сам при старте; файл — для установки с нуля и истории схемы.
CREATE TABLE IF NOT EXISTS kavkaz_trucker (
    citizenid VARCHAR(50) NOT NULL PRIMARY KEY,
    xp INT NOT NULL DEFAULT 0,
    trips INT NOT NULL DEFAULT 0,
    km DECIMAL(10,1) NOT NULL DEFAULT 0,
    earned BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
