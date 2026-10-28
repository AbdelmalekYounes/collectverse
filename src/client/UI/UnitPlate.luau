-- Plaque d'information au-dessus d'un combattant 3D : nom, PV, bouclier,
-- jauge d'ultime, statuts et ordre planifié. Toute la plaque est cliquable
-- (sélection d'un allié ou choix d'une cible), à la souris comme au toucher.
-- Taille exprimée en studs : elle suit la perspective et ne se chevauche pas
-- d'un emplacement à l'autre.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Statuses = require(Shared.Catalog.Statuses)

local BattleLayout = require(script.Parent.Parent.Battle.BattleLayout)

local UnitPlate = {}

local function viewportHeight(): number
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize.Y else 800
end

-- Taille calculée par BattleLayout selon la hauteur de l'écran (voir ce module).
local function applySize(billboard: BillboardGui)
	local studsX, pixelsX, studsY, pixelsY = BattleLayout.plateSize(viewportHeight())
	billboard.Size = UDim2.new(studsX, pixelsX, studsY, pixelsY)
end

export type Info = {
	selected: boolean,
	targetable: boolean,
	plannedText: string?,
	chargeMax: number,
}

local function label(parent: Instance, name: string, y: number, height: number, props): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromScale(0, y)
	text.Size = UDim2.fromScale(1, height)
	text.TextScaled = true
	text.FontFace = Theme.Fonts.Body
	text.TextColor3 = Theme.Colors.Text
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Text = ""
	for key, value in props or {} do
		(text :: any)[key] = value
	end
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 22
	constraint.Parent = text
	text.Parent = parent
	return text
end

local function bar(parent: Instance, name: string, y: number, height: number, color: Color3): Frame
	local track = Instance.new("Frame")
	track.Name = name
	track.BackgroundColor3 = Theme.Colors.SurfaceHigh
	track.BorderSizePixel = 0
	track.Position = UDim2.fromScale(0, y)
	track.Size = UDim2.fromScale(1, height)
	track.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = track
	corner:Clone().Parent = fill
	return fill
end

local function statusText(unit): string
	local parts = {}
	for _, statusId in Statuses.Order do
		local status = unit.statuses[statusId]
		if status then
			table.insert(parts, string.format("%s %d", Statuses.Info[statusId].name, status.duration))
		end
	end
	return table.concat(parts, " · ")
end

-- Crée la plaque d'un combattant. Renvoie { billboard, update(unit, info) }.
function UnitPlate.create(model: Model, unit, parent: Instance, onClick: (uid: string) -> ())
	local sideColor = if unit.side == "Ally" then Theme.Colors.Cyan else Theme.Colors.Coral

	local billboard = Instance.new("BillboardGui")
	billboard.Name = unit.uid .. "Plate"
	billboard.Adornee = model.PrimaryPart
	-- Taille en studs (suit la perspective) + marge en pixels pour rester lisible de loin.
	applySize(billboard)
	-- Position par camp et ligne (BattleLayout.plateOffset) : au sol devant les alliés de
	-- la ligne avant, au-dessus des têtes ailleurs. Décalage en espace monde :
	-- StudsOffset suivrait l'inclinaison de la caméra et placerait la plaque ~1,4× trop haut.
	local offset = BattleLayout.plateOffset(unit.side, unit.row, model:GetExtentsSize().Y)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	billboard.AlwaysOnTop = true
	billboard.Active = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 250
	billboard.ResetOnSpawn = false
	billboard.Parent = parent

	local button = Instance.new("TextButton")
	button.Name = "Plate"
	button.AutoButtonColor = false
	button.Text = ""
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundColor3 = Theme.Colors.Background
	button.BackgroundTransparency = 0.2
	button.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.12, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 1.5
	stroke.Parent = button
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.PaddingTop = UDim.new(0.05, 0)
	padding.PaddingBottom = UDim.new(0.05, 0)
	padding.Parent = button

	label(button, "Name", 0, 0.22, { Text = unit.name, FontFace = Theme.Fonts.Bold, TextColor3 = sideColor })
	local hpFill = bar(button, "Hp", 0.25, 0.11, Theme.Colors.Success)
	local hpText = label(button, "HpText", 0.38, 0.17)
	local chargeFill = bar(button, "Charge", 0.58, 0.05, Theme.Colors.Gold)
	local statusLabel = label(button, "Status", 0.65, 0.16, { TextColor3 = Theme.Colors.TextMuted })
	local plannedLabel =
		label(button, "Planned", 0.82, 0.17, { FontFace = Theme.Fonts.Bold, TextColor3 = Theme.Colors.Cyan })

	button.Activated:Connect(function()
		onClick(unit.uid)
	end)

	local function update(current, info: Info)
		billboard.Enabled = current.alive
		if not current.alive then
			return
		end
		local ratio = current.hp / current.maxHp
		hpFill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		hpFill.BackgroundColor3 = if ratio > 0.3 then Theme.Colors.Success else Theme.Colors.Coral
		hpText.Text = string.format(
			"%d / %d%s",
			current.hp,
			current.maxHp,
			if current.shield > 0 then string.format("  +%d", current.shield) else ""
		)
		local charge = math.clamp(current.charge / info.chargeMax, 0, 1)
		chargeFill.Size = UDim2.fromScale(charge, 1)

		if charge >= 1 then
			statusLabel.Text = "ULTIME PRÊT"
			statusLabel.TextColor3 = Theme.Colors.Gold
		else
			statusLabel.Text = statusText(current)
			statusLabel.TextColor3 = Theme.Colors.TextMuted
		end
		plannedLabel.Text = info.plannedText or ""

		if info.selected then
			stroke.Color, stroke.Thickness = Theme.Colors.Gold, 3
		elseif info.targetable then
			stroke.Color, stroke.Thickness = Theme.Colors.Text, 3
		else
			stroke.Color, stroke.Thickness = sideColor, 1.5
		end
		button.BackgroundTransparency = if info.targetable then 0.05 else 0.2
	end

	update(unit, { selected = false, targetable = false, plannedText = nil, chargeMax = 100 })
	-- resize : à rappeler quand la résolution ou l'orientation change.
	return {
		billboard = billboard,
		update = update,
		resize = function()
			applySize(billboard)
		end,
	}
end

return UnitPlate
