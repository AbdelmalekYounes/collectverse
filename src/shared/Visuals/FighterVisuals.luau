-- Apparence provisoire de chaque combattant, séparée de sa définition de gameplay.
-- archetype choisit la silhouette (arme, accessoires) dans ModelFactory.
-- Pour remplacer un modèle par un asset final, voir ModelFactory.build.

local Freeze = require(script.Parent.Parent.Util.Freeze)

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

local FighterVisuals = {
	F001 = { -- Kael
		archetype = "Warrior",
		body = hex("#7A2418"),
		trim = hex("#2B1C1A"),
		skin = hex("#E8B48A"),
		glow = hex("#FF7A3D"),
		scale = 1,
		bulk = 1,
	},
	F002 = { -- Terra
		archetype = "Tank",
		body = hex("#6B5434"),
		trim = hex("#3B4038"),
		skin = hex("#C9925F"),
		glow = hex("#F0B35A"),
		scale = 1.1,
		bulk = 1.3,
	},
	F003 = { -- Lyra
		archetype = "Healer",
		body = hex("#2C6FB0"),
		trim = hex("#1C2E52"),
		skin = hex("#F0C9A8"),
		hair = hex("#9FE3F5"),
		glow = hex("#5FD0FF"),
		scale = 1,
		bulk = 0.9,
	},
	F004 = { -- Nox
		archetype = "Assassin",
		body = hex("#2A2340"),
		trim = hex("#15121F"),
		skin = hex("#B9A6D9"),
		glow = hex("#A86CFF"),
		scale = 0.95,
		bulk = 0.9,
	},
	F005 = { -- Astra
		archetype = "Mage",
		body = hex("#3B3A78"),
		trim = hex("#1D1C3E"),
		skin = hex("#F2D3B3"),
		glow = hex("#F7E866"),
		scale = 1,
		bulk = 0.9,
	},
	F006 = { -- Oris
		archetype = "Support",
		body = hex("#E9E2CF"),
		trim = hex("#B89A55"),
		skin = hex("#F5DEC4"),
		glow = hex("#FFE9A8"),
		scale = 1.05,
		bulk = 1,
	},
}

return Freeze.deep(FighterVisuals)
