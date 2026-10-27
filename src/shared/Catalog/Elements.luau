-- Éléments et table d'avantages.
-- Cycle : Eau > Feu > Terre > Foudre > Eau. Ombre et Lumière se dominent mutuellement.

local Freeze = require(script.Parent.Parent.Util.Freeze)
local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local Elements = {
	Order = { "Fire", "Earth", "Water", "Shadow", "Lightning", "Light" },
	Info = {
		Fire = { name = "Feu", strongAgainst = "Earth" },
		Earth = { name = "Terre", strongAgainst = "Lightning" },
		Water = { name = "Eau", strongAgainst = "Fire" },
		Shadow = { name = "Ombre", strongAgainst = "Light" },
		Lightning = { name = "Foudre", strongAgainst = "Water" },
		Light = { name = "Lumière", strongAgainst = "Shadow" },
	},
}

function Elements.isValid(element: any): boolean
	return type(element) == "string" and Elements.Info[element] ~= nil
end

-- Multiplicateur appliqué aux dégâts d'un attaquant contre un défenseur.
-- L'avantage est vérifié en premier : Ombre/Lumière donne donc ×1,25 dans les deux sens.
function Elements.getMultiplier(attacker: string, defender: string): number
	local attackerInfo = Elements.Info[attacker]
	local defenderInfo = Elements.Info[defender]
	if not attackerInfo or not defenderInfo then
		return 1
	end
	if attackerInfo.strongAgainst == defender then
		return GameConfig.Battle.ElementAdvantage
	end
	if defenderInfo.strongAgainst == attacker then
		return GameConfig.Battle.ElementDisadvantage
	end
	return 1
end

return Freeze.deep(Elements)
