-- Écran Boosters : visuel du booster First Rift et table des probabilités exactes.
-- Les taux affichés sont calculés à partir de la même configuration que le tirage
-- serveur (BoosterOdds). L'ouverture elle-même arrive au jalon 4.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Boosters = require(Shared.Catalog.Boosters)
local BoosterOdds = require(Shared.Catalog.BoosterOdds)
local Rarities = require(Shared.Catalog.Rarities)
local Text = require(Shared.Util.Text)

local UI = script.Parent.Parent
local Components = require(UI.Components)

local new = Components.new

local BoosterScreen = {
	id = "Booster",
	title = "Boosters",
	accent = Theme.Colors.Gold,
}

local function packVisual(parent: Instance, booster)
	local pack = new("Frame", {
		Name = "Pack",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(190, 266),
		BackgroundColor3 = Theme.Colors.White,
		Parent = parent,
	}, {
		Components.corner(Theme.Radius.Large),
		Components.gradient(Theme.Colors.Violet, Theme.Colors.Background, 160),
		Components.stroke(Theme.Colors.Gold, 2, 0.1),
		Components.padding(16),
	})
	Components.label({
		Text = Text.upper(booster.name),
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Heading,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 70),
		Parent = pack,
	})
	Components.label({
		Text = string.format("%d cartes", booster.cardCount),
		TextColor3 = Theme.Colors.Cyan,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 104),
		Parent = pack,
	})
	Components.label({
		Text = "1 carte Rare ou mieux garantie",
		TextColor3 = Theme.Colors.Gold,
		TextSize = Theme.TextSize.Caption,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Parent = pack,
	})
end

local function oddsTable(parent: Instance, booster)
	local odds = BoosterOdds.compute(booster)
	local function find(list, rarity)
		for _, entry in list do
			if entry.rarity == rarity then
				return entry
			end
		end
		return nil
	end

	local tableFrame = new("Frame", {
		Name = "OddsTable",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = parent,
	}, { Components.list(Enum.FillDirection.Vertical, 4) })

	local columns = {
		{ label = "Rareté", width = 0.28 },
		{ label = string.format("Cartes 1 à %d", odds.standardSlots), width = 0.26 },
		{ label = string.format("Carte %d", booster.cardCount), width = 0.22 },
		{ label = "Cartes", width = 0.24 },
	}

	local function row(layoutOrder: number, values: { string }, colors: { Color3 }?, bold: boolean?)
		local frame = new("Frame", {
			BackgroundColor3 = Theme.Colors.Surface,
			BackgroundTransparency = if bold then 1 else 0.2,
			Size = UDim2.new(1, 0, 0, 28),
			LayoutOrder = layoutOrder,
			Parent = tableFrame,
		}, { Components.corner(Theme.Radius.Small), Components.padding(0, 10) })
		local x = 0
		for index, column in columns do
			Components.label({
				Text = values[index],
				FontFace = if bold then Theme.Fonts.Bold else Theme.Fonts.Body,
				TextSize = Theme.TextSize.Caption,
				TextColor3 = (colors and colors[index]) or Theme.Colors.Text,
				Position = UDim2.fromScale(x, 0),
				Size = UDim2.fromScale(column.width, 1),
				Parent = frame,
			})
			x += column.width
		end
	end

	local headers = {}
	for index, column in columns do
		headers[index] = column.label
	end
	row(0, headers, {
		Theme.Colors.TextMuted,
		Theme.Colors.TextMuted,
		Theme.Colors.TextMuted,
		Theme.Colors.TextMuted,
	}, true)

	for index, rarity in Rarities.Order do
		local standard = find(odds.standard, rarity)
		local guaranteed = find(odds.guaranteed, rarity)
		local poolSize = (standard and #standard.cardIds) or (guaranteed and #guaranteed.cardIds) or 0
		row(index, {
			Rarities.Info[rarity].name,
			if standard then BoosterOdds.formatPercent(standard.probability) else "—",
			if guaranteed then BoosterOdds.formatPercent(guaranteed.probability) else "—",
			tostring(poolSize),
		}, { Theme.Rarity[rarity] })
	end
end

function BoosterScreen.build(container: Frame, _controller)
	local booster = Boosters.FirstRift

	local left = new("Frame", {
		Name = "PackColumn",
		BackgroundTransparency = 1,
		Size = UDim2.new(0.38, -8, 1, 0),
		Parent = container,
	})
	packVisual(left, booster)
	local openButton = Components.button({
		text = "Ouvrir",
		variant = "gold",
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 282),
		size = UDim2.fromOffset(190, 44),
	})
	Components.setButtonEnabled(openButton, false)
	openButton.Parent = left
	Components.label({
		Text = "Ouverture disponible au jalon 4",
		TextColor3 = Theme.Colors.TextDim,
		TextSize = Theme.TextSize.Caption,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 332),
		Parent = left,
	})

	local right = new("ScrollingFrame", {
		Name = "Odds",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0.38, 8, 0, 0),
		Size = UDim2.new(0.62, -8, 1, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = container,
	}, { Components.list(Enum.FillDirection.Vertical, 10) })

	Components.heading("Probabilités exactes", { LayoutOrder = 1, Parent = right })
	oddsTable(right, booster)
	Components.paragraph(
		booster.description
			.. " Chaque emplacement tire d'abord une rareté, puis une carte au hasard parmi celles de cette rareté. "
			.. "Les boosters sont gratuits : ils s'obtiennent au premier lancement et en remportant des combats.",
		{ TextSize = Theme.TextSize.Caption, LayoutOrder = 3, Parent = right }
	)
	return {}
end

return BoosterScreen
