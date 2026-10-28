-- Banc d'essai visuel de l'arène de combat : valide un modèle candidat dans les
-- conditions réelles (arène, caméra, plaques, éclairage du jeu, 10 combattants).
-- Outil de production, Studio uniquement, en mode Run (F8) : jamais appelé par le
-- jeu. Rien n'est enregistré ni publié : tout disparaît à l'arrêt de la simulation.
--
--   local Bench = require(game.ServerScriptService.Server.Dev.ArenaBench)
--   Bench.stage({ variant = "P2", look = "A", effects = "Full" })
--   Bench.camera("combat1080")        -- caméra du combat à la densité 1080p (ou "combat", "ally", "enemy", "face")
--   Bench.play("Attack")              -- action sur les deux Kael ; Bench.pose("Skill", 0.6) la fige
--   print(Bench.measure(5))           -- temps d'image et mémoire
--
-- Variantes de Kael : dossiers ServerStorage.KaelBench.<variante> contenant un
-- « F001_Kael » préparé (Bench.prepare). « V022 » = modèle de production, avec ses
-- animations publiées. Les autres jouent les animations converties depuis
-- AnimationData.F001_Kael_AF, enregistrées localement (KeyframeSequenceProvider).
--
-- Looks comparés (sur les 10 combattants, comme le ferait le jeu) :
--   A : éclairage d'avant la V0.2.5, Highlight d'origine (allié invisible, ennemi corail) ;
--   B : A + contre-jour : un SpotLight chaud par combattant, au-delà de lui par
--       rapport à la caméra, qui éclaire épaules et tête (lumière dynamique) ;
--   C : A + contour fin des alliés : état du jeu depuis la V0.2.5
--       (SummonController.AllyOutline, contour seul, 60 % transparent).
-- Effets réduits : suivent EffectsPolicy (lumière d'arène gardée depuis la V0.2.5).

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local TeamRules = require(Shared.Battle.TeamRules)
local ModelFactory = require(Shared.Visuals.ModelFactory)
local EffectsPolicy = require(Shared.Visuals.EffectsPolicy)
local VisualAssets = require(Shared.Visuals.VisualAssets)

local Client = StarterPlayer.StarterPlayerScripts.Client
local Arena = require(Client.Battle.Arena)
local BattleLayout = require(Client.Battle.BattleLayout)
local UnitPlate = require(Client.UI.UnitPlate)

local Dev = script.Parent
local KeyframeBuilder = require(Dev.KeyframeBuilder)
local FighterAssetPrep = require(Dev.FighterAssetPrep)
local FighterEmberFx = require(Dev.FighterEmberFx)

local Bench = {}

local KAEL = "F001"
local NAMES = { F001 = "Kael", F002 = "Terra", F003 = "Lyra", F004 = "Nox", F005 = "Astra", F006 = "Oris" }
-- 5 contre 5 ; Kael au centre de chaque ligne avant (emplacement 2).
local LINEUP = {
	Ally = { "F002", KAEL, "F003", "F004", "F005" },
	Enemy = { "F006", KAEL, "F002", "F003", "F004" },
}
local RIM_COLOR = Color3.fromHex("#FFC98F")
local OUTLINE_COLOR = Color3.fromHex("#FFE3B8")

type Fighter = { model: Model, side: string, slot: number, fighterId: string, tracks: { [string]: AnimationTrack } }

local state = {
	root = nil :: Folder?,
	fighters = {} :: { Fighter },
	options = nil :: any,
}
local registered: { [string]: { [string]: string } } = {}

local function benchFolder(): Folder
	local folder = ServerStorage:FindFirstChild("KaelBench")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "KaelBench"
		folder.Parent = ServerStorage
	end
	return folder :: Folder
end

-- Met un modèle importé au contrat dans ServerStorage.KaelBench.<variant>.F001_Kael
-- (jamais dans ReplicatedStorage : la production n'est pas touchée), avec les braises.
-- Hors Play, Studio garde en cache les modules déjà requis : si FighterAssetPrep a
-- été modifié depuis, une version périmée peut ignorer le dossier de destination
-- ou nommer le pivot « Root » (constaté en V0.2.5). Relancer Studio avant, puis
-- contrôler le résultat avec check-fighter-asset.
function Bench.prepare(model: Model, variant: string): string
	local destination = benchFolder():FindFirstChild(variant)
	if not destination then
		destination = Instance.new("Folder")
		destination.Name = variant
		destination.Parent = benchFolder()
	end
	local report = FighterAssetPrep.prepare(model, VisualAssets.modelName(KAEL), destination)
	local fx = FighterEmberFx.apply(destination:FindFirstChild(VisualAssets.modelName(KAEL)) :: Model, KAEL)
	return FighterAssetPrep.describe(report)
		.. string.format(" | braises : %d lumières, %d émetteurs, os %d", fx.lights, fx.emitters, fx.bones)
end

local function variantFolder(variant: string): Instance?
	if variant == "V022" then
		return nil -- modèle de production (ReplicatedStorage.Assets.Fighters)
	end
	local folder = benchFolder():FindFirstChild(variant)
	assert(folder, "ArenaBench : variante absente, lancer Bench.prepare : " .. variant)
	return folder
end

local function animationData(): { [string]: any }
	local data = {}
	for _, module in Dev.AnimationData.F001_Kael_AF:GetChildren() do
		data[module.Name] = require(module :: ModuleScript)
	end
	return data
end

-- Animations converties (KeyframeBuilder) et enregistrées localement : identifiants
-- temporaires, valables dans cette session Studio uniquement. Rien n'est publié.
local function animationIds(variant: string, template: Model): { [string]: string }
	if variant == "V022" then
		local ids = {}
		for _, kind in VisualAssets.AnimationKinds do
			ids[kind] = VisualAssets.animation(KAEL, kind) :: string
		end
		return ids
	end
	if not registered[variant] then
		local ids = {}
		for kind, data in animationData() do
			local sequence = KeyframeBuilder.build(template, data)
			ids[kind] = KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
		end
		registered[variant] = ids
	end
	return registered[variant]
end

-- Rapport KeyframeBuilder.verify des 7 animations sur une copie du modèle candidat.
function Bench.verify(variant: string): string
	local folder = variantFolder(variant) :: Instance
	local copy = (folder:FindFirstChild(VisualAssets.modelName(KAEL)) :: Model):Clone()
	local lines = {}
	for _, data in animationData() do
		table.insert(lines, KeyframeBuilder.describe(KeyframeBuilder.verify(copy, data)))
	end
	copy:Destroy()
	table.sort(lines)
	return table.concat(lines, "\n")
end

-- Highlight identique à SummonController.addHighlight (un seul par modèle).
local function addHighlight(model: Model, tint: Color3?)
	local highlight = Instance.new("Highlight")
	highlight.Name = "FxHighlight"
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = tint or Color3.new(1, 1, 1)
	highlight.OutlineColor = tint or Color3.new(1, 1, 1)
	highlight.FillTransparency = if tint then 0.85 else 1
	highlight.OutlineTransparency = if tint then 0.35 else 1
	highlight.Parent = model
	return highlight
end

local function addRimLight(model: Model)
	local root = model.PrimaryPart :: BasePart
	local camera = Arena.cameraPosition()
	local away = root.Position - camera
	away = Vector3.new(away.X, 0, away.Z).Unit
	local height = model:GetExtentsSize().Y
	local source = root.Position + away * 3 + Vector3.new(0, height + 2.5, 0)
	local target = root.Position + Vector3.new(0, height * 0.8, 0)
	local attachment = Instance.new("Attachment")
	attachment.Name = "BenchRim"
	attachment.WorldCFrame = CFrame.lookAt(source, target)
	attachment.Parent = root
	local light = Instance.new("SpotLight")
	light.Name = "BenchRimLight"
	light.Face = Enum.NormalId.Front
	light.Color = RIM_COLOR
	light.Brightness = 5 -- 2,2 : invisible en jeu ; 10 : effet de projecteur (testé dans Studio)
	light.Range = 9
	light.Angle = 70
	light.Shadows = false
	light.Parent = attachment
end

-- Budget réduit : comme GraphicsQuality.applyToModel (lumières et particules éteintes).
local function reduce(instance: Instance)
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("Light") or descendant:IsA("ParticleEmitter") then
			(descendant :: any).Enabled = false
		end
	end
end

local function fakeUnit(side: string, slot: number, fighterId: string)
	return {
		uid = side .. slot,
		side = side,
		slot = slot,
		row = TeamRules.rowOfSlot(slot),
		name = NAMES[fighterId] or fighterId,
		hp = 820 - slot * 37,
		maxHp = 1000,
		shield = 0,
		charge = 20 * slot,
		alive = true,
		statuses = {},
	}
end

function Bench.clear()
	for _, fighter in state.fighters do
		fighter.model:Destroy()
	end
	state.fighters = {}
	if state.root then
		state.root:Destroy()
		state.root = nil
	end
	Arena.destroy()
end

-- options : variant ("V022", "P1", "P2"…), look ("A", "B", "C"), effects ("Full",
-- "Reduced"), plates (true par défaut), lineup (false : Kael seuls), detail ("Low" :
-- variante allégée F001_Kael_LOD du dossier, si elle existe).
function Bench.stage(options)
	assert(RunService:IsStudio(), "ArenaBench : Studio uniquement")
	options = options or {}
	local variant = options.variant or "P2"
	local look = options.look or "A"
	local reduced = options.effects == "Reduced"
	Bench.clear()
	state.options = { variant = variant, look = look, effects = if reduced then "Reduced" else "Full" }

	local arena = Arena.build()
	if reduced then
		if not EffectsPolicy.budget("Reduced").arenaLight then
			reduce(arena)
		end
	end
	local root = Instance.new("Folder")
	root.Name = "BenchActors"
	root.Parent = Workspace
	state.root = root

	local folder = variantFolder(variant)
	local ids = nil
	for side, list in LINEUP do
		for slot, fighterId in list do
			if fighterId ~= KAEL and options.lineup == false then
				continue
			end
			local model = ModelFactory.build(
				fighterId,
				if fighterId == KAEL then { assetsFolder = folder, detail = options.detail } else nil
			)
			model.Name = side .. slot .. "_" .. fighterId
			local highlight = addHighlight(model, if side == "Enemy" then Theme.Colors.Coral else nil)
			model:PivotTo(Arena.slotCFrame(side, slot))
			model.Parent = root
			if look == "B" then
				addRimLight(model)
			elseif look == "C" and side == "Ally" then
				highlight.OutlineColor = OUTLINE_COLOR
				highlight.OutlineTransparency = 0.6
			end
			if reduced then
				reduce(model)
			end
			if options.plates ~= false then
				UnitPlate.create(model, fakeUnit(side, slot, fighterId), root, function() end)
			end
			local fighter: Fighter = { model = model, side = side, slot = slot, fighterId = fighterId, tracks = {} }
			if fighterId == KAEL then
				ids = ids or animationIds(variant, model)
				local animator = model:FindFirstChildWhichIsA("Animator", true) :: Animator
				for kind, id in ids do
					local animation = Instance.new("Animation")
					animation.AnimationId = id
					fighter.tracks[kind] = animator:LoadAnimation(animation)
				end
				local idle = fighter.tracks.Idle
				if idle then
					idle.Looped = true
					idle:Play(0)
				end
			end
			table.insert(state.fighters, fighter)
		end
	end
	return string.format(
		"%s | look %s | effets %s | %d combattants",
		variant,
		look,
		state.options.effects,
		#state.fighters
	)
end

local function kaels(): { Fighter }
	local list = {}
	for _, fighter in state.fighters do
		if fighter.fighterId == KAEL then
			table.insert(list, fighter)
		end
	end
	return list
end

-- Joue une action sur les Kael (par-dessus l'Idle, comme FighterAnimator.play).
function Bench.play(kind: string, speed: number?)
	for _, fighter in kaels() do
		local track = fighter.tracks[kind]
		if track then
			if kind == "Defeat" and fighter.tracks.Idle then
				fighter.tracks.Idle:Stop(0.1)
			end
			track:Play(0.1, 1, speed or 1)
		end
	end
end

-- Fige une action à l'instant t (secondes) pour une capture ; Bench.reset() relâche.
function Bench.pose(kind: string, t: number)
	for _, fighter in kaels() do
		for name, track in fighter.tracks do
			if name ~= "Idle" or kind == "Idle" then
				track:Stop(0)
			end
		end
		local track = fighter.tracks[kind]
		if track then
			track:Play(0, 1, 0)
			track.TimePosition = t
			track:AdjustSpeed(0)
		end
	end
end

function Bench.reset()
	for _, fighter in kaels() do
		for _, track in fighter.tracks do
			track:Stop(0)
		end
		local idle = fighter.tracks.Idle
		if idle then
			idle.Looped = true
			idle:Play(0)
		end
	end
end

local function kaelOf(side: string): Model?
	for _, fighter in kaels() do
		if fighter.side == side then
			return fighter.model
		end
	end
	return nil
end

-- Vues : "combat" (caméra du jeu, champ adapté à la fenêtre), "combat1080" (même
-- caméra, champ resserré pour la densité de pixels d'un écran 1080p en 16:9 : un
-- recadrage central de la vue de combat, à taille réelle, quelle que soit la
-- fenêtre de Studio), "ally" (Kael allié de dos, rapproché), "enemy" (Kael ennemi
-- de face), "face" (visage de l'ennemi).
function Bench.camera(view: string?)
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local size = camera.ViewportSize
	if view == nil or view == "combat" then
		camera.FieldOfView = BattleLayout.fieldOfView(if size.Y > 0 then size.X / size.Y else 0)
		camera.CFrame = Arena.cameraCFrame()
		return
	elseif view == "combat1080" then
		local half = math.rad(BattleLayout.BaseFieldOfView / 2)
		camera.FieldOfView = 2 * math.deg(math.atan(math.tan(half) * size.Y / 1080))
		camera.CFrame = Arena.cameraCFrame()
		return
	end
	camera.FieldOfView = 30
	local model = kaelOf(if view == "ally" then "Ally" else "Enemy")
	assert(model, "ArenaBench : aucun Kael sur scène")
	local base = (model.PrimaryPart :: BasePart).CFrame
	local height = model:GetExtentsSize().Y
	if view == "ally" then
		-- Derrière l'allié (il regarde vers −Z) : même direction que la caméra du jeu.
		local eye = base.Position + Vector3.new(1.5, height * 1.05, 15)
		camera.CFrame = CFrame.lookAt(eye, base.Position + Vector3.new(0, height * 0.55, 0))
	elseif view == "enemy" then
		local eye = base.Position + Vector3.new(-1.5, height * 0.85, 15)
		camera.CFrame = CFrame.lookAt(eye, base.Position + Vector3.new(0, height * 0.55, 0))
	else
		local head = base.Position + Vector3.new(0, height * 0.88, 0)
		camera.FieldOfView = 20
		camera.CFrame = CFrame.lookAt(head + Vector3.new(0, 0.3, 8), head)
	end
end

local function statNumber(name: string): number?
	local ok, value = pcall(function()
		return (Stats :: any)[name]
	end)
	return if ok and type(value) == "number" then value else nil
end

local function memory(tag: Enum.DeveloperMemoryTag): number
	local ok, value = pcall(Stats.GetMemoryUsageMbForTag, Stats, tag)
	return if ok then value else -1
end

-- Mesure pendant `seconds` : intervalle entre images (Heartbeat), temps CPU/GPU
-- de rendu quand Stats les expose, mémoire maillages, textures et animations.
function Bench.measure(seconds: number?): string
	local duration = seconds or 5
	local samples, render, gpu = {}, {}, {}
	local stop = os.clock() + duration
	while os.clock() < stop do
		local dt = RunService.Heartbeat:Wait()
		table.insert(samples, dt * 1000)
		local cpu = statNumber("RenderCPUFrameTime")
		local gpuTime = statNumber("RenderGPUFrameTime")
		if cpu then
			table.insert(render, cpu)
		end
		if gpuTime then
			table.insert(gpu, gpuTime)
		end
	end
	local function summary(list: { number }): string
		if #list == 0 then
			return "n/d"
		end
		table.sort(list)
		local total = 0
		for _, value in list do
			total += value
		end
		return string.format("moy %.2f / p95 %.2f", total / #list, list[math.max(1, math.floor(#list * 0.95))])
	end
	local options = state.options or {}
	return string.format(
		"[Bench] %s look %s effets %s | %d images en %.0f s | image (ms) %s | rendu CPU %s | GPU %s | mém. maillages %.1f Mo, textures %.1f Mo, animation %.1f Mo | instances %d",
		tostring(options.variant),
		tostring(options.look),
		tostring(options.effects),
		#samples,
		duration,
		summary(samples),
		summary(render),
		summary(gpu),
		memory(Enum.DeveloperMemoryTag.GraphicsMeshParts),
		memory(Enum.DeveloperMemoryTag.GraphicsTexture),
		memory(Enum.DeveloperMemoryTag.Animation),
		Stats.InstanceCount
	)
end

-- Les trois versions côte à côte, face à la caméra, dans l'éclairage de l'arène.
function Bench.versions(variants: { string }?, details: { string }?)
	Bench.clear()
	local list = variants or { "V022", "P1", "P2" }
	Arena.build()
	local root = Instance.new("Folder")
	root.Name = "BenchActors"
	root.Parent = Workspace
	state.root = root
	state.options = { variant = table.concat(list, "+"), look = "A", effects = "Full" }
	local center = Arena.slotCFrame("Ally", 2).Position
	for index, variant in list do
		local model =
			ModelFactory.build(KAEL, { assetsFolder = variantFolder(variant), detail = details and details[index] })
		model.Name = "Version_" .. variant
		local position = center + Vector3.new((index - (#list + 1) / 2) * 5, 0, 0)
		model:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, 1)))
		model.Parent = root
		local fighter: Fighter = { model = model, side = "Version", slot = index, fighterId = KAEL, tracks = {} }
		local animator = model:FindFirstChildWhichIsA("Animator", true) :: Animator
		for kind, id in animationIds(variant, model) do
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			fighter.tracks[kind] = animator:LoadAnimation(animation)
		end
		table.insert(state.fighters, fighter)
	end
	Bench.reset()
	return "versions : " .. table.concat(list, ", ")
end

-- Caméra des versions : "front", "back", "three" (3/4), "faces" (visages).
function Bench.versionsCamera(view: string?)
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local center = Arena.slotCFrame("Ally", 2).Position
	camera.FieldOfView = 30
	if view == "back" then
		camera.CFrame = CFrame.lookAt(center + Vector3.new(0, 4.5, -30), center + Vector3.new(0, 3.6, 0))
	elseif view == "three" then
		camera.CFrame = CFrame.lookAt(center + Vector3.new(16, 5, 25), center + Vector3.new(0, 3.6, 0))
	elseif view == "faces" then
		camera.FieldOfView = 16
		camera.CFrame = CFrame.lookAt(center + Vector3.new(0, 6.6, 20), center + Vector3.new(0, 6.0, 0))
	else
		camera.CFrame = CFrame.lookAt(center + Vector3.new(0, 4.5, 30), center + Vector3.new(0, 3.6, 0))
	end
end

return Bench
