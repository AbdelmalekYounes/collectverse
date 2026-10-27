-- Raretés des cartes, de la plus commune à la plus rare.
-- Les couleurs associées vivent dans Config/Theme (présentation).

local Freeze = require(script.Parent.Parent.Util.Freeze)

local Rarities = {
	Order = { "Common", "Rare", "Epic", "Legendary" },
	Info = {
		Common = { name = "Commune", rank = 1 },
		Rare = { name = "Rare", rank = 2 },
		Epic = { name = "Épique", rank = 3 },
		Legendary = { name = "Légendaire", rank = 4 },
	},
}

function Rarities.isValid(rarity: any): boolean
	return type(rarity) == "string" and Rarities.Info[rarity] ~= nil
end

return Freeze.deep(Rarities)
