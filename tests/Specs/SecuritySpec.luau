-- Défenses contre les entrées client : nettoyage des plans et limitation de fréquence.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlanSanitizer = require(ReplicatedStorage.Shared.Battle.PlanSanitizer)
local RateLimiter = require(ServerScriptService.Server.Net.RateLimiter)

return function(test, expect)
	test("le nettoyage refuse les plans malformés", function()
		local cases = {
			{ name = "nil", plan = nil },
			{ name = "texte", plan = "A1" },
			{ name = "entrée non table", plan = { A1 = "basic" } },
			{ name = "action inconnue", plan = { A1 = { slot = "hack" } } },
			{ name = "action absente", plan = { A1 = {} } },
			{ name = "cible numérique", plan = { A1 = { slot = "basic", target = 123 } } },
			{ name = "cible trop longue", plan = { A1 = { slot = "basic", target = string.rep("E", 50) } } },
			{ name = "clé numérique", plan = { { slot = "basic" } } },
			{ name = "clé trop longue", plan = { [string.rep("A", 50)] = { slot = "basic" } } },
			{
				name = "trop d'entrées",
				plan = {
					A1 = { slot = "basic" },
					A2 = { slot = "basic" },
					A3 = { slot = "basic" },
					A4 = { slot = "basic" },
					A5 = { slot = "basic" },
					A6 = { slot = "basic" },
				},
			},
		}
		for _, case in cases do
			local result = PlanSanitizer.sanitize(case.plan)
			expect.equal(result, nil, case.name)
		end
	end)

	test("le nettoyage ne conserve que les champs attendus", function()
		local raw = { A1 = { slot = "skill", target = "E2", damage = 99999, extra = { nested = true } } }
		local result = PlanSanitizer.sanitize(raw)
		expect.truthy(result, "plan accepté")
		expect.truthy(result.A1 ~= raw.A1, "nouvelle table")
		expect.equal(result.A1.slot, "skill")
		expect.equal(result.A1.target, "E2")
		expect.equal(result.A1.damage, nil, "champ ignoré")
		expect.equal(result.A1.extra, nil, "champ ignoré")
	end)

	test("le limiteur bloque au-delà du quota puis se libère", function()
		local now = 0
		local limiter = RateLimiter.new(2, 1, function()
			return now
		end)
		local player = {}
		expect.truthy(limiter:allow(player), "1er appel")
		expect.truthy(limiter:allow(player), "2e appel")
		expect.falsy(limiter:allow(player), "3e appel bloqué")
		expect.truthy(limiter:allow({}), "un autre joueur n'est pas affecté")
		now = 1
		expect.truthy(limiter:allow(player), "fenêtre écoulée")
		limiter:forget(player)
		expect.truthy(limiter:allow(player), "historique oublié")
	end)
end
