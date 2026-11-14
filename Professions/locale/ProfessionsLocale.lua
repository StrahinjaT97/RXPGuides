local _, addon = ...

addon.professions = addon.professions or {}

addon.professions.locale = {}

addon.professions.locale.PROFESSION_NAMES = {
    --EN
    ["Alchemy"] = "Alchemy",
    ["Blacksmithing"] = "Blacksmithing",
    ["Enchanting"] = "Enchanting",
    ["Engineering"] = "Engineering",
    ["Herbalism"] = "Herbalism",
    ["Leatherworking"] = "Leatherworking",
    ["Mining"] = "Mining",
    ["Skinning"] = "Skinning",
    ["Tailoring"] = "Tailoring",
    --DE
    ["Alchemie"] = "Alchemy",
    ["Schmiedekunst"] = "Blacksmithing",
    ["Verzauberkunst"] = "Enchanting",
    ["Ingenieurskunst"] = "Engineering",
    ["Kräuterkunde"] = "Herbalism",
    ["Lederverarbeitung"] = "Leatherworking",
    ["Bergbau"] = "Mining",
    ["Kürschnerei"] = "Skinning",
    ["Schneiderei"] = "Tailoring",
    --ES
    ["Alquimia"] = "Alchemy",
    ["Herrería"] = "Blacksmithing",
    ["Encantamiento"] = "Enchanting",
    ["Ingeniería"] = "Engineering",
    ["Botánica"] = "Herbalism",
    ["Marroquinería"] = "Leatherworking",
    ["Minería"] = "Mining",
    ["Desollar"] = "Skinning",
    ["Costura"] = "Tailoring",
    --AL
    ["Alquimia"] = "Alchemy",
    ["Herrería"] = "Blacksmithing",
    ["Encantamiento"] = "Enchanting",
    ["Ingeniería"] = "Engineering",
    ["Herboristería"] = "Herbalism",
    ["Peletería"] = "Leatherworking",
    ["Minería"] = "Mining",
    ["Desuello"] = "Skinning",
    ["Sastrería"] = "Tailoring",
    --PT
    ["Alquimia"] = "Alchemy",
    ["Ferraria"] = "Blacksmithing",
    ["Encantamento"] = "Enchanting",
    ["Engenharia"] = "Engineering",
    ["Herborismo"] = "Herbalism",
    ["Couraria"] = "Leatherworking",
    ["Mineração"] = "Mining",
    ["Esfolamento"] = "Skinning",
    ["Alfaiataria"] = "Tailoring",
    --FR
    ["Alchimie"] = "Alchemy",
    ["Forge"] = "Blacksmithing",
    ["Enchantement"] = "Enchanting",
    ["Ingénierie"] = "Engineering",
    ["Herboristerie"] = "Herbalism",
    ["Travail du cuir"] = "Leatherworking",
    ["Minage"] = "Mining",
    ["Dépeçage"] = "Skinning",
    ["Couture"] = "Tailoring",
    --RU
    ["Алхимия"] = "Alchemy",
    ["Кузнечное дело"] = "Blacksmithing",
    ["Наложение чар"] = "Enchanting",
    ["Инженерное дело"] = "Engineering",
    ["Травничество"] = "Herbalism",
    ["Кожевничество"] = "Leatherworking",
    ["Горное дело"] = "Mining",
    ["Снятие шкур"] = "Skinning",
    ["Портняжное дело"] = "Tailoring",
    --KO
    ["연금술"] = "Alchemy",
    ["대장기술"] = "Blacksmithing",
    ["마법부여"] = "Enchanting",
    ["기계공학"] = "Engineering",
    ["약초 채집"] = "Herbalism",
    ["가죽 세공"] = "Leatherworking",
    ["채광"] = "Mining",
    ["무두질"] = "Skinning",
    ["재봉술"] = "Tailoring",
    --CN
    ["炼金术"] = "Alchemy",
    ["锻造"] = "Blacksmithing",
    ["附魔"] = "Enchanting",
    ["工程学"] = "Engineering",
    ["草药学"] = "Herbalism",
    ["制皮"] = "Leatherworking",
    ["采矿"] = "Mining",
    ["剥皮"] = "Skinning",
    ["裁缝"] = "Tailoring",
    --TW
    ["煉金術"] = "Alchemy",
    ["鍛造"] = "Blacksmithing",
    ["附魔"] = "Enchanting",
    ["工程學"] = "Engineering",
    ["草藥學"] = "Herbalism",
    ["製皮"] = "Leatherworking",
    ["採礦"] = "Mining",
    ["剝皮"] = "Skinning",
    ["裁縫"] = "Tailoring",
}

addon.professions.locale.FACTION_NAMES = {
    --EN
    ["Alliance"] = "Alliance",
    ["Horde"] = "Horde",
    --DE
    ["Allianz"] = "Alliance",
    ["Horde"] = "Horde",
    --ES
    ["Alianza"] = "Alliance",
    ["Horda"] = "Horde",
    --AL
    --PT
    ["Aliança"] = "Alliance",
    ["Horda"] = "Horde",
    --FR
    ["Alliance"] = "Alliance",
    ["Horde"] = "Horde",
    --RU
    ["Альянс"] = "Alliance",
    ["Орда"] = "Horde",
    --KO
    ["얼라이언스 연합"] = "Alliance",
    ["호드 연합"] = "Horde",
    --CN
    ["联盟"] = "Alliance",
    ["部落"] = "Horde",
    --TW
    ["聯盟"] = "Alliance",
    ["部落"] = "Horde",
}