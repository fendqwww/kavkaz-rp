# Задание для Claude в VS Code: картинки предметов как у Majestic (рендеры моделей GTA)

Основатель 15.11: картинки предметов из наборов ox_inventory / qb-inventory «странные, как у Qbox» (мультяшные, 100×100).
У Majestic — реалистичные рендеры настоящих моделей GTA на прозрачном фоне. Делаем так же, своими силами.
Макет окна инвентаря (утверждается отдельно): `docs/design/inventory-mock-v2.jpg`.

## Что сделать
1. Список предметов — `overrides/resources/[ox]/ox_inventory/data/items.lua` (111 штук, в т.ч. наши:
   shawarma, shawarma_xl, shashlyk, zhizhig, chepalgash, samsa, chai, ayran, lepeshka, yabloki, tvorog, kompot).
2. Для каждого подобрать модель GTA (prop_*), например: телефон `prop_npc_phone_02`, вода `prop_ld_flow_bottle`,
   бургер `prop_cs_burger_01`, канистра `w_am_jerrycan`, аптечка `prop_ld_health_pack`, бинт `prop_gaffer_arm_bind`,
   оружие `w_pi_pistol` и т.д. Для нашей еды — ближайшие пропы (шаурма — `prop_food_bs_burger2`/свой простой меш, чай — `prop_tea_urn`/стакан,
   лаваш — `prop_food_bs_bag_04`…) или простая модель в Blender, но **в том же свете и ракурсе**.
3. Рендер в Blender (Sollumz, как пульт Хазарда): один ракурс 3/4 сверху, мягкий свет, прозрачный фон, 256×256, без тени на полу.
   скрипт рядом с остальными: `setup/models/render_items.py` (вход — список item → prop, выход — png).
4. Положить в `overrides/resources/[ox]/ox_inventory/web/images/<item>.png` (имя = ключ предмета).
   Модели GTA в git не кладём — только готовые png.
5. Скрин листа всех картинок основателю до выкладки.
