-- Valeurs attendues calculées à la main à partir des formules de docs/CATALOGUE.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Encounters = require(Shared.Catalog.Encounters)
local AbilitySystem = require(Shared.Battle.AbilitySystem)
local BattleEngine = require(Shared.Battle.BattleEngine)

local Battle = GameConfig.Battle
local TEAM = { "F001", "F002", "F004", "F003", "F005" } -- Kael, Terra, Nox | Lyra, Astra

local function entries(ids, multiplier)
	local result = {}
	for _, id in ids do
		table.insert(result, { fighterId = id, statMultiplier = multiplier })
	end
	return result
end

local function duel(allyIds, enemyIds, enemyMultiplier)
	return BattleEngine.create(entries(allyIds), entries(enemyIds, enemyMultiplier))
end

-- Valide les deux plans puis résout le tour ; échoue si un plan est refusé.
local function play(battle, allyPlan, enemyPlan)
	local okAlly, ally = BattleEngine.validatePlan(battle, "Ally", allyPlan or {})
	assert(okAlly, ally)
	local okEnemy, enemy = BattleEngine.validatePlan(battle, "Enemy", enemyPlan or {})
	assert(okEnemy, enemy)
	return BattleEngine.resolveTurn(battle, ally, enemy)
end

local function findEvent(events, predicate)
	for _, event in events do
		if predicate(event) then
			return event
		end
	end
	return nil
end

return function(test, expect)
	test("dégâts : formule, élément, Garde, Armure brisée, Attaque renforcée", function()
		local battle = duel({ "F001" }, { "F002" })
		local kael, terra = battle.units.A1, battle.units.E1
		-- 135 × 100 / (100 + 140) × 1,25 = 70,31
		expect.equal(AbilitySystem.computeDamage(kael, terra, 1, "attack"), 70, "base Feu > Terre")
		terra.statuses.Guard = { duration = 1, power = 0, tickValue = 0 }
		expect.equal(AbilitySystem.computeDamage(kael, terra, 1, "attack"), 35, "Garde -50 %")
		terra.statuses.Guard = nil
		terra.statuses.DefenseDown = { duration = 1, power = 0.2, tickValue = 0 }
		-- DÉF 112 : 135 × 100 / 212 × 1,25 = 79,6
		expect.equal(AbilitySystem.computeDamage(kael, terra, 1, "attack"), 80, "Armure brisée")
		terra.statuses.DefenseDown = nil
		kael.statuses.AttackUp = { duration = 1, power = 0.15, tickValue = 0 }
		-- ATQ 155,25 : 155,25 × 100 / 240 × 1,25 = 80,9
		expect.equal(AbilitySystem.computeDamage(kael, terra, 1, "attack"), 81, "Attaque renforcée")
	end)

	test("les dégâts minimaux s'appliquent", function()
		local battle = duel({ "F002" }, { "F002" })
		expect.equal(AbilitySystem.computeDamage(battle.units.A1, battle.units.E1, 0.001, "attack"), Battle.MinDamage)
	end)

	test("le bouclier absorbe avant les PV", function()
		local battle = duel({ "F001" }, { "F002" })
		local terra = battle.units.E1
		terra.shield = 50
		local events = {}
		AbilitySystem.applyDamage(terra, 70, events, "A1")
		expect.equal(terra.shield, 0, "bouclier consommé")
		expect.equal(terra.hp, terra.maxHp - 20, "PV restants")
		expect.equal(events[1].absorbed, 50, "événement absorbé")
	end)

	test("les boucliers se cumulent jusqu'aux PV max", function()
		local battle = duel({ "F001" }, { "F002" })
		local kael = battle.units.A1
		AbilitySystem.applyShield(kael, kael.maxHp, {}, "A1")
		AbilitySystem.applyShield(kael, 100, {}, "A1")
		expect.equal(kael.shield, kael.maxHp, "plafond")
	end)

	test("les soins sont plafonnés aux PV max", function()
		local battle = duel({ "F001" }, { "F002" })
		local kael = battle.units.A1
		kael.hp = kael.maxHp - 10
		local healed = AbilitySystem.applyHeal(kael, 100, {}, "A1")
		expect.equal(healed, 10, "soin effectif")
		expect.equal(kael.hp, kael.maxHp, "PV max")
	end)

	test("un combattant à 0 PV tombe et perd ses effets", function()
		local battle = duel({ "F001" }, { "F002" })
		local terra = battle.units.E1
		terra.statuses.Taunt = { duration = 2, power = 0, tickValue = 0 }
		terra.charge = 50
		local events = {}
		AbilitySystem.applyDamage(terra, 99999, events, "A1")
		expect.falsy(terra.alive, "à terre")
		expect.equal(terra.hp, 0, "PV")
		expect.equal(terra.charge, 0, "jauge")
		expect.equal(next(terra.statuses), nil, "statuts retirés")
		expect.truthy(
			findEvent(events, function(e)
				return e.type == "Defeated"
			end),
			"événement Defeated"
		)
	end)

	test("le soin vise l'allié le plus blessé", function()
		local battle = duel({ "F003", "F001" }, { "F001" }, 0.01)
		local kael = battle.units.A2
		kael.hp = 500
		local events = play(battle, { A1 = { slot = "skill" } })
		local heal = findEvent(events, function(e)
			return e.type == "Heal" and e.kind == "Heal"
		end)
		expect.truthy(heal, "soin effectué")
		expect.equal(heal.target, "A2", "cible : Kael")
		expect.equal(heal.amount, 220, "2,0 × 110 ATQ")
	end)

	test("énergie : dépense, gain par tour et refus si insuffisante", function()
		local battle = BattleEngine.createEncounter(TEAM, Encounters.RiftEcho1)
		expect.equal(battle.energy.Ally, Battle.StartingEnergy, "énergie de départ")

		local ok, reason = BattleEngine.validatePlan(battle, "Ally", {
			A1 = { slot = "skill" },
			A3 = { slot = "skill", target = "E4" },
		})
		expect.falsy(ok, "6 énergie demandées pour 3")
		expect.contains(reason, "Énergie insuffisante")

		play(battle, { A1 = { slot = "skill", target = "E1" } })
		expect.equal(battle.energy.Ally, Battle.StartingEnergy - 3 + Battle.EnergyPerTurn, "après une compétence")
	end)

	test("se défendre rend de l'énergie, plafonnée", function()
		local battle = BattleEngine.createEncounter(TEAM, Encounters.RiftEcho1)
		play(battle, { A1 = { slot = "defend" } })
		expect.equal(
			battle.energy.Ally,
			Battle.StartingEnergy + Battle.DefendEnergyGain + Battle.EnergyPerTurn,
			"défense + tour"
		)
		battle.energy.Ally = Battle.MaxEnergy
		play(battle, { A1 = { slot = "defend" }, A2 = { slot = "defend" } })
		expect.equal(battle.energy.Ally, Battle.MaxEnergy, "plafond")
	end)

	test("la ligne avant protège la ligne arrière, sauf pour les assassins", function()
		local battle = BattleEngine.createEncounter(TEAM, Encounters.RiftEcho1)
		local blocked = BattleEngine.validatePlan(battle, "Ally", { A1 = { slot = "basic", target = "E4" } })
		expect.falsy(blocked, "Kael ne peut pas viser la ligne arrière")
		local allowed, reason = BattleEngine.validatePlan(battle, "Ally", { A3 = { slot = "skill", target = "E4" } })
		expect.truthy(allowed, reason)

		-- Ligne avant tombée : la ligne arrière devient accessible
		for _, uid in { "E1", "E2", "E3" } do
			battle.units[uid].alive = false
			battle.units[uid].hp = 0
		end
		local open, openReason = BattleEngine.validatePlan(battle, "Ally", { A1 = { slot = "basic", target = "E4" } })
		expect.truthy(open, openReason)
	end)

	test("les actions invalides sont refusées", function()
		local battle = BattleEngine.createEncounter(TEAM, Encounters.RiftEcho1)
		local cases = {
			{ name = "plan non table", plan = "attack" },
			{ name = "combattant adverse", plan = { E1 = { slot = "basic" } } },
			{ name = "combattant inconnu", plan = { Z9 = { slot = "basic" } } },
			{ name = "action inconnue", plan = { A1 = { slot = "teleport" } } },
			{ name = "entrée non table", plan = { A1 = "basic" } },
			{ name = "cible inexistante", plan = { A1 = { slot = "basic", target = "Z9" } } },
			{ name = "cible alliée pour une attaque", plan = { A1 = { slot = "basic", target = "A2" } } },
			{ name = "cible non textuelle", plan = { A1 = { slot = "basic", target = 3 } } },
			{ name = "ultime sans jauge", plan = { A1 = { slot = "ultimate" } } },
		}
		for _, case in cases do
			local ok = BattleEngine.validatePlan(battle, "Ally", case.plan)
			expect.falsy(ok, case.name)
		end
	end)

	test("l'ultime exige la jauge pleine et la vide", function()
		local battle = BattleEngine.createEncounter(TEAM, Encounters.RiftEcho1)
		battle.units.A1.charge = Battle.UltimateChargeMax
		battle.energy.Ally = Battle.MaxEnergy
		local events = play(battle, { A1 = { slot = "ultimate" } })
		local action = findEvent(events, function(e)
			return e.type == "Action" and e.actor == "A1"
		end)
		expect.equal(action.slot, "ultimate", "ultime lancé")
		expect.equal(#action.targets, 5, "Nova des braises touche les cinq ennemis")
		expect.truthy(battle.units.A1.charge < Battle.UltimateChargeMax, "jauge vidée")
	end)

	test("ordre de résolution par vitesse décroissante", function()
		local battle = BattleEngine.createEncounter(TEAM, Encounters.RiftEcho1)
		local events = play(battle)
		local previous = math.huge
		local first = nil
		for _, event in events do
			if event.type == "Action" then
				local speed = battle.units[event.actor].speed
				expect.truthy(speed <= previous, "vitesse croissante détectée pour " .. event.actor)
				previous = speed
				first = first or event.actor
			end
		end
		expect.equal(first, "A3", "Nox (130) agit en premier")
	end)

	test("égalité de vitesse : le camp allié agit d'abord", function()
		local battle = duel({ "F001" }, { "F001" })
		local events = play(battle)
		local first = findEvent(events, function(e)
			return e.type == "Action"
		end)
		expect.equal(first.actor, "A1")
	end)

	test("l'étourdissement fait perdre l'action suivante, même appliqué en cours de tour", function()
		local battle = duel({ "F005" }, { "F001" })
		battle.energy.Ally = Battle.MaxEnergy
		local events = play(battle, { A1 = { slot = "skill", target = "E1" } })
		local skip = findEvent(events, function(e)
			return e.type == "Skip" and e.actor == "E1"
		end)
		expect.truthy(skip, "Kael perd son tour")
		expect.equal(battle.units.E1.statuses.Stun, nil, "étourdissement consommé")
		local enemyAction = findEvent(events, function(e)
			return e.type == "Action" and e.actor == "E1"
		end)
		expect.equal(enemyAction, nil, "aucune action de Kael")
	end)

	test("la brûlure inflige ses dégâts en fin de tour puis expire", function()
		local battle = duel({ "F001" }, { "F002" })
		local events = play(battle, { A1 = { slot = "skill", target = "E1" } })
		local burn = findEvent(events, function(e)
			return e.type == "Damage" and e.kind == "Burn"
		end)
		expect.truthy(burn, "brûlure appliquée")
		expect.equal(burn.amount, 27, "0,2 × 135 ATQ")
		expect.equal(battle.units.E1.statuses.Burn.duration, 1, "un tour restant")
		play(battle)
		expect.equal(battle.units.E1.statuses.Burn, nil, "expirée après deux tours")
	end)

	test("la provocation redirige les attaques ciblées", function()
		local battle = duel({ "F002", "F001" }, { "F001" }, 0.5)
		local events = play(battle, { A1 = { slot = "defend" } }, { E1 = { slot = "basic", target = "A2" } })
		local attack = findEvent(events, function(e)
			return e.type == "Action" and e.actor == "E1"
		end)
		expect.equal(attack.targets[1], "A1", "attaque redirigée vers Terra")
	end)

	test("victoire quand toute l'équipe adverse est éliminée", function()
		local battle = duel({ "F001" }, { "F001" }, 0.01)
		local events = play(battle)
		expect.equal(battle.status, "Finished", "combat terminé")
		expect.equal(battle.winner, "Ally", "vainqueur")
		expect.truthy(
			findEvent(events, function(e)
				return e.type == "BattleEnd"
			end),
			"événement de fin"
		)
		local ok = BattleEngine.validatePlan(battle, "Ally", {})
		expect.falsy(ok, "plus aucun plan accepté")
	end)

	test("égalité à la limite de tours", function()
		local battle = duel({ "F002" }, { "F002" })
		battle.maxTurns = 1
		play(battle, { A1 = { slot = "defend" } }, { E1 = { slot = "defend" } })
		expect.equal(battle.status, "Finished", "terminé")
		expect.equal(battle.winner, "Draw", "égalité")
	end)

	test("le snapshot est une copie indépendante", function()
		local battle = duel({ "F001" }, { "F002" })
		local snapshot = BattleEngine.snapshot(battle)
		snapshot.units.A1.hp = 1
		snapshot.energy.Ally = 99
		expect.equal(battle.units.A1.hp, battle.units.A1.maxHp, "PV intacts")
		expect.equal(battle.energy.Ally, Battle.StartingEnergy, "énergie intacte")
	end)
end
