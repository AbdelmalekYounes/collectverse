-- Parcours de progression de bout en bout, côté logique serveur :
-- profil neuf → équipe → combat gagné → booster crédité → ouverture → collection.
-- Mêmes modules que les services, sans réseau ni DataStore.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Encounters = require(Shared.Catalog.Encounters)
local BattleEngine = require(Shared.Battle.BattleEngine)
local CombatAI = require(Shared.Battle.CombatAI)
local TeamRules = require(Shared.Battle.TeamRules)
local Server = ServerScriptService.Server
local ProfileTemplate = require(Server.Data.ProfileTemplate)
local BattleRewards = require(Server.Logic.BattleRewards)
local BoosterLogic = require(Server.Logic.BoosterLogic)
local Inventory = require(Server.Logic.Inventory)

local VICTORY = GameConfig.Progression.VictoryBoosters

-- xorshift32 : générateur déterministe, indépendant de Roblox.
local function makeRng(seed: number)
	local state = seed
	return function(min: number, max: number): number
		state = bit32.bxor(state, bit32.lshift(state, 13))
		state = bit32.bxor(state, bit32.rshift(state, 17))
		state = bit32.bxor(state, bit32.lshift(state, 5))
		return min + state % (max - min + 1)
	end
end

-- L'IA joue les deux camps jusqu'à la fin du combat.
local function playOut(battle)
	local guard = 0
	while battle.status == "Planning" and guard <= battle.maxTurns do
		guard += 1
		local _, ally = BattleEngine.validatePlan(battle, "Ally", CombatAI.choosePlan(battle, "Ally"))
		local _, enemy = BattleEngine.validatePlan(battle, "Enemy", CombatAI.choosePlan(battle, "Enemy"))
		BattleEngine.resolveTurn(battle, ally, enemy)
	end
	return battle
end

return function(test, expect)
	test("parcours complet : équipe, victoire, booster, ouverture, collection", function()
		local profile = ProfileTemplate.create()
		expect.truthy(TeamRules.validate(profile.team, profile.unlockedFighters), "équipe de départ valide")

		-- Booster de démonstration du premier lancement
		local ok = BoosterLogic.open(profile, "FirstRift", makeRng(11))
		expect.truthy(ok, "booster de démonstration ouvert")
		expect.equal(profile.boosters.FirstRift, 0)

		local battle = playOut(BattleEngine.createEncounter(profile.team, Encounters.RiftEcho1))
		expect.equal(battle.winner, "Ally", "l'équipe par défaut gagne la rencontre 1")

		local rewards = BattleRewards.apply(profile, battle.winner, VICTORY)
		expect.equal(rewards.boosters.FirstRift, 1, "récompense annoncée")
		expect.equal(profile.boosters.FirstRift, 1, "booster crédité")
		expect.equal(profile.stats.battlesWon, 1)

		local _, copiesBefore = Inventory.summary(profile)
		local opened, result = BoosterLogic.open(profile, "FirstRift", makeRng(29))
		expect.truthy(opened, "booster de victoire ouvert")
		local _, copiesAfter = Inventory.summary(profile)
		expect.equal(copiesAfter, copiesBefore + #result.cards, "collection mise à jour")
		expect.equal(profile.boosters.FirstRift, 0)
		expect.equal(profile.stats.boostersOpened, 2)
	end)

	test("défaite et égalité : statistiques seules, aucun booster", function()
		local profile = ProfileTemplate.create()
		local before = profile.boosters.FirstRift

		local lost = BattleRewards.apply(profile, "Enemy", VICTORY)
		expect.equal(next(lost.boosters), nil, "aucune récompense en cas de défaite")
		expect.equal(profile.stats.battlesLost, 1)

		local drawn = BattleRewards.apply(profile, nil, VICTORY)
		expect.equal(next(drawn.boosters), nil, "aucune récompense en cas d'égalité")
		expect.equal(profile.stats.battlesDrawn, 1)

		expect.equal(profile.boosters.FirstRift, before, "boosters inchangés")
		expect.equal(profile.stats.battlesWon, 0)
	end)
end
