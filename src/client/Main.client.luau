-- Point d'entrée client.
-- Jalon 1 : interface du Hub, navigation entre écrans et ambiance.
-- Jalon 2 : profil (lecture seule), équipe et combats via le serveur.
-- Jalon 4 : préférences synchronisées avec le profil sauvegardé.

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Controllers = script.Parent.Controllers
local DataController = require(Controllers.DataController)
local UIController = require(Controllers.UIController)
local ZoneController = require(Controllers.ZoneController)
local HubAmbience = require(Controllers.HubAmbience)
local SettingsSync = require(Controllers.SettingsSync)
local PerfProbe = require(Controllers.PerfProbe)

UIController.init()
DataController.init()
SettingsSync.init()
ZoneController.init()
HubAmbience.init()
PerfProbe.init()
