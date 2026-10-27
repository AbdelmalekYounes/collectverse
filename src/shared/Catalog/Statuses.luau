-- Effets temporaires applicables par l'effet déclaratif { type = "Status" }.
-- needsPower : l'effet exige une valeur `power` (pourcentage).
-- detail : indique au module de texte comment présenter cette valeur.

local Freeze = require(script.Parent.Parent.Util.Freeze)

local Statuses = {
	Info = {
		Burn = { name = "Brûlure", kind = "Debuff", needsPower = true, detail = "PerTurnAttack" },
		Regen = { name = "Régénération", kind = "Buff", needsPower = true, detail = "PerTurnAttack" },
		Guard = { name = "Garde", kind = "Buff", needsPower = false, detail = "Guard" },
		Taunt = { name = "Provocation", kind = "Buff", needsPower = false },
		AttackUp = { name = "Attaque renforcée", kind = "Buff", needsPower = true, detail = "AttackBonus" },
		DefenseDown = { name = "Armure brisée", kind = "Debuff", needsPower = true, detail = "DefenseMalus" },
		Stun = { name = "Étourdissement", kind = "Debuff", needsPower = false },
	},
}

return Freeze.deep(Statuses)
