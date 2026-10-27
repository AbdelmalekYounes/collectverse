-- Rencontres PvE. Les ennemis réutilisent les définitions des combattants
-- (mêmes actions déclaratives) avec un multiplicateur de statistiques.
-- L'ordre de `enemies` donne les emplacements : 1 à 3 en ligne avant, 4 et 5 en ligne arrière.

local Freeze = require(script.Parent.Parent.Util.Freeze)

local Encounters = {
	RiftEcho1 = {
		id = "RiftEcho1",
		name = "Faille instable",
		description = "Des Échos s'échappent de la faille centrale.",
		enemies = {
			{ fighterId = "F002", statMultiplier = 0.85 },
			{ fighterId = "F001", statMultiplier = 0.85 },
			{ fighterId = "F004", statMultiplier = 0.85 },
			{ fighterId = "F003", statMultiplier = 0.85 },
			{ fighterId = "F005", statMultiplier = 0.85 },
		},
	},
}

return Freeze.deep(Encounters)
