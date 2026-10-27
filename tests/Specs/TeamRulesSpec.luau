local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local TeamRules = require(Shared.Battle.TeamRules)
local ProfileTemplate = require(ServerScriptService.Server.Data.ProfileTemplate)

local OWNED = { F001 = true, F002 = true, F003 = true, F004 = true, F005 = true }
local VALID_TEAM = { "F001", "F002", "F004", "F003", "F005" }

return function(test, expect)
	test("une équipe complète de combattants débloqués est valide", function()
		local ok, reason = TeamRules.validate(VALID_TEAM, OWNED)
		expect.truthy(ok, reason)
	end)

	test("les compositions invalides sont refusées", function()
		local cases = {
			{ name = "pas une table", team = "F001" },
			{ name = "4 combattants", team = { "F001", "F002", "F004", "F003" } },
			{ name = "6 combattants", team = { "F001", "F002", "F004", "F003", "F005", "F006" } },
			{ name = "doublon", team = { "F001", "F001", "F004", "F003", "F005" } },
			{ name = "id inconnu", team = { "F999", "F002", "F004", "F003", "F005" } },
			{ name = "carte d'objet", team = { "I001", "F002", "F004", "F003", "F005" } },
			{ name = "non débloqué", team = { "F006", "F002", "F004", "F003", "F005" } },
			{ name = "valeur non textuelle", team = { 1, "F002", "F004", "F003", "F005" } },
			{ name = "clé textuelle", team = { a = "F001", b = "F002", c = "F004", d = "F003", e = "F005" } },
			{
				name = "clé décimale",
				team = { [1] = "F001", [1.5] = "F002", [3] = "F004", [4] = "F003", [5] = "F005" },
			},
			{ name = "trou", team = { [1] = "F001", [2] = "F002", [3] = "F004", [4] = "F003", [6] = "F005" } },
		}
		for _, case in cases do
			local ok = TeamRules.validate(case.team, OWNED)
			expect.falsy(ok, case.name)
		end
	end)

	test("sans contrôle de possession, tout combattant existant est accepté", function()
		local ok = TeamRules.validate({ "F006", "F002", "F004", "F003", "F005" }, nil)
		expect.truthy(ok, "F006 accepté sans ensemble possédé")
	end)

	test("lignes des emplacements", function()
		for slot = 1, GameConfig.Team.Size do
			local expected = if slot <= GameConfig.Team.FrontSlots then "Front" else "Back"
			expect.equal(TeamRules.rowOfSlot(slot), expected, "emplacement " .. slot)
		end
	end)

	test("la suggestion respecte les lignes préférées", function()
		local team = TeamRules.suggest(GameConfig.Progression.StarterFighters)
		for slot, id in VALID_TEAM do
			expect.equal(team[slot], id, "emplacement " .. slot)
		end
	end)

	test("la suggestion accepte une liste gelée et reste partielle si besoin", function()
		local team = TeamRules.suggest(table.freeze({ "F003", "F001" }))
		expect.equal(#team, 2, "taille")
		expect.falsy(TeamRules.validate(team, OWNED), "équipe incomplète refusée")
	end)

	test("le profil par défaut est cohérent et modifiable", function()
		local profile = ProfileTemplate.create()
		expect.equal(profile.schemaVersion, GameConfig.Save.SchemaVersion, "version de schéma")
		local ok, reason = TeamRules.validate(profile.team, profile.unlockedFighters)
		expect.truthy(ok, reason)
		expect.equal(profile.boosters.FirstRift, 1, "booster de premier lancement")
		for _, id in GameConfig.Progression.StarterFighters do
			expect.equal(profile.cards[id], 1, id .. " exemplaire")
		end
		profile.boosters.FirstRift += 1
		profile.team[1] = "F002"
		expect.equal(profile.boosters.FirstRift, 2, "profil modifiable")
	end)
end
