-- Copie locale (lecture seule) du profil détenu par le serveur.
-- Le client ne modifie jamais ce profil : il demande au serveur, qui renvoie
-- la nouvelle version via l'événement ProfileUpdated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local DataController = {}

local RETRY_DELAY = 1
local MAX_ATTEMPTS = 10

local profile = nil
local changed = Instance.new("BindableEvent")
DataController.Changed = changed.Event

local function setProfile(newProfile)
	profile = newProfile
	changed:Fire(profile)
end

function DataController.getProfile()
	return profile
end

-- Demande au serveur d'enregistrer une équipe ; la réponse fait foi.
function DataController.requestSetTeam(team: { string })
	local remote = Remotes.getFunction("SetTeam")
	local ok, result = pcall(remote.InvokeServer, remote, team)
	if not ok or type(result) ~= "table" then
		return { ok = false, reason = "Connexion au serveur impossible" }
	end
	return result
end

function DataController.init()
	Remotes.getEvent("ProfileUpdated").OnClientEvent:Connect(setProfile)

	task.spawn(function()
		local getProfile = Remotes.getFunction("GetProfile")
		for _ = 1, MAX_ATTEMPTS do
			local ok, result = pcall(getProfile.InvokeServer, getProfile)
			if ok and type(result) == "table" and result.ok then
				setProfile(result.profile)
				return
			end
			task.wait(RETRY_DELAY)
		end
		warn("[DataController] Profil indisponible après plusieurs tentatives")
	end)
end

return DataController
