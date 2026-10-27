-- Arène de combat, construite localement (chaque joueur voit son propre combat).
-- Elle est placée en altitude, loin du Hub : le personnage du joueur reste au Hub,
-- seule la caméra se déplace.
--
-- Disposition : les alliés regardent vers -Z, les Échos vers +Z. La caméra est
-- placée derrière les alliés : leur ligne arrière est donc la plus proche de l'écran.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local TeamRules = require(Shared.Battle.TeamRules)

local GraphicsQuality = require(script.Parent.Parent.State.GraphicsQuality)

local Arena = {}

local ORIGIN = Vector3.new(0, 400, -1200)
local FLOOR_RADIUS = 34
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- un Cylinder est orienté selon X

-- Positions des emplacements dans chaque ligne (x), et profondeur des lignes (z).
-- Valeurs choisies par projection (caméra ci-dessous, champ de vision 42°) pour
-- que, de 16:9 à 2,4:1, tout tienne entre 14 % et 75 % de la hauteur d'écran
-- (sous la barre du haut, au-dessus de la barre d'ordres) sans plaques superposées.
-- La ligne arrière est décalée entre les combattants de la ligne avant.
local ROW_X = {
	Front = { -10, 0, 10 },
	Back = { -5, 5 },
}
local ROW_Z = { Front = 4.5, Back = 10 }

local folder: Folder? = nil

local function part(parent: Instance, name: string, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function disk(parent: Instance, name: string, center: Vector3, radius: number, thickness: number, props)
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(thickness, radius * 2, radius * 2)
	props.CFrame = CFrame.new(center.X, center.Y - thickness / 2, center.Z) * UPRIGHT
	return part(parent, name, props)
end

-- Position et orientation d'un emplacement (au niveau du sol).
function Arena.slotCFrame(side: string, slot: number): CFrame
	local row = TeamRules.rowOfSlot(slot)
	local indexInRow = if row == "Front" then slot else slot - 3
	local x = ROW_X[row][indexInRow] or 0
	local z = ROW_Z[row] * (if side == "Ally" then 1 else -1)
	local position = ORIGIN + Vector3.new(x, 0, z)
	local facing = if side == "Ally" then Vector3.new(0, 0, -1) else Vector3.new(0, 0, 1)
	return CFrame.lookAt(position, position + facing)
end

function Arena.cameraCFrame(): CFrame
	return CFrame.lookAt(ORIGIN + Vector3.new(0, 32, 34), ORIGIN + Vector3.new(0, 0, -1))
end

function Arena.cameraPosition(): Vector3
	return Arena.cameraCFrame().Position
end

function Arena.build(): Folder
	if folder and folder.Parent then
		return folder
	end
	local root = Instance.new("Folder")
	root.Name = "CollectverseArena"

	disk(root, "Floor", ORIGIN, FLOOR_RADIUS, 3, {
		Color = Color3.fromHex("#1B2140"),
		Material = Enum.Material.Slate,
	})
	disk(root, "Rim", ORIGIN + Vector3.new(0, -0.6, 0), FLOOR_RADIUS + 0.6, 1, {
		Color = Theme.Colors.Violet,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	-- Ligne médiane lumineuse
	part(root, "CenterLine", {
		Size = Vector3.new(FLOOR_RADIUS * 1.6, 0.06, 0.3),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 0.03, 0)),
		Color = Theme.Colors.Cyan,
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		CanCollide = false,
	})

	-- Repères d'emplacement aux couleurs de chaque camp
	for _, side in { "Ally", "Enemy" } do
		local color = if side == "Ally" then Theme.Colors.Cyan else Theme.Colors.Coral
		for slot = 1, 5 do
			local position = Arena.slotCFrame(side, slot).Position
			disk(root, side .. "Pad" .. slot, position + Vector3.new(0, 0.08, 0), 2, 0.1, {
				Color = color,
				Material = Enum.Material.Neon,
				Transparency = 0.55,
				CanCollide = false,
			})
		end
	end

	-- Piliers de la faille en arrière-plan
	for index = -2, 2 do
		local position = ORIGIN + Vector3.new(index * 10, 6, -FLOOR_RADIUS + 4)
		part(root, "BackPillar", {
			Size = Vector3.new(1.4, 12, 1.4),
			CFrame = CFrame.new(position),
			Color = Theme.Colors.Surface,
			Material = Enum.Material.Metal,
		})
		part(root, "BackPillarCap", {
			Size = Vector3.new(1.6, 0.6, 1.6),
			CFrame = CFrame.new(position + Vector3.new(0, 6.3, 0)),
			Color = Theme.Colors.Coral,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end

	local glow = part(root, "Glow", {
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 14, 0)),
		Transparency = 1,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = Theme.Colors.Violet
	light.Brightness = 1.5
	light.Range = 45
	light.Enabled = GraphicsQuality.budget().dynamicLights
	light.Parent = glow

	root.Parent = Workspace
	folder = root
	return root
end

function Arena.destroy()
	if folder then
		folder:Destroy()
		folder = nil
	end
end

return Arena
