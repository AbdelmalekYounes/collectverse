-- Profils des joueurs, détenus par le serveur.
--
-- Jalon 2 : profils en mémoire uniquement, perdus à la déconnexion. Le client en
-- est informé (persistence = "Session") et l'affiche. Le jalon 4 ajoutera la
-- persistance DataStore, le versionnement et un adaptateur simulé pour les tests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local Server = script.Parent.Parent
local ProfileTemplate = require(Server.Data.ProfileTemplate)
local RemoteGuard = require(Server.Net.RemoteGuard)

local PlayerDataService = {}

PlayerDataService.PersistenceMode = "Session"

local profiles: { [Player]: any } = {}
local profileUpdated: RemoteEvent

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

function PlayerDataService.getProfile(player: Player)
	return profiles[player]
end

-- Vue envoyée au client : une copie, jamais la table du serveur.
function PlayerDataService.toClientView(profile)
	local view = deepCopy(profile)
	view.persistence = PlayerDataService.PersistenceMode
	return view
end

-- Point unique de modification d'un profil : le client est notifié après chaque changement.
function PlayerDataService.update(player: Player, mutator: (profile: any) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	mutator(profile)
	if player.Parent then
		profileUpdated:FireClient(player, PlayerDataService.toClientView(profile))
	end
	return true
end

local function onPlayerAdded(player: Player)
	if not profiles[player] then
		profiles[player] = ProfileTemplate.create()
	end
end

function PlayerDataService.start()
	profileUpdated = Remotes.getEvent("ProfileUpdated")

	RemoteGuard.bindFunction(
		Remotes.getFunction("GetProfile"),
		{ maxRequests = 10, windowSeconds = 10 },
		function(player)
			local profile = profiles[player]
			if not profile then
				return { ok = false, reason = "Profil en cours de chargement" }
			end
			return { ok = true, profile = PlayerDataService.toClientView(profile) }
		end
	)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		profiles[player] = nil
	end)

	warn(
		"[Collectverse] Sauvegarde non active : les profils ne durent que le temps de la session (persistance au jalon 4)"
	)
end

return PlayerDataService
