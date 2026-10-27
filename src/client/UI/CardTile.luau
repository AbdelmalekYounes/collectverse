-- Vignette de carte réutilisée par la collection, le Team Builder et les boosters.
-- Visuel provisoire : initiale du nom sur un dégradé à la couleur de l'élément.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Elements = require(Shared.Catalog.Elements)
local Rarities = require(Shared.Catalog.Rarities)
local Components = require(script.Parent.Components)
local Motion = require(script.Parent.Motion)

local new = Components.new

local CardTile = {}

export type Options = {
	layoutOrder: number?,
	quantity: number?, -- affiche « x2 » si > 1
	owned: boolean?, -- false : carte grisée
	onClick: (() -> ())?,
}

local function firstCharacter(text: string): string
	-- Gère les caractères accentués (UTF-8 multi-octets)
	local ok, codepoint = pcall(utf8.codepoint, text, 1)
	return if ok and codepoint then utf8.char(codepoint) else "?"
end

function CardTile.create(card, options: Options?): TextButton
	local opts = options or {}
	local rarityColor = Theme.Rarity[card.rarity] or Theme.Colors.TextMuted
	local artColor = if card.kind == "Fighter" then Theme.Element[card.element] else rarityColor
	local subtitle = if card.kind == "Fighter" then Elements.Info[card.element].name else "Objet"

	local scale = new("UIScale")
	local stroke = Components.stroke(rarityColor, 1.5, 0.25)
	stroke.Name = "RarityStroke"

	local tile = new("TextButton", {
		Name = card.id,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Theme.Colors.White,
		LayoutOrder = opts.layoutOrder or 0,
		Size = UDim2.fromOffset(112, 158),
	}, {
		Components.corner(Theme.Radius.Medium),
		Components.gradient(Theme.Colors.SurfaceHigh, Theme.Colors.Background),
		stroke,
		scale,
	})

	local art = new("Frame", {
		Name = "Art",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(1, -16, 0.56, 0),
		BackgroundColor3 = Theme.Colors.White,
		Parent = tile,
	}, {
		Components.corner(Theme.Radius.Small),
		Components.gradient(artColor, Theme.Colors.Background, 120),
	})
	Components.label({
		Text = firstCharacter(card.name),
		FontFace = Theme.Fonts.Title,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		TextTransparency = 0.1,
		Parent = art,
	})

	Components.label({
		Name = "CardName",
		Text = card.name,
		FontFace = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Body,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0, 8, 0.56, 14),
		Size = UDim2.new(1, -16, 0, 18),
		Parent = tile,
	})
	Components.label({
		Name = "CardSubtitle",
		Text = subtitle .. " · " .. Rarities.Info[card.rarity].name,
		TextSize = Theme.TextSize.Caption,
		TextColor3 = Theme.Colors.TextMuted,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0, 8, 0.56, 32),
		Size = UDim2.new(1, -16, 0, 16),
		Parent = tile,
	})
	new("Frame", {
		Name = "RarityBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -24, 0, 3),
		BackgroundColor3 = rarityColor,
		Parent = tile,
	}, { Components.corner(Theme.Radius.Pill) })

	if opts.quantity and opts.quantity > 1 then
		new("Frame", {
			Name = "Quantity",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(30, 20),
			BackgroundColor3 = Theme.Colors.Background,
			BackgroundTransparency = 0.15,
			ZIndex = 2,
			Parent = tile,
		}, {
			Components.corner(Theme.Radius.Pill),
			Components.stroke(Theme.Colors.Gold, 1, 0.2),
			Components.label({
				Text = "x" .. opts.quantity,
				FontFace = Theme.Fonts.Bold,
				TextSize = Theme.TextSize.Caption,
				TextColor3 = Theme.Colors.Gold,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
			}),
		})
	end

	if opts.owned == false then
		tile.BackgroundTransparency = 0.4
		art.BackgroundTransparency = 0.7
	end

	tile.MouseEnter:Connect(function()
		Motion.tween(scale, Theme.Motion.Fast, { Scale = 1.04 })
	end)
	tile.MouseLeave:Connect(function()
		Motion.tween(scale, Theme.Motion.Fast, { Scale = 1 })
	end)
	tile.Activated:Connect(function()
		if opts.onClick then
			opts.onClick()
		end
	end)

	return tile
end

function CardTile.setSelected(tile: TextButton, card, selected: boolean)
	local stroke = tile:FindFirstChild("RarityStroke") :: UIStroke?
	if not stroke then
		return
	end
	stroke.Color = if selected then Theme.Colors.Cyan else (Theme.Rarity[card.rarity] or Theme.Colors.TextMuted)
	stroke.Thickness = if selected then 3 else 1.5
	stroke.Transparency = if selected then 0 else 0.25
end

return CardTile
