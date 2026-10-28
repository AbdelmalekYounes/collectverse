-- Effets de braise d'un combattant riggé (V0.2.4) : lumières et particules posées
-- sur les os existants. Outil de production (barre de commande de Studio, hors
-- Play), jamais appelé par le jeu : les effets sont enregistrés dans l'asset.
--
--   local Fx = require(game.ServerScriptService.Server.Dev.FighterEmberFx)
--   print(Fx.apply(workspace.F001_Kael_Premium, "F001"))
--
-- Un Bone est une Attachment : une PointLight ou un ParticleEmitter qui en est
-- l'enfant suit l'os pendant les animations, sans ajouter d'os (le rig garde ses
-- 17 os) ni de pièce. En jeu, GraphicsQuality.applyToModel éteint ces effets
-- quand le budget est réduit (EffectsPolicy : dynamicLights, modelParticles).
-- Idempotent : les effets précédents (préfixe « EmberFx_ ») sont remplacés.

local FighterEmberFx = {}

FighterEmberFx.Prefix = "EmberFx_"

local EMBER = Color3.fromHex("#FF7A3D")
local HOT = Color3.fromHex("#FFD27A")

export type Effect = {
	bone: string,
	name: string,
	light: { color: Color3, brightness: number, range: number }?,
	particles: { rate: number, lifetime: NumberRange, size: number, speed: NumberRange }?,
}

-- Effets par combattant. Kael : lame (main droite) et cœur du plastron.
FighterEmberFx.Specs = {
	F001 = {
		{
			bone = "RightHand",
			name = "Blade",
			light = { color = EMBER, brightness = 1.6, range = 7 },
			particles = {
				rate = 6,
				lifetime = NumberRange.new(0.8, 1.4),
				size = 0.16,
				speed = NumberRange.new(0.4, 1.2),
			},
		},
		{
			bone = "UpperTorso",
			name = "Core",
			light = { color = HOT, brightness = 0.7, range = 4 },
		},
	} :: { Effect },
}

export type Report = {
	lights: number,
	emitters: number,
	missingBones: { string },
	bones: number, -- os du modèle après application (inchangé)
}

local function bonesOf(model: Instance): { [string]: Bone }
	local bones = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Bone") then
			bones[descendant.Name] = descendant
		end
	end
	return bones
end

function FighterEmberFx.remove(model: Instance)
	for _, descendant in model:GetDescendants() do
		if string.sub(descendant.Name, 1, #FighterEmberFx.Prefix) == FighterEmberFx.Prefix then
			descendant:Destroy()
		end
	end
end

local function addLight(bone: Bone, name: string, spec)
	local light = Instance.new("PointLight")
	light.Name = FighterEmberFx.Prefix .. name .. "Light"
	light.Color = spec.color
	light.Brightness = spec.brightness
	light.Range = spec.range
	light.Shadows = false
	light.Parent = bone
end

local function addEmitter(bone: Bone, name: string, spec)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = FighterEmberFx.Prefix .. name .. "Embers"
	-- Texture intégrée au client Roblox (aucun asset téléversé).
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, HOT),
		ColorSequenceKeypoint.new(1, EMBER),
	})
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, spec.size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Rate = spec.rate
	emitter.Lifetime = spec.lifetime
	emitter.Speed = spec.speed
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 3, 0) -- les braises montent
	emitter.Drag = 1
	emitter.LockedToPart = false
	emitter.Parent = bone
end

function FighterEmberFx.apply(model: Instance, fighterId: string): Report
	local specs = FighterEmberFx.Specs[fighterId]
	assert(specs, "FighterEmberFx : aucun effet déclaré pour " .. tostring(fighterId))
	FighterEmberFx.remove(model)
	local bones = bonesOf(model)
	local report: Report = { lights = 0, emitters = 0, missingBones = {}, bones = 0 }
	for _, effect in specs do
		local bone = bones[effect.bone]
		if not bone then
			table.insert(report.missingBones, effect.bone)
			continue
		end
		if effect.light then
			addLight(bone, effect.name, effect.light)
			report.lights += 1
		end
		if effect.particles then
			addEmitter(bone, effect.name, effect.particles)
			report.emitters += 1
		end
	end
	for _ in bonesOf(model) do
		report.bones += 1
	end
	return report
end

return FighterEmberFx
