-- Applique la politique d'effets (EffectsPolicy) côté client : option « Effets
-- réduits » des Options et qualité graphique Roblox. Présentation uniquement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EffectsPolicy = require(ReplicatedStorage.Shared.Visuals.EffectsPolicy)
local ClientSettings = require(script.Parent.ClientSettings)

local GraphicsQuality = {}

-- Niveau 1 à 10 choisi par le joueur dans les paramètres Roblox, nil en automatique.
local function robloxQualityLevel(): number?
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if not ok or typeof(level) ~= "EnumItem" or level == Enum.SavedQualitySetting.Automatic then
		return nil
	end
	return level.Value
end

function GraphicsQuality.level(): string
	return EffectsPolicy.level(ClientSettings.get("lowEffects"), robloxQualityLevel())
end

function GraphicsQuality.budget()
	return EffectsPolicy.budget(GraphicsQuality.level())
end

-- Éteint les lumières dynamiques et les particules permanentes d'un modèle si le
-- budget l'exige.
function GraphicsQuality.applyToModel(model: Instance)
	local budget = GraphicsQuality.budget()
	if budget.dynamicLights and budget.modelParticles then
		return
	end
	for _, descendant in model:GetDescendants() do
		local light = descendant:IsA("Light") and not budget.dynamicLights
		local particles = descendant:IsA("ParticleEmitter") and not budget.modelParticles
		if light or particles then
			(descendant :: any).Enabled = false
		end
	end
end

return GraphicsQuality
