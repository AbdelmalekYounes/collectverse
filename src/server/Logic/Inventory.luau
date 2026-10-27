-- Inventaire d'un profil : exemplaires de cartes et combattants débloqués.
-- (Le module de référence « CollectionService » porte ce nom pour éviter tout
-- conflit avec le service Roblox CollectionService.)
-- Logique pure, sans service Roblox : testée avec Lune.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardCatalog = require(ReplicatedStorage.Shared.Catalog.CardCatalog)

local Inventory = {}

export type Grant = {
	id: string,
	rarity: string,
	count: number, -- exemplaires possédés après l'ajout
	isNew: boolean, -- première fois que le joueur obtient cette carte
	unlockedFighter: boolean, -- la carte vient de débloquer un combattant
}

function Inventory.countOf(profile, cardId: string): number
	return profile.cards[cardId] or 0
end

-- Ajoute un exemplaire de chaque carte (les doublons sont conservés).
-- Erreur si un id est inconnu : un tirage invalide ne doit jamais être crédité en silence.
function Inventory.grant(profile, cardIds: { string }): { Grant }
	for _, id in cardIds do
		if not CardCatalog.get(id) then
			error("Inventory.grant : carte inconnue " .. tostring(id))
		end
	end

	local results = {}
	for _, id in cardIds do
		local card = CardCatalog.get(id)
		local before = Inventory.countOf(profile, id)
		profile.cards[id] = before + 1
		local unlocked = false
		if card.kind == "Fighter" and not profile.unlockedFighters[id] then
			profile.unlockedFighters[id] = true
			unlocked = true
		end
		table.insert(results, {
			id = id,
			rarity = card.rarity,
			count = profile.cards[id],
			isNew = before == 0,
			unlockedFighter = unlocked,
		})
	end
	return results
end

-- Nombre de cartes différentes possédées, et nombre total d'exemplaires.
function Inventory.summary(profile): (number, number)
	local unique, copies = 0, 0
	for id, count in profile.cards do
		if CardCatalog.get(id) and count > 0 then
			unique += 1
			copies += count
		end
	end
	return unique, copies
end

return Inventory
