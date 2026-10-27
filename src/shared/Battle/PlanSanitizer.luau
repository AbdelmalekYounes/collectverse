-- Copie défensive d'un plan reçu du client, avant toute validation métier.
-- Seuls les champs attendus, de types primitifs et de taille bornée, sont conservés :
-- le reste du serveur ne manipule jamais la table d'origine.

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local CardCatalog = require(Shared.Catalog.CardCatalog)

local PlanSanitizer = {}

local MAX_ID_LENGTH = 8

local function isShortString(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= MAX_ID_LENGTH
end

function PlanSanitizer.sanitize(raw: any): (any, string?)
	if type(raw) ~= "table" then
		return nil, "Plan invalide"
	end
	local result = {}
	local count = 0
	for uid, entry in raw do
		count += 1
		if count > GameConfig.Team.Size then
			return nil, "Plan trop volumineux"
		end
		if not isShortString(uid) or type(entry) ~= "table" then
			return nil, "Plan invalide"
		end
		local slot = entry.slot
		if type(slot) ~= "string" or not table.find(CardCatalog.ActionSlots, slot) then
			return nil, "Action invalide"
		end
		local target = entry.target
		if target ~= nil and not isShortString(target) then
			return nil, "Cible invalide"
		end
		result[uid] = { slot = slot, target = target }
	end
	return result, nil
end

return PlanSanitizer
