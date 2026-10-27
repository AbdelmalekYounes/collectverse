-- Ciblage : choix proposés au joueur pendant la planification, puis résolution
-- des cibles réelles au moment où l'action s'exécute.
--
-- Règles :
--  - SingleEnemy : la ligne avant protège la ligne arrière tant qu'elle compte un vivant.
--  - SingleEnemyAny : contourne cette protection (assassins).
--  - Provocation (Taunt) : à l'exécution, toute attaque ciblée d'un ennemi est
--    redirigée vers le premier provocateur vivant du camp visé.
--  - Si la cible choisie est tombée entre-temps, l'action vise le premier choix valide.

local Shared = script.Parent.Parent
local Targets = require(Shared.Catalog.Targets)
local Units = require(script.Parent.Units)

local Targeting = {}

local function uids(units): { string }
	local result = {}
	for _, unit in units do
		table.insert(result, unit.uid)
	end
	return result
end

function Targeting.needsChoice(ruleId: string): boolean
	local rule = Targets.Rules[ruleId]
	return rule ~= nil and not rule.automatic
end

-- Identifiants que le joueur peut choisir (vide pour une règle automatique).
function Targeting.choices(battle, actor, ruleId: string): { string }
	local rule = Targets.Rules[ruleId]
	if not rule or rule.automatic then
		return {}
	end
	if rule.side == "Enemy" then
		local enemies = Units.living(battle, Units.opposingSide(actor.side))
		if rule.ignoresFrontLine then
			return uids(enemies)
		end
		local front = {}
		for _, unit in enemies do
			if unit.row == "Front" then
				table.insert(front, unit)
			end
		end
		return uids(if #front > 0 then front else enemies)
	elseif rule.side == "Ally" then
		return uids(Units.living(battle, actor.side))
	end
	return {}
end

local function firstTaunter(battle, side: string)
	for _, unit in Units.living(battle, side) do
		if Units.hasStatus(unit, "Taunt") then
			return unit
		end
	end
	return nil
end

-- Cibles effectives au moment de l'exécution.
function Targeting.resolve(battle, actor, ruleId: string, chosenUid: string?)
	local rule = Targets.Rules[ruleId]
	if not rule then
		return {}
	end
	if rule.side == "Self" then
		return { actor }
	end

	local side = if rule.side == "Enemy" then Units.opposingSide(actor.side) else actor.side
	if rule.scope == "All" then
		return Units.living(battle, side)
	end
	if ruleId == "LowestHpAlly" then
		local target = Units.lowestHpRatio(Units.living(battle, side))
		return if target then { target } else {}
	end

	if rule.side == "Enemy" then
		local taunter = firstTaunter(battle, side)
		if taunter then
			return { taunter }
		end
	end

	local choices = Targeting.choices(battle, actor, ruleId)
	if chosenUid and table.find(choices, chosenUid) then
		return { battle.units[chosenUid] }
	end
	if choices[1] then
		return { battle.units[choices[1]] }
	end
	return {}
end

return Targeting
