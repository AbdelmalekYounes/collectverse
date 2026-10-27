-- Combats PvE en cours, un par joueur, entièrement résolus par le serveur.
-- Le client n'envoie que des intentions (plan d'actions du tour). On nettoie et
-- valide le plan, fait jouer l'IA, résout le tour, puis renvoie les événements et
-- l'état. Les récompenses sont attribuées une seule fois par combat, ici.
--
-- Logique pure : l'accès au profil et l'attribution des récompenses sont injectés
-- (BattleService en jeu, fonctions simulées dans les tests Lune).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Encounters = require(Shared.Catalog.Encounters)
local BattleEngine = require(Shared.Battle.BattleEngine)
local CombatAI = require(Shared.Battle.CombatAI)
local PlanSanitizer = require(Shared.Battle.PlanSanitizer)
local TeamRules = require(Shared.Battle.TeamRules)

local BattleSessions = {}
BattleSessions.__index = BattleSessions

export type Dependencies = {
	getProfile: (player: any) -> any?,
	-- Faux si le profil ne peut pas enregistrer de progression (lecture seule).
	canModify: (player: any) -> (boolean, string?),
	-- Applique l'issue au profil ; renvoie les récompenses réellement attribuées.
	applyOutcome: (player: any, winner: string?) -> { boosters: { [string]: number } },
}

type Session = { battle: any, encounterId: string, rewarded: boolean }

function BattleSessions.new(dependencies: Dependencies)
	return setmetatable({ deps = dependencies, sessions = {} :: { [any]: Session } }, BattleSessions)
end

function BattleSessions.isInBattle(self, player: any): boolean
	local session = self.sessions[player]
	return session ~= nil and session.battle.status == "Planning"
end

-- Enregistre l'issue et attribue les récompenses (une seule fois par combat).
local function settle(self, player: any, session: Session)
	if session.rewarded then
		return nil
	end
	session.rewarded = true
	return self.deps.applyOutcome(player, session.battle.winner)
end

function BattleSessions.start(self, player: any, encounterId: any)
	if type(encounterId) ~= "string" or #encounterId > 32 then
		return { ok = false, reason = "Rencontre invalide" }
	end
	local encounter = Encounters[encounterId]
	if not encounter then
		return { ok = false, reason = "Rencontre inconnue" }
	end

	local existing = self.sessions[player]
	if existing and existing.battle.status == "Planning" then
		-- Reprise après un rechargement de l'interface
		if existing.encounterId == encounterId then
			return { ok = true, resumed = true, snapshot = BattleEngine.snapshot(existing.battle) }
		end
		return { ok = false, reason = "Un combat est déjà en cours" }
	end

	local profile = self.deps.getProfile(player)
	if not profile then
		return { ok = false, reason = "Profil indisponible" }
	end
	-- Un combat dont la récompense ne pourrait pas être enregistrée n'est pas lancé.
	local modifiable, blocked = self.deps.canModify(player)
	if not modifiable then
		return { ok = false, reason = blocked }
	end
	-- L'équipe enregistrée a déjà été validée, mais le serveur ne présume de rien.
	local valid, reason = TeamRules.validate(profile.team, profile.unlockedFighters)
	if not valid then
		return { ok = false, reason = "Équipe invalide : " .. tostring(reason) }
	end

	local battle = BattleEngine.createEncounter(profile.team, encounter)
	self.sessions[player] = { battle = battle, encounterId = encounterId, rewarded = false }
	return { ok = true, snapshot = BattleEngine.snapshot(battle) }
end

function BattleSessions.submit(self, player: any, rawPlan: any, expectedTurn: any)
	local session = self.sessions[player]
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
	local rewards = if battle.status == "Finished" then settle(self, player, session) else nil
	return { ok = true, events = events, snapshot = BattleEngine.snapshot(battle), rewards = rewards }
end

function BattleSessions.forfeit(self, player: any)
	local session = self.sessions[player]
	if not session or session.battle.status ~= "Planning" then
		return { ok = false, reason = "Aucun combat en cours" }
	end
	session.battle.status = "Finished"
	session.battle.winner = "Enemy"
	settle(self, player, session)
	return { ok = true, snapshot = BattleEngine.snapshot(session.battle) }
end

-- Départ du joueur : le combat en cours est abandonné sans être comptabilisé.
function BattleSessions.remove(self, player: any)
	self.sessions[player] = nil
end

return BattleSessions
