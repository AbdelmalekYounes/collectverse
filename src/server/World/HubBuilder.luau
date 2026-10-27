-- Construit le Hub 3D provisoire à partir de primitives.
--
-- Trois zones autour d'une faille centrale : Boosters, Collection, Combat PvE.
-- Chaque zone porte un ProximityPrompt avec l'attribut "CollectverseScreen" ;
-- le client (ZoneController) ouvre l'écran correspondant. Le serveur ne fait
-- que construire la scène : aucune donnée de joueur ne transite ici.
--
-- Les pièces animées côté client portent les attributs AmbientSpin (degrés/s)
-- et AmbientBob (amplitude en studs), lus par HubAmbience.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local CardCatalog = require(Shared.Catalog.CardCatalog)
local Elements = require(Shared.Catalog.Elements)
local ModelFactory = require(Shared.Visuals.ModelFactory)
local Text = require(Shared.Util.Text)

local HubBuilder = {}

local HUB_NAME = "CollectverseHub"
local PLATFORM_RADIUS = 60
local PLATFORM_TOP = 1
local ZONE_RADIUS = 36
local HUB_CENTER = Vector3.new(0, PLATFORM_TOP, 0)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- un Cylinder est orienté selon X

local ZONES = {
	{
		id = "Collection",
		screen = "Collection",
		label = "Collection",
		subtitle = "Consulter vos cartes",
		color = Theme.Colors.Cyan,
		angle = 160,
		labelHeight = 11, -- au-dessus des noms des statues
	},
	{
		id = "Booster",
		screen = "Booster",
		label = "Boosters",
		subtitle = "Ouvrir des boosters gratuits",
		color = Theme.Colors.Gold,
		angle = 90,
		labelHeight = 10.5, -- au-dessus du paquet flottant
	},
	{
		id = "Battle",
		screen = "Battle",
		label = "Combat PvE",
		subtitle = "Affronter les Échos de la faille",
		color = Theme.Colors.Coral,
		angle = 20,
		labelHeight = 9.5, -- au-dessus de l'arche
	},
}

local function part(parent: Instance, name: string, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- Disque horizontal dont le dessus est à `top`.
local function disk(
	parent: Instance,
	name: string,
	center: Vector3,
	radius: number,
	thickness: number,
	top: number,
	props
)
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(thickness, radius * 2, radius * 2)
	props.CFrame = CFrame.new(center.X, top - thickness / 2, center.Z) * UPRIGHT
	return part(parent, name, props)
end

-- Panneau flottant. Dimensions en studs ; le décalage est vertical dans le monde.
-- StudsOffset serait relatif à la caméra et StudsOffsetWorldSpace est exprimé
-- dans le repère du support (un cylindre est couché) : on convertit donc.
local ZONE_LABEL = { width = 14, height = 3.6, maxDistance = 160 }
local STATUE_LABEL = { width = 4.2, height = 1.5, maxDistance = 60 }

local function label(parent: BasePart, title: string, subtitle: string, color: Color3, offsetY: number, style)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromScale(style.width, style.height)
	billboard.StudsOffsetWorldSpace = parent.CFrame:VectorToObjectSpace(Vector3.new(0, offsetY, 0))
	billboard.LightInfluence = 0
	billboard.MaxDistance = style.maxDistance
	billboard.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.fromScale(1, 0.62)
	titleLabel.Text = Text.upper(title)
	titleLabel.FontFace = Theme.Fonts.Title
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = color
	titleLabel.TextStrokeTransparency = 0.6
	titleLabel.TextStrokeColor3 = Theme.Colors.Background
	titleLabel.Parent = billboard

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.fromScale(0, 0.64)
	subtitleLabel.Size = UDim2.fromScale(1, 0.32)
	subtitleLabel.Text = subtitle
	subtitleLabel.FontFace = Theme.Fonts.Body
	subtitleLabel.TextScaled = true
	subtitleLabel.TextColor3 = Theme.Colors.Text
	subtitleLabel.TextStrokeTransparency = 0.7
	subtitleLabel.Parent = billboard
end

local function prompt(parent: BasePart, zone)
	local proximityPrompt = Instance.new("ProximityPrompt")
	proximityPrompt.Name = "ZonePrompt"
	proximityPrompt.ActionText = "Ouvrir"
	proximityPrompt.ObjectText = zone.label
	proximityPrompt.HoldDuration = 0
	proximityPrompt.MaxActivationDistance = 14
	proximityPrompt.RequiresLineOfSight = false
	proximityPrompt.KeyboardKeyCode = Enum.KeyCode.E
	proximityPrompt:SetAttribute("CollectverseScreen", zone.screen)
	proximityPrompt.Parent = parent
end

local function buildPlatform(hub: Folder)
	disk(hub, "Platform", HUB_CENTER, PLATFORM_RADIUS, 4, PLATFORM_TOP, {
		Color = Color3.fromHex("#1B2140"),
		Material = Enum.Material.Slate,
	})
	-- Liseré lumineux visible sur la tranche de la plateforme
	disk(hub, "PlatformRim", HUB_CENTER, PLATFORM_RADIUS + 0.6, 1.2, PLATFORM_TOP - 0.4, {
		Color = Theme.Colors.Cyan,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})

	-- Piliers décoratifs en périphérie
	local pillars = 10
	for index = 1, pillars do
		local angle = (index / pillars) * math.pi * 2
		local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (PLATFORM_RADIUS - 4)
		part(hub, "EdgePillar", {
			Size = Vector3.new(1.4, 9, 1.4),
			CFrame = CFrame.new(position.X, PLATFORM_TOP + 4.5, position.Z),
			Color = Theme.Colors.Surface,
			Material = Enum.Material.Metal,
		})
		part(hub, "EdgePillarCap", {
			Size = Vector3.new(1.6, 0.5, 1.6),
			CFrame = CFrame.new(position.X, PLATFORM_TOP + 9.25, position.Z),
			Color = Theme.Colors.Violet,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
end

local function buildRift(hub: Folder)
	local rift = Instance.new("Folder")
	rift.Name = "Rift"
	rift.Parent = hub

	disk(rift, "RiftBase", HUB_CENTER, 6, 0.6, PLATFORM_TOP + 0.6, {
		Color = Theme.Colors.SurfaceRaised,
		Material = Enum.Material.Metal,
	})
	disk(rift, "RiftEmblem", HUB_CENTER, 6.6, 0.2, PLATFORM_TOP + 0.05, {
		Color = Theme.Colors.Violet,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})

	local core = part(rift, "RiftCore", {
		Size = Vector3.new(3, 7, 3),
		CFrame = CFrame.new(0, PLATFORM_TOP + 9, 0) * CFrame.Angles(math.rad(12), math.rad(45), 0),
		Color = Theme.Colors.Violet,
		Material = Enum.Material.Neon,
		Transparency = 0.1,
		CanCollide = false,
	})
	core:SetAttribute("AmbientSpin", 25)
	core:SetAttribute("AmbientBob", 0.6)

	local light = Instance.new("PointLight")
	light.Color = Theme.Colors.Violet
	light.Brightness = 2
	light.Range = 30
	light.Parent = core

	for index = 1, 3 do
		local angle = (index / 3) * math.pi * 2
		local shard = part(rift, "RiftShard", {
			Size = Vector3.new(0.9, 2.4, 0.9),
			CFrame = CFrame.new(math.cos(angle) * 4.5, PLATFORM_TOP + 8, math.sin(angle) * 4.5)
				* CFrame.Angles(0, angle, math.rad(20)),
			Color = Theme.Colors.Cyan,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		shard:SetAttribute("AmbientSpin", -60)
		shard:SetAttribute("AmbientBob", 0.4)
	end
end

-- Repère local d'une zone : -Z regarde vers le centre du Hub, +Z s'en éloigne.
local function zoneFrame(zone): CFrame
	local radians = math.rad(zone.angle)
	local position = Vector3.new(math.cos(radians) * ZONE_RADIUS, PLATFORM_TOP, -math.sin(radians) * ZONE_RADIUS)
	return CFrame.lookAt(position, HUB_CENTER)
end

local function buildPad(folder: Folder, frame: CFrame, color: Color3)
	disk(folder, "PadRing", frame.Position, 9.4, 0.3, PLATFORM_TOP + 0.1, {
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	disk(folder, "Pad", frame.Position, 9, 0.4, PLATFORM_TOP + 0.2, {
		Color = Theme.Colors.SurfaceRaised,
		Material = Enum.Material.Slate,
	})
end

local function buildBoosterZone(folder: Folder, frame: CFrame, zone)
	local pedestal = part(folder, "BoosterPedestal", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 4.4, 4.4),
		CFrame = (frame * CFrame.new(0, 1.2, 2)) * UPRIGHT,
		Color = Theme.Colors.Surface,
		Material = Enum.Material.Metal,
	})

	local packCFrame = frame * CFrame.new(0, 5.6, 2) * CFrame.Angles(0, math.rad(180), 0)
	local pack = part(folder, "BoosterPack", {
		Size = Vector3.new(2.6, 3.6, 0.35),
		CFrame = packCFrame,
		Color = Theme.Colors.Violet,
		CanCollide = false,
	})
	pack:SetAttribute("AmbientSpin", 40)
	pack:SetAttribute("AmbientBob", 0.4)

	-- Cadre doré soudé au paquet : il suit l'animation du paquet côté client.
	local frameGlow = part(folder, "BoosterPackFrame", {
		Size = Vector3.new(2.9, 3.9, 0.25),
		CFrame = packCFrame,
		Color = zone.color,
		Material = Enum.Material.Neon,
		Anchored = false,
		CanCollide = false,
		Massless = true,
	})
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = pack
	weld.Part1 = frameGlow
	weld.Parent = frameGlow

	return pedestal
end

local function buildCollectionZone(folder: Folder, frame: CFrame, _zone)
	local statues = Instance.new("Folder")
	statues.Name = "Statues"
	statues.Parent = folder

	local fighters = CardCatalog.getFighters()
	local count = #fighters
	for index, fighter in fighters do
		local lateral = (index - (count + 1) / 2) * 4.4
		local back = 7 - math.abs(lateral) * 0.18
		local base = frame * CFrame.new(lateral, 0, back)

		part(statues, "StatuePedestal", {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.4, 3.2, 3.2),
			CFrame = (base * CFrame.new(0, 0.7, 0)) * UPRIGHT,
			Color = Theme.Colors.Surface,
			Material = Enum.Material.Metal,
		})

		local model = ModelFactory.build(fighter.id)
		local feet = base.Position + Vector3.new(0, 1.4, 0)
		model:PivotTo(CFrame.lookAt(feet, Vector3.new(HUB_CENTER.X, feet.Y, HUB_CENTER.Z)))
		model.Parent = statues

		local elementName = Elements.Info[fighter.element].name
		label(model.PrimaryPart :: BasePart, fighter.name, elementName, Theme.Element[fighter.element], 8, STATUE_LABEL)
	end

	-- Console devant les statues : point d'interaction de la zone
	return part(folder, "CollectionConsole", {
		Size = Vector3.new(3, 2.6, 1.2),
		CFrame = frame * CFrame.new(0, 1.3 + 0.2, 0),
		Color = Theme.Colors.SurfaceRaised,
		Material = Enum.Material.Metal,
	})
end

local function buildBattleZone(folder: Folder, frame: CFrame, zone)
	for _, side in { -1, 1 } do
		part(folder, "ArchPillar", {
			Size = Vector3.new(1.6, 12, 1.6),
			CFrame = frame * CFrame.new(side * 5, 6, 4),
			Color = Theme.Colors.Surface,
			Material = Enum.Material.Metal,
		})
	end
	part(folder, "ArchBeam", {
		Size = Vector3.new(11.6, 1.6, 1.6),
		CFrame = frame * CFrame.new(0, 12.8, 4),
		Color = Theme.Colors.Surface,
		Material = Enum.Material.Metal,
	})
	local portal = part(folder, "Portal", {
		Size = Vector3.new(8.4, 11, 0.3),
		CFrame = frame * CFrame.new(0, 6.5, 4),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = zone.color
	light.Brightness = 1.5
	light.Range = 18
	light.Parent = portal
	return portal
end

local ZONE_BUILDERS = {
	Booster = buildBoosterZone,
	Collection = buildCollectionZone,
	Battle = buildBattleZone,
}

local function buildSpawn(hub: Folder)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.CFrame = CFrame.new(0, PLATFORM_TOP + 0.1, 24)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0 -- pas de champ de force
	spawn.Parent = hub

	-- Les autres SpawnLocation de la place sont désactivées pendant la session
	-- (aucune modification enregistrée dans le fichier .rbxl).
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") and descendant ~= spawn and descendant.Enabled then
			descendant.Enabled = false
			warn("[Collectverse] SpawnLocation désactivée pour la session : " .. descendant:GetFullName())
		end
	end
end

function HubBuilder.build(): Folder
	-- Reconstruction idempotente : seul notre propre dossier est remplacé.
	local previous = Workspace:FindFirstChild(HUB_NAME)
	if previous then
		previous:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HUB_NAME

	buildPlatform(hub)
	buildRift(hub)

	for _, zone in ZONES do
		local folder = Instance.new("Folder")
		folder.Name = zone.id .. "Zone"
		folder.Parent = hub

		local frame = zoneFrame(zone)
		buildPad(folder, frame, zone.color)
		local anchor = ZONE_BUILDERS[zone.id](folder, frame, zone)
		prompt(anchor, zone)
		label(anchor, zone.label, zone.subtitle, zone.color, zone.labelHeight, ZONE_LABEL)
	end

	buildSpawn(hub)
	hub.Parent = Workspace
	return hub
end

return HubBuilder
