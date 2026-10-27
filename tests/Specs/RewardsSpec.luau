-- Non-régression du gameplay de progression : combats (victoire, défaite,
-- abandon, reprise, récompense unique) et boosters (ouvertures successives,
-- déblocage d'un légendaire, disponibilité immédiate dans l'équipe).
-- Les tirages rares utilisent une fixture déterministe, sans toucher aux taux.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Boosters = require(Shared.Catalog.Boosters)
local CombatAI = require(Shared.Battle.CombatAI)
local TeamRules = require(Shared.Battle.TeamRules)
local Server = ServerScriptService.Server
local ProfileTemplate = require(Server.Data.ProfileTemplate)
local BattleRewards = require(Server.Logic.BattleRewards)
local BattleSessions = require(Server.Logic.BattleSessions)
local BoosterLogic = require(Server.Logic.BoosterLogic)
local Inventory = require(Server.Logic.Inventory)
local BoosterFixtures = require(ServerScriptService.Tests.Fixtures.BoosterFixtures)

local ENCOUNTER = "RiftEcho1"
local PLAYER = "joueur"
local FIRST_RIFT = Boosters.FirstRift

-- Combats branchés sur un vrai profil ; compte les attributions d'issue.
local function newBattles(options)
	local opts = options or {}
	local world = { profile = ProfileTemplate.create(), outcomes = {} }
	world.battles = BattleSessions.new({
		getProfile = function()
			return world.profile
		end,
		canModify = function()
			if opts.readonly then
				return false, "Sauvegarde indisponible"
			end
			return true
		end,
		applyOutcome = function(_, winner)
			table.insert(world.outcomes, winner or "Draw")
			return BattleRewards.apply(world.profile, winner, GameConfig.Progression.VictoryBoosters)
		end,
	})
	return world
end

-- Joue le combat avec l'IA côté allié jusqu'à la fin ; renvoie la dernière réponse.
local function playToEnd(world)
	local response
	for _ = 1, GameConfig.Battle.MaxTurns + 1 do
		local battle = world.battles.sessions[PLAYER].battle
		if battle.status ~= "Planning" then
			break
		end
		response = world.battles:submit(PLAYER, CombatAI.choosePlan(battle, "Ally"), battle.turn)
		assert(response.ok, tostring(response.reason))
	end
	return response
end

local function copiesOf(profile): number
	local _, copies = Inventory.summary(profile)
	return copies
end

return function(test, expect)
	test("victoire : un booster, attribué une seule fois", function()
		local world = newBattles()
		local boosters = world.profile.boosters.FirstRift
		expect.truthy(world.battles:start(PLAYER, ENCOUNTER).ok, "lancement")
		local final = playToEnd(world)
		expect.equal(final.snapshot.winner, "Ally", "victoire")
		expect.equal(final.rewards.boosters.FirstRift, 1, "récompense annoncée")
		expect.equal(world.profile.boosters.FirstRift, boosters + 1, "booster crédité")

		-- Toute tentative de rejouer la fin est refusée, sans nouvelle récompense.
		expect.falsy(world.battles:submit(PLAYER, {}, final.snapshot.turn).ok, "tour après la fin")
		expect.falsy(world.battles:forfeit(PLAYER).ok, "abandon après la fin")
		expect.equal(#world.outcomes, 1, "issue appliquée une fois")
		expect.equal(world.profile.boosters.FirstRift, boosters + 1, "toujours un seul booster")
		expect.equal(world.profile.stats.battlesWon, 1)
	end)

	test("abandon : défaite comptée, aucune récompense, une seule fois", function()
		local world = newBattles()
		local boosters = world.profile.boosters.FirstRift
		world.battles:start(PLAYER, ENCOUNTER)
		expect.truthy(world.battles:isInBattle(PLAYER), "en combat")
		local result = world.battles:forfeit(PLAYER)
		expect.truthy(result.ok, "abandon accepté")
		expect.equal(result.snapshot.winner, "Enemy", "défaite")
		expect.falsy(world.battles:forfeit(PLAYER).ok, "second abandon refusé")
		expect.equal(#world.outcomes, 1, "issue appliquée une fois")
		expect.equal(world.profile.stats.battlesLost, 1, "défaite comptée")
		expect.equal(world.profile.boosters.FirstRift, boosters, "aucun booster")
		expect.falsy(world.battles:isInBattle(PLAYER), "équipe de nouveau modifiable")
	end)

	test("réouverture pendant un combat : reprise au même tour, sans nouveau combat", function()
		local world = newBattles()
		world.battles:start(PLAYER, ENCOUNTER)
		local battle = world.battles.sessions[PLAYER].battle
		world.battles:submit(PLAYER, CombatAI.choosePlan(battle, "Ally"), battle.turn)
		local turn = battle.turn
		local resumed = world.battles:start(PLAYER, ENCOUNTER)
		expect.truthy(resumed.ok and resumed.resumed, "reprise")
		expect.equal(resumed.snapshot.turn, turn, "même tour")
		expect.equal(world.battles.sessions[PLAYER].battle, battle, "même combat côté serveur")
		expect.equal(#world.outcomes, 0, "aucune issue appliquée")
	end)

	test("un tour déjà joué (double envoi) n'est pas résolu deux fois", function()
		local world = newBattles()
		world.battles:start(PLAYER, ENCOUNTER)
		local battle = world.battles.sessions[PLAYER].battle
		local plan = CombatAI.choosePlan(battle, "Ally")
		local turn = battle.turn
		expect.truthy(world.battles:submit(PLAYER, plan, turn).ok, "premier envoi")
		local again = world.battles:submit(PLAYER, plan, turn)
		expect.falsy(again.ok, "second envoi refusé")
		expect.equal(battle.turn, turn + 1, "un seul tour résolu")
	end)

	test("profil en lecture seule : combat refusé (récompense impossible à enregistrer)", function()
		local world = newBattles({ readonly = true })
		local result = world.battles:start(PLAYER, ENCOUNTER)
		expect.falsy(result.ok, "refusé")
		expect.contains(tostring(result.reason), "Sauvegarde")
		expect.falsy(world.battles:isInBattle(PLAYER))
	end)

	test("départ pendant un combat : abandonné sans être comptabilisé", function()
		local world = newBattles()
		world.battles:start(PLAYER, ENCOUNTER)
		world.battles:remove(PLAYER)
		expect.falsy(world.battles:isInBattle(PLAYER))
		expect.equal(#world.outcomes, 0, "aucune issue")
		expect.truthy(world.battles:start(PLAYER, ENCOUNTER).ok, "un nouveau combat est possible")
	end)

	test("ouvertures successives : chaque booster consommé une fois, 5 cartes chacun", function()
		local profile = ProfileTemplate.create()
		profile.boosters.FirstRift = 5
		local copies = copiesOf(profile)
		local seed = 3
		for index = 1, 5 do
			seed += 7
			local state = seed
			local ok, result = BoosterLogic.open(profile, "FirstRift", function(min, max)
				state = (state * 1103515245 + 12345) % 2147483648
				return min + state % (max - min + 1)
			end)
			expect.truthy(ok, "ouverture " .. index)
			expect.equal(result.remaining, 5 - index, "restants")
		end
		expect.equal(copiesOf(profile), copies + 25, "25 cartes ajoutées")
		expect.equal(profile.stats.boostersOpened, 5)
		local before = copiesOf(profile)
		local ok = BoosterLogic.open(profile, "FirstRift", function(min)
			return min
		end)
		expect.falsy(ok, "plus de booster")
		expect.equal(copiesOf(profile), before, "rien n'est crédité sans booster")
	end)

	test("légendaire : Oris débloqué et utilisable aussitôt dans l'équipe", function()
		local profile = ProfileTemplate.create()
		expect.falsy(profile.unlockedFighters.F006, "Oris verrouillé au départ")
		local rng = BoosterFixtures.scripted(FIRST_RIFT, { "F001", "F002", "F003", "I001", "F006" })
		local ok, result = BoosterLogic.open(profile, "FirstRift", rng)
		expect.truthy(ok, "ouverture")
		local oris = result.cards[5]
		expect.equal(oris.id, "F006")
		expect.equal(oris.rarity, "Legendary")
		expect.truthy(oris.isNew and oris.unlockedFighter, "nouveau et débloqué")
		expect.truthy(profile.unlockedFighters.F006, "déblocage enregistré dans le profil")

		-- Le serveur accepte immédiatement une équipe avec Oris (validation de SetTeam).
		local team = { "F001", "F002", "F004", "F003", "F006" }
		local valid, reason = TeamRules.validate(team, profile.unlockedFighters)
		expect.truthy(valid, reason)

		-- Second exemplaire : doublon conservé, pas de nouveau déblocage.
		local again = BoosterFixtures.scripted(FIRST_RIFT, { "F001", "F001", "F001", "F001", "F006" })
		profile.boosters.FirstRift = 1
		local _, second = BoosterLogic.open(profile, "FirstRift", again)
		expect.equal(second.cards[5].count, 2, "deux exemplaires")
		expect.falsy(second.cards[5].isNew or second.cards[5].unlockedFighter, "doublon")
	end)

	test("la fixture ne peut pas produire un tirage impossible en production", function()
		expect.fails(function()
			-- Kael est Commun : interdit dans l'emplacement garanti (Rare ou mieux).
			BoosterFixtures.scripted(FIRST_RIFT, { "F001", "F001", "F001", "F001", "F001" })
		end, "Commune dans l'emplacement garanti")
	end)
end
