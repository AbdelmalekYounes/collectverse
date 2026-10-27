-- Données de règles partagées : éléments, probabilités de booster, textes d'actions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Catalog = Shared.Catalog
local AbilityText = require(Catalog.AbilityText)
local BoosterOdds = require(Catalog.BoosterOdds)
local Boosters = require(Catalog.Boosters)
local CardCatalog = require(Catalog.CardCatalog)
local Elements = require(Catalog.Elements)

return function(test, expect)
	test("multiplicateurs élémentaires", function()
		local advantage = GameConfig.Battle.ElementAdvantage
		local disadvantage = GameConfig.Battle.ElementDisadvantage
		expect.equal(Elements.getMultiplier("Water", "Fire"), advantage, "Eau > Feu")
		expect.equal(Elements.getMultiplier("Fire", "Water"), disadvantage, "Feu < Eau")
		expect.equal(Elements.getMultiplier("Fire", "Earth"), advantage, "Feu > Terre")
		expect.equal(Elements.getMultiplier("Earth", "Lightning"), advantage, "Terre > Foudre")
		expect.equal(Elements.getMultiplier("Lightning", "Water"), advantage, "Foudre > Eau")
		expect.equal(Elements.getMultiplier("Shadow", "Light"), advantage, "Ombre > Lumière")
		expect.equal(Elements.getMultiplier("Light", "Shadow"), advantage, "Lumière > Ombre")
		expect.equal(Elements.getMultiplier("Fire", "Fire"), 1, "neutre")
		expect.equal(Elements.getMultiplier("Fire", "Light"), 1, "sans relation")
		expect.equal(Elements.getMultiplier("Plasma", "Fire"), 1, "élément inconnu")
	end)

	test("probabilités First Rift : chaque emplacement totalise 100 %", function()
		local odds = BoosterOdds.compute(Boosters.FirstRift)
		for _, slotKind in { "standard", "guaranteed" } do
			local total, cardTotal = 0, 0
			for _, entry in odds[slotKind] do
				total += entry.probability
				cardTotal += entry.perCard * #entry.cardIds
			end
			expect.near(total, 1, 1e-9, slotKind .. " raretés")
			expect.near(cardTotal, 1, 1e-9, slotKind .. " cartes")
		end
		expect.equal(odds.standardSlots + odds.guaranteedSlots, Boosters.FirstRift.cardCount, "emplacements")
	end)

	test("probabilités First Rift : valeurs exactes publiées", function()
		local odds = BoosterOdds.compute(Boosters.FirstRift)
		local byRarity = {}
		for _, entry in odds.standard do
			byRarity[entry.rarity] = entry
		end
		expect.near(byRarity.Common.probability, 0.70, 1e-9, "Commune")
		expect.near(byRarity.Rare.probability, 0.23, 1e-9, "Rare")
		expect.near(byRarity.Epic.probability, 0.06, 1e-9, "Épique")
		expect.near(byRarity.Legendary.probability, 0.01, 1e-9, "Légendaire")
		expect.near(byRarity.Common.perCard, 0.70 / #CardCatalog.getBoosterPool("Common"), 1e-9, "par carte")
	end)

	test("l'emplacement garanti ne contient jamais de Commune", function()
		local odds = BoosterOdds.compute(Boosters.FirstRift)
		expect.truthy(odds.guaranteedSlots >= 1, "au moins un emplacement garanti")
		for _, entry in odds.guaranteed do
			expect.truthy(entry.rarity ~= "Common", "rareté " .. entry.rarity)
		end
	end)

	test("format des pourcentages", function()
		expect.equal(BoosterOdds.formatPercent(0.7), "70,0 %")
		expect.equal(BoosterOdds.formatPercent(0.23333, 2), "23,33 %")
	end)

	test("chaque action a une description et un coût lisibles", function()
		for _, fighter in CardCatalog.getFighters() do
			for _, slot in CardCatalog.ActionSlots do
				local action = fighter.actions[slot]
				local text = AbilityText.describe(action)
				expect.truthy(#text > 10, action.id .. " description")
				expect.falsy(string.find(text, "inconnu", 1, true), action.id .. " effet inconnu")
				expect.truthy(#AbilityText.costText(action) > 0, action.id .. " coût")
			end
		end
	end)

	test("description de la compétence de Kael", function()
		local text = AbilityText.describe(CardCatalog.getFighter("F001").actions.skill)
		expect.contains(text, "150 % de l'ATQ à un ennemi")
		expect.contains(text, "Brûlure (20 % de l'ATQ par tour) pendant 2 tours à la cible")
	end)

	test("la compétence de Nox mentionne le contournement de la ligne avant", function()
		local text = AbilityText.describe(CardCatalog.getFighter("F004").actions.skill)
		expect.contains(text, "même en ligne arrière")
	end)

	test("la défense mentionne le gain d'énergie", function()
		local text = AbilityText.describe(CardCatalog.getFighter("F002").actions.defend)
		expect.contains(text, "énergie")
	end)
end
