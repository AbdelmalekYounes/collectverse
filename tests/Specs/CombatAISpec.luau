local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Encounters = require(Shared.Catalog.Encounters)
local BattleEngine = require(Shared.Battle.BattleEngine)
local CombatAI = require(Shared.Battle.CombatAI)

local TEAM = { "F001", "F002", "F004", "F003", "F005" }

-- Fait jouer l'IA des deux côtés jusqu'à la fin. Renvoie le combat, le premier
-- refus de plan rencontré (nil si tous valides) et un résumé pour le diagnostic.
local function simulate()
	local battle = BattleEngine.createEncounter(TEAM, Encounters.RiftEcho1)
	local ultimates = { Ally = 0, Enemy = 0 }
	local guard = 0
	while battle.status == "Planning" and guard < battle.maxTurns + 1 do
		guard += 1
		local okAlly, ally = BattleEngine.validatePlan(battle, "Ally", CombatAI.choosePlan(battle, "Ally"))
		if not okAlly then
			return battle, "allié tour " .. battle.turn .. " : " .. tostring(ally), ""
		end
		local okEnemy, enemy = BattleEngine.validatePlan(battle, "Enemy", CombatAI.choosePlan(battle, "Enemy"))
		if not okEnemy then
			return battle, "ennemi tour " .. battle.turn .. " : " .. tostring(enemy), ""
		end
		for _, event in BattleEngine.resolveTurn(battle, ally, enemy) do
			if event.type == "Action" and event.slot == "ultimate" then
				local side = battle.units[event.actor].side
				ultimates[side] += 1
			end
		end
	end

	local hp = {}
	for _, uid in battle.unitOrder do
		local unit = battle.units[uid]
		table.insert(hp, string.format("%s %d/%d", unit.name, unit.hp, unit.maxHp))
	end
	local summary = string.format(
		"tour %d, ultimes allié %d / ennemi %d, PV : %s",
		battle.turn,
		ultimates.Ally,
		ultimates.Enemy,
		table.concat(hp, ", ")
	)
	return battle, nil, summary
end

local function fingerprint(battle): string
	local parts = { tostring(battle.turn), tostring(battle.winner) }
	for _, uid in battle.unitOrder do
		local unit = battle.units[uid]
		table.insert(parts, string.format("%s:%d:%d:%d", uid, unit.hp, unit.shield, unit.charge))
	end
	return table.concat(parts, "|")
end

return function(test, expect)
	test("l'IA produit des plans valides pendant tout un combat", function()
		local battle, refusal = simulate()
		expect.equal(refusal, nil, "plan refusé")
		expect.equal(battle.status, "Finished", "combat terminé")
		expect.truthy(battle.winner ~= nil, "issue définie")
	end)

	test("le combat est déterministe", function()
		local first = simulate()
		local second = simulate()
		expect.equal(fingerprint(first), fingerprint(second), "deux simulations identiques")
	end)

	test("la rencontre 1 est gagnable avec l'équipe de départ", function()
		local battle, _, summary = simulate()
		expect.equal(battle.winner, "Ally", summary)
	end)

	test("l'IA respecte le budget d'énergie et la jauge d'ultime", function()
		local battle = BattleEngine.createEncounter(TEAM, Encounters.RiftEcho1)
		battle.energy.Enemy = 0
		local plan = CombatAI.choosePlan(battle, "Enemy")
		for uid, entry in plan do
			expect.equal(entry.slot ~= "skill" and entry.slot ~= "ultimate", true, uid .. " sans énergie")
		end
		battle.energy.Enemy = 10
		battle.units.E2.charge = battle.chargeMax
		-- Nox et Astra, plus rapides, dépenseraient l'énergie avant Kael : on les étourdit.
		for _, uid in { "E3", "E5" } do
			battle.units[uid].statuses.Stun = { duration = 1, power = 0, tickValue = 0 }
		end
		plan = CombatAI.choosePlan(battle, "Enemy")
		expect.equal(plan.E2.slot, "ultimate", "ultime lancé dès que possible")
	end)

	test("l'IA ne soigne pas une équipe en pleine santé", function()
		local battle = BattleEngine.createEncounter(TEAM, Encounters.RiftEcho1)
		battle.energy.Enemy = 10
		local plan = CombatAI.choosePlan(battle, "Enemy")
		expect.equal(plan.E4.slot ~= "skill", true, "Lyra garde son soin")
		battle.units.E1.hp = math.floor(battle.units.E1.maxHp * 0.4)
		plan = CombatAI.choosePlan(battle, "Enemy")
		expect.equal(plan.E4.slot, "skill", "Lyra soigne un allié blessé")
	end)

	test("l'IA laisse un combattant étourdi sans ordre", function()
		local battle = BattleEngine.createEncounter(TEAM, Encounters.RiftEcho1)
		battle.units.E1.statuses.Stun = { duration = 1, power = 0, tickValue = 0 }
		local plan = CombatAI.choosePlan(battle, "Enemy")
		expect.equal(plan.E1, nil, "pas d'ordre pour E1")
	end)
end
