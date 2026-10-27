-- Synchronise les préférences locales (ClientSettings) avec le profil sauvegardé.
-- Au premier chargement du profil, les préférences enregistrées s'appliquent ;
-- ensuite, chaque changement fait par le joueur est envoyé au serveur.

local Client = script.Parent.Parent
local ClientSettings = require(Client.State.ClientSettings)
local DataController = require(script.Parent.DataController)

local SettingsSync = {}

local applying = false
local applied = false

local function applyFromProfile(profile)
	if applied or not profile or type(profile.settings) ~= "table" then
		return
	end
	applied = true
	applying = true
	for key, value in profile.settings do
		-- pcall : une clé inconnue de cette version du client est ignorée.
		pcall(ClientSettings.set, key, value)
	end
	applying = false
end

function SettingsSync.init()
	DataController.Changed:Connect(applyFromProfile)
	applyFromProfile(DataController.getProfile())

	ClientSettings.Changed:Connect(function(key, value)
		if applying then
			return
		end
		task.spawn(DataController.requestSetSettings, { [key] = value })
	end)
end

return SettingsSync
