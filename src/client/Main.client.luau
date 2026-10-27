-- Point d'entrée client.
-- Jalon 1 : interface du Hub, navigation entre écrans et ambiance.

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Controllers = script.Parent.Controllers
local UIController = require(Controllers.UIController)
local ZoneController = require(Controllers.ZoneController)
local HubAmbience = require(Controllers.HubAmbience)

UIController.init()
ZoneController.init()
HubAmbience.init()
