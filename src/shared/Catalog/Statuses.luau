-- Effets temporaires applicables par l'effet déclaratif { type = "Status" }.
-- needsPower : l'effet exige une valeur `power` (pourcentage).
-- detail : indique au module de texte comment présenter cette valeur.
-- consumedOnSkip : la durée diminue quand le statut fait perdre une action,
--   et non en fin de tour (sinon un étourdissement appliqué après l'action
--   de la cible n'aurait aucun effet).
-- Order fixe l'ordre de traitement en fin de tour (résolution déterministe).

local Freeze = require(script.Parent.Parent.Util.Freeze)

local Statuses = {
	Order = { "Burn", "Regen", "Guard", "Taunt", "AttackUp", "DefenseDown", "Stun" },
	Info = {
		Burn = { name = "Brûlure", kind = "Debuff", needsPower = true, detail = "PerTurnAttack" },
		Regen = { name = "Régénération", kind = "Buff", needsPower = true, detail = "PerTurnAttack" },
		Guard = { name = "Garde", kind = "Buff", needsPower = false, detail = "Guard" },
		Taunt = { name = "Provocation", kind = "Buff", needsPower = false },
		AttackUp = { name = "Attaque renforcée", kind = "Buff", needsPower = true, detail = "AttackBonus" },
		DefenseDown = { name = "Armure brisée", kind = "Debuff", needsPower = true, detail = "DefenseMalus" },
		Stun = { name = "Étourdissement", kind = "Debuff", needsPower = false, consumedOnSkip = true },
	},
}

return Freeze.deep(Statuses)
