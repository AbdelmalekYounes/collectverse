local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage.Shared
local Encounters = require(Shared.Catalog.Encounters)
local BattleEngine = require(Shared.Battle.BattleEngine)
local CombatAI = require(Shared.Battle.CombatAI)
local BattleReplay = require(StarterPlayer.StarterPlayerScripts.Client.Controllers.BattleReplay)

local TEAM = { "F001", "F002", "F004", "F003", "F005" }

local function keys(map): string
	local list = {}
	for key in map do
		table.insert(list, key)
	end
	table.sort(list)
	return table.concat(list, ",")
end

local function playTurn(battle)
	local _, ally = BattleEngine.validatePlan(battle, "Ally", CombatAI.choosePlan(battle, "Ally"))
	local _, enemy = BattleEngine.validatePlan(battle, "Enemy", CombatAI.choosePlan(battle, "Enemy"))
	return BattleEngine.resolveTurn(battle, ally, enemy)
end

return function(test, expect)
	test("rejouer les événements reproduit l'état du serveur, tour après tour", function()
		local battle = BattleEngine.createEncounter(TEAM, Encounters.RiftEcho1)
		local turns = 0
		while battle.status == "Planning" and turns < 40 do
			turns += 1
			local display = BattleReplay.copy(battle)
			for _, event in playTurn(battle) do
				BattleReplay.apply(display, event)
			end
			local where = "tour " .. turns .. " "
			expect.equal(display.turn, battle.turn, where .. "numéro de tour")
			expect.equal(display.status, battle.status, where .. "statut")
			expect.equal(display.winner, battle.winner, where .. "vainqueur")
			expect.equal(display.energy.Ally, battle.energy.Ally, where .. "énergie alliée")
			expect.equal(display.energy.Enemy, battle.energy.Enemy, where .. "énergie ennemie")
			for uid, unit in battle.units do
				local shown = display.units[uid]
				expect.equal(shown.hp, unit.hp, where .. uid .. " PV")
				expect.equal(shown.shield, unit.shield, where .. uid .. " bouclier")
				expect.equal(shown.alive, unit.alive, where .. uid .. " en vie")
				expect.equal(keys(shown.statuses), keys(unit.statuses), where .. uid .. " statuts")
			end
		end
		expect.equal(battle.status, "Finished", "le combat se termine")
	end)

	test("découpage en temps forts", function()
		local battle = BattleEngine.createEncounter(TEAM, Encounters.RiftEcho1)
		-- Kael applique une brûlure : le tour contient des effets de fin de tour.
		local _, ally = BattleEngine.validatePlan(battle, "Ally", { A1 = { slot = "skill", target = "E1" } })
		local _, enemy = BattleEngine.validatePlan(battle, "Enemy", {})
		local events = BattleEngine.resolveTurn(battle, ally, enemy)
		local beats = BattleReplay.group(events)

		expect.equal(beats[1].kind, "TurnStart", "premier temps fort")
		local actions, ticks, total = 0, 0, 0
		for _, beat in beats do
			total += #beat.events
			if beat.kind == "Action" then
				actions += 1
				expect.equal(beat.events[1].type, "Action", "une action ouvre son temps fort")
			elseif beat.kind == "Ticks" then
				ticks += 1
			end
		end
		expect.equal(actions, 10, "une par combattant")
		expect.equal(ticks, 1, "un seul temps fort de fin de tour")
		expect.equal(total, #events, "aucun événement perdu")
	end)
end
