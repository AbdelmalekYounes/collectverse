-- Ouverture des boosters : le client demande, le serveur tire et attribue.
-- Aucun résultat calculé par le client n'est jamais pris en compte.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local Server = script.Parent.Parent
local RemoteGuard = require(Server.Net.RemoteGuard)
local BoosterLogic = require(Server.Logic.BoosterLogic)
local PlayerDataService = require(script.Parent.PlayerDataService)

local BoosterService = {}

local random = Random.new()

local function nextInteger(min: number, max: number): number
	return random:NextInteger(min, max)
end

local function openBooster(player: Player, boosterId: any)
	if type(boosterId) ~= "string" or #boosterId > 32 then
		return { ok = false, reason = "Booster invalide" }
	end
	if not PlayerDataService.getProfile(player) then
		return { ok = false, reason = "Profil en cours de chargement" }
	end

	local success, result
	PlayerDataService.update(player, function(profile)
		success, result = BoosterLogic.open(profile, boosterId, nextInteger)
		return success
	end)
	if not success then
		return { ok = false, reason = result }
	end
	return { ok = true, cards = result.cards, remaining = result.remaining }
end

function BoosterService.start()
	RemoteGuard.bindFunction(Remotes.getFunction("OpenBooster"), { maxRequests = 3, windowSeconds = 4 }, openBooster)
end

return BoosterService
