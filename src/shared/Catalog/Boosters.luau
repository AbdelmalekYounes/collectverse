-- Définitions des boosters (gratuits, obtenus en jeu uniquement).
--
-- Les poids sont des entiers sur 1000 pour des probabilités exactes et lisibles.
-- Tirage d'un emplacement : 1) rareté selon les poids, 2) carte uniforme parmi
-- les cartes de cette rareté présentes dans le pool (CardCatalog.getBoosterPool).
-- Les `guaranteedSlots` derniers emplacements utilisent `guaranteedWeights`,
-- ce qui garantit au moins une carte Rare ou supérieure par booster.

local Freeze = require(script.Parent.Parent.Util.Freeze)

local Boosters = {
	FirstRift = {
		id = "FirstRift",
		name = "First Rift",
		description = "Cinq cartes issues de la première faille. Au moins une carte Rare ou supérieure.",
		cardCount = 5,
		guaranteedSlots = 1,
		standardWeights = { Common = 700, Rare = 230, Epic = 60, Legendary = 10 },
		guaranteedWeights = { Rare = 800, Epic = 170, Legendary = 30 },
	},
}

return Freeze.deep(Boosters)
