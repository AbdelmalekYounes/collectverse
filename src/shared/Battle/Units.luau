-- Fonctions utilitaires sur les combattants d'un combat.
-- Elles acceptent l'état complet du moteur comme sa copie envoyée au client
-- (mêmes champs : units, unitOrder, side, slot, row, hp, statuses…).

local Units = {}

function Units.opposingSide(side: string): string
	return if side == "Ally" then "Enemy" else "Ally"
end

-- Combattants vivants d'un camp, dans l'ordre des emplacements.
function Units.living(battle, side: string)
	local result = {}
	for _, uid in battle.unitOrder do
		local unit = battle.units[uid]
		if unit.side == side and unit.alive then
			table.insert(result, unit)
		end
	end
	return result
end

function Units.hasStatus(unit, statusId: string): boolean
	return unit.statuses[statusId] ~= nil
end

function Units.statusPower(unit, statusId: string): number
	local status = unit.statuses[statusId]
	return if status and status.power then status.power else 0
end

function Units.hpRatio(unit): number
	return unit.hp / unit.maxHp
end

-- Statistique effective, modificateurs de statut compris.
function Units.effectiveStat(unit, scaling: string): number
	if scaling == "attack" then
		return unit.attack * (1 + Units.statusPower(unit, "AttackUp"))
	elseif scaling == "defense" then
		return unit.defense * math.max(0, 1 - Units.statusPower(unit, "DefenseDown"))
	elseif scaling == "maxHp" then
		return unit.maxHp
	end
	error("Units.effectiveStat : scaling inconnu " .. tostring(scaling))
end

-- Premier combattant avec le plus faible ratio de PV (égalité : premier emplacement).
function Units.lowestHpRatio(units)
	local best = nil
	for _, unit in units do
		if best == nil or Units.hpRatio(unit) < Units.hpRatio(best) then
			best = unit
		end
	end
	return best
end

return Units
