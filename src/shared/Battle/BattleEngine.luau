-- Moteur de combat au tour par tour, 5 contre 5. Logique pure et déterministe :
-- aucun hasard, aucune dépendance aux services Roblox. Le serveur l'exécute ;
-- le client reçoit une copie de l'état (snapshot) et la liste des événements.
--
-- Déroulement d'un tour :
--  1. chaque camp planifie une action par combattant (validatePlan) ;
--  2. les actions s'exécutent par vitesse décroissante (égalité : camp allié,
--     puis emplacement le plus petit) ; l'énergie est dépensée à l'exécution ;
--  3. fin de tour : brûlures et régénérations, durées des statuts, +énergie.
-- Le combat se termine dès qu'un camp n'a plus de combattant debout,
-- ou par une égalité après MaxTurns tours.

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local CardCatalog = require(Shared.Catalog.CardCatalog)
local Statuses = require(Shared.Catalog.Statuses)
local AbilitySystem = require(script.Parent.AbilitySystem)
local Targeting = require(script.Parent.Targeting)
local TeamRules = require(script.Parent.TeamRules)
local Units = require(script.Parent.Units)

local Battle = GameConfig.Battle

local BattleEngine = {}

export type Entry = { fighterId: string, statMultiplier: number?, name: string? }
export type PlannedAction = { uid: string, slot: string?, target: string? }

local function buildUnit(side: string, slot: number, entry: Entry)
	local fighter = CardCatalog.getFighter(entry.fighterId)
	if not fighter then
		error("BattleEngine : combattant inconnu " .. tostring(entry.fighterId))
	end
	local multiplier = entry.statMultiplier or 1
	local function scaled(value: number): number
		return math.max(1, math.floor(value * multiplier + 0.5))
	end
	local maxHp = scaled(fighter.stats.maxHp)
	return {
		uid = (if side == "Ally" then "A" else "E") .. slot,
		side = side,
		slot = slot,
		row = TeamRules.rowOfSlot(slot),
		fighterId = fighter.id,
		name = entry.name or fighter.name,
		element = fighter.element,
		role = fighter.role,
		maxHp = maxHp,
		hp = maxHp,
		attack = scaled(fighter.stats.attack),
		defense = scaled(fighter.stats.defense),
		speed = scaled(fighter.stats.speed),
		shield = 0,
		charge = 0,
		alive = true,
		statuses = {},
	}
end

function BattleEngine.create(allyEntries: { Entry }, enemyEntries: { Entry })
	local size = GameConfig.Team.Size
	assert(#allyEntries >= 1 and #allyEntries <= size, "BattleEngine : nombre d'alliés invalide")
	assert(#enemyEntries >= 1 and #enemyEntries <= size, "BattleEngine : nombre d'ennemis invalide")

	local battle = {
		turn = 1,
		maxTurns = Battle.MaxTurns,
		status = "Planning",
		winner = nil :: string?,
		energy = { Ally = Battle.StartingEnergy, Enemy = Battle.StartingEnergy },
		maxEnergy = Battle.MaxEnergy,
		chargeMax = Battle.UltimateChargeMax,
		units = {},
		unitOrder = {},
	}
	for side, entries in { Ally = allyEntries, Enemy = enemyEntries } do
		for slot, entry in entries do
			local unit = buildUnit(side, slot, entry)
			battle.units[unit.uid] = unit
		end
	end
	-- Ordre stable : alliés puis ennemis, par emplacement.
	for _, prefix in { "A", "E" } do
		for slot = 1, size do
			if battle.units[prefix .. slot] then
				table.insert(battle.unitOrder, prefix .. slot)
			end
		end
	end
	return battle
end

-- Combat PvE : l'équipe du joueur contre les Échos d'une rencontre.
function BattleEngine.createEncounter(teamIds: { string }, encounter)
	local allies = {}
	for _, id in teamIds do
		table.insert(allies, { fighterId = id })
	end
	local enemies = {}
	for _, enemy in encounter.enemies do
		local fighter = CardCatalog.getFighter(enemy.fighterId)
		table.insert(enemies, {
			fighterId = enemy.fighterId,
			statMultiplier = enemy.statMultiplier,
			name = (fighter and fighter.name or "?") .. " (Écho)",
		})
	end
	return BattleEngine.create(allies, enemies)
end

function BattleEngine.getAction(unit, slot: string)
	local fighter = CardCatalog.getFighter(unit.fighterId)
	return fighter and fighter.actions[slot]
end

-- L'action est-elle utilisable par ce combattant, hors question d'énergie ?
function BattleEngine.checkAction(battle, unit, slot: string): (boolean, string?)
	if not BattleEngine.getAction(unit, slot) then
		return false, "Action inconnue"
	end
	if not unit.alive then
		return false, "Combattant à terre"
	end
	if slot == "ultimate" and unit.charge < battle.chargeMax then
		return false, "Jauge d'ultime incomplète"
	end
	return true, nil
end

-- Valide le plan d'un camp et le normalise en liste d'actions.
-- plan : { [uid] = { slot, target? } }. Un combattant sans entrée effectue
-- une attaque normale sur la première cible valide. Un combattant étourdi
-- reçoit une entrée sans action (il perdra son tour).
function BattleEngine.validatePlan(battle, side: string, plan: any): (boolean, any)
	if battle.status ~= "Planning" then
		return false, "Le combat est terminé"
	end
	if type(plan) ~= "table" then
		return false, "Plan invalide"
	end
	for uid, entry in plan do
		local unit = type(uid) == "string" and battle.units[uid]
		if not unit or unit.side ~= side then
			return false, "Combattant invalide dans le plan"
		end
		if type(entry) ~= "table" or type(entry.slot) ~= "string" then
			return false, "Action invalide pour " .. unit.name
		end
		if entry.target ~= nil and type(entry.target) ~= "string" then
			return false, "Cible invalide pour " .. unit.name
		end
	end

	local normalized: { PlannedAction } = {}
	local cost = 0
	for _, unit in Units.living(battle, side) do
		if Units.hasStatus(unit, "Stun") then
			table.insert(normalized, { uid = unit.uid })
			continue
		end
		local entry = plan[unit.uid]
		local slot = if entry then entry.slot else "basic"
		local ok, reason = BattleEngine.checkAction(battle, unit, slot)
		if not ok then
			return false, unit.name .. " : " .. (reason :: string)
		end
		local action = BattleEngine.getAction(unit, slot)
		local target = nil
		if Targeting.needsChoice(action.target) then
			local choices = Targeting.choices(battle, unit, action.target)
			target = if entry then entry.target else nil
			if target == nil then
				target = choices[1]
			elseif not table.find(choices, target) then
				return false, unit.name .. " : cible invalide"
			end
		end
		cost += action.cost
		table.insert(normalized, { uid = unit.uid, slot = slot, target = target })
	end

	if cost > battle.energy[side] then
		return false, string.format("Énergie insuffisante (%d requise, %d disponible)", cost, battle.energy[side])
	end
	return true, normalized
end

local function addEnergy(battle, side: string, amount: number)
	battle.energy[side] = math.min(battle.maxEnergy, battle.energy[side] + amount)
end

local function checkVictory(battle, events): boolean
	local alliesStanding = #Units.living(battle, "Ally") > 0
	local enemiesStanding = #Units.living(battle, "Enemy") > 0
	if alliesStanding and enemiesStanding then
		return false
	end
	battle.status = "Finished"
	battle.winner = if alliesStanding then "Ally" elseif enemiesStanding then "Enemy" else "Draw"
	table.insert(events, { type = "BattleEnd", winner = battle.winner })
	return true
end

local function performAction(battle, unit, planned: PlannedAction, events)
	local slot = planned.slot :: string
	local action = BattleEngine.getAction(unit, slot)
	if battle.energy[unit.side] < action.cost then
		-- Ne peut pas arriver avec un plan validé ; garde-fou défensif.
		table.insert(events, { type = "Skip", actor = unit.uid, reason = "Energy" })
		return
	end
	battle.energy[unit.side] -= action.cost

	local targets = Targeting.resolve(battle, unit, action.target, planned.target)
	local targetIds = {}
	for _, target in targets do
		table.insert(targetIds, target.uid)
	end
	table.insert(events, {
		type = "Action",
		actor = unit.uid,
		slot = slot,
		actionId = action.id,
		cost = action.cost,
		targets = targetIds,
	})

	AbilitySystem.execute(unit, action, targets, events)

	if slot == "ultimate" then
		unit.charge = 0
	else
		unit.charge = math.min(battle.chargeMax, unit.charge + Battle.ChargeOnAction)
	end
	if slot == "defend" and Battle.DefendEnergyGain > 0 then
		addEnergy(battle, unit.side, Battle.DefendEnergyGain)
		table.insert(events, { type = "Energy", side = unit.side, energy = battle.energy[unit.side] })
	end
end

local function endOfTurn(battle, events)
	-- Effets périodiques, dans un ordre fixe
	for _, uid in battle.unitOrder do
		local unit = battle.units[uid]
		for _, statusId in Statuses.Order do
			if not unit.alive then
				break
			end
			local status = unit.statuses[statusId]
			if status and statusId == "Burn" then
				AbilitySystem.applyDamage(unit, status.tickValue, events, status.source, "Burn")
			elseif status and statusId == "Regen" then
				AbilitySystem.applyHeal(unit, status.tickValue, events, status.source, "Regen")
			end
		end
	end
	if checkVictory(battle, events) then
		return
	end

	-- Durées
	for _, uid in battle.unitOrder do
		local unit = battle.units[uid]
		for _, statusId in Statuses.Order do
			local status = unit.statuses[statusId]
			if status and not Statuses.Info[statusId].consumedOnSkip then
				status.duration -= 1
				if status.duration <= 0 then
					unit.statuses[statusId] = nil
					table.insert(events, { type = "StatusExpired", target = uid, status = statusId })
				end
			end
		end
	end

	addEnergy(battle, "Ally", Battle.EnergyPerTurn)
	addEnergy(battle, "Enemy", Battle.EnergyPerTurn)
	table.insert(events, {
		type = "TurnEnd",
		turn = battle.turn,
		energy = { Ally = battle.energy.Ally, Enemy = battle.energy.Enemy },
	})

	battle.turn += 1
	if battle.turn > battle.maxTurns then
		battle.status = "Finished"
		battle.winner = "Draw"
		table.insert(events, { type = "BattleEnd", winner = "Draw" })
	end
end

-- Résout un tour à partir de deux plans normalisés par validatePlan.
function BattleEngine.resolveTurn(battle, allyPlan: { PlannedAction }, enemyPlan: { PlannedAction })
	assert(battle.status == "Planning", "BattleEngine : le combat est terminé")

	local queue = {}
	for _, plan in { allyPlan, enemyPlan } do
		for _, planned in plan do
			table.insert(queue, { planned = planned, unit = battle.units[planned.uid] })
		end
	end
	table.sort(queue, function(a, b)
		if a.unit.speed ~= b.unit.speed then
			return a.unit.speed > b.unit.speed
		end
		if a.unit.side ~= b.unit.side then
			return a.unit.side == "Ally"
		end
		return a.unit.slot < b.unit.slot
	end)

	local events = { { type = "TurnStart", turn = battle.turn } }
	for _, item in queue do
		local unit = item.unit
		if not unit.alive then
			continue
		end
		local stun = unit.statuses.Stun
		if stun then
			stun.duration -= 1
			if stun.duration <= 0 then
				unit.statuses.Stun = nil
			end
			table.insert(events, { type = "Skip", actor = unit.uid, reason = "Stun" })
			continue
		end
		if item.planned.slot then
			performAction(battle, unit, item.planned, events)
			if checkVictory(battle, events) then
				return events
			end
		end
	end

	endOfTurn(battle, events)
	return events
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

-- Copie indépendante de l'état, sérialisable pour un RemoteFunction.
function BattleEngine.snapshot(battle)
	return deepCopy(battle)
end

return BattleEngine
