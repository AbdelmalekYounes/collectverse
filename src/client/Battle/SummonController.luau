-- Invocation : transformation d'une carte en personnage 3D.
--
-- Déroulé (durée totale GameConfig.Summon.DurationSeconds, ≈ 1,3 s) :
--   1. apparition de la carte sur son emplacement   (15 %)
--   2. la carte s'élève et s'illumine               (27 %)
--   3. anneau d'énergie dimensionnelle + particules (23 %)
--   4. la carte se replie et disparaît              (12 %)
--   5. le personnage se matérialise                 (23 %)
-- Modes : "full", "reduced" (même déroulé, accéléré) ou "instant".
-- requestSkip() termine immédiatement toutes les invocations en cours.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local GameConfig = require(Shared.Config.GameConfig)
local CardCatalog = require(Shared.Catalog.CardCatalog)
local ModelFactory = require(Shared.Visuals.ModelFactory)
local VisualAssets = require(Shared.Visuals.VisualAssets)

local Arena = require(script.Parent.Arena)
local GraphicsQuality = require(script.Parent.Parent.State.GraphicsQuality)

local SummonController = {}

local PHASES = { appear = 0.15, rise = 0.27, energy = 0.23, vanish = 0.12, materialize = 0.23 }
local CARD_SIZE = Vector3.new(2.4, 3.4, 0.12)
local RISE_HEIGHT = 1.6
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

export type Mode = "full" | "reduced" | "instant"

local skipRequested = false

function SummonController.requestSkip()
	skipRequested = true
end

function SummonController.isSkipping(): boolean
	return skipRequested
end

local function totalDuration(mode: Mode): number
	if mode == "full" then
		return GameConfig.Summon.DurationSeconds
	elseif mode == "reduced" then
		return GameConfig.Summon.ReducedDurationSeconds
	end
	return 0
end

-- Attend `seconds` ; renvoie false si un passage a été demandé entre-temps.
local function waitOrSkip(seconds: number): boolean
	local elapsed = 0
	while elapsed < seconds do
		if skipRequested then
			return false
		end
		elapsed += task.wait()
	end
	return not skipRequested
end

local function newPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

-- Carte face à la caméra, avec son illustration provisoire.
local function buildCard(unit, footCFrame: CFrame, parent: Instance)
	local fighter = CardCatalog.getFighter(unit.fighterId)
	local elementColor = Theme.Element[unit.element] or Theme.Colors.Violet
	local rarityColor = Theme.Rarity[fighter and fighter.rarity or "Common"]

	local center = footCFrame.Position + Vector3.new(0, CARD_SIZE.Y / 2 + 0.3, 0)
	local camera = Arena.cameraPosition()
	local cardCFrame = CFrame.lookAt(center, Vector3.new(camera.X, center.Y, camera.Z))

	local glow = newPart({
		Name = "SummonGlow",
		Size = CARD_SIZE + Vector3.new(0.35, 0.35, -0.06),
		CFrame = cardCFrame * CFrame.new(0, 0, 0.06),
		Color = elementColor,
		Material = Enum.Material.Neon,
		Transparency = 1,
		Parent = parent,
	})
	local card = newPart({
		Name = "SummonCard",
		Size = CARD_SIZE * Vector3.new(0.2, 0.2, 1),
		CFrame = cardCFrame,
		Color = Theme.Colors.Background,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = elementColor
	light.Brightness = 0
	light.Range = 10
	light.Enabled = GraphicsQuality.budget().dynamicLights
	light.Parent = card

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 60
	surface.LightInfluence = 0
	surface.Parent = card

	local canvas = Instance.new("CanvasGroup")
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundColor3 = Color3.new(1, 1, 1)
	canvas.GroupTransparency = 1
	canvas.Parent = surface
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(elementColor, Theme.Colors.Background)
	gradient.Rotation = 90
	gradient.Parent = canvas
	local stroke = Instance.new("UIStroke")
	stroke.Color = rarityColor
	stroke.Thickness = 6
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = canvas

	local initial = Instance.new("TextLabel")
	initial.BackgroundTransparency = 1
	initial.Size = UDim2.fromScale(1, 0.62)
	local ok, codepoint = pcall(utf8.codepoint, unit.name, 1)
	initial.Text = if ok and codepoint then utf8.char(codepoint) else "?"
	initial.FontFace = Theme.Fonts.Title
	initial.TextScaled = true
	initial.TextColor3 = Theme.Colors.Text
	initial.Parent = canvas
	-- Illustration V0.2 par-dessus l'initiale (qui reste en repli si l'image manque).
	local illustration = VisualAssets.cardArt(unit.fighterId)
	if illustration then
		local image = Instance.new("ImageLabel")
		image.Name = "Illustration"
		image.BackgroundTransparency = 1
		image.Image = illustration
		image.ScaleType = Enum.ScaleType.Crop
		image.Size = UDim2.fromScale(1, 0.68)
		image.ZIndex = 2
		image.Parent = canvas
	end
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromScale(0.05, 0.72)
	name.Size = UDim2.fromScale(0.9, 0.16)
	name.Text = fighter and fighter.name or unit.name
	name.FontFace = Theme.Fonts.Bold
	name.TextScaled = true
	name.TextColor3 = Theme.Colors.Text
	name.Parent = canvas

	return card, glow, light, canvas, cardCFrame
end

local function energyBurst(footCFrame: CFrame, color: Color3, parent: Instance, duration: number, tweens)
	local ring = newPart({
		Name = "SummonRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 2, 2),
		CFrame = CFrame.new(footCFrame.Position + Vector3.new(0, 0.12, 0)) * UPRIGHT,
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.1,
		Parent = parent,
	})
	local attachment = Instance.new("Attachment")
	attachment.Parent = ring
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 3
	emitter.Size = NumberSequence.new(0.45, 0)
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Parent = attachment
	emitter:Emit(GraphicsQuality.budget().summonParticles)

	if duration > 0 then
		local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(ring, info, { Size = Vector3.new(0.12, 9, 9), Transparency = 1 })
		tween:Play()
		table.insert(tweens, tween)
	end
	-- Laisse les particules finir avant de nettoyer.
	task.delay(1, function()
		ring:Destroy()
	end)
	return ring
end

-- Masque le modèle et renvoie de quoi le révéler.
local function hideModel(model: Model)
	local parts = {}
	local lights = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= model.PrimaryPart then
			parts[descendant] = descendant.Transparency
			descendant.Transparency = 1
		elseif descendant:IsA("Light") then
			lights[descendant] = descendant.Brightness
			descendant.Brightness = 0
		end
	end
	return parts, lights
end

-- Contour des alliés (sans teinte) : liseré chaud, fin et peu opaque, qui détache
-- la silhouette du sol, surtout de dos, sur mobile et en effets réduits (validé
-- dans Studio, V0.2.5). Pas de remplissage, pas de contour blanc épais.
SummonController.AllyOutline = table.freeze({
	color = Color3.fromHex("#FFE3B8"),
	transparency = 0.6,
})

local function addHighlight(model: Model, tint: Color3?)
	-- Un seul Highlight par modèle : BattleFx l'utilise aussi pour les impacts.
	local highlight = Instance.new("Highlight")
	highlight.Name = "FxHighlight"
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = tint or Color3.new(1, 1, 1)
	highlight.OutlineColor = tint or SummonController.AllyOutline.color
	highlight.FillTransparency = if tint then 0.85 else 1
	highlight.OutlineTransparency = if tint then 0.35 else SummonController.AllyOutline.transparency
	highlight:SetAttribute("BaseFillTransparency", highlight.FillTransparency)
	highlight:SetAttribute("BaseOutlineTransparency", highlight.OutlineTransparency)
	highlight:SetAttribute("BaseColor", highlight.FillColor)
	highlight:SetAttribute("BaseOutlineColor", highlight.OutlineColor)
	highlight.Parent = model
end

-- assetsFolder : dossier de modèles injecté (tests), sinon celui du jeu.
export type Options = { mode: Mode, tint: Color3?, assetsFolder: Instance? }

-- Invoque un combattant à `footCFrame` et renvoie son modèle (attend la fin de l'animation).
function SummonController.summon(unit, footCFrame: CFrame, parent: Instance, options: Options): Model
	local model = ModelFactory.build(
		unit.fighterId,
		{ assetsFolder = options.assetsFolder, detail = GraphicsQuality.modelDetail() }
	)
	GraphicsQuality.applyToModel(model)
	model.Name = unit.uid
	model:SetAttribute("Uid", unit.uid)
	addHighlight(model, options.tint)
	local root = model.PrimaryPart :: BasePart

	local total = totalDuration(options.mode)
	if total <= 0 or skipRequested then
		model:PivotTo(footCFrame)
		model.Parent = parent
		return model
	end

	local tweens = {}
	local function play(instance: Instance, seconds: number, goal, style: Enum.EasingStyle?)
		local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(instance, info, goal)
		tween:Play()
		table.insert(tweens, tween)
	end

	local elementColor = Theme.Element[unit.element] or Theme.Colors.Violet
	local card, glow, light, canvas, cardCFrame = buildCard(unit, footCFrame, parent)
	local parts, lights = hideModel(model)
	local finished = false

	local function finish()
		if finished then
			return
		end
		finished = true
		for _, tween in tweens do
			tween:Cancel()
		end
		card:Destroy()
		glow:Destroy()
		root.CFrame = footCFrame
		for part, transparency in parts do
			part.Transparency = transparency
		end
		for instance, brightness in lights do
			instance.Brightness = brightness
		end
	end

	local function phase(name: string): number
		return PHASES[name] * total
	end

	-- 1. Apparition
	play(card, phase("appear"), { Size = CARD_SIZE }, Enum.EasingStyle.Back)
	play(canvas, phase("appear"), { GroupTransparency = 0 })
	if not waitOrSkip(phase("appear")) then
		finish()
		model:PivotTo(footCFrame)
		model.Parent = parent
		return model
	end

	-- 2. Élévation et illumination
	local raised = cardCFrame + Vector3.new(0, RISE_HEIGHT, 0)
	play(card, phase("rise"), { CFrame = raised }, Enum.EasingStyle.Sine)
	play(glow, phase("rise"), { CFrame = raised * CFrame.new(0, 0, 0.06), Transparency = 0.25 }, Enum.EasingStyle.Sine)
	play(light, phase("rise"), { Brightness = 3 })

	-- Le modèle attend, invisible, sous son emplacement.
	model:PivotTo(footCFrame * CFrame.new(0, -0.8, 0))
	model.Parent = parent

	if waitOrSkip(phase("rise")) then
		-- 3. Énergie dimensionnelle
		energyBurst(footCFrame, elementColor, parent, phase("energy"), tweens)
		if waitOrSkip(phase("energy")) then
			-- 4. La carte se replie et disparaît
			local thin = Vector3.new(0.05, CARD_SIZE.Y * 1.1, CARD_SIZE.Z)
			play(card, phase("vanish"), { Size = thin, Transparency = 1 })
			play(glow, phase("vanish"), { Size = thin, Transparency = 1 })
			play(canvas, phase("vanish"), { GroupTransparency = 1 })
			if waitOrSkip(phase("vanish")) then
				-- 5. Matérialisation
				play(root, phase("materialize"), { CFrame = footCFrame }, Enum.EasingStyle.Back)
				for part, transparency in parts do
					play(part, phase("materialize"), { Transparency = transparency })
				end
				for instance, brightness in lights do
					play(instance, phase("materialize"), { Brightness = brightness })
				end
				waitOrSkip(phase("materialize"))
			end
		end
	end
	finish()
	return model
end

-- Invoque une liste { unit, cframe } en décalé. Renvoie { [uid] = Model } une fois tout terminé.
function SummonController.summonAll(entries, parent: Instance, mode: Mode, tintFor: (unit: any) -> Color3?)
	skipRequested = false
	local models = {}
	local pending = #entries
	local stagger = if mode == "full"
		then GameConfig.Summon.StaggerSeconds
		elseif mode == "reduced" then GameConfig.Summon.StaggerSeconds / 3
		else 0
	for index, entry in entries do
		task.spawn(function()
			if index > 1 and stagger > 0 then
				waitOrSkip((index - 1) * stagger)
			end
			models[entry.unit.uid] =
				SummonController.summon(entry.unit, entry.cframe, parent, { mode = mode, tint = tintFor(entry.unit) })
			pending -= 1
		end)
	end
	while pending > 0 do
		task.wait()
	end
	skipRequested = false
	return models
end

return SummonController
