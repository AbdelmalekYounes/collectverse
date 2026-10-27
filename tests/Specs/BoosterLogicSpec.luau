-- Tirages et ouverture de boosters, avec un générateur à graine fixe (résultats reproductibles).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Catalog = ReplicatedStorage.Shared.Catalog
local Boosters = require(Catalog.Boosters)
local BoosterOdds = require(Catalog.BoosterOdds)
local CardCatalog = require(Catalog.CardCatalog)
local Server = ServerScriptService.Server
local BoosterLogic = require(Server.Logic.BoosterLogic)
local Inventory = require(Server.Logic.Inventory)
local ProfileTemplate = require(Server.Data.ProfileTemplate)

local BOOSTER = Boosters.FirstRift
local SAMPLES = 20000

-- xorshift32 : générateur déterministe, indépendant de Roblox.
local function makeRng(seed: number)
	local state = seed
	return function(min: number, max: number): number
		state = bit32.bxor(state, bit32.lshift(state, 13))
		state = bit32.bxor(state, bit32.rshift(state, 17))
		state = bit32.bxor(state, bit32.lshift(state, 5))
		return min + state % (max - min + 1)
	end
end

local function serialize(value): string
	if type(value) ~= "table" then
		return tostring(value)
	end
	local keys = {}
	for key in value do
		table.insert(keys, tostring(key))
	end
	table.sort(keys)
	local parts = {}
	for _, key in keys do
		local child = value[key]
		if child == nil then
			child = value[tonumber(key)]
		end
		table.insert(parts, key .. "=" .. serialize(child))
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

return function(test, expect)
	test("un booster contient 5 cartes existantes", function()
		local cards = BoosterLogic.roll(BOOSTER, makeRng(1))
		expect.equal(#cards, BOOSTER.cardCount)
		for _, id in cards do
			expect.truthy(CardCatalog.get(id), id)
		end
	end)

	test("le tirage est reproductible avec la même graine", function()
		local a = BoosterLogic.roll(BOOSTER, makeRng(42))
		local b = BoosterLogic.roll(BOOSTER, makeRng(42))
		expect.equal(table.concat(a, ","), table.concat(b, ","))
	end)

	test("bornes du tirage de rareté", function()
		local maxRoll = BoosterLogic.roll(BOOSTER, function(_, max)
			return max
		end)
		local minRoll = BoosterLogic.roll(BOOSTER, function(min)
			return min
		end)
		for slot = 1, BOOSTER.cardCount do
			expect.equal(CardCatalog.get(maxRoll[slot]).rarity, "Legendary", "max → Légendaire")
		end
		for slot = 1, BOOSTER.cardCount - 1 do
			expect.equal(CardCatalog.get(minRoll[slot]).rarity, "Common", "min → Commune")
		end
		expect.equal(CardCatalog.get(minRoll[BOOSTER.cardCount]).rarity, "Rare", "garanti : min → Rare")
	end)

	test(string.format("fréquences observées sur %d boosters conformes aux taux publiés", SAMPLES), function()
		local rng = makeRng(20261027)
		local standardCounts, guaranteedCounts, cardCounts = {}, {}, {}
		local standardTotal = 0
		for _ = 1, SAMPLES do
			local cards = BoosterLogic.roll(BOOSTER, rng)
			for slot, id in cards do
				local rarity = CardCatalog.get(id).rarity
				if slot == BOOSTER.cardCount then
					guaranteedCounts[rarity] = (guaranteedCounts[rarity] or 0) + 1
					expect.truthy(rarity ~= "Common", "emplacement garanti sans Commune")
				else
					standardCounts[rarity] = (standardCounts[rarity] or 0) + 1
					cardCounts[id] = (cardCounts[id] or 0) + 1
					standardTotal += 1
				end
			end
		end

		-- Tolérance : 5 écarts-types de la proportion attendue.
		local function check(observed: number, total: number, expected: number, label: string)
			local tolerance = 5 * math.sqrt(expected * (1 - expected) / total)
			expect.near(observed / total, expected, tolerance, label)
		end
		local odds = BoosterOdds.compute(BOOSTER)
		for _, entry in odds.standard do
			check(
				standardCounts[entry.rarity] or 0,
				standardTotal,
				entry.probability,
				"emplacements 1-4 " .. entry.rarity
			)
			for _, id in entry.cardIds do
				check(cardCounts[id] or 0, standardTotal, entry.perCard, "carte " .. id)
			end
		end
		for _, entry in odds.guaranteed do
			check(guaranteedCounts[entry.rarity] or 0, SAMPLES, entry.probability, "emplacement 5 " .. entry.rarity)
		end
	end)

	test("ouvrir consomme un booster et attribue les 5 cartes", function()
		local profile = ProfileTemplate.create()
		local _, copiesBefore = Inventory.summary(profile)
		local ok, result = BoosterLogic.open(profile, "FirstRift", makeRng(7))
		expect.truthy(ok, result)
		expect.equal(#result.cards, 5, "cartes")
		expect.equal(result.remaining, 0, "boosters restants")
		expect.equal(profile.boosters.FirstRift, 0, "profil")
		expect.equal(profile.stats.boostersOpened, 1, "statistique")
		local _, copiesAfter = Inventory.summary(profile)
		expect.equal(copiesAfter, copiesBefore + 5, "exemplaires ajoutés")
	end)

	test("les ouvertures invalides sont refusées sans rien modifier", function()
		local profile = ProfileTemplate.create()
		profile.boosters.FirstRift = 0
		local before = serialize(profile)
		local cases = {
			{ name = "aucun booster", id = "FirstRift" },
			{ name = "booster inconnu", id = "SecondRift" },
			{ name = "id non textuel", id = 12 },
			{ name = "id nil", id = nil },
		}
		for _, case in cases do
			local ok = BoosterLogic.open(profile, case.id, makeRng(3))
			expect.falsy(ok, case.name)
		end
		expect.equal(serialize(profile), before, "profil inchangé")
	end)

	test("inventaire : doublons conservés, déblocage et nouveauté signalés", function()
		local profile = ProfileTemplate.create()
		local grants = Inventory.grant(profile, { "F006", "F006", "F001", "I004" })
		expect.truthy(grants[1].isNew and grants[1].unlockedFighter, "Oris : nouveau et débloqué")
		expect.falsy(grants[2].isNew or grants[2].unlockedFighter, "Oris en double")
		expect.equal(grants[2].count, 2, "deux exemplaires d'Oris")
		expect.falsy(grants[3].isNew, "Kael déjà possédé")
		expect.equal(grants[3].count, 2, "Kael en double")
		expect.truthy(grants[4].isNew and not grants[4].unlockedFighter, "objet nouveau, sans déblocage")
		expect.truthy(profile.unlockedFighters.F006, "Oris débloqué dans le profil")
	end)

	test("inventaire : un id inconnu est refusé avant toute modification", function()
		local profile = ProfileTemplate.create()
		local before = serialize(profile)
		expect.fails(function()
			Inventory.grant(profile, { "F001", "X999" })
		end)
		expect.equal(serialize(profile), before, "profil inchangé")
	end)
end
