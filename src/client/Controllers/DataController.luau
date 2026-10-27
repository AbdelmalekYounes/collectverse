-- Copie locale (lecture seule) du profil détenu par le serveur.
-- Le client ne modifie jamais ce profil : il demande au serveur, qui renvoie
-- la nouvelle version via l'événement ProfileUpdated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local DataController = {}

local RETRY_DELAY = 1
local MAX_ATTEMPTS = 20

local profile = nil
local changed = Instance.new("BindableEvent")
DataController.Changed = changed.Event

local function setProfile(newProfile)
	profile = newProfile
	changed:Fire(profile)
end

local function invoke(name: string, ...): any
	local remote = Remotes.getFunction(name)
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if not ok or type(result) ~= "table" then
		return { ok = false, reason = "Connexion au serveur impossible" }
	end
	return result
end

function DataController.getProfile()
	return profile
end

-- Les réponses du serveur font foi ; le profil à jour arrive par ProfileUpdated.
function DataController.requestSetTeam(team: { string })
	return invoke("SetTeam", team)
end

function DataController.requestOpenBooster(boosterId: string)
	return invoke("OpenBooster", boosterId)
end

function DataController.requestSetSettings(settings: { [string]: boolean })
	return invoke("SetSettings", settings)
end

function DataController.init()
	Remotes.getEvent("ProfileUpdated").OnClientEvent:Connect(setProfile)

	-- Le serveur pousse le profil dès qu'il est chargé ; cette demande couvre
	-- le cas où le client serait prêt après cet envoi.
	task.spawn(function()
		for _ = 1, MAX_ATTEMPTS do
			if profile then
				return
			end
			local result = invoke("GetProfile")
			if result.ok and not profile then
				setProfile(result.profile)
				return
			end
			task.wait(RETRY_DELAY)
		end
		if not profile then
			warn("[DataController] Profil indisponible après plusieurs tentatives")
		end
	end)
end

return DataController
