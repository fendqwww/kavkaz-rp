Config.Theme = {
    currentTheme = "kavkaz", -- KAVKAZ: своя тема по скиллу kavkaz-ui (графит, акцент изумруд, радиус 4 px)
    themes = {
        {
            -- KAVKAZ: тема KAVKAZ RP. primary — плашки разделов и кнопки, selected — выбранное (акцент), secondary — фон панели
            id = "kavkaz",
            borderRadius = "4px",
            fontColor = "242, 243, 245",
            fontColorHover = "255, 255, 255",
            fontColorSelected = "13, 14, 15",
            fontFamily = "Golos Text, Segoe UI, Arial, sans-serif",
            primaryBackground = "34, 35, 38",
            primaryBackgroundSelected = "47, 191, 138",
            secondaryBackground = "18, 19, 20",
            scaleOnHover = false,
            sectionFontWeight = "bold",
            smoothBackgroundTransition = false
        },
        {
            id = "default",
            borderRadius = "4px",
            fontColor = "255, 255, 255",
            fontColorHover = "255, 255, 255",
            fontColorSelected = "0, 0, 0",
            fontFamily = "Inter",
            primaryBackground = "0, 0, 0",
            primaryBackgroundSelected = "255, 255, 255",
            secondaryBackground = "0, 0, 0",
            scaleOnHover = false,
            sectionFontWeight = "normal",
            smoothBackgroundTransition = false
        },
        {
            id = "qb-core",
            borderRadius = "3vh",
            fontColor = "255, 255, 255",
            fontColorHover = "255, 255, 255",
            fontColorSelected = "255, 255, 255",
            fontFamily = "Poppins",
            primaryBackground = "220, 20, 60",
            primaryBackgroundSelected = "220, 20, 60",
            secondaryBackground = "23, 23, 23",
            scaleOnHover = true,
            sectionFontWeight = "bold",
            smoothBackgroundTransition = true
        },
        {
            id = "project-sloth",
            borderRadius = "6vh",
            fontColor = "255, 255, 255",
            fontColorHover = "255, 255, 255",
            fontColorSelected = "255, 255, 255",
            fontFamily = "Inter",
            primaryBackground = "2, 241, 181",
            primaryBackgroundSelected = "2, 241, 181",
            secondaryBackground = "27, 24, 69",
            scaleOnHover = true,
            sectionFontWeight = "bold",
            smoothBackgroundTransition = false
        },
        {
            id = "not-heavily-inspired",
            borderRadius = "10vh",
            fontColor = "255, 255, 255",
            fontColorHover = "255, 255, 255",
            fontColorSelected = "255, 255, 255",
            fontFamily = "Inter",
            primaryBackground = "149, 239, 119",
            primaryBackgroundSelected = "242, 163, 101",
            secondaryBackground = "25, 46, 70",
            scaleOnHover = true,
            sectionFontWeight = "bold",
            smoothBackgroundTransition = false
        }
    }
}
