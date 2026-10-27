-- Règles de ciblage des actions.
-- side : camp visé ("Enemy", "Ally" ou "Self").
-- scope : "Single" (une cible) ou "All" (tout le camp).
-- ignoresFrontLine : la cible peut être choisie en ligne arrière même si la ligne avant vit.
-- automatic : la cible est choisie par le moteur, pas par le joueur.
-- text / followText : formulations utilisées par AbilityText.

local Freeze = require(script.Parent.Parent.Util.Freeze)

local Targets = {
	Rules = {
		SingleEnemy = {
			side = "Enemy",
			scope = "Single",
			ignoresFrontLine = false,
			automatic = false,
			text = "à un ennemi",
			followText = "à la cible",
		},
		SingleEnemyAny = {
			side = "Enemy",
			scope = "Single",
			ignoresFrontLine = true,
			automatic = false,
			text = "à un ennemi au choix, même en ligne arrière",
			followText = "à la cible",
		},
		AllEnemies = {
			side = "Enemy",
			scope = "All",
			ignoresFrontLine = true,
			automatic = true,
			text = "à tous les ennemis",
			followText = "aux cibles",
		},
		Self = {
			side = "Self",
			scope = "Single",
			ignoresFrontLine = true,
			automatic = true,
			text = "à soi-même",
			followText = "à soi-même",
		},
		SingleAlly = {
			side = "Ally",
			scope = "Single",
			ignoresFrontLine = true,
			automatic = false,
			text = "à un allié",
			followText = "à la cible",
		},
		LowestHpAlly = {
			side = "Ally",
			scope = "Single",
			ignoresFrontLine = true,
			automatic = true,
			text = "à l'allié le plus blessé",
			followText = "à la cible",
		},
		AllAllies = {
			side = "Ally",
			scope = "All",
			ignoresFrontLine = true,
			automatic = true,
			text = "à tous les alliés",
			followText = "aux alliés",
		},
	},
}

return Freeze.deep(Targets)
