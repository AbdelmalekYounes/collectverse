-- Scénario du test privé de performance (branche test/kael-af-perf).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PerfScenario = require(ReplicatedStorage.Shared.Util.PerfScenario)

return function(test, expect)
	local ids = {
		Idle = "rbxassetid://1",
		Attack = "rbxassetid://2",
		Skill = "rbxassetid://3",
		Ultimate = "rbxassetid://4",
		Defend = "rbxassetid://5",
		Hit = "rbxassetid://6",
		Defeat = "rbxassetid://7",
	}

	test("identifiants d'animation : les 7, valides et distincts, sinon aucun", function()
		expect.truthy(PerfScenario.validAnimations(ids), "7 identifiants valides")
		local missing = table.clone(ids)
		missing.Hit = ""
		expect.equal(PerfScenario.validAnimations(missing), nil, "un identifiant vide (non publié)")
		local duplicate = table.clone(ids)
		duplicate.Hit = ids.Idle
		expect.equal(PerfScenario.validAnimations(duplicate), nil, "doublon")
		local malformed = table.clone(ids)
		malformed.Hit = "123"
		expect.equal(PerfScenario.validAnimations(malformed), nil, "format")
		expect.equal(PerfScenario.validAnimations(nil), nil, "absent")
	end)

	test("scénario présent seulement dans les places de test de performance", function()
		local scenario = PerfScenario.get()
		if not ReplicatedStorage:FindFirstChild("PerfTest") then
			expect.equal(scenario, nil, "jeu normal : aucun scénario")
			return
		end
		expect.truthy(scenario, "place perf/<A|B|C> : scénario lu")
		expect.truthy(table.find({ "A", "B", "C" }, scenario.name), "nom du scénario")
		expect.truthy(scenario.forceModelDetail == "High" or scenario.forceModelDetail == "Low", "détail imposé")
	end)
end
