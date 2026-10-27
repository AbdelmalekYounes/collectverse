-- Composition d'équipe : seul le serveur décide de ce qui est enregistré.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Net.Remotes)
local TeamRules = require(Shared.Battle.TeamRules)

local Server = script.Parent.Parent
local RemoteGuard = require(Server.Net.RemoteGuard)
local BattleService = require(script.Parent.BattleService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local TeamService = {}

local function setTeam(player: Player, team: any)
	local profile = PlayerDataService.getProfile(player)
	if not profile then
		return { ok = false, reason = "Profil indisponible" }
	end
	if BattleService.isInBattle(player) then
		return { ok = false, reason = "Impossible de modifier l'équipe pendant un combat" }
	end
	local valid, reason = TeamRules.validate(team, profile.unlockedFighters)
	if not valid then
		return { ok = false, reason = reason }
	end

	-- On ne conserve jamais la table envoyée par le client.
	local copy = {}
	for slot = 1, GameConfig.Team.Size do
		copy[slot] = team[slot]
	end
	PlayerDataService.update(player, function(data)
		data.team = copy
	end)
	return { ok = true, team = copy }
end

function TeamService.start()
	RemoteGuard.bindFunction(Remotes.getFunction("SetTeam"), { maxRequests = 5, windowSeconds = 5 }, setTeam)
end

return TeamService
