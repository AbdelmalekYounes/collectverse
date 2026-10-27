-- IA des ennemis : produit un plan toujours valide, de façon déterministe.
--
-- 1. Les ultimes prêts et utiles sont servis en premier, du plus rapide au plus lent.
--    Si un ultime prêt n'est pas encore abordable, l'équipe économise son énergie.
-- 2. Puis, pour chaque autre combattant, du plus rapide au plus lent :
--    compétence utile (en mode économie : seulement un soin urgent),
--    défense sous 30 % de PV, sinon attaque normale.
-- Cible ennemie : le moins de PV restants. Cible alliée : le plus faible ratio de PV.
--
-- Sans l'économie d'énergie, le combattant le plus rapide dépensait l'énergie du
-- tour sur sa compétence et aucun ultime (5 ou 6 énergie) n'était jamais lancé.

local Shared = script.Parent.Parent
local Targets = require(Shared.Catalog.Targets)
local BattleEngine = require(script.Parent.BattleEngine)
local Targeting = require(script.Parent.Targeting)
local Units = require(script.Parent.Units)

local CombatAI = {}

local LOW_HP_DEFEND = 0.3
local HEAL_THRESHOLD = 0.7
local URGENT_HEAL_THRESHOLD = 0.4
local SHIELD_THRESHOLD = 0.85

-- Effet qui détermine l'utilité d'une action : le premier effet offensif ou destiné
-- aux autres (ex. le soin de Lyra, pas sa régénération annexe).
local function primaryEffect(action)
	for _, effect in action.effects do
		if effect.type == "Damage" or effect.target ~= "Self" then
			return effect
		end
	end
	return nil
end

-- Une action offensive est toujours utile ; une action de soutien seulement si un allié en a besoin.
local function isUseful(battle, unit, action, healThreshold: number): boolean
	local primary = primaryEffect(action)
	if not primary then
		return false
	end
	if primary.type == "Damage" then
		return true
	end
	for _, ally in Units.living(battle, unit.side) do
		local ratio = Units.hpRatio(ally)
		if primary.type == "Heal" and ratio < healThreshold then
			return true
		elseif primary.type == "Shield" and ratio < SHIELD_THRESHOLD then
			return true
		elseif primary.type == "Status" and not Units.hasStatus(ally, primary.status) then
			return true
		end
	end
	return false
end

local function isUrgentHeal(battle, unit, action): boolean
	local primary = primaryEffect(action)
	return primary ~= nil and primary.type == "Heal" and isUseful(battle, unit, action, URGENT_HEAL_THRESHOLD)
end

local function chooseTarget(battle, unit, action): string?
	if not Targeting.needsChoice(action.target) then
		return nil
	end
	local targetsEnemy = Targets.Rules[action.target].side == "Enemy"
	local best = nil
	for _, uid in Targeting.choices(battle, unit, action.target) do
		local candidate = battle.units[uid]
		local better
		if best == nil then
			better = true
		elseif targetsEnemy then
			better = candidate.hp < best.hp
		else
			better = Units.hpRatio(candidate) < Units.hpRatio(best)
		end
		if better then
			best = candidate
		end
	end
	return best and best.uid
end

function CombatAI.choosePlan(battle, side: string)
	local budget = battle.energy[side]
	local units = {}
	for _, unit in Units.living(battle, side) do
		if not Units.hasStatus(unit, "Stun") then
			table.insert(units, unit)
		end
	end
	table.sort(units, function(a, b)
		if a.speed ~= b.speed then
			return a.speed > b.speed
		end
		return a.slot < b.slot
	end)

	local plan = {}
	local function assign(unit, slot: string)
		local action = BattleEngine.getAction(unit, slot)
		budget -= action.cost
		plan[unit.uid] = { slot = slot, target = chooseTarget(battle, unit, action) }
	end

	-- 1. Ultimes prêts
	local saving = false
	for _, unit in units do
		local ultimate = BattleEngine.getAction(unit, "ultimate")
		if BattleEngine.checkAction(battle, unit, "ultimate") and isUseful(battle, unit, ultimate, HEAL_THRESHOLD) then
			if ultimate.cost <= budget then
				assign(unit, "ultimate")
			else
				saving = true
			end
		end
	end

	-- 2. Les autres combattants
	for _, unit in units do
		if plan[unit.uid] then
			continue
		end
		local skill = BattleEngine.getAction(unit, "skill")
		local wantsSkill = if saving
			then isUrgentHeal(battle, unit, skill)
			else isUseful(battle, unit, skill, HEAL_THRESHOLD)
		if skill.cost <= budget and wantsSkill then
			assign(unit, "skill")
		elseif Units.hpRatio(unit) < LOW_HP_DEFEND and not Units.hasStatus(unit, "Guard") then
			assign(unit, "defend")
		else
			assign(unit, "basic")
		end
	end
	return plan
end

return CombatAI
