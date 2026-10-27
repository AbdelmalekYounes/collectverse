local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage.Shared
local Encounters = require(Shared.Catalog.Encounters)
local BattleEngine = require(Shared.Battle.BattleEngine)
local BattlePlanner = require(StarterPlayer.StarterPlayerScripts.Client.Controllers.BattlePlanner)

local TEAM = { "F001", "F002", "F004", "F003", "F005" } -- A1 Kael, A2 Terra, A3 Nox | A4 Lyra, A5 Astra

local function setup()
	local battle = BattleEngine.createEncounter(TEAM, Encounters.RiftEcho1)
	local planner = BattlePlanner.new(function()
		return battle
	end)
	planner:reset()
	return battle, planner
end

return function(test, expect)
	test("la remise à zéro sélectionne le premier allié commandable", function()
		local _, planner = setup()
		expect.equal(planner.selectedUid, "A1")
	end)

	test("une attaque ciblée attend une cible valide", function()
		local _, planner = setup()
		expect.equal(planner:chooseAction("basic"), "needsTarget")
		local targetable = planner:targetable()
		expect.truthy(targetable.E1 and targetable.E2 and targetable.E3, "ligne avant ciblable")
		expect.falsy(targetable.E4, "ligne arrière protégée")
		expect.falsy(planner:click("E4"), "clic sur une cible invalide")
		expect.equal(planner.pendingSlot, "basic", "toujours en attente")
		expect.truthy(planner:click("E2"), "cible valide")
		expect.equal(planner.plan.A1.slot, "basic")
		expect.equal(planner.plan.A1.target, "E2")
		expect.equal(planner.selectedUid, "A2", "passe à l'allié suivant")
	end)

	test("l'énergie réservée bloque les actions trop chères, l'ordre propre est remboursé", function()
		local battle, planner = setup()
		planner:select("A2")
		expect.equal(planner:chooseAction("skill"), "planned", "Rempart vivant (automatique)")
		expect.equal(planner:plannedCost(), 3)
		expect.equal(planner:remainingFor("A3"), battle.energy.Ally - 3)
		planner:select("A3")
		expect.equal(planner:chooseAction("skill"), "unavailable", "plus d'énergie pour Nox")
		expect.equal(planner:remainingFor("A2"), battle.energy.Ally, "son propre ordre est remboursé")
	end)

	test("l'ultime reste indisponible sans jauge pleine", function()
		local battle, planner = setup()
		battle.energy.Ally = 10
		local usable, reason = planner:isUsable("A1", "ultimate")
		expect.falsy(usable)
		expect.contains(reason, "Jauge")
		battle.units.A1.charge = battle.chargeMax
		expect.truthy(planner:isUsable("A1", "ultimate"), "jauge pleine")
	end)

	test("un allié étourdi ou un ennemi ne peut pas être commandé", function()
		local battle, planner = setup()
		battle.units.A2.statuses.Stun = { duration = 1, power = 0, tickValue = 0 }
		expect.falsy(planner:select("A2"), "étourdi")
		expect.falsy(planner:select("E1"), "ennemi")
		expect.equal(planner:plannedText(battle.units.A2), "Étourdi")
		planner:select("A1")
		planner:chooseAction("defend")
		expect.equal(planner.selectedUid, "A3", "l'allié étourdi est sauté")
	end)

	test("le plan produit est accepté par le moteur", function()
		local battle, planner = setup()
		planner:chooseAction("basic")
		planner:click("E3")
		planner:select("A3")
		planner:chooseAction("skill")
		planner:click("E5")
		local plan = planner:getPlan()
		expect.equal(plan.A3.target, "E5", "Nox vise la ligne arrière")
		local ok, reason = BattleEngine.validatePlan(battle, "Ally", plan)
		expect.truthy(ok, reason)
		expect.contains(planner:plannedText(battle.units.A1), "→")
		expect.equal(planner:plannedText(battle.units.A2), "Attaque (auto)")
	end)

	test("aucune commande une fois le combat terminé", function()
		local battle, planner = setup()
		battle.status = "Finished"
		expect.falsy(planner:select("A2"), "sélection")
		expect.equal(planner:chooseAction("defend"), "unavailable", "action")
	end)

	test("le signal Changed est émis à chaque modification", function()
		local _, planner = setup()
		local count = 0
		local connection = planner.Changed:Connect(function()
			count += 1
		end)
		planner:select("A2")
		planner:chooseAction("defend")
		connection:Disconnect()
		planner:select("A1")
		expect.equal(count, 2)
	end)
end
