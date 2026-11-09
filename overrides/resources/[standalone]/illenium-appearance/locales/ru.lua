-- KAVKAZ: русский перевод редактора внешности (включается convar illenium-appearance:locale "ru")
Locales["ru"] = {
    UI = {
        modal = {
            save = {
                title = "Сохранить внешность",
                description = "Готово? Внешность можно будет поменять у парикмахера и в магазине одежды"
            },
            exit = {
                title = "Выйти без сохранения",
                description = "Изменения не сохранятся"
            },
            accept = "Да",
            decline = "Нет"
        },
        ped = {
            title = "Модель",
            model = "Модель"
        },
        headBlend = {
            title = "Родители",
            shape = {
                title = "Лицо",
                firstOption = "Отец",
                secondOption = "Мать",
                mix = "На кого похож"
            },
            skin = {
                title = "Кожа",
                firstOption = "Отец",
                secondOption = "Мать",
                mix = "На кого похож"
            },
            race = {
                title = "Дополнительно",
                shape = "Форма",
                skin = "Кожа",
                mix = "Смешивание"
            }
        },
        faceFeatures = {
            title = "Черты лица",
            nose = {
                title = "Нос",
                width = "Ширина",
                height = "Высота",
                size = "Длина",
                boneHeight = "Высота переносицы",
                boneTwist = "Искривление",
                peakHeight = "Кончик носа"
            },
            eyebrows = {
                title = "Брови",
                height = "Высота",
                depth = "Глубина"
            },
            cheeks = {
                title = "Скулы и щёки",
                boneHeight = "Высота скул",
                boneWidth = "Ширина скул",
                width = "Щёки"
            },
            eyesAndMouth = {
                title = "Глаза и губы",
                eyesOpening = "Разрез глаз",
                lipsThickness = "Толщина губ"
            },
            jaw = {
                title = "Челюсть",
                width = "Ширина",
                size = "Размер"
            },
            chin = {
                title = "Подбородок",
                lowering = "Высота",
                length = "Длина",
                size = "Ширина",
                hole = "Ямочка"
            },
            neck = {
                title = "Шея",
                thickness = "Толщина"
            }
        },
        headOverlays = {
            title = "Внешность",
            hair = {
                title = "Волосы",
                style = "Причёска",
                color = "Цвет",
                highlight = "Мелирование",
                texture = "Вариант",
                fade = "Переход"
            },
            opacity = "Насыщенность",
            style = "Вид",
            color = "Цвет",
            secondColor = "Второй цвет",
            blemishes = "Пятна на лице",
            beard = "Борода",
            eyebrows = "Брови",
            ageing = "Возраст (морщины)",
            makeUp = "Макияж",
            blush = "Румяна",
            complexion = "Цвет лица",
            sunDamage = "Загар и веснушки от солнца",
            lipstick = "Помада",
            moleAndFreckles = "Родинки и веснушки",
            chestHair = "Волосы на груди",
            bodyBlemishes = "Пятна на теле",
            eyeColor = "Цвет глаз"
        },
        components = {
            title = "Одежда",
            drawable = "Модель",
            texture = "Цвет",
            mask = "Маска",
            upperBody = "Руки",
            lowerBody = "Штаны",
            bags = "Сумки и рюкзаки",
            shoes = "Обувь",
            scarfAndChains = "Шарфы и цепочки",
            shirt = "Футболка / рубашка",
            bodyArmor = "Бронежилет",
            decals = "Нашивки",
            jackets = "Верхняя одежда",
            head = "Голова"
        },
        props = {
            title = "Аксессуары",
            drawable = "Модель",
            texture = "Цвет",
            hats = "Головные уборы",
            glasses = "Очки",
            ear = "Серьги",
            watches = "Часы",
            bracelets = "Браслеты"
        },
        tattoos = {
            title = "Татуировки",
            items = {
                ZONE_TORSO = "Торс",
                ZONE_HEAD = "Голова",
                ZONE_LEFT_ARM = "Левая рука",
                ZONE_RIGHT_ARM = "Правая рука",
                ZONE_LEFT_LEG = "Левая нога",
                ZONE_RIGHT_LEG = "Правая нога"
            },
            apply = "Набить",
            delete = "Свести",
            deleteAll = "Свести все татуировки",
            opacity = "Насыщенность"
        }
    },
    outfitManagement = {
        title = "Образы",
        jobText = "Рабочие образы",
        gangText = "Образы банды"
    },
    cancelled = {
        title = "Отменено",
        description = "Внешность не сохранена"
    },
    outfits = {
        import = {
            title = "Введи код образа",
            menuTitle = "Загрузить образ по коду",
            description = "Получить образ по коду, которым с тобой поделились",
            name = {
                label = "Название образа",
                placeholder = "Нарядный",
                default = "Загруженный образ"
            },
            code = {
                label = "Код образа"
            },
            success = {
                title = "Образ загружен",
                description = "Переодеться в него можно в меню образов"
            },
            failure = {
                title = "Не получилось",
                description = "Неверный код образа"
            }
        },
        generate = {
            title = "Поделиться образом",
            description = "Получить код образа, чтобы поделиться им",
            failure = {
                title = "Что-то пошло не так",
                description = "Не удалось создать код образа"
            },
            success = {
                title = "Код готов",
                description = "Вот код твоего образа"
            }
        },
        save = {
            menuTitle = "Сохранить текущий образ",
            menuDescription = "Сохранить текущий образ как %s",
            description = "Сохранить то, что сейчас надето",
            title = "Название образа",
            managementTitle = "Настройки образа",
            name = {
                label = "Название",
                placeholder = "Мой лучший образ"
            },
            gender = {
                label = "Пол",
                male = "Мужской",
                female = "Женский"
            },
            rank = {
                label = "С какого ранга"
            },
            failure = {
                title = "Не сохранилось",
                description = "Образ с таким названием уже есть"
            },
            success = {
                title = "Готово",
                description = "Образ «%s» сохранён"
            }
        },
        update = {
            title = "Обновить образ",
            description = "Записать текущую одежду в сохранённый образ",
            failure = {
                title = "Не обновилось",
                description = "Такого образа нет"
            },
            success = {
                title = "Готово",
                description = "Образ «%s» обновлён"
            }
        },
        change = {
            title = "Переодеться",
            description = "Выбрать из сохранённых образов: %s",
            pDescription = "Выбрать из сохранённых образов",
            failure = {
                title = "Что-то пошло не так",
                description = "У этого образа нет базовой внешности"
            }
        },
        delete = {
            title = "Удалить образ",
            description = "Удалить сохранённый образ: %s",
            mDescription = "Удалить любой из сохранённых образов",
            item = {
                title = 'Удалить «%s»',
                description = "Модель: %s%s"
            },
            success = {
                title = "Готово",
                description = "Образ удалён"
            }
        },
        manage = {
            title = "👔 | Образы: %s"
        }
    },
    jobOutfits = {
        title = "Рабочая форма",
        description = "Выбрать рабочую форму"
    },
    menu = {
        returnTitle = "Назад",
        title = "Гардероб",
        outfitsTitle = "Мои образы",
        clothingShopTitle = "Магазин одежды",
        barberShopTitle = "Парикмахерская",
        tattooShopTitle = "Тату-салон",
        surgeonShopTitle = "Пластическая хирургия"
    },
    clothing = {
        title = "Купить одежду — %d ₽",
        titleNoPrice = "Переодеться",
        options = {
            title = "👔 | Магазин одежды",
            description = "Большой выбор одежды"
        },
        outfits = {
            title = "👔 | Образы",
            civilian = {
                title = "Обычная одежда",
                description = "Надеть свою одежду"
            }
        }
    },
    commands = {
        reloadskin = {
            title = "Перезагрузить внешность персонажа",
            failure = {
                title = "Ошибка",
                description = "Сейчас нельзя перезагрузить внешность"
            }
        },
        clearstuckprops = {
            title = "Убрать застрявшие на персонаже предметы",
            failure = {
                title = "Ошибка",
                description = "Сейчас нельзя это сделать"
            }
        },
        pedmenu = {
            title = "Открыть / выдать меню одежды",
            failure = {
                title = "Ошибка",
                description = "Игрок не в сети"
            }
        },
        joboutfits = {
            title = "Меню рабочей формы"
        },
        gangoutfits = {
            title = "Меню образов банды"
        },
        bossmanagedoutfits = {
            title = "Меню образов от начальника"
        }
    },
    textUI = {
        clothing = "Магазин одежды — цена: %d ₽",
        barber = "Парикмахерская — цена: %d ₽",
        tattoo = "Тату-салон — цена: %d ₽",
        surgeon = "Пластический хирург — цена: %d ₽",
        clothingRoom = "Гардероб",
        playerOutfitRoom = "Образы"
    },
    migrate = {
        success = {
            title = "Готово",
            description = "Перенос закончен. Перенесено внешностей: %s",
            descriptionSingle = "Внешность перенесена"
        },
        skip = {
            title = "Информация",
            description = "Внешность пропущена"
        },
        typeError = {
            title = "Ошибка",
            description = "Неверный тип"
        }
    },
    purchase = {
        tattoo = {
            success = {
                title = "Готово",
                description = "Татуировка %s набита за %s ₽"
            },
            failure = {
                title = "Татуировку не набили",
                description = "Не хватает денег!"
            }
        },
        store = {
            success = {
                title = "Готово",
                description = "Оплачено %s ₽: %s"
            },
            failure = {
                title = "Ошибка оплаты",
                description = "Не хватает денег!"
            }
        }
    }
}
