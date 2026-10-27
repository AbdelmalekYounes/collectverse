-- Génère les descriptions d'actions à partir des effets déclarés.
-- Le texte affiché reste ainsi toujours fidèle aux données réellement utilisées en combat.

local Catalog = script.Parent
local GameConfig = require(Catalog.Parent.Config.GameConfig)
local Statuses = require(Catalog.Statuses)
local Targets = require(Catalog.Targets)

local AbilityText = {}

local SLOT_LABELS = {
	basic = "Attaque",
	skill = "Compétence",
	ultimate = "Ultime",
	defend = "Défense",
}

local SCALING_LABELS = {
	attack = "de l'ATQ",
	defense = "de la DÉF",
	maxHp = "des PV max",
}

local function percent(value: number): string
	return tostring(math.floor(value * 100 + 0.5)) .. " %"
end

local function turns(count: number): string
	return if count > 1 then (count .. " tours") else "1 tour"
end

local function statusDetail(effect, info): string
	if info.detail == "PerTurnAttack" then
		return " (" .. percent(effect.power) .. " de l'ATQ par tour)"
	elseif info.detail == "AttackBonus" then
		return " (+" .. percent(effect.power) .. " ATQ)"
	elseif info.detail == "DefenseMalus" then
		return " (-" .. percent(effect.power) .. " DÉF)"
	elseif info.detail == "Guard" then
		return " (dégâts subis -" .. percent(1 - GameConfig.Battle.GuardDamageTakenMultiplier) .. ")"
	end
	return ""
end

-- targetPhrase : formulation de la cible déjà résolue par describe().
function AbilityText.describeEffect(effect, targetPhrase: string): string
	local scaling = SCALING_LABELS[effect.scaling or "attack"] or ""
	if effect.type == "Damage" then
		return string.format("Inflige %s %s %s", percent(effect.power), scaling, targetPhrase)
	elseif effect.type == "Heal" then
		return string.format("Rend %s %s en PV %s", percent(effect.power), scaling, targetPhrase)
	elseif effect.type == "Shield" then
		return string.format("Octroie un bouclier de %s %s %s", percent(effect.power), scaling, targetPhrase)
	elseif effect.type == "Status" then
		local info = Statuses.Info[effect.status]
		if not info then
			return "Effet inconnu"
		end
		return string.format(
			"Applique %s%s pendant %s %s",
			info.name,
			statusDetail(effect, info),
			turns(effect.duration),
			targetPhrase
		)
	end
	return "Effet inconnu"
end

function AbilityText.describe(action): string
	local rule = Targets.Rules[action.target]
	local selfRule = Targets.Rules.Self
	local mentionedTargets = false
	local sentences = {}

	for _, effect in action.effects do
		local phrase
		if effect.target == "Self" or rule == nil then
			phrase = selfRule.text
		elseif mentionedTargets then
			-- Évite de répéter « à un ennemi » sur chaque effet d'une même action.
			phrase = rule.followText
		else
			phrase = rule.text
			mentionedTargets = true
		end
		table.insert(sentences, AbilityText.describeEffect(effect, phrase))
	end

	if action.slot == "defend" and GameConfig.Battle.DefendEnergyGain > 0 then
		table.insert(sentences, string.format("Rend %d énergie à l'équipe", GameConfig.Battle.DefendEnergyGain))
	end

	return table.concat(sentences, ". ") .. "."
end

function AbilityText.costText(action): string
	if action.slot == "ultimate" then
		return string.format("%d énergie + jauge", action.cost)
	end
	if action.cost == 0 then
		return "Gratuit"
	end
	return string.format("%d énergie", action.cost)
end

function AbilityText.slotLabel(slot: string): string
	return SLOT_LABELS[slot] or slot
end

return AbilityText
