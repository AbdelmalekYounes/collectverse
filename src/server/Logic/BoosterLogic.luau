-- Tirage et ouverture des boosters, entièrement décidés par le serveur.
--
-- Pour chaque emplacement : 1) rareté tirée selon les poids (Catalog/Boosters),
-- 2) carte tirée uniformément parmi le pool de cette rareté. Les derniers
-- `guaranteedSlots` emplacements utilisent la table garantie (Rare ou mieux).
-- Ce sont exactement les règles affichées au joueur (BoosterOdds).
--
-- Le générateur aléatoire est injecté : nextInteger(min, max) -> entier dans [min, max].
-- Le serveur utilise Random ; les tests utilisent un générateur à graine fixe.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = ReplicatedStorage.Shared.Catalog
local Boosters = require(Catalog.Boosters)
local CardCatalog = require(Catalog.CardCatalog)
local Rarities = require(Catalog.Rarities)
local Inventory = require(script.Parent.Inventory)

local BoosterLogic = {}

export type NextInteger = (min: number, max: number) -> number

local function pickRarity(weights, nextInteger: NextInteger): string
	local total = 0
	for _, rarity in Rarities.Order do
		total += weights[rarity] or 0
	end
	local roll = nextInteger(1, total)
	local cumulative = 0
	for _, rarity in Rarities.Order do
		cumulative += weights[rarity] or 0
		if roll <= cumulative then
			return rarity
		end
	end
	error("BoosterLogic : tirage de rareté hors bornes")
end

-- Tire les cartes d'un booster. Renvoie une liste d'ids (ordre de révélation).
function BoosterLogic.roll(booster, nextInteger: NextInteger): { string }
	local guaranteed = booster.guaranteedSlots or 0
	local standardSlots = booster.cardCount - guaranteed
	local cards = {}
	for slot = 1, booster.cardCount do
		local weights = if slot > standardSlots then booster.guaranteedWeights else booster.standardWeights
		local rarity = pickRarity(weights, nextInteger)
		local pool = CardCatalog.getBoosterPool(rarity)
		table.insert(cards, pool[nextInteger(1, #pool)])
	end
	return cards
end

-- Ouvre un booster possédé : consomme un exemplaire, tire et crédite les cartes.
-- Modifie `profile` ; renvoie (true, résultats) ou (false, raison) sans rien modifier.
function BoosterLogic.open(profile, boosterId: any, nextInteger: NextInteger): (boolean, any)
	if type(boosterId) ~= "string" then
		return false, "Booster invalide"
	end
	local booster = Boosters[boosterId]
	if not booster then
		return false, "Booster inconnu"
	end
	local owned = profile.boosters[boosterId] or 0
	if owned < 1 then
		return false, "Aucun booster " .. booster.name .. " disponible"
	end

	local cardIds = BoosterLogic.roll(booster, nextInteger)
	-- Crédit d'abord (Inventory.grant valide tous les ids avant toute écriture) :
	-- le booster n'est consommé que si les cartes ont bien été attribuées.
	local grants = Inventory.grant(profile, cardIds)
	profile.boosters[boosterId] = owned - 1
	profile.stats.boostersOpened += 1
	return true, { boosterId = boosterId, cards = grants, remaining = profile.boosters[boosterId] }
end

return BoosterLogic
