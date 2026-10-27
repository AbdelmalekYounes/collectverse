-- Relie les zones 3D du Hub aux écrans : une invite de proximité portant
-- l'attribut "CollectverseScreen" ouvre l'écran correspondant.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local UIController = require(script.Parent.UIController)

local ZoneController = {}

function ZoneController.init()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if player ~= Players.LocalPlayer then
			return
		end
		local screenId = prompt:GetAttribute("CollectverseScreen")
		if type(screenId) == "string" then
			UIController.open(screenId)
		end
	end)
end

return ZoneController
