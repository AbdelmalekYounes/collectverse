-- Interprète les effets déclaratifs du catalogue (Damage, Heal, Shield, Status).
-- Aucune règle propre à un combattant : tout passe par ces fonctions génériques.
-- Chaque modification d'état ajoute un événement à `events` pour l'affichage.

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local Elements = require(Shared.Catalog.Elements)
local Units = require(script.Parent.Units)

local Battle = GameConfig.Battle

local AbilitySystem = {}

local function round(value: number): number
	return math.floor(value + 0.5)
end

-- Dégâts = puissance × stat × K / (K + DÉF effective) × élément × Garde, arrondis, minimum MinDamage.
function AbilitySystem.computeDamage(attacker, defender, power: number, scaling: string): number
	local raw = power * Units.effectiveStat(attacker, scaling)
	local constant = Battle.DefenseConstant
	local amount = raw * constant / (constant + Units.effectiveStat(defender, "defense"))
	amount *= Elements.getMultiplier(attacker.element, defender.element)
	if Units.hasStatus(defender, "Guard") then
		amount *= Battle.GuardDamageTakenMultiplier
	end
	return math.max(Battle.MinDamage, round(amount))
end

-- Inflige un montant déjà calculé : le bouclier absorbe en premier.
function AbilitySystem.applyDamage(target, amount: number, events, sourceUid: string?, kind: string?)
	local absorbed = math.min(target.shield, amount)
	target.shield -= absorbed
	local hpLoss = math.min(target.hp, amount - absorbed)
	target.hp -= hpLoss
	if amount > 0 then
		target.charge = math.min(Battle.UltimateChargeMax, target.charge + Battle.ChargeOnDamageTaken)
	end
	table.insert(events, {
		type = "Damage",
		kind = kind or "Hit",
		source = sourceUid,
		target = target.uid,
		amount = amount,
		absorbed = absorbed,
		hp = target.hp,
		shield = target.shield,
	})
	if target.hp <= 0 then
		target.alive = false
		target.shield = 0
		target.charge = 0
		table.clear(target.statuses)
		table.insert(events, { type = "Defeated", target = target.uid })
	end
	return hpLoss
end

function AbilitySystem.applyHeal(target, amount: number, events, sourceUid: string?, kind: string?)
	local healed = math.min(amount, target.maxHp - target.hp)
	target.hp += healed
	table.insert(events, {
		type = "Heal",
		kind = kind or "Heal",
		source = sourceUid,
		target = target.uid,
		amount = healed,
		hp = target.hp,
	})
	return healed
end

function AbilitySystem.applyShield(target, amount: number, events, sourceUid: string?)
	-- Les boucliers se cumulent, plafonnés aux PV max.
	target.shield = math.min(target.maxHp, target.shield + amount)
	table.insert(events, {
		type = "Shield",
		source = sourceUid,
		target = target.uid,
		amount = amount,
		shield = target.shield,
	})
end

-- Réappliquer un statut actif conserve la valeur la plus forte et la durée la plus longue.
function AbilitySystem.applyStatus(caster, target, effect, events)
	local power = effect.power or 0
	-- Brûlure et régénération figent leur valeur par tour à l'application.
	local tickValue = round(power * Units.effectiveStat(caster, "attack"))
	local current = target.statuses[effect.status]
	if current then
		current.duration = math.max(current.duration, effect.duration)
		current.power = math.max(current.power, power)
		current.tickValue = math.max(current.tickValue, tickValue)
	else
		target.statuses[effect.status] = {
			duration = effect.duration,
			power = power,
			tickValue = tickValue,
			source = caster.uid,
		}
	end
	table.insert(events, {
		type = "Status",
		source = caster.uid,
		target = target.uid,
		status = effect.status,
		duration = target.statuses[effect.status].duration,
	})
end

function AbilitySystem.applyEffect(actor, target, effect, events)
	if effect.type == "Damage" then
		local amount = AbilitySystem.computeDamage(actor, target, effect.power, effect.scaling)
		AbilitySystem.applyDamage(target, amount, events, actor.uid)
	elseif effect.type == "Heal" then
		AbilitySystem.applyHeal(
			target,
			round(effect.power * Units.effectiveStat(actor, effect.scaling)),
			events,
			actor.uid
		)
	elseif effect.type == "Shield" then
		AbilitySystem.applyShield(
			target,
			round(effect.power * Units.effectiveStat(actor, effect.scaling)),
			events,
			actor.uid
		)
	elseif effect.type == "Status" then
		AbilitySystem.applyStatus(actor, target, effect, events)
	else
		error("AbilitySystem : type d'effet inconnu " .. tostring(effect.type))
	end
end

-- Exécute tous les effets d'une action. Un effet `target = "Self"` s'applique
-- une seule fois au lanceur ; les autres s'appliquent à chaque cible encore debout.
function AbilitySystem.execute(actor, action, targets, events)
	for _, effect in action.effects do
		local recipients = if effect.target == "Self" then { actor } else targets
		for _, target in recipients do
			if target.alive then
				AbilitySystem.applyEffect(actor, target, effect, events)
			end
		end
	end
end

return AbilitySystem
