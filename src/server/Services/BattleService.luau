-- Combats PvE, entièrement résolus par le serveur.
-- Le client n'envoie que des intentions (plan d'actions du tour). Le serveur
-- nettoie et valide le plan, fait jouer l'IA, résout le tour, puis renvoie les
-- événements et l'état. Les récompenses sont attribuées une seule fois, ici.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Encounters = require(Shared.Catalog.Encounters)
local Remotes = require(Shared.Net.Remotes)
local BattleEngine = require(Shared.Battle.BattleEngine)
local CombatAI = require(Shared.Battle.CombatAI)
local PlanSanitizer = require(Shared.Battle.PlanSanitizer)
local TeamRules = require(Shared.Battle.TeamRules)

local Server = script.Parent.Parent
local RemoteGuard = require(Server.Net.RemoteGuard)
local PlayerDataService = require(script.Parent.PlayerDataService)

local BattleService = {}

type Session = { battle: any, encounterId: string, rewarded: boolean }

local sessions: { [Player]: Session } = {}

function BattleService.isInBattle(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.battle.status == "Planning"
end

-- Enregistre l'issue et attribue les récompenses (une seule fois par combat).
local function settle(player: Player, session: Session)
	if session.rewarded then
		return nil
	end
	session.rewarded = true

	local winner = session.battle.winner
	local rewards = { boosters = {} }
	PlayerDataService.update(player, function(profile)
		if winner == "Ally" then
			profile.stats.battlesWon += 1
			for boosterId, quantity in GameConfig.Progression.VictoryBoosters do
				profile.boosters[boosterId] = (profile.boosters[boosterId] or 0) + quantity
				rewards.boosters[boosterId] = quantity
			end
		elseif winner == "Enemy" then
			profile.stats.battlesLost += 1
		else
			profile.stats.battlesDrawn += 1
		end
	end)
	return rewards
end

local function startBattle(player: Player, encounterId: any)
	if type(encounterId) ~= "string" or #encounterId > 32 then
		return { ok = false, reason = "Rencontre invalide" }
	end
	local encounter = Encounters[encounterId]
	if not encounter then
		return { ok = false, reason = "Rencontre inconnue" }
	end

	local existing = sessions[player]
	if existing and existing.battle.status == "Planning" then
		-- Reprise après un rechargement de l'interface
		if existing.encounterId == encounterId then
			return { ok = true, resumed = true, snapshot = BattleEngine.snapshot(existing.battle) }
		end
		return { ok = false, reason = "Un combat est déjà en cours" }
	end

	local profile = PlayerDataService.getProfile(player)
	if not profile then
		return { ok = false, reason = "Profil indisponible" }
	end
	-- L'équipe enregistrée a déjà été validée, mais le serveur ne présume de rien.
	local valid, reason = TeamRules.validate(profile.team, profile.unlockedFighters)
	if not valid then
		return { ok = false, reason = "Équipe invalide : " .. tostring(reason) }
	end

	local battle = BattleEngine.createEncounter(profile.team, encounter)
	sessions[player] = { battle = battle, encounterId = encounterId, rewarded = false }
	return { ok = true, snapshot = BattleEngine.snapshot(battle) }
end

local function submitTurn(player: Player, rawPlan: any, expectedTurn: any)
	local session = sessions[player]
	if not session or session.battle.status ~= "Planning" then
		return { ok = false, reason = "Aucun combat en cours" }
	end
	local battle = session.battle
	-- Empêche le rejeu d'un même plan (double clic, latence).
	if expectedTurn ~= battle.turn then
		return { ok = false, reason = "Ce tour a déjà été joué" }
	end

	local plan, sanitizeError = PlanSanitizer.sanitize(rawPlan)
	if not plan then
		return { ok = false, reason = sanitizeError }
	end
	local valid, allyPlan = BattleEngine.validatePlan(battle, "Ally", plan)
	if not valid then
		return { ok = false, reason = allyPlan }
	end
	local enemyValid, enemyPlan = BattleEngine.validatePlan(battle, "Enemy", CombatAI.choosePlan(battle, "Enemy"))
	if not enemyValid then
		error("Plan de l'IA invalide : " .. tostring(enemyPlan))
	end

	local events = BattleEngine.resolveTurn(battle, allyPlan, enemyPlan)
	local rewards = if battle.status == "Finished" then settle(player, session) else nil
	return { ok = true, events = events, snapshot = BattleEngine.snapshot(battle), rewards = rewards }
end

local function forfeit(player: Player)
	local session = sessions[player]
	if not session or session.battle.status ~= "Planning" then
		return { ok = false, reason = "Aucun combat en cours" }
	end
	session.battle.status = "Finished"
	session.battle.winner = "Enemy"
	settle(player, session)
	return { ok = true, snapshot = BattleEngine.snapshot(session.battle) }
end

function BattleService.start()
	RemoteGuard.bindFunction(Remotes.getFunction("StartBattle"), { maxRequests = 3, windowSeconds = 5 }, startBattle)
	RemoteGuard.bindFunction(Remotes.getFunction("SubmitTurn"), { maxRequests = 4, windowSeconds = 2 }, submitTurn)
	RemoteGuard.bindFunction(Remotes.getFunction("ForfeitBattle"), { maxRequests = 3, windowSeconds = 5 }, forfeit)

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

return BattleService
