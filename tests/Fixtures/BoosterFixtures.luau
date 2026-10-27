-- Fixtures de tirage déterministes pour les tests.
--
-- scripted(booster, cardIds) renvoie un générateur nextInteger qui fait sortir
-- exactement `cardIds` (un id par emplacement) en passant par le vrai
-- BoosterLogic.roll et les vrais poids de production : rien n'est modifié dans
-- les probabilités. Pour chaque emplacement, la valeur fournie au tirage de rareté
-- tombe dans l'intervalle de la rareté voulue, puis l'index de la carte dans le
-- pool de cette rareté est fourni.
--
-- Un résultat impossible en production (ex. une Commune dans l'emplacement
-- garanti, rareté de poids nul) lève une erreur : la fixture ne peut pas
-- fabriquer un tirage que le jeu ne pourrait pas produire.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = ReplicatedStorage.Shared.Catalog
local CardCatalog = require(Catalog.CardCatalog)
local Rarities = require(Catalog.Rarities)

local BoosterFixtures = {}

function BoosterFixtures.scripted(booster, cardIds: { string })
	assert(#cardIds == booster.cardCount, "une carte par emplacement est attendue")
	local standardSlots = booster.cardCount - (booster.guaranteedSlots or 0)
	local values = {}
	for slot, id in cardIds do
		local card = CardCatalog.get(id)
		assert(card, "carte inconnue : " .. tostring(id))
		local weights = if slot > standardSlots then booster.guaranteedWeights else booster.standardWeights
		local before = 0
		for _, rarity in Rarities.Order do
			if rarity == card.rarity then
				break
			end
			before += weights[rarity] or 0
		end
		local weight = weights[card.rarity] or 0
		if weight <= 0 then
			error(string.format("%s (%s) ne peut pas sortir à l'emplacement %d", id, card.rarity, slot))
		end
		local index = table.find(CardCatalog.getBoosterPool(card.rarity), id)
		assert(index, id .. " absent du pool " .. card.rarity)
		table.insert(values, before + weight) -- borne haute de l'intervalle de la rareté
		table.insert(values, index)
	end

	local position = 0
	return function(min: number, max: number): number
		position += 1
		local value = values[position]
		assert(value ~= nil, "tirage plus long que prévu")
		assert(value >= min and value <= max, string.format("valeur %d hors de [%d, %d]", value, min, max))
		return value
	end
end

return BoosterFixtures
