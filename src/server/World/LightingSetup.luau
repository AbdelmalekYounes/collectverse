-- Ambiance lumineuse du Hub : nuit dimensionnelle, halo violet, bloom mesuré.
-- Note : Lighting.Technology n'est pas modifiable par script ; régler « Future »
-- dans les propriétés de Lighting dans Studio pour le meilleur rendu.

local Lighting = game:GetService("Lighting")

local LightingSetup = {}

local function ensure(className: string, name: string)
	local existing = Lighting:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = Lighting
	return instance
end

function LightingSetup.apply()
	Lighting.ClockTime = 20.5
	Lighting.Brightness = 1.6
	Lighting.Ambient = Color3.fromRGB(38, 34, 70)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 62, 120)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.6

	local atmosphere = ensure("Atmosphere", "CollectverseAtmosphere") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromHex("#3A2E6E")
	atmosphere.Decay = Color3.fromHex("#101426")
	atmosphere.Glare = 0
	atmosphere.Haze = 1.4

	local bloom = ensure("BloomEffect", "CollectverseBloom") :: BloomEffect
	bloom.Intensity = 0.6
	bloom.Size = 26
	bloom.Threshold = 1.2

	local grading = ensure("ColorCorrectionEffect", "CollectverseGrading") :: ColorCorrectionEffect
	grading.Saturation = 0.1
	grading.Contrast = 0.06
	grading.TintColor = Color3.fromRGB(240, 238, 255)
end

return LightingSetup
