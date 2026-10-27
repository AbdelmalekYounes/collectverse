-- Ouverture des boosters : le client demande, le serveur tire et attribue.
-- Aucun résultat calculé par le client n'est jamais pris en compte.

local Players = game:GetService("Players")
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

-- Tirage imposé pour la prochaine ouverture d'un joueur : utilisé uniquement par
-- StudioDebug (Studio) pour vérifier les cartes rares sans toucher aux taux.
local scriptedRolls: { [Player]: BoosterLogic.NextInteger } = {}

function BoosterService.setNextRoll(player: Player, roll: BoosterLogic.NextInteger)
	scriptedRolls[player] = roll
end

local function openBooster(player: Player, boosterId: any)
	if type(boosterId) ~= "string" or #boosterId > 32 then
		return { ok = false, reason = "Booster invalide" }
	end
	-- Profil en lecture seule : on refuse plutôt que de montrer des cartes
	-- qui ne seraient jamais enregistrées.
	local modifiable, blocked = PlayerDataService.canModify(player)
	if not modifiable then
		return { ok = false, reason = blocked }
	end

	-- Le tirage, le crédit des cartes et la consommation du booster forment une
	-- seule modification du profil, enregistrée d'un bloc : jamais de cartes sans
	-- booster consommé, ni l'inverse. Sauvegarde rapide ensuite.
	local roll = scriptedRolls[player] or nextInteger
	scriptedRolls[player] = nil
	local success, result
	PlayerDataService.update(player, function(profile)
		success, result = BoosterLogic.open(profile, boosterId, roll)
		return success
	end, { saveNow = true })
	if not success then
		return { ok = false, reason = result or "Sauvegarde indisponible" }
	end
	return { ok = true, cards = result.cards, remaining = result.remaining }
end

function BoosterService.start()
	RemoteGuard.bindFunction(Remotes.getFunction("OpenBooster"), { maxRequests = 3, windowSeconds = 4 }, openBooster)
	Players.PlayerRemoving:Connect(function(player)
		scriptedRolls[player] = nil
	end)
end

return BoosterService
