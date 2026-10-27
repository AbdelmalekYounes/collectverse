-- Traduit les événements du moteur de combat en lignes de journal lisibles.
-- Renvoie nil pour les événements sans intérêt textuel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local AbilityText = require(Shared.Catalog.AbilityText)
local CardCatalog = require(Shared.Catalog.CardCatalog)
local Statuses = require(Shared.Catalog.Statuses)

local BattleLog = {}

local WINNER_TEXT = {
	Ally = "Victoire !",
	Enemy = "Défaite…",
	Draw = "Égalité : limite de tours atteinte.",
}

local function nameOf(snapshot, uid: string?): string
	local unit = uid and snapshot.units[uid]
	return if unit then unit.name else "?"
end

local function actionName(snapshot, event): string
	local unit = snapshot.units[event.actor]
	local fighter = unit and CardCatalog.getFighter(unit.fighterId)
	local action = fighter and fighter.actions[event.slot]
	return if action then action.name else AbilityText.slotLabel(event.slot)
end

-- Renvoie (texte, catégorie) ; la catégorie sert à colorer la ligne.
function BattleLog.format(snapshot, event): (string?, string?)
	local kind = event.type
	if kind == "TurnStart" then
		return string.format("— Tour %d —", event.turn), "Turn"
	elseif kind == "Action" then
		local targets = {}
		for _, uid in event.targets do
			table.insert(targets, nameOf(snapshot, uid))
		end
		local suffix = if #targets > 0 then " → " .. table.concat(targets, ", ") else ""
		return string.format("%s : %s%s", nameOf(snapshot, event.actor), actionName(snapshot, event), suffix), "Action"
	elseif kind == "Damage" then
		local absorbed = if event.absorbed > 0 then string.format(" (%d absorbés)", event.absorbed) else ""
		if event.kind == "Burn" then
			return string.format("   %s brûle : %d dégâts%s", nameOf(snapshot, event.target), event.amount, absorbed),
				"Damage"
		end
		return string.format("   %s subit %d dégâts%s", nameOf(snapshot, event.target), event.amount, absorbed),
			"Damage"
	elseif kind == "Heal" then
		local verb = if event.kind == "Regen" then "régénère" else "récupère"
		return string.format("   %s %s %d PV", nameOf(snapshot, event.target), verb, event.amount), "Heal"
	elseif kind == "Shield" then
		return string.format("   %s gagne un bouclier de %d", nameOf(snapshot, event.target), event.amount), "Heal"
	elseif kind == "Status" then
		local info = Statuses.Info[event.status]
		return string.format(
			"   %s : %s (%d t.)",
			nameOf(snapshot, event.target),
			if info then info.name else event.status,
			event.duration
		),
			"Status"
	elseif kind == "Defeated" then
		return string.format("   %s est à terre", nameOf(snapshot, event.target)), "Defeated"
	elseif kind == "Skip" and event.reason == "Stun" then
		return string.format("%s est étourdi et passe son tour", nameOf(snapshot, event.actor)), "Status"
	elseif kind == "BattleEnd" then
		return WINNER_TEXT[event.winner] or "Fin du combat", "End"
	end
	return nil, nil
end

return BattleLog
