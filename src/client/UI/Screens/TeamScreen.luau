-- Écran Équipe (aperçu du jalon 1).
-- Affiche la disposition 3 avant / 2 arrière avec l'équipe de départ.
-- La composition éditable, validée par le serveur (TeamService), arrive au jalon 2.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local GameConfig = require(Shared.Config.GameConfig)
local CardCatalog = require(Shared.Catalog.CardCatalog)

local UI = script.Parent.Parent
local Components = require(UI.Components)
local CardTile = require(UI.CardTile)

local new = Components.new

local TeamScreen = {
	id = "Team",
	title = "Équipe",
	accent = Theme.Colors.Violet,
}

-- Répartition indicative selon la ligne préférée (présentation uniquement).
local function previewRows(): ({ string }, { string })
	local front, back, rest = {}, {}, {}
	for _, id in GameConfig.Progression.StarterFighters do
		local fighter = CardCatalog.getFighter(id)
		if fighter then
			if fighter.preferredRow == "Front" and #front < GameConfig.Team.FrontSlots then
				table.insert(front, id)
			elseif fighter.preferredRow == "Back" and #back < GameConfig.Team.BackSlots then
				table.insert(back, id)
			else
				table.insert(rest, id)
			end
		end
	end
	for _, id in rest do
		if #front < GameConfig.Team.FrontSlots then
			table.insert(front, id)
		elseif #back < GameConfig.Team.BackSlots then
			table.insert(back, id)
		end
	end
	return front, back
end

local function emptySlot(layoutOrder: number): Frame
	return new("Frame", {
		Name = "EmptySlot",
		Size = UDim2.fromOffset(112, 158),
		BackgroundColor3 = Theme.Colors.Surface,
		BackgroundTransparency = 0.3,
		LayoutOrder = layoutOrder,
	}, {
		Components.corner(Theme.Radius.Medium),
		Components.stroke(Theme.Colors.Stroke, 1.5, 0.2),
		Components.label({
			Text = "Vide",
			TextColor3 = Theme.Colors.TextDim,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
		}),
	})
end

local function buildRow(parent: Instance, layoutOrder: number, title: string, slotCount: number, ids: { string })
	local section = new("Frame", {
		Name = title,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = layoutOrder,
		Parent = parent,
	}, { Components.list(Enum.FillDirection.Vertical, 6) })
	Components.heading(title, { LayoutOrder = 1, Parent = section })

	local slots = new("Frame", {
		Name = "Slots",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 158),
		LayoutOrder = 2,
		Parent = section,
	}, { Components.list(Enum.FillDirection.Horizontal, 10) })

	for index = 1, slotCount do
		local fighter = ids[index] and CardCatalog.getFighter(ids[index])
		if fighter then
			CardTile.create(fighter, { layoutOrder = index }).Parent = slots
		else
			emptySlot(index).Parent = slots
		end
	end
end

function TeamScreen.build(container: Frame, _controller)
	local scroll = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = container,
	}, { Components.list(Enum.FillDirection.Vertical, 14) })

	Components.paragraph(
		"La ligne avant protège la ligne arrière : les attaques ciblées normales doivent viser un combattant "
			.. "de première ligne tant qu'il en reste un debout. Les assassins peuvent contourner cette protection.",
		{ LayoutOrder = 1, Parent = scroll }
	)

	local front, back = previewRows()
	buildRow(scroll, 2, "Ligne avant", GameConfig.Team.FrontSlots, front)
	buildRow(scroll, 3, "Ligne arrière", GameConfig.Team.BackSlots, back)

	Components.paragraph("Aperçu de l'équipe de départ. La modification de l'équipe arrive au jalon 2.", {
		TextColor3 = Theme.Colors.TextDim,
		TextSize = Theme.TextSize.Caption,
		LayoutOrder = 4,
		Parent = scroll,
	})
	return {}
end

return TeamScreen
