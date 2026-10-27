-- Rôles de combat. Purement descriptifs : le comportement vient des actions déclarées.

local Freeze = require(script.Parent.Parent.Util.Freeze)

local Roles = {
	Info = {
		Warrior = { name = "Guerrier", description = "Dégâts soutenus en première ligne." },
		Tank = { name = "Tank", description = "Encaisse et protège l'équipe." },
		Healer = { name = "Soigneur", description = "Restaure les PV des alliés." },
		Assassin = { name = "Assassin", description = "Frappe la ligne arrière adverse." },
		Mage = { name = "Mage", description = "Dégâts de zone et contrôle." },
		Support = { name = "Support", description = "Renforce et protège les alliés." },
	},
	Rows = {
		Front = { name = "Ligne avant" },
		Back = { name = "Ligne arrière" },
	},
}

function Roles.isValid(role: any): boolean
	return type(role) == "string" and Roles.Info[role] ~= nil
end

return Freeze.deep(Roles)
