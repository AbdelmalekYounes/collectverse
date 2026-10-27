-- Combats PvE : branche les remotes sur BattleSessions (logique pure, testée avec
-- Lune) et applique l'issue des combats au profil via PlayerDataService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Net.Remotes)

local Server = script.Parent.Parent
local RemoteGuard = require(Server.Net.RemoteGuard)
local BattleRewards = require(Server.Logic.BattleRewards)
local BattleSessions = require(Server.Logic.BattleSessions)
local PlayerDataService = require(script.Parent.PlayerDataService)

local BattleService = {}

local battles = BattleSessions.new({
	getProfile = PlayerDataService.getProfile,
	canModify = PlayerDataService.canModify,
	applyOutcome = function(player: Player, winner: string?)
		local rewards = { boosters = {} }
		-- Récompense : sauvegarde rapide, pour ne pas dépendre de la prochaine périodique.
		PlayerDataService.update(player, function(profile)
			rewards = BattleRewards.apply(profile, winner, GameConfig.Progression.VictoryBoosters)
		end, { saveNow = true })
		return rewards
	end,
})

function BattleService.isInBattle(player: Player): boolean
	return battles:isInBattle(player)
end

function BattleService.start()
	RemoteGuard.bindFunction(
		Remotes.getFunction("StartBattle"),
		{ maxRequests = 3, windowSeconds = 5 },
		function(player, encounterId)
			return battles:start(player, encounterId)
		end
	)
	RemoteGuard.bindFunction(
		Remotes.getFunction("SubmitTurn"),
		{ maxRequests = 4, windowSeconds = 2 },
		function(player, plan, expectedTurn)
			return battles:submit(player, plan, expectedTurn)
		end
	)
	RemoteGuard.bindFunction(
		Remotes.getFunction("ForfeitBattle"),
		{ maxRequests = 3, windowSeconds = 5 },
		function(player)
			return battles:forfeit(player)
		end
	)

	Players.PlayerRemoving:Connect(function(player)
		battles:remove(player)
	end)
end

return BattleService
