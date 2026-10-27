-- Carte d'un combattant pendant un combat : PV, bouclier, jauge d'ultime,
-- statuts actifs et action planifiée. Visuel provisoire du jalon 2 ;
-- le jalon 3 ajoutera l'arène 3D et les invocations.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Statuses = require(Shared.Catalog.Statuses)
local Components = require(script.Parent.Components)

local new = Components.new

local UnitCard = {}

UnitCard.Size = UDim2.fromOffset(108, 112)

export type Options = {
	selected: boolean?,
	targetable: boolean?,
	plannedText: string?,
	onClick: (() -> ())?,
}

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

function UnitCard.create(unit, chargeMax: number, options: Options): TextButton
	local sideColor = if unit.side == "Ally" then Theme.Colors.Cyan else Theme.Colors.Coral
	local strokeColor = sideColor
	local strokeThickness = 1
	if options.selected then
		strokeColor, strokeThickness = Theme.Colors.Gold, 2.5
	elseif options.targetable then
		strokeColor, strokeThickness = Theme.Colors.Text, 2.5
	end

	local card = new("TextButton", {
		Name = unit.uid,
		AutoButtonColor = false,
		Text = "",
		Size = UnitCard.Size,
		BackgroundColor3 = Theme.Colors.White,
		LayoutOrder = unit.slot,
		BackgroundTransparency = if unit.alive then 0 else 0.6,
	}, {
		Components.corner(Theme.Radius.Medium),
		Components.gradient(Theme.Colors.SurfaceHigh, Theme.Colors.Surface),
		Components.stroke(strokeColor, strokeThickness, if unit.alive then 0.1 else 0.6),
		Components.padding(6, 8),
		Components.list(Enum.FillDirection.Vertical, 3),
	})

	local header =
		new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1, Parent = card })
	Components.label({
		Text = unit.name,
		FontFace = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Caption,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -24, 1, 0),
		Parent = header,
	})
	Components.label({
		Text = if unit.row == "Front" then "AV" else "AR",
		TextSize = 10,
		TextColor3 = Theme.Colors.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 22, 1, 0),
		Parent = header,
	})

	if not unit.alive then
		Components.label({
			Text = "À terre",
			TextColor3 = Theme.Colors.TextDim,
			TextSize = Theme.TextSize.Caption,
			LayoutOrder = 2,
			Parent = card,
		})
	else
		local hpColor = if unit.hp / unit.maxHp > 0.3 then Theme.Colors.Success else Theme.Colors.Coral
		Components.bar(unit.hp / unit.maxHp, hpColor, { LayoutOrder = 2 }).Parent = card
		local shield = if unit.shield > 0 then string.format("  +%d", unit.shield) else ""
		Components.label({
			Text = string.format("%d / %d%s", unit.hp, unit.maxHp, shield),
			TextSize = 11,
			Size = UDim2.new(1, 0, 0, 13),
			LayoutOrder = 3,
			Parent = card,
		})
		local charged = unit.charge >= chargeMax
		Components.bar(unit.charge / chargeMax, Theme.Colors.Gold, {
			Size = UDim2.new(1, 0, 0, 3),
			LayoutOrder = 4,
		}).Parent =
			card
		Components.label({
			Text = if charged then "ULTIME PRÊT" else statusText(unit),
			TextColor3 = if charged then Theme.Colors.Gold else Theme.Colors.TextMuted,
			FontFace = if charged then Theme.Fonts.Bold else Theme.Fonts.Body,
			TextSize = 10,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, 0, 0, 12),
			LayoutOrder = 5,
			Parent = card,
		})
		if charged and next(unit.statuses) ~= nil then
			Components.label({
				Text = statusText(unit),
				TextColor3 = Theme.Colors.TextMuted,
				TextSize = 10,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.new(1, 0, 0, 12),
				LayoutOrder = 6,
				Parent = card,
			})
		end
	end

	if options.plannedText then
		Components.label({
			Text = options.plannedText,
			TextColor3 = Theme.Colors.Cyan,
			FontFace = Theme.Fonts.Bold,
			TextSize = 10,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, 0, 0, 12),
			LayoutOrder = 7,
			Parent = card,
		})
	end

	card.Activated:Connect(function()
		if options.onClick then
			options.onClick()
		end
	end)
	return card
end

return UnitCard
