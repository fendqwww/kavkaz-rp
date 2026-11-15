-- KAVKAZ RP: вид номера (Россия, такси, полиция, военные, страны СНГ) и рамка с надписью. ресурс накатывает это сам при старте.
ALTER TABLE `kavkaz_plates`
    ADD COLUMN IF NOT EXISTS `style`      VARCHAR(16) NOT NULL DEFAULT 'ru',  -- ru / ru_taxi / ru_police / ru_army / kz / by / am / ge / az
    ADD COLUMN IF NOT EXISTS `frame`      VARCHAR(24) NULL DEFAULT NULL,       -- id из Config.Frames или 'custom'
    ADD COLUMN IF NOT EXISTS `frame_text` VARCHAR(48) NULL DEFAULT NULL;       -- своя надпись (/setframe)
