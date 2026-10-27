-- Fabrique les modèles 3D des combattants.
--
-- Remplacement d'assets : si un Model portant le nom donné par VisualAssets.modelName
-- (par défaut l'id du combattant, ex. Assets/Fighters/F001) existe dans
-- ReplicatedStorage.Assets.Fighters et respecte le contrat (validateAsset, voir
-- VisualAssets), il est cloné. Sinon, un modèle provisoire est construit à partir
-- de primitives : le jeu reste jouable si un asset manque ou est mal configuré.
--
-- Convention : le pivot du modèle (PrimaryPart "Root", invisible et ancrée) est
-- au niveau des pieds, et l'avant du personnage regarde vers -Z (LookVector).
-- Toutes les autres pièces sont soudées à Root : déplacer Root suffit à animer
-- le modèle entier (utilisé par les invocations du jalon 3).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FighterVisuals = require(script.Parent.FighterVisuals)
local VisualAssets = require(script.Parent.VisualAssets)

local ModelFactory = {}

type AddPart = (className: string, name: string, props: { [string]: any }, offset: CFrame) -> BasePart
type Ctx = {
	add: AddPart,
	size: (x: number, y: number, z: number) -> Vector3,
	at: (x: number, y: number, z: number) -> CFrame,
	spec: any,
	armX: number,
}

local NEON = Enum.Material.Neon
local BALL = Enum.PartType.Ball
local CYLINDER = Enum.PartType.Cylinder
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- un Cylinder est orienté selon X

-- Silhouettes par archétype : uniquement de la présentation.
local ARCHETYPES: { [string]: (ctx: Ctx) -> () } = {}

function ARCHETYPES.Warrior(ctx)
	local spec, add, size, at = ctx.spec, ctx.add, ctx.size, ctx.at
	add("WedgePart", "Crest", { Size = size(0.3, 0.8, 1.2), Color = spec.glow, Material = NEON }, at(0, 6.3, 0.1))
	for _, side in { -1, 1 } do
		add(
			"Part",
			"Pauldron",
			{ Shape = BALL, Size = size(1.1, 1.1, 1.1), Color = spec.trim },
			at(side * ctx.armX, 4.4, 0)
		)
	end
	add("Part", "SwordHilt", { Size = size(0.25, 0.9, 0.25), Color = spec.trim }, at(ctx.armX, 2.1, -0.6))
	add("Part", "SwordGuard", { Size = size(0.9, 0.15, 0.3), Color = spec.glow }, at(ctx.armX, 2.6, -0.6))
	add(
		"Part",
		"SwordBlade",
		{ Size = size(0.15, 3, 0.45), Color = spec.glow, Material = NEON },
		at(ctx.armX, 4.15, -0.6)
	)
end

function ARCHETYPES.Tank(ctx)
	local spec, add, size, at = ctx.spec, ctx.add, ctx.size, ctx.at
	for _, side in { -1, 1 } do
		add(
			"Part",
			"Boulder",
			{ Shape = BALL, Size = size(1.4, 1.4, 1.4), Color = spec.trim, Material = Enum.Material.Slate },
			at(side * ctx.armX, 4.6, 0)
		)
	end
	add(
		"Part",
		"Shield",
		{ Size = size(2.6, 3.4, 0.45), Color = spec.trim, Material = Enum.Material.Slate },
		at(-ctx.armX, 3.2, -1)
	)
	add(
		"Part",
		"ShieldGem",
		{ Size = size(0.8, 0.8, 0.12), Color = spec.glow, Material = NEON },
		at(-ctx.armX, 3.4, -1.28) * CFrame.Angles(0, 0, math.rad(45))
	)
end

function ARCHETYPES.Healer(ctx)
	local spec, add, size, at = ctx.spec, ctx.add, ctx.size, ctx.at
	add(
		"Part",
		"Hair",
		{ Shape = BALL, Size = size(1.75, 1.75, 1.75), Color = spec.hair or spec.trim },
		at(0, 5.6, 0.25)
	)
	add("Part", "Robe", { Size = size(2.3, 1.4, 1.5), Color = spec.body }, at(0, 1.8, 0))
	add(
		"Part",
		"Staff",
		{ Shape = CYLINDER, Size = size(5.6, 0.25, 0.25), Color = spec.trim },
		at(ctx.armX + 0.3, 3, -0.5) * UPRIGHT
	)
	add(
		"Part",
		"StaffOrb",
		{ Shape = BALL, Size = size(1, 1, 1), Color = spec.glow, Material = NEON, Transparency = 0.15 },
		at(ctx.armX + 0.3, 6, -0.5)
	)
end

function ARCHETYPES.Assassin(ctx)
	local spec, add, size, at = ctx.spec, ctx.add, ctx.size, ctx.at
	add("Part", "Hood", { Shape = BALL, Size = size(1.8, 1.8, 1.8), Color = spec.trim }, at(0, 5.55, 0.2))
	add("Part", "Scarf", { Size = size(1.5, 0.4, 1.4), Color = spec.glow, Material = NEON }, at(0, 4.65, 0))
	for _, side in { -1, 1 } do
		add("Part", "DaggerHilt", { Size = size(0.2, 0.5, 0.2), Color = spec.trim }, at(side * ctx.armX, 2, -0.3))
		add(
			"Part",
			"DaggerBlade",
			{ Size = size(0.12, 1.4, 0.35), Color = spec.glow, Material = NEON },
			at(side * ctx.armX, 1.1, -0.3)
		)
	end
end

function ARCHETYPES.Mage(ctx)
	local spec, add, size, at = ctx.spec, ctx.add, ctx.size, ctx.at
	for index, x in { -0.45, 0, 0.45 } do
		local height = if index == 2 then 6.4 else 6.25
		add(
			"WedgePart",
			"CrownSpike",
			{ Size = size(0.25, 0.7, 0.5), Color = spec.glow, Material = NEON },
			at(x, height, 0)
		)
	end
	add("Part", "Cape", { Size = size(2, 3.2, 0.15), Color = spec.trim }, at(0, 3, 0.75))
	for _, side in { -1, 1 } do
		add(
			"Part",
			"FloatingOrb",
			{ Shape = BALL, Size = size(0.8, 0.8, 0.8), Color = spec.glow, Material = NEON },
			at(side * (ctx.armX + 1.1), 4.2, -0.4)
		)
	end
end

function ARCHETYPES.Support(ctx)
	local spec, add, size, at = ctx.spec, ctx.add, ctx.size, ctx.at
	-- Halo : anneau de petits segments lumineux au-dessus de la tête
	local segments = 10
	for index = 1, segments do
		local angle = (index / segments) * math.pi * 2
		add(
			"Part",
			"HaloSegment",
			{ Size = size(0.18, 0.12, 0.7), Color = spec.glow, Material = NEON },
			at(math.cos(angle) * 1.1, 6.6, math.sin(angle) * 1.1) * CFrame.Angles(0, -angle, 0)
		)
	end
	for _, side in { -1, 1 } do
		add(
			"Part",
			"Wing",
			{ Size = size(0.15, 2.6, 1.6), Color = spec.glow, Material = NEON, Transparency = 0.3 },
			at(side * 1, 4.2, 0.9) * CFrame.Angles(0, math.rad(side * 30), 0)
		)
	end
end

-- Contrat d'un modèle final (voir VisualAssets). Renvoie (true) ou (false, raison).
function ModelFactory.validateAsset(model: Instance): (boolean, string?)
	if not model:IsA("Model") then
		return false, "n'est pas un Model"
	end
	local root = model.PrimaryPart
	if not root then
		return false, "PrimaryPart manquante"
	end
	if not root.Anchored then
		return false, "PrimaryPart non ancrée"
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= root and descendant.Anchored then
			return false, "pièce ancrée « " .. descendant.Name .. " » : elle ne suivrait pas la PrimaryPart"
		end
	end
	return true, nil
end

local warned: { [string]: boolean } = {}

local function findAsset(fighterId: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local fighters = assets and assets:FindFirstChild("Fighters")
	local model = fighters and fighters:FindFirstChild(VisualAssets.modelName(fighterId))
	if not model then
		return nil
	end
	local valid, reason = ModelFactory.validateAsset(model)
	if not valid then
		if not warned[fighterId] then
			warned[fighterId] = true
			warn(
				string.format(
					"[ModelFactory] Asset de %s ignoré (%s) : modèle provisoire utilisé",
					fighterId,
					reason
				)
			)
		end
		return nil
	end
	return model :: Model
end

function ModelFactory.hasVisual(fighterId: string): boolean
	return FighterVisuals[fighterId] ~= nil or findAsset(fighterId) ~= nil
end

function ModelFactory.buildPlaceholder(fighterId: string): Model
	local spec = FighterVisuals[fighterId]
	if not spec then
		error("ModelFactory : aucune apparence définie pour " .. tostring(fighterId))
	end
	local builder = ARCHETYPES[spec.archetype]
	if not builder then
		error("ModelFactory : archétype inconnu " .. tostring(spec.archetype))
	end

	local scale = spec.scale or 1
	local bulk = spec.bulk or 1

	local model = Instance.new("Model")
	model.Name = fighterId
	model:SetAttribute("FighterId", fighterId)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	local function size(x: number, y: number, z: number): Vector3
		return Vector3.new(x, y, z) * scale
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * scale, y * scale, z * scale)
	end
	local function add(className: string, name: string, props: { [string]: any }, offset: CFrame): BasePart
		local part = Instance.new(className) :: BasePart
		part.Name = name
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		for key, value in props do
			(part :: any)[key] = value
		end
		-- Le CFrame est fixé avant la soudure : la WeldConstraint mémorise ce décalage.
		part.CFrame = root.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
		return part
	end

	-- Corps commun à toutes les silhouettes
	local armX = 1.1 * bulk + 0.4
	for _, side in { -1, 1 } do
		add("Part", "Leg", { Size = size(0.8, 2.2, 0.9), Color = spec.trim }, at(side * 0.55 * bulk, 1.1, 0))
		add("Part", "Arm", { Size = size(0.7, 2.2, 0.8), Color = spec.body }, at(side * armX, 3.3, 0))
	end
	local torso = add("Part", "Torso", { Size = size(2.2 * bulk, 2.4, 1.2), Color = spec.body }, at(0, 3.4, 0))
	add("Part", "Belt", { Size = size(2.25 * bulk, 0.3, 1.25), Color = spec.glow, Material = NEON }, at(0, 2.35, 0))
	add("Part", "Head", { Shape = BALL, Size = size(1.6, 1.6, 1.6), Color = spec.skin }, at(0, 5.4, 0))
	add("Part", "Visor", { Size = size(1.1, 0.28, 0.3), Color = spec.glow, Material = NEON }, at(0, 5.45, -0.68))

	builder({ add = add, size = size, at = at, spec = spec, armX = armX })

	local light = Instance.new("PointLight")
	light.Color = spec.glow
	light.Brightness = 1.2
	light.Range = 7 * scale
	light.Parent = torso

	return model
end

-- Renvoie un nouveau modèle (asset final s'il existe, sinon provisoire).
function ModelFactory.build(fighterId: string): Model
	local asset = findAsset(fighterId)
	if asset then
		local clone = asset:Clone()
		clone:SetAttribute("FighterId", fighterId)
		return clone
	end
	return ModelFactory.buildPlaceholder(fighterId)
end

return ModelFactory
