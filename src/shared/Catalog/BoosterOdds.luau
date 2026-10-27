-- Calcule les probabilités exactes d'un booster à partir de ses poids et des pools.
-- Utilisé par l'interface (transparence des taux), par les tests et, au jalon 4,
-- par le BoosterService pour garantir que l'affichage correspond au tirage réel.

local Catalog = script.Parent
local CardCatalog = require(Catalog.CardCatalog)
local Rarities = require(Catalog.Rarities)

local BoosterOdds = {}

export type RarityOdds = {
	rarity: string,
	weight: number,
	probability: number, -- probabilité de la rareté pour un emplacement
	perCard: number, -- probabilité d'une carte précise pour un emplacement
	cardIds: { string },
}

function BoosterOdds.computeSlot(weights): { RarityOdds }
	local total = 0
	for _, weight in weights do
		total += weight
	end

	local result = {}
	if total <= 0 then
		return result
	end
	for _, rarity in Rarities.Order do
		local weight = weights[rarity] or 0
		if weight > 0 then
			local pool = CardCatalog.getBoosterPool(rarity)
			local probability = weight / total
			table.insert(result, {
				rarity = rarity,
				weight = weight,
				probability = probability,
				perCard = if #pool > 0 then probability / #pool else 0,
				cardIds = pool,
			})
		end
	end
	return result
end

function BoosterOdds.compute(booster)
	local guaranteed = booster.guaranteedSlots or 0
	return {
		standardSlots = booster.cardCount - guaranteed,
		guaranteedSlots = guaranteed,
		standard = BoosterOdds.computeSlot(booster.standardWeights or {}),
		guaranteed = BoosterOdds.computeSlot(booster.guaranteedWeights or {}),
	}
end

-- Format français : 23,3 %
function BoosterOdds.formatPercent(probability: number, decimals: number?): string
	local text = string.format("%." .. tostring(decimals or 1) .. "f", probability * 100)
	return (string.gsub(text, "%.", ",")) .. " %"
end

return BoosterOdds
