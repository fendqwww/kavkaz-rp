-- KAVKAZ RP: водительские права. получают в автошколе (kavkaz_quests, Зарема Поворотовна) — предмет driver_license
-- и metadata.licences.driver = true. здесь — всё, что дальше: проверка, лишение, возврат, ездить без прав.

Config = {}

-- кто может проверять и лишать прав: работа = минимальный ранг (на смене)
Config.Jobs = { police = 0, sheriff = 0, sasp = 0 }
Config.Distance = 4.0          -- как близко к водителю, м
Config.MaxDays = 30            -- самый долгий срок лишения, дней (реальных)
Config.AdminLevel = 4          -- уровень админа для /agivelicense и /atakelicense (kavkaz_admin)

-- предупреждение, если сел за руль без прав (машины; мотоциклы, велосипеды, лодки, самолёты — не трогаем)
Config.WarnClasses = { [0]=true, [1]=true, [2]=true, [3]=true, [4]=true, [5]=true, [6]=true, [7]=true, [9]=true, [10]=true, [11]=true, [12]=true, [17]=true, [18]=true, [20]=true }
