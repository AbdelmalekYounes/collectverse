-- Écran Boosters : booster First Rift, probabilités exactes et ouverture.
-- Les taux affichés sont calculés à partir de la même configuration que le tirage
-- serveur (BoosterOdds). Le tirage est fait par le serveur AVANT l'animation ; le
-- client ne fait que mettre en scène les 5 cartes reçues (RevealTimeline) :
-- le paquet s'illumine et s'ouvre, les dos (tous identiques) sont distribués, puis
-- chaque carte est retournée. Une carte Épique ou Légendaire est mise en lumière
-- seulement APRÈS son retournement : rien ne suggère une rareté à l'avance.
-- « Tout révéler » termine tout instantanément. Animations réduites : déroulé
-- raccourci et sans mouvement ; effets réduits : ni éclair, ni rayons, ni éclats.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Boosters = require(Shared.Catalog.Boosters)
local BoosterOdds = require(Shared.Catalog.BoosterOdds)
local CardCatalog = require(Shared.Catalog.CardCatalog)
local Rarities = require(Shared.Catalog.Rarities)
local Text = require(Shared.Util.Text)

local Client = script.Parent.Parent.Parent
local ClientSettings = require(Client.State.ClientSettings)
local GraphicsQuality = require(Client.State.GraphicsQuality)
local DataController = require(Client.Controllers.DataController)
local UI = script.Parent.Parent
local Components = require(UI.Components)
local CardTile = require(UI.CardTile)
local Motion = require(UI.Motion)
local RevealTimeline = require(UI.RevealTimeline)

local new = Components.new

local BoosterScreen = {
	id = "Booster",
	title = "Boosters",
	accent = Theme.Colors.Gold,
}

local PACK_SIZE = Vector2.new(190, 266)

-- Emblème de la faille : deux anneaux et un cristal central.
local function riftEmblem(parent: Instance, size: number, position: UDim2, zIndex: number)
	local emblem = new("Frame", {
		Name = "Emblem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = zIndex,
		Parent = parent,
	})
	for _, ring in
		{
			{ scale = 1, color = Theme.Colors.Gold, transparency = 0.15 },
			{
				scale = 0.72,
				color = Theme.Colors.Cyan,
				transparency = 0.35,
			},
		}
	do
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(ring.scale, ring.scale),
			BackgroundTransparency = 1,
			ZIndex = zIndex,
			Parent = emblem,
		}, { Components.corner(Theme.Radius.Pill), Components.stroke(ring.color, 2, ring.transparency) })
	end
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.3),
		Rotation = 45,
		BackgroundColor3 = Theme.Colors.White,
		ZIndex = zIndex,
		Parent = emblem,
	}, { Components.gradient(Theme.Colors.Cyan, Theme.Colors.Violet, 45) })
	return emblem
end

-- Reflet qui balaie une surface (figé si animations réduites, absent si effets réduits).
local function sheen(parent: GuiObject, zIndex: number)
	if not GraphicsQuality.budget().rarityBurst then
		return
	end
	local frame = new("Frame", {
		Name = "Sheen",
		BackgroundColor3 = Theme.Colors.White,
		Size = UDim2.fromScale(1, 1),
		ZIndex = zIndex,
		Parent = parent,
	}, { Components.corner(Theme.Radius.Large) })
	local gradient = new("UIGradient", {
		Rotation = 20,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.45, 1),
			NumberSequenceKeypoint.new(0.5, 0.82),
			NumberSequenceKeypoint.new(0.55, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = Vector2.new(-0.7, 0),
		Parent = frame,
	})
	if ClientSettings.get("reducedMotion") then
		gradient.Offset = Vector2.new(0.15, 0)
		return
	end
	local info = TweenInfo.new(2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 2)
	TweenService:Create(gradient, info, { Offset = Vector2.new(0.9, 0) }):Play()
end

-- Face du paquet, réutilisée dans la colonne et pour l'animation d'ouverture.
local function packFace(parent: Instance, booster, zIndex: number): Frame
	local pack = new("Frame", {
		Name = "PackFace",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.White,
		ZIndex = zIndex,
		Parent = parent,
	}, {
		Components.corner(Theme.Radius.Large),
		Components.gradient(Theme.Colors.Violet, Theme.Colors.Background, 160),
		new("UIStroke", {
			Name = "PackStroke",
			Color = Theme.Colors.White,
			Thickness = 2.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, {
			new("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHex("#FFF4D1")),
					ColorSequenceKeypoint.new(0.5, Theme.Colors.Gold),
					ColorSequenceKeypoint.new(1, Color3.fromHex("#A8711C")),
				}),
			}),
		}),
	})
	-- Bandeau supérieur « COLLECTVERSE »
	new("Frame", {
		Name = "Band",
		Position = UDim2.fromScale(0, 0.06),
		Size = UDim2.fromScale(1, 0.09),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.25,
		ZIndex = zIndex,
		Parent = pack,
	}, {
		Components.label({
			Text = "COLLECTVERSE",
			FontFace = Theme.Fonts.Title,
			TextScaled = true,
			TextColor3 = Theme.Colors.Gold,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 0.7),
			Position = UDim2.fromScale(0, 0.15),
			ZIndex = zIndex,
		}),
	})
	riftEmblem(pack, 84, UDim2.fromScale(0.5, 0.36), zIndex)
	Components.label({
		Text = Text.upper(booster.name),
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Heading,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromScale(0, 0.56),
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = zIndex,
		Parent = pack,
	})
	Components.label({
		Text = string.format("%d cartes", booster.cardCount),
		TextColor3 = Theme.Colors.Cyan,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromScale(0, 0.68),
		ZIndex = zIndex,
		Parent = pack,
	})
	Components.label({
		Text = "1 carte Rare ou mieux garantie",
		TextColor3 = Theme.Colors.Gold,
		TextSize = Theme.TextSize.Caption,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -12),
		ZIndex = zIndex,
		Parent = pack,
	})
	sheen(pack, zIndex + 1)
	return pack
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
local SPOTLIGHT_TEXT = {
	Epic = "ÉPIQUE",
	Legendary = "LÉGENDAIRE !",
}

-- Dos de carte : identique pour toutes les cartes (ne révèle aucune rareté).
local function cardBack(parent: Instance): Frame
	local back = new("Frame", {
		Name = "Back",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.White,
		ZIndex = 6,
		Parent = parent,
	}, {
		Components.corner(Theme.Radius.Medium),
		Components.gradient(Theme.Colors.Violet, Theme.Colors.Background, 150),
		Components.stroke(Theme.Colors.Gold, 2, 0.15),
	})
	new("Frame", {
		Name = "Inset",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -12, 1, -12),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = back,
	}, { Components.corner(Theme.Radius.Small), Components.stroke(Theme.Colors.Gold, 1, 0.6) })
	riftEmblem(back, 52, UDim2.fromScale(0.5, 0.42), 6)
	Components.label({
		Text = "FIRST RIFT",
		FontFace = Theme.Fonts.Title,
		TextSize = 10,
		TextColor3 = Theme.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromScale(0, 0.76),
		Size = UDim2.fromScale(1, 0.12),
		ZIndex = 6,
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
		ZIndex = 9,
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
			ZIndex = 9,
		}),
	})
end

-- Rayons de lumière derrière une carte mise en lumière.
local function rays(parent: Instance, color: Color3): Frame
	local holder = new("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(2.4, 2.4 * CARD_SIZE.X / CARD_SIZE.Y),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = parent,
	}, { new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	for index = 0, 5 do
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 0.07),
			Rotation = index * 30,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = holder,
		}, {
			new("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0.45),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end
	return holder
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
	local packHolder = new("Frame", {
		Name = "Pack",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(PACK_SIZE.X, PACK_SIZE.Y),
		BackgroundTransparency = 1,
		Parent = left,
	})
	packFace(packHolder, booster, 1)
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

	-- Paquet animé au centre (CanvasGroup : il peut s'effacer d'un bloc)
	local packStage = new("CanvasGroup", {
		Name = "PackStage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 52 + CARD_SIZE.Y / 2),
		Size = UDim2.fromOffset(PACK_SIZE.X * 0.7, PACK_SIZE.Y * 0.7),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = reveal,
	})
	local packScale = new("UIScale", { Parent = packStage })
	local stagedPack = packFace(packStage, booster, 7)
	local stagedStroke = stagedPack:FindFirstChild("PackStroke") :: UIStroke
	local flash = new("Frame", {
		Name = "Flash",
		BackgroundColor3 = Theme.Colors.White,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 9,
		Parent = reveal,
	}, { Components.corner(Theme.Radius.Medium) })

	local banner = Components.label({
		Name = "Spotlight",
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Title,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 24),
		ZIndex = 9,
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

	-- Attente interrompue dès que le joueur demande à tout révéler.
	local function pause(seconds: number)
		local elapsed = 0
		while elapsed < seconds and not state.skip do
			elapsed += task.wait()
		end
	end

	local function effectsAllowed(): boolean
		return GraphicsQuality.budget().rarityBurst
	end

	-- Retourne une carte : la face arrière se replie, la face avant se déplie.
	local function flip(slot, instant: boolean)
		if slot.flipped then
			return
		end
		slot.flipped = true
		slot.scale.Scale = 1
		if not instant and not ClientSettings.get("reducedMotion") then
			Motion.tween(slot.holder, Theme.Motion.Fast, { Size = UDim2.fromScale(0, 1) })
			task.wait(Theme.Motion.Fast.Time)
		end
		slot.back.Visible = false
		slot.front.Visible = true
		if instant then
			slot.holder.Size = UDim2.fromScale(1, 1)
		else
			Motion.tween(slot.holder, Theme.Motion.Normal, { Size = UDim2.fromScale(1, 1) })
		end
		-- Éclat aux couleurs de la rareté, à partir de Rare (après le retournement)
		if Rarities.Info[slot.rarity].rank >= 2 and not instant and effectsAllowed() then
			slot.burst.BackgroundTransparency = 0.25
			slot.burst.Size = UDim2.fromScale(1, 1)
			Motion.tween(
				slot.burst,
				Theme.Motion.Slow,
				{ BackgroundTransparency = 1, Size = UDim2.fromScale(1.35, 1.25) }
			)
		end
	end

	-- Mise en lumière d'une carte déjà retournée (Épique, Légendaire).
	local function spotlight(slot, duration: number)
		local color = Theme.Rarity[slot.rarity]
		banner.Text = SPOTLIGHT_TEXT[slot.rarity] or ""
		banner.TextColor3 = color
		banner.TextTransparency = 0
		local beams
		if effectsAllowed() then
			beams = rays(slot.frame, color)
			if not ClientSettings.get("reducedMotion") then
				local info = TweenInfo.new(math.max(duration, 0.3), Enum.EasingStyle.Linear)
				TweenService:Create(beams, info, { Rotation = 40 }):Play()
			end
		end
		if not ClientSettings.get("reducedMotion") then
			slot.pop.Scale = 1.12
			Motion.tween(slot.pop, Theme.Motion.Slow, { Scale = 1 })
		end
		pause(duration)
		if beams then
			beams:Destroy()
		end
		Motion.tween(banner, Theme.Motion.Normal, { TextTransparency = 1 })
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
		banner.TextTransparency = 1
		skipButton.Visible = false
		againButton.Visible = true
		doneButton.Visible = true
		Components.setButtonEnabled(againButton, state.remaining > 0)
		refresh()
	end

	-- Construit les emplacements (dos visibles, faces cachées) pour les cartes reçues.
	local function buildSlots(grants)
		for _, child in cardRow:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
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
			local scale = new("UIScale", { Scale = 0, Parent = frame })
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
			local pop = new("UIScale", { Parent = holder })
			local back = cardBack(holder)
			local front = CardTile.create(card, { quantity = grant.count, sizeClass = "Standard" })
			front.Size = UDim2.fromScale(1, 1)
			front.Visible = false
			front.Parent = holder
			if grant.unlockedFighter then
				badge(front, "DÉBLOQUÉ", Theme.Colors.Gold)
			elseif grant.isNew then
				badge(front, "NOUVEAU", Theme.Colors.Cyan)
			end
			slots[index] = {
				frame = frame,
				scale = scale,
				holder = holder,
				pop = pop,
				back = back,
				front = front,
				burst = burst,
				rarity = card.rarity,
				flipped = false,
			}
		end
		return slots
	end

	local function playStep(step, slots)
		if step.kind == "Charge" then
			-- Le paquet se charge d'énergie : léger tremblement et contour plus vif.
			if step.duration > 0 then
				Motion.tween(stagedStroke, TweenInfo.new(step.duration), { Thickness = 5 })
				local swings = 4
				for swing = 1, swings do
					if state.skip then
						break
					end
					local angle = if swing % 2 == 1 then 3 else -3
					Motion.tween(packStage, TweenInfo.new(step.duration / swings), { Rotation = angle })
					pause(step.duration / swings)
				end
				packStage.Rotation = 0
			end
		elseif step.kind == "Burst" then
			-- Ouverture : éclair (effets complets) et le paquet s'efface en grandissant.
			if effectsAllowed() then
				flash.BackgroundTransparency = 0.55
				Motion.tween(flash, TweenInfo.new(step.duration + 0.25), { BackgroundTransparency = 1 })
			end
			local info = TweenInfo.new(math.max(step.duration, 0.05), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			Motion.tween(packScale, info, { Scale = 1.35 })
			Motion.tween(packStage, info, { GroupTransparency = 1 })
			pause(step.duration)
			packStage.Visible = false
		elseif step.kind == "Deal" then
			-- Distribution des dos, tous identiques, dans l'ordre de révélation.
			local per = if #slots > 0 then step.duration / #slots else 0
			for _, slot in slots do
				if state.skip then
					break
				end
				Motion.tween(slot.scale, Theme.Motion.Normal, { Scale = 1 })
				pause(per)
			end
		elseif step.kind == "Flip" then
			pause(step.duration)
			if not state.skip then
				flip(slots[step.index], false)
			end
		elseif step.kind == "Spotlight" then
			if not state.skip and step.duration > 0 then
				spotlight(slots[step.index], step.duration)
			end
		end
	end

	local function startReveal(grants)
		summary.Text = ""
		banner.TextTransparency = 1
		state.skip = false
		state.revealing = true
		skipButton.Visible = true
		againButton.Visible = false
		doneButton.Visible = false

		local slots = buildSlots(grants)
		packStage.Visible = true
		packStage.GroupTransparency = 0
		packStage.Rotation = 0
		packScale.Scale = 1
		stagedStroke.Thickness = 2.5
		flash.BackgroundTransparency = 1
		showReveal(true)

		local rarities = {}
		for index, slot in slots do
			rarities[index] = slot.rarity
		end
		local steps = RevealTimeline.build(rarities, { reducedMotion = ClientSettings.get("reducedMotion") })

		task.spawn(function()
			for _, step in steps do
				if state.skip or not reveal.Parent then
					break
				end
				playStep(step, slots)
			end
			if not reveal.Parent then
				return
			end
			-- Fin normale ou « Tout révéler » : état final complet, sans animation.
			packStage.Visible = false
			flash.BackgroundTransparency = 1
			for _, slot in slots do
				slot.scale.Scale = 1
				slot.pop.Scale = 1
				flip(slot, true)
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
