-- Écran Boosters : booster First Rift, probabilités exactes et ouverture.
-- Les taux affichés sont calculés à partir de la même configuration que le tirage
-- serveur (BoosterOdds). Le tirage est fait par le serveur ; le client ne fait
-- que révéler les 5 cartes reçues, une par une (révélation complète possible).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Boosters = require(Shared.Catalog.Boosters)
local BoosterOdds = require(Shared.Catalog.BoosterOdds)
local CardCatalog = require(Shared.Catalog.CardCatalog)
local Rarities = require(Shared.Catalog.Rarities)
local Text = require(Shared.Util.Text)

local Client = script.Parent.Parent.Parent
local ClientSettings = require(Client.State.ClientSettings)
local DataController = require(Client.Controllers.DataController)
local UI = script.Parent.Parent
local Components = require(UI.Components)
local CardTile = require(UI.CardTile)
local Motion = require(UI.Motion)

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

-- Révélation des cartes ---------------------------------------------------------

local CARD_SIZE = Vector2.new(116, 164)
local CARD_GAP = 14

local function cardBack(parent: Instance): Frame
	local back = new("Frame", {
		Name = "Back",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.White,
		Parent = parent,
	}, {
		Components.corner(Theme.Radius.Medium),
		Components.gradient(Theme.Colors.Violet, Theme.Colors.Background, 150),
		Components.stroke(Theme.Colors.Gold, 1.5, 0.2),
	})
	Components.label({
		Text = "?",
		FontFace = Theme.Fonts.Title,
		TextSize = 44,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 0.8),
		Parent = back,
	})
	Components.label({
		Text = "FIRST RIFT",
		FontFace = Theme.Fonts.Title,
		TextSize = 10,
		TextColor3 = Theme.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromScale(0, 0.8),
		Size = UDim2.fromScale(1, 0.14),
		Parent = back,
	})
	return back
end

local function badge(parent: Instance, text: string, color: Color3)
	new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = color,
		ZIndex = 4,
		Parent = parent,
	}, {
		Components.corner(Theme.Radius.Pill),
		Components.padding(0, 8),
		Components.label({
			Text = text,
			FontFace = Theme.Fonts.Bold,
			TextSize = 11,
			TextColor3 = Theme.Colors.Background,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			TextWrapped = false,
			ZIndex = 4,
		}),
	})
end

function BoosterScreen.build(container: Frame, _controller)
	local booster = Boosters.FirstRift
	local state = {
		opening = false,
		revealing = false,
		skip = false,
		remaining = 0,
	}

	local left = new("Frame", {
		Name = "PackColumn",
		BackgroundTransparency = 1,
		Size = UDim2.new(0.38, -8, 1, 0),
		Parent = container,
	})
	packVisual(left, booster)
	local openButton
	local countLabel = Components.label({
		TextColor3 = Theme.Colors.Gold,
		FontFace = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Caption,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 330),
		Parent = left,
	})
	local message = Components.label({
		TextColor3 = Theme.Colors.Coral,
		TextSize = Theme.TextSize.Caption,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 350),
		Parent = left,
	})

	-- Superposition de révélation, au-dessus des deux colonnes
	local reveal = new("Frame", {
		Name = "Reveal",
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 5,
		Parent = container,
	}, { Components.corner(Theme.Radius.Medium) })
	Components.label({
		Text = Text.upper(booster.name) .. " · OUVERTURE",
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Label,
		TextColor3 = Theme.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 24),
		ZIndex = 5,
		Parent = reveal,
	})
	local cardRow = new("Frame", {
		Name = "Cards",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.fromOffset(5 * CARD_SIZE.X + 4 * CARD_GAP, CARD_SIZE.Y),
		ZIndex = 5,
		Parent = reveal,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, CARD_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local summary = Components.label({
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Colors.Text,
		Position = UDim2.fromOffset(0, 52 + CARD_SIZE.Y + 18),
		Size = UDim2.new(1, 0, 0, 36),
		ZIndex = 5,
		Parent = reveal,
	})
	local revealButtons = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, 0, 0, 44),
		ZIndex = 5,
		Parent = reveal,
	}, { Components.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center) })

	local skipButton, againButton, doneButton

	-- Pendant la révélation, les colonnes du booster et des taux sont masquées :
	-- seules les cartes tirées restent à l'écran.
	local function showReveal(visible: boolean)
		reveal.Visible = visible
		for _, child in container:GetChildren() do
			if child ~= reveal and child:IsA("GuiObject") then
				child.Visible = not visible
			end
		end
	end
	local refresh

	local function pause(seconds: number)
		local elapsed = 0
		while elapsed < seconds and not state.skip do
			elapsed += task.wait()
		end
	end

	-- Retourne une carte : la face arrière se replie, la face avant se déplie.
	local function flip(slot, instant: boolean)
		local holder, back, front, burst, rarity = slot.holder, slot.back, slot.front, slot.burst, slot.rarity
		if not instant and not ClientSettings.get("reducedMotion") then
			Motion.tween(holder, Theme.Motion.Fast, { Size = UDim2.fromScale(0, 1) })
			task.wait(Theme.Motion.Fast.Time)
		end
		back.Visible = false
		front.Visible = true
		Motion.tween(holder, Theme.Motion.Normal, { Size = UDim2.fromScale(1, 1) })
		-- Éclat aux couleurs de la rareté, à partir de Rare
		if Rarities.Info[rarity].rank >= 2 and not instant then
			burst.BackgroundTransparency = 0.25
			burst.Size = UDim2.fromScale(1, 1)
			Motion.tween(burst, Theme.Motion.Slow, { BackgroundTransparency = 1, Size = UDim2.fromScale(1.35, 1.25) })
		end
	end

	local function finishReveal(grants)
		state.revealing = false
		local newFighters, newCards = {}, 0
		for _, grant in grants do
			if grant.isNew then
				newCards += 1
			end
			if grant.unlockedFighter then
				table.insert(newFighters, CardCatalog.get(grant.id).name)
			end
		end
		if #newFighters > 0 then
			summary.Text = "Nouveau combattant débloqué : " .. table.concat(newFighters, ", ") .. " !"
			summary.TextColor3 = Theme.Colors.Gold
		elseif newCards > 0 then
			summary.Text = string.format("%d nouvelle(s) carte(s) ajoutée(s) à votre collection.", newCards)
			summary.TextColor3 = Theme.Colors.Cyan
		else
			summary.Text = "Des doublons : ils sont conservés dans votre collection."
			summary.TextColor3 = Theme.Colors.TextMuted
		end
		skipButton.Visible = false
		againButton.Visible = true
		doneButton.Visible = true
		Components.setButtonEnabled(againButton, state.remaining > 0)
		refresh()
	end

	local function startReveal(grants)
		for _, child in cardRow:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		summary.Text = ""
		state.skip = false
		state.revealing = true
		skipButton.Visible = true
		againButton.Visible = false
		doneButton.Visible = false

		local slots = {}
		for index, grant in grants do
			local card = CardCatalog.get(grant.id)
			local frame = new("Frame", {
				Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y),
				BackgroundTransparency = 1,
				LayoutOrder = index,
				ZIndex = 5,
				Parent = cardRow,
			})
			local burst = new("Frame", {
				Name = "Burst",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Rarity[card.rarity],
				BackgroundTransparency = 1,
				ZIndex = 5,
				Parent = frame,
			}, { Components.corner(Theme.Radius.Large) })
			local holder = new("Frame", {
				Name = "Holder",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 6,
				Parent = frame,
			})
			local back = cardBack(holder)
			local front = CardTile.create(card, { quantity = grant.count })
			front.Size = UDim2.fromScale(1, 1)
			front.Visible = false
			front.Parent = holder
			if grant.unlockedFighter then
				badge(front, "DÉBLOQUÉ", Theme.Colors.Gold)
			elseif grant.isNew then
				badge(front, "NOUVEAU", Theme.Colors.Cyan)
			end
			slots[index] = { holder = holder, back = back, front = front, burst = burst, rarity = card.rarity }
		end

		showReveal(true)
		task.spawn(function()
			local gap = if ClientSettings.get("reducedMotion") then 0.15 else 0.55
			for index, slot in slots do
				pause(if index == 1 then 0.35 else gap)
				if not reveal.Parent then
					return
				end
				flip(slot, state.skip)
			end
			finishReveal(grants)
		end)
	end

	local function open()
		if state.opening or state.revealing then
			return
		end
		state.opening = true
		message.Text = ""
		refresh()
		local result = DataController.requestOpenBooster(booster.id)
		state.opening = false
		if not result.ok then
			message.Text = result.reason or "Ouverture impossible"
			warn("[Booster] Ouverture refusée : " .. tostring(result.reason))
			refresh()
			return
		end
		state.remaining = result.remaining
		startReveal(result.cards)
		refresh()
	end

	openButton = Components.button({
		text = "Ouvrir",
		variant = "gold",
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 282),
		size = UDim2.fromOffset(190, 44),
		onClick = open,
	})
	openButton.Parent = left

	skipButton = Components.button({
		text = "Tout révéler",
		variant = "gold",
		size = UDim2.fromOffset(170, 40),
		layoutOrder = 1,
		onClick = function()
			state.skip = true
		end,
	})
	againButton = Components.button({
		text = "Ouvrir un autre",
		variant = "gold",
		size = UDim2.fromOffset(170, 40),
		layoutOrder = 2,
		onClick = function()
			showReveal(false)
			open()
		end,
	})
	doneButton = Components.button({
		text = "Terminer",
		size = UDim2.fromOffset(150, 40),
		layoutOrder = 3,
		onClick = function()
			showReveal(false)
		end,
	})
	for _, button in { skipButton, againButton, doneButton } do
		button.ZIndex = 5
		button.Parent = revealButtons
	end

	refresh = function()
		local profile = DataController.getProfile()
		local owned = if profile then profile.boosters[booster.id] or 0 else 0
		state.remaining = owned
		countLabel.Text = if profile
			then string.format("Vous possédez %d booster(s)", owned)
			else "Chargement du profil…"
		Components.setButtonEnabled(openButton, owned > 0 and not state.opening and not state.revealing)
		openButton.Text = if state.opening then "Ouverture…" else "Ouvrir"
	end
	DataController.Changed:Connect(function()
		refresh()
	end)
	refresh()

	state.onClose = function()
		-- Fermer pendant la révélation la termine instantanément.
		state.skip = true
	end
	state.refresh = refresh

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
	return state
end

function BoosterScreen.onOpen(state)
	state.refresh()
end

function BoosterScreen.onClose(state)
	state.onClose()
end

return BoosterScreen
