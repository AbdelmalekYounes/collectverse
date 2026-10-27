-- Écran Collection : grille de cartes filtrable + fiche détaillée.
-- Jalon 1 : affiche le catalogue complet. Au jalon 4, les quantités possédées
-- viendront du profil serveur (CollectionService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local CardCatalog = require(Shared.Catalog.CardCatalog)
local AbilityText = require(Shared.Catalog.AbilityText)
local Elements = require(Shared.Catalog.Elements)
local Rarities = require(Shared.Catalog.Rarities)
local Roles = require(Shared.Catalog.Roles)

local UI = script.Parent.Parent
local Components = require(UI.Components)
local CardTile = require(UI.CardTile)

local new = Components.new

local CollectionScreen = {
	id = "Collection",
	title = "Collection",
	accent = Theme.Colors.Cyan,
}

local FILTERS = {
	{ id = "All", label = "Tout" },
	{ id = "Fighter", label = "Combattants" },
	{ id = "Item", label = "Objets" },
}

local STATS = {
	{ key = "maxHp", label = "PV", color = Theme.Colors.Success },
	{ key = "attack", label = "ATQ", color = Theme.Colors.Coral },
	{ key = "defense", label = "DÉF", color = Theme.Colors.Cyan },
	{ key = "speed", label = "VIT", color = Theme.Colors.Gold },
}

local SLOT_COLORS = {
	basic = Theme.Colors.TextMuted,
	skill = Theme.Colors.Cyan,
	ultimate = Theme.Colors.Gold,
	defend = Theme.Colors.Success,
}

-- Maxima du catalogue : les barres de statistiques sont relatives au meilleur combattant.
local function computeStatMaxima()
	local maxima = {}
	for _, stat in STATS do
		maxima[stat.key] = 1
	end
	for _, fighter in CardCatalog.getFighters() do
		for _, stat in STATS do
			maxima[stat.key] = math.max(maxima[stat.key], fighter.stats[stat.key])
		end
	end
	return maxima
end

local function chipRow(parent: Instance, layoutOrder: number, chips: { Frame })
	local row = new("Frame", {
		Name = "Chips",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = layoutOrder,
		Parent = parent,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, chip in chips do
		chip.LayoutOrder = index
		chip.Parent = row
	end
end

local function statRow(parent: Instance, layoutOrder: number, stat, value: number, maximum: number)
	local row = new("Frame", {
		Name = stat.key,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = layoutOrder,
		Parent = parent,
	})
	Components.label({
		Text = stat.label,
		FontFace = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Caption,
		TextColor3 = Theme.Colors.TextMuted,
		Size = UDim2.new(0, 36, 1, 0),
		Parent = row,
	})
	local bar = Components.bar(value / maximum, stat.color, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 40, 0.5, 0),
		Size = UDim2.new(1, -92, 0, 6),
	})
	bar.Parent = row
	Components.label({
		Text = tostring(value),
		FontFace = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Caption,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 46, 1, 0),
		Parent = row,
	})
end

local function actionCard(parent: Instance, layoutOrder: number, action)
	local color = SLOT_COLORS[action.slot] or Theme.Colors.Text
	local card = Components.panel({
		Name = action.id,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = layoutOrder,
		Parent = parent,
	}, {
		Components.padding(8, 10),
		Components.list(Enum.FillDirection.Vertical, 2),
	})

	local header = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 1,
		Parent = card,
	})
	Components.label({
		Text = string.upper(AbilityText.slotLabel(action.slot)),
		FontFace = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Caption,
		TextColor3 = color,
		Size = UDim2.fromScale(0.5, 1),
		Parent = header,
	})
	Components.label({
		Text = AbilityText.costText(action),
		TextSize = Theme.TextSize.Caption,
		TextColor3 = Theme.Colors.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.5, 1),
		Parent = header,
	})
	Components.label({
		Text = action.name,
		FontFace = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Label,
		LayoutOrder = 2,
		Parent = card,
	})
	Components.paragraph(AbilityText.describe(action), {
		TextSize = Theme.TextSize.Caption,
		LayoutOrder = 3,
		Parent = card,
	})
end

local function renderDetail(content: Frame, card, maxima)
	for _, child in content:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	Components.label({
		Text = card.name,
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Title,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local rarityChip = Components.chip(Rarities.Info[card.rarity].name, Theme.Rarity[card.rarity])

	if card.kind == "Fighter" then
		Components.label({
			Text = card.title,
			TextColor3 = Theme.Colors.Cyan,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
		chipRow(content, nextOrder(), {
			rarityChip,
			Components.chip(Elements.Info[card.element].name, Theme.Element[card.element]),
			Components.chip(Roles.Info[card.role].name, Theme.Colors.Violet),
			Components.chip(Roles.Rows[card.preferredRow].name, Theme.Colors.TextMuted),
		})
		Components.paragraph(card.lore, { LayoutOrder = nextOrder(), Parent = content })

		Components.heading("Statistiques", { LayoutOrder = nextOrder(), Parent = content })
		for _, stat in STATS do
			statRow(content, nextOrder(), stat, card.stats[stat.key], maxima[stat.key])
		end

		Components.heading("Actions", { LayoutOrder = nextOrder(), Parent = content })
		for _, slot in CardCatalog.ActionSlots do
			actionCard(content, nextOrder(), card.actions[slot])
		end
	else
		chipRow(content, nextOrder(), { rarityChip, Components.chip("Objet", Theme.Colors.TextMuted) })
		Components.paragraph(card.lore, { LayoutOrder = nextOrder(), Parent = content })
		Components.heading("Usage prévu", { LayoutOrder = nextOrder(), Parent = content })
		Components.paragraph(card.plannedUse or "—", { LayoutOrder = nextOrder(), Parent = content })
	end

	Components.paragraph("Exemplaires possédés : synchronisés avec votre profil au jalon 4.", {
		TextSize = Theme.TextSize.Caption,
		TextColor3 = Theme.Colors.TextDim,
		LayoutOrder = nextOrder(),
		Parent = content,
	})
end

function CollectionScreen.build(container: Frame, _controller)
	local state = {
		filter = "All",
		selectedId = nil :: string?,
		tiles = {} :: { [string]: TextButton },
		filterButtons = {} :: { [string]: TextButton },
	}
	local maxima = computeStatMaxima()

	local browser = new("Frame", {
		Name = "Browser",
		BackgroundTransparency = 1,
		Size = UDim2.new(0.58, -8, 1, 0),
		Parent = container,
	})
	local filterBar = new("Frame", {
		Name = "Filters",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = browser,
	}, { Components.list(Enum.FillDirection.Horizontal, 8) })

	local grid = new("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.Cyan,
		Parent = browser,
	}, {
		Components.padding(6),
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(112, 158),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local detail = new("ScrollingFrame", {
		Name = "Detail",
		BackgroundColor3 = Theme.Colors.Surface,
		BorderSizePixel = 0,
		Position = UDim2.new(0.58, 8, 0, 0),
		Size = UDim2.new(0.42, -8, 1, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.Cyan,
		Parent = container,
	}, {
		Components.corner(Theme.Radius.Medium),
		Components.stroke(Theme.Colors.Stroke, 1, 0.3),
		Components.padding(14),
	})
	local detailContent = new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = detail,
	}, { Components.list(Enum.FillDirection.Vertical, 8) })

	local function selectCard(cardId: string)
		local card = CardCatalog.get(cardId)
		if not card then
			return
		end
		if state.selectedId then
			local previous = CardCatalog.get(state.selectedId)
			local previousTile = state.tiles[state.selectedId]
			if previous and previousTile then
				CardTile.setSelected(previousTile, previous, false)
			end
		end
		state.selectedId = cardId
		CardTile.setSelected(state.tiles[cardId], card, true)
		renderDetail(detailContent, card, maxima)
		detail.CanvasPosition = Vector2.zero
	end

	local function applyFilter(filterId: string)
		state.filter = filterId
		local firstVisible = nil
		for _, card in CardCatalog.getAll() do
			local visible = filterId == "All" or card.kind == filterId
			state.tiles[card.id].Visible = visible
			if visible and not firstVisible then
				firstVisible = card.id
			end
		end
		for id, button in state.filterButtons do
			button.BackgroundColor3 = if id == filterId then Theme.Colors.Violet else Theme.Colors.SurfaceHigh
		end
		-- Garde la sélection si elle reste visible, sinon sélectionne la première carte.
		local selected = state.selectedId and CardCatalog.get(state.selectedId)
		local selectionVisible = selected and (filterId == "All" or selected.kind == filterId)
		if not selectionVisible and firstVisible then
			selectCard(firstVisible)
		end
	end

	for index, filter in FILTERS do
		state.filterButtons[filter.id] = Components.button({
			name = filter.id,
			text = filter.label,
			size = UDim2.fromOffset(120, 34),
			textSize = Theme.TextSize.Body,
			layoutOrder = index,
			onClick = function()
				applyFilter(filter.id)
			end,
		})
		state.filterButtons[filter.id].Parent = filterBar
	end

	for index, card in CardCatalog.getAll() do
		local tile = CardTile.create(card, {
			layoutOrder = index,
			onClick = function()
				selectCard(card.id)
			end,
		})
		tile.Parent = grid
		state.tiles[card.id] = tile
	end

	applyFilter("All")
	return state
end

return CollectionScreen
