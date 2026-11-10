-- KAVKAZ: копия ox_inventory/data/items.lua с русскими названиями (overrides). при обновлении ox_inventory — перенести заново
return {
    ['testburger'] = {
        label = 'Пробный бургер',
        weight = 220,
        degrade = 60,
        client = {
            image = 'burger_chicken.png',
            status = { hunger = 200000 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            export = 'ox_inventory_examples.testburger'
        },
        server = {
            export = 'ox_inventory_examples.testburger',
            test = 'what an amazingly delicious burger, amirite?'
        },
        buttons = {
            {
                label = 'Леденец',
                action = function(slot)
                    print('You licked the burger')
                end
            },
            {
                label = 'Кетчуп',
                action = function(slot)
                    print('You squeezed the burger :(')
                end
            },
            {
                label = 'Как назвать веганский бургер?',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('A misteak.')
                end
            },
            {
                label = 'Что лягушки едят с бургерами?',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('French flies.')
                end
            },
            {
                label = 'Почему бургер и картошка бежали?',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('Because they\'re fast food.')
                end
            }
        },
        consume = 0.3
    },

    ['bandage'] = {
        label = 'Бинт',
        weight = 115,
    },

    ['burger'] = {
        label = 'Бургер',
        weight = 220,
        client = {
            status = { hunger = 200000 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            notification = 'Бургер съеден'
        },
    },

    ['sprunk'] = {
        label = 'Лимонад',
        weight = 350,
        client = {
            status = { thirst = 200000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_can_01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) },
            usetime = 2500,
            notification = 'Газировка, бодрит'
        }
    },

    ['parachute'] = {
        label = 'Парашют',
        weight = 8000,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 1500
        }
    },

    ['garbage'] = {
        label = 'Мусор',
    },

    ['paperbag'] = {
        label = 'Бумажный пакет',
        weight = 1,
        stack = false,
        close = false,
        consume = 0
    },

    ['panties'] = {
        label = 'Бельё',
        weight = 10,
        consume = 0,
        client = {
            status = { thirst = -100000, stress = -25000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_cs_panties_02`, pos = vec3(0.03, 0.0, 0.02), rot = vec3(0.0, -13.5, -1.5) },
            usetime = 2500,
        }
    },

    ['lockpick'] = {
        label = 'Отмычка',
        weight = 160,
    },

    ['phone'] = {
        label = 'Телефон',
        weight = 190,
        stack = false,
        consume = 0,
        client = {
            add = function(total)
                if total > 0 then
                    pcall(function() return exports.npwd:setPhoneDisabled(false) end)
                end
            end,

            remove = function(total)
                if total < 1 then
                    pcall(function() return exports.npwd:setPhoneDisabled(true) end)
                end
            end
        }
    },

    ['mustard'] = {
        label = 'Горчица',
        weight = 500,
        client = {
            status = { hunger = 25000, thirst = 25000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_food_mustard`, pos = vec3(0.01, 0.0, -0.07), rot = vec3(1.0, 1.0, -1.5) },
            usetime = 2500,
            notification = 'Ты... выпил горчицу'
        }
    },

    ['water'] = {
        label = 'Вода',
        weight = 500,
        client = {
            status = { thirst = 200000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
            usetime = 2500,
            cancel = true,
            notification = 'Вода, свежая'
        }
    },

    ['armour'] = {
        label = 'Бронежилет',
        weight = 3000,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 3500
        }
    },

    ['clothing'] = {
        label = 'Одежда',
        consume = 0,
    },

    ['money'] = {
        label = 'Рубли',
    },

    ['black_money'] = {
        label = 'Грязные деньги',
    },

    ['id_card'] = {
        label = 'Паспорт',
    },

    ['driver_license'] = {
        label = 'Водительское удостоверение',
    },

    ['weaponlicense'] = {
        label = 'Лицензия на оружие',
    },

    ['lawyerpass'] = {
        label = 'Удостоверение адвоката',
    },

    ['radio'] = {
        label = 'Рация',
        weight = 1000,
        allowArmed = true,
        consume = 0,
        client = {
            event = 'mm_radio:client:use'
        }
    },

    ['jammer'] = {
        label = 'Глушилка связи',
        weight = 10000,
        allowArmed = true,
        client = {
            event = 'mm_radio:client:usejammer'
        }
    },

    ['radiocell'] = {
        label = 'Батарейки ААА',
        weight = 1000,
        stack = true,
        allowArmed = true,
        client = {
            event = 'mm_radio:client:recharge'
        }
    },

    ['advancedlockpick'] = {
        label = 'Улучшенная отмычка',
        weight = 500,
    },

    ['screwdriverset'] = {
        label = 'Набор отвёрток',
        weight = 500,
    },

    ['electronickit'] = {
        label = 'Набор электроники',
        weight = 500,
    },

    ['cleaningkit'] = {
        label = 'Набор для чистки',
        weight = 500,
    },

    ['repairkit'] = {
        label = 'Ремкомплект',
        weight = 2500,
    },

    ['advancedrepairkit'] = {
        label = 'Большой ремкомплект',
        weight = 4000,
    },

    ['diamond'] = {
        label = 'Бриллиант',
        weight = 1500,
    },

    ['diamond_ring'] = {
        label = 'Кольцо с бриллиантом',
        weight = 1500,
    },

    ['rolex'] = {
        label = 'Золотые часы',
        weight = 1500,
    },

    ['goldbar'] = {
        label = 'Слиток золота',
        weight = 1500,
    },

    ['goldchain'] = {
        label = 'Золотая цепочка',
        weight = 1500,
    },

    ['10kgoldchain'] = {
        label = 'Золотая цепь 10к',
        weight = 1500,
    },

    ['crack_baggy'] = {
        label = 'Пакетик крэка',
        weight = 100,
    },

    ['cokebaggy'] = {
        label = 'Пакетик кокаина',
        weight = 100,
    },

    ['coke_brick'] = {
        label = 'Брикет кокаина',
        weight = 2000,
    },

    ['coke_small_brick'] = {
        label = 'Упаковка кокаина',
        weight = 1000,
    },

    ['xtcbaggy'] = {
        label = 'Пакетик экстази',
        weight = 100,
    },

    ['meth'] = {
        label = 'Метамфетамин',
        weight = 100,
    },

    ['oxy'] = {
        label = 'Оксикодон',
        weight = 100,
    },

    ['weed_ak47'] = {
        label = 'Трава «AK-47», 2 г',
        weight = 200,
    },

    ['weed_ak47_seed'] = {
        label = 'Семена «AK-47»',
        weight = 1,
    },

    ['weed_skunk'] = {
        label = 'Трава «Skunk», 2 г',
        weight = 200,
    },

    ['weed_skunk_seed'] = {
        label = 'Семена «Skunk»',
        weight = 1,
    },

    ['weed_amnesia'] = {
        label = 'Трава «Амнезия», 2 г',
        weight = 200,
    },

    ['weed_amnesia_seed'] = {
        label = 'Семена «Амнезия»',
        weight = 1,
    },

    ['weed_og-kush'] = {
        label = 'Трава «OG Kush», 2 г',
        weight = 200,
    },

    ['weed_og-kush_seed'] = {
        label = 'Семена «OG Kush»',
        weight = 1,
    },

    ['weed_white-widow'] = {
        label = 'Трава «OG Kush», 2 г',
        weight = 200,
    },

    ['weed_white-widow_seed'] = {
        label = 'Семена «White Widow»',
        weight = 1,
    },

    ['weed_purple-haze'] = {
        label = 'Трава «Purple Haze», 2 г',
        weight = 200,
    },

    ['weed_purple-haze_seed'] = {
        label = 'Семена «Purple Haze»',
        weight = 1,
    },

    ['weed_brick'] = {
        label = 'Брикет травы',
        weight = 2000,
    },

    ['weed_nutrition'] = {
        label = 'Удобрение',
        weight = 2000,
    },

    ['joint'] = {
        label = 'Самокрутка',
        weight = 200,
    },

    ['rolling_paper'] = {
        label = 'Бумага для самокруток',
        weight = 0,
    },

    ['empty_weed_bag'] = {
        label = 'Пустой пакетик',
        weight = 0,
    },

    ['firstaid'] = {
        label = 'Аптечка',
        weight = 2500,
    },

    ['ifaks'] = {
        label = 'Индивидуальная аптечка',
        weight = 2500,
    },

    ['painkillers'] = {
        label = 'Обезболивающее',
        weight = 400,
    },

    ['firework1'] = {
        label = 'Картина «Два брата»',
        weight = 1000,
    },

    ['firework2'] = {
        label = 'Чипсы',
        weight = 1000,
    },

    ['firework3'] = {
        label = 'Энергетик',
        weight = 1000,
    },

    ['firework4'] = {
        label = 'Картина «Плакучая ива»',
        weight = 1000,
    },

    ['steel'] = {
        label = 'Сталь',
        weight = 100,
    },

    ['rubber'] = {
        label = 'Резина',
        weight = 100,
    },

    ['metalscrap'] = {
        label = 'Металлолом',
        weight = 100,
    },

    ['iron'] = {
        label = 'Железо',
        weight = 100,
    },

    ['copper'] = {
        label = 'Медь',
        weight = 100,
    },

    ['aluminum'] = {
        label = 'Алюминий',
        weight = 100,
    },

    ['plastic'] = {
        label = 'Пластик',
        weight = 100,
    },

    ['glass'] = {
        label = 'Стекло',
        weight = 100,
    },

    ['gatecrack'] = {
        label = 'Взломщик ворот',
        weight = 1000,
    },

    ['cryptostick'] = {
        label = 'Крипто-флешка',
        weight = 100,
    },

    ['trojan_usb'] = {
        label = 'Флешка с вирусом',
        weight = 100,
    },

    ['toaster'] = {
        label = 'Тостер',
        weight = 5000,
    },

    ['small_tv'] = {
        label = 'Маленький телевизор',
        weight = 100,
    },

    ['security_card_01'] = {
        label = 'Ключ-карта А',
        weight = 100,
    },

    ['security_card_02'] = {
        label = 'Ключ-карта Б',
        weight = 100,
    },

    ['drill'] = {
        label = 'Дрель',
        weight = 5000,
    },

    ['thermite'] = {
        label = 'Термит',
        weight = 1000,
    },

    ['diving_gear'] = {
        label = 'Акваланг',
        weight = 30000,
    },

    ['diving_fill'] = {
        label = 'Баллон для акваланга',
        weight = 3000,
    },

    ['antipatharia_coral'] = {
        label = 'Чёрный коралл',
        weight = 1000,
    },

    ['dendrogyra_coral'] = {
        label = 'Коралл',
        weight = 1000,
    },

    ['jerry_can'] = {
        label = 'Канистра',
        weight = 3000,
    },

    ['nitrous'] = {
        label = 'Закись азота',
        weight = 1000,
    },

    ['wine'] = {
        label = 'Вино',
        weight = 500,
    },

    ['grape'] = {
        label = 'Виноград',
        weight = 10,
    },

    ['grapejuice'] = {
        label = 'Виноградный сок',
        weight = 200,
    },

    ['coffee'] = {
        label = 'Кофе',
        weight = 200,
        client = { -- KAVKAZ: кофе теперь можно выпить (продаётся в kavkaz_food)
            status = { thirst = 150000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            usetime = 2500,
            notification = 'Кофе, бодрит'
        },
    },

    ['vodka'] = {
        label = 'Водка',
        weight = 500,
    },

    ['whiskey'] = {
        label = 'Виски',
        weight = 200,
    },

    ['beer'] = {
        label = 'Пиво',
        weight = 200,
    },

    ['sandwich'] = {
        label = 'Бутерброд',
        weight = 200,
    },

    ['walking_stick'] = {
        label = 'Трость',
        weight = 1000,
    },

    ['lighter'] = {
        label = 'Зажигалка',
        weight = 200,
    },

    ['binoculars'] = {
        label = 'Бинокль',
        weight = 800,
    },

    ['stickynote'] = {
        label = 'Записка',
        weight = 0,
    },

    ['empty_evidence_bag'] = {
        label = 'Пустой пакет для улик',
        weight = 200,
    },

    ['filled_evidence_bag'] = {
        label = 'Пакет с уликой',
        weight = 200,
    },

    ['harness'] = {
        label = 'Гоночные ремни',
        weight = 200,
    },

    ['handcuffs'] = {
        label = 'Наручники',
        weight = 200,
    },

    ['shawarma'] = { -- KAVKAZ: kavkaz_food
        label = 'Шаурма',
        weight = 350,
        client = {
            image = 'burger.png',
            status = { hunger = 250000 },
            anim = 'eating',
            usetime = 2500,
            notification = 'Шаурма — то, что надо'
        },
    },

    ['shawarma_xl'] = { -- KAVKAZ: kavkaz_food
        label = 'Шаурма XL',
        weight = 550,
        client = {
            image = 'burger.png',
            status = { hunger = 450000 },
            anim = 'eating',
            usetime = 2500,
            notification = 'Двойная шаурма, сыт надолго'
        },
    },

    ['shashlyk'] = { -- KAVKAZ: kavkaz_food
        label = 'Шашлык',
        weight = 400,
        client = {
            image = 'burger.png',
            status = { hunger = 400000 },
            anim = 'eating',
            usetime = 2500,
            notification = 'Шашлык с углей'
        },
    },

    ['zhizhig'] = { -- KAVKAZ: kavkaz_food
        label = 'Жижиг-галнаш',
        weight = 600,
        client = {
            image = 'burger.png',
            status = { hunger = 600000, thirst = 100000 },
            anim = 'eating',
            usetime = 2500,
            notification = 'Жижиг-галнаш, как дома'
        },
    },

    ['chepalgash'] = { -- KAVKAZ: kavkaz_food
        label = 'Чепалгаш',
        weight = 250,
        client = {
            image = 'burger.png',
            status = { hunger = 250000 },
            anim = 'eating',
            usetime = 2500,
            notification = 'Тёплый чепалгаш с маслом'
        },
    },

    ['samsa'] = { -- KAVKAZ: kavkaz_food
        label = 'Самса',
        weight = 200,
        client = {
            image = 'burger.png',
            status = { hunger = 180000 },
            anim = 'eating',
            usetime = 2500,
            notification = 'Горячая самса'
        },
    },

    ['chai'] = { -- KAVKAZ: kavkaz_food
        label = 'Чай с чабрецом',
        weight = 250,
        client = {
            image = 'coffee.png',
            status = { thirst = 250000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            usetime = 2500,
            notification = 'Чай с чабрецом, горячий'
        },
    },

    ['ayran'] = { -- KAVKAZ: kavkaz_food
        label = 'Айран',
        weight = 400,
        client = {
            image = 'water.png',
            status = { hunger = 30000, thirst = 300000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            usetime = 2500,
            notification = 'Холодный айран'
        },
    },
}
