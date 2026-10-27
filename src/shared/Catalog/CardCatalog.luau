-- Point d'accès unique au catalogue de cartes (combattants + objets).
--
-- Au chargement : normalise les définitions (kind, identifiants d'actions,
-- scaling par défaut), les indexe par id puis les gèle. Les listes renvoyées
-- sont donc en lecture seule : copiez-les avant de les trier ou de les filtrer en place.

local Catalog = script.Parent
local Freeze = require(Catalog.Parent.Util.Freeze)
local Rarities = require(Catalog.Rarities)
local Fighters = require(Catalog.Fighters)
local Items = require(Catalog.Items)

local ACTION_SLOTS = { "basic", "skill", "ultimate", "defend" }
local POWER_EFFECTS = { Damage = true, Heal = true, Shield = true }

local CardCatalog = {}
CardCatalog.ActionSlots = table.freeze(ACTION_SLOTS)

local byId = {}
local allCards = {}
local fighterCards = {}
local itemCards = {}
local duplicateIds = {}

local function normalizeFighter(def)
	if type(def.actions) ~= "table" then
		return
	end
	for _, slot in ACTION_SLOTS do
		local action = def.actions[slot]
		if type(action) == "table" then
			action.slot = slot
			action.id = def.id .. "_" .. slot
			if type(action.effects) == "table" then
				for _, effect in action.effects do
					if POWER_EFFECTS[effect.type] and effect.scaling == nil then
						effect.scaling = "attack"
					end
				end
			end
		end
	end
end

local function register(def, kind: string, list)
	def.kind = kind
	if def.inBoosterPool == nil then
		def.inBoosterPool = true
	end
	if byId[def.id] ~= nil then
		-- Le validateur signalera l'erreur ; on garde la première définition.
		table.insert(duplicateIds, def.id)
	else
		byId[def.id] = def
	end
	table.insert(list, def)
	table.insert(allCards, def)
end

for _, def in Fighters do
	normalizeFighter(def)
	register(def, "Fighter", fighterCards)
end
for _, def in Items do
	register(def, "Item", itemCards)
end

local function compareById(a, b)
	return a.id < b.id
end
table.sort(allCards, compareById)
table.sort(fighterCards, compareById)
table.sort(itemCards, compareById)

-- Pools de booster par rareté (liste d'ids triés).
local boosterPools = {}
for _, rarity in Rarities.Order do
	boosterPools[rarity] = {}
end
for _, card in allCards do
	if card.inBoosterPool and boosterPools[card.rarity] then
		table.insert(boosterPools[card.rarity], card.id)
	end
end

Freeze.deep(allCards)
Freeze.deep(fighterCards)
Freeze.deep(itemCards)
Freeze.deep(boosterPools)
table.freeze(duplicateIds)

function CardCatalog.get(id: any)
	if type(id) ~= "string" then
		return nil
	end
	return byId[id]
end

function CardCatalog.exists(id: any): boolean
	return CardCatalog.get(id) ~= nil
end

function CardCatalog.getFighter(id: any)
	local card = CardCatalog.get(id)
	if card and card.kind == "Fighter" then
		return card
	end
	return nil
end

function CardCatalog.getItem(id: any)
	local card = CardCatalog.get(id)
	if card and card.kind == "Item" then
		return card
	end
	return nil
end

function CardCatalog.getAll()
	return allCards
end

function CardCatalog.getFighters()
	return fighterCards
end

function CardCatalog.getItems()
	return itemCards
end

function CardCatalog.getBoosterPool(rarity: string)
	return boosterPools[rarity] or table.freeze({})
end

function CardCatalog.getDuplicateIds()
	return duplicateIds
end

return table.freeze(CardCatalog)
