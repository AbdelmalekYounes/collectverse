-- Point d'entrée client.
-- Jalon 1 : interface du Hub, navigation entre écrans et ambiance.
-- Jalon 2 : profil (lecture seule), équipe et combats via le serveur.

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Controllers = script.Parent.Controllers
local DataController = require(Controllers.DataController)
local UIController = require(Controllers.UIController)
local ZoneController = require(Controllers.ZoneController)
local HubAmbience = require(Controllers.HubAmbience)

UIController.init()
DataController.init()
ZoneController.init()
HubAmbience.init()
