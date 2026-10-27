local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = ReplicatedStorage.Shared.Catalog
local CardCatalog = require(Catalog.CardCatalog)
local CatalogValidator = require(Catalog.CatalogValidator)

local EXPECTED_FIGHTERS = {
	{ id = "F001", name = "Kael", element = "Fire", role = "Warrior" },
	{ id = "F002", name = "Terra", element = "Earth", role = "Tank" },
	{ id = "F003", name = "Lyra", element = "Water", role = "Healer" },
	{ id = "F004", name = "Nox", element = "Shadow", role = "Assassin" },
	{ id = "F005", name = "Astra", element = "Lightning", role = "Mage" },
	{ id = "F006", name = "Oris", element = "Light", role = "Support" },
}

local EXPECTED_ITEMS = { "Cristal fracturé", "Boussole dimensionnelle", "Lanterne des Échos", "Sceau ancestral" }

-- Combattant valide minimal, copié puis cassé dans les tests négatifs.
local function validFighter()
	return {
		id = "F999",
		name = "Test",
		element = "Fire",
		role = "Warrior",
		rarity = "Common",
		preferredRow = "Front",
		stats = { maxHp = 100, attack = 10, defense = 10, speed = 10 },
		actions = {
			basic = { name = "A", cost = 0, target = "SingleEnemy", effects = { { type = "Damage", power = 1 } } },
			skill = { name = "B", cost = 2, target = "SingleEnemy", effects = { { type = "Damage", power = 1.5 } } },
			ultimate = { name = "C", cost = 5, target = "AllEnemies", effects = { { type = "Damage", power = 2 } } },
			defend = {
				name = "D",
				cost = 0,
				target = "Self",
				effects = { { type = "Status", status = "Guard", duration = 1 } },
			},
		},
	}
end

local function errorsFor(def): { string }
	local errors = {}
	CatalogValidator.validateFighter(def, errors)
	return errors
end

return function(test, expect)
	test("le catalogue complet est valide", function()
		local errors = CatalogValidator.validateAll()
		expect.equal(#errors, 0, "erreurs : " .. table.concat(errors, " | "))
	end)

	test("contient les six combattants attendus", function()
		expect.equal(#CardCatalog.getFighters(), #EXPECTED_FIGHTERS, "nombre de combattants")
		for _, expected in EXPECTED_FIGHTERS do
			local fighter = CardCatalog.getFighter(expected.id)
			expect.truthy(fighter, expected.id)
			expect.equal(fighter.name, expected.name, expected.id .. " nom")
			expect.equal(fighter.element, expected.element, expected.id .. " élément")
			expect.equal(fighter.role, expected.role, expected.id .. " rôle")
		end
	end)

	test("chaque combattant a ses quatre actions normalisées", function()
		for _, fighter in CardCatalog.getFighters() do
			for _, slot in CardCatalog.ActionSlots do
				local action = fighter.actions[slot]
				expect.truthy(action, fighter.id .. "." .. slot)
				expect.equal(action.slot, slot, fighter.id .. " slot")
				expect.equal(action.id, fighter.id .. "_" .. slot, fighter.id .. " id d'action")
				for _, effect in action.effects do
					if effect.type ~= "Status" then
						expect.truthy(effect.scaling, action.id .. " scaling par défaut")
					end
				end
			end
		end
	end)

	test("contient les quatre objets attendus", function()
		local names = {}
		for _, item in CardCatalog.getItems() do
			names[item.name] = true
			expect.equal(item.kind, "Item", item.id)
		end
		expect.equal(#CardCatalog.getItems(), #EXPECTED_ITEMS, "nombre d'objets")
		for _, name in EXPECTED_ITEMS do
			expect.truthy(names[name], name)
		end
	end)

	test("les accesseurs distinguent combattants et objets", function()
		expect.truthy(CardCatalog.getFighter("F001"), "F001 combattant")
		expect.falsy(CardCatalog.getItem("F001"), "F001 n'est pas un objet")
		expect.truthy(CardCatalog.getItem("I001"), "I001 objet")
		expect.falsy(CardCatalog.getFighter("I001"), "I001 n'est pas un combattant")
		expect.falsy(CardCatalog.get("X404"), "id inconnu")
		expect.falsy(CardCatalog.get(42), "id non textuel")
		expect.falsy(CardCatalog.get(nil), "id nil")
	end)

	test("le catalogue est en lecture seule", function()
		local fighter = CardCatalog.getFighter("F001")
		expect.fails(function()
			fighter.name = "Pirate"
		end, "modification du nom")
		expect.fails(function()
			fighter.stats.attack = 9999
		end, "modification des stats")
		expect.fails(function()
			table.insert(CardCatalog.getAll() :: any, {})
		end, "ajout à la liste")
	end)

	test("le validateur accepte un combattant valide", function()
		local errors = errorsFor(validFighter())
		expect.equal(#errors, 0, table.concat(errors, " | "))
	end)

	test("le validateur refuse les définitions invalides", function()
		local cases = {
			function(def)
				def.actions.ultimate = nil
			end,
			function(def)
				def.actions.skill.cost = -1
			end,
			function(def)
				def.actions.basic.cost = 2
			end,
			function(def)
				def.actions.skill.target = "Everyone"
			end,
			function(def)
				def.actions.skill.effects = {}
			end,
			function(def)
				def.actions.skill.effects[1].type = "Teleport"
			end,
			function(def)
				def.actions.skill.effects[1].power = 0
			end,
			function(def)
				def.actions.defend.effects = { { type = "Status", status = "Burn", duration = 2 } }
			end,
			function(def)
				def.actions.defend.target = "SingleEnemy"
			end,
			function(def)
				def.actions.skill.effects = { { type = "Heal", power = 1 } }
			end,
			function(def)
				def.actions.skill.cost = 99
			end,
			function(def)
				def.stats.speed = 0
			end,
			function(def)
				def.element = "Plasma"
			end,
			function(def)
				def.id = "Kael"
			end,
		}
		for index, mutate in cases do
			local def = validFighter()
			mutate(def)
			expect.truthy(#errorsFor(def) > 0, "cas invalide n°" .. index)
		end
	end)

	test("le validateur refuse un booster sans carte garantie valide", function()
		local errors = {}
		CatalogValidator.validateBooster({
			id = "Broken",
			cardCount = 5,
			guaranteedSlots = 1,
			standardWeights = { Common = 1 },
			guaranteedWeights = { Common = 1 },
		}, errors)
		expect.truthy(#errors > 0, "Common interdit dans l'emplacement garanti")
	end)

	test("le validateur refuse une rareté sans carte dans le pool", function()
		local errors = {}
		CatalogValidator.validateBooster(
			{
				id = "EmptyPool",
				cardCount = 1,
				guaranteedSlots = 0,
				standardWeights = { Legendary = 1 },
			},
			errors,
			function()
				return {}
			end
		)
		expect.truthy(#errors > 0, "pool vide détecté")
	end)
end
