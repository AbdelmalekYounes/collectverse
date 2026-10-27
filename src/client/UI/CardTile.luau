-- Carte premium réutilisée par la Collection, le Team Builder et les boosters.
--
-- Apparence décrite par CardStyle (cadre de la rareté, variante, tailles) :
--  - cadre à dégradé, épaisseur et ornements selon la rareté ;
--  - fenêtre d'illustration : image déclarée dans VisualAssets si elle existe,
--    posée au-dessus du visuel de repli (emblème, initiale, dégradé de l'élément),
--    qui reste visible si l'image manque ou ne se charge pas ;
--  - gemmes de rareté, nom, élément et rôle, libellé de rareté (lecture redondante) ;
--  - reflet holographique léger pour les Légendaires et la variante Holo, figé si
--    « Animations réduites », absent si « Effets réduits ».
-- Toute la mise en page est proportionnelle : la même carte sert de 100 × 140 à
-- la grande carte de la fiche. API inchangée : create(card, options), setSelected.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Elements = require(Shared.Catalog.Elements)
local Rarities = require(Shared.Catalog.Rarities)
local Roles = require(Shared.Catalog.Roles)
local CardStyle = require(Shared.Visuals.CardStyle)
local VisualAssets = require(Shared.Visuals.VisualAssets)
local Text = require(Shared.Util.Text)
local Components = require(script.Parent.Components)
local Motion = require(script.Parent.Motion)
local ClientSettings = require(script.Parent.Parent.State.ClientSettings)
local GraphicsQuality = require(script.Parent.Parent.State.GraphicsQuality)

local new = Components.new

local CardTile = {}

type Options = {
	layoutOrder: number?,
	quantity: number?, -- affiche « x2 » si > 1
	owned: boolean?, -- false : carte grisée
	onClick: (() -> ())?,
	sizeClass: string?, -- "Compact" | "Standard" | "Large" (sinon déduite de la taille)
	variant: string?, -- remplace la variante du registre (aperçus)
}

local DEFAULT_SIZE = Vector2.new(112, 158)

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

-- Dégradé régulier à partir d'une liste de couleurs hexadécimales.
local function colorSequence(colors: { string }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(hex(colors[1]))
	end
	local points = {}
	for index, color in colors do
		table.insert(points, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), hex(color)))
	end
	return ColorSequence.new(points)
end

local function firstCharacter(text: string): string
	-- Gère les caractères accentués (UTF-8 multi-octets)
	local ok, codepoint = pcall(utf8.codepoint, text, 1)
	return if ok and codepoint then utf8.char(codepoint) else "?"
end

-- Texte qui suit la taille de la carte, plafonné selon la classe de taille.
local function scaledLabel(parent: Instance, name: string, props: { [string]: any }): TextLabel
	local label = Components.label({
		Name = name,
		TextScaled = true,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = parent,
	})
	for key, value in props do
		(label :: any)[key] = value
	end
	new("UITextSizeConstraint", { Name = "SizeLimit", MinTextSize = 6, MaxTextSize = 14, Parent = label })
	return label
end

local function region(spec, x: number?, width: number?): (UDim2, UDim2)
	return UDim2.fromScale(x or 0.06, spec.y), UDim2.fromScale(width or 0.88, spec.height)
end

-- Gemme de rareté : un losange (carré tourné de 45°).
local function gem(parent: Instance, color: Color3, layoutOrder: number, count: number)
	local holder = new("Frame", {
		Name = "Gem",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1 / count, 1),
		LayoutOrder = layoutOrder,
		ZIndex = 3,
		Parent = parent,
	})
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.68, 0.68),
		Rotation = 45,
		BackgroundColor3 = color,
		ZIndex = 3,
		Parent = holder,
	}, {
		new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }),
		Components.stroke(Theme.Colors.Background, 1, 0.2),
	})
end

-- Ornement d'angle (deux traits fins) pour les raretés Épique et Légendaire.
local function ornament(parent: Instance, corner: Vector2, color: Color3)
	local length, thickness = 0.16, 0.012
	local horizontal = new("Frame", {
		Name = "Ornament",
		AnchorPoint = corner,
		Position = UDim2.fromScale(corner.X, corner.Y),
		Size = UDim2.fromScale(length, thickness),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = parent,
	})
	local vertical = horizontal:Clone()
	-- Mêmes dimensions en pixels que le trait horizontal (la carte est plus haute que large).
	vertical.Size = UDim2.fromScale(thickness / CardStyle.AspectRatio, length * CardStyle.AspectRatio)
	vertical.Parent = parent
end

-- Reflet holographique : bande irisée qui traverse la carte.
local function foil(tile: GuiObject)
	local sheen = new("Frame", {
		Name = "Foil",
		BackgroundColor3 = Theme.Colors.White,
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Active = false,
		Parent = tile,
	}, { Components.corner(Theme.Radius.Medium) })
	local gradient = new("UIGradient", {
		Rotation = 25,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.Colors.Cyan),
			ColorSequenceKeypoint.new(0.5, Theme.Colors.Violet),
			ColorSequenceKeypoint.new(1, Theme.Colors.Gold),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.8),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = Vector2.new(-0.6, 0),
		Parent = sheen,
	})
	if ClientSettings.get("reducedMotion") then
		gradient.Offset = Vector2.new(0.1, 0) -- reflet figé
		return
	end
	-- Balayage lent et continu ; la tween s'arrête avec la destruction de la carte.
	local info = TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 1.6)
	TweenService:Create(gradient, info, { Offset = Vector2.new(0.9, 0) }):Play()
end

-- Applique la classe de taille (tailles de texte maximales, libellé de rareté).
local function applySizeClass(tile: GuiObject, className: string)
	local spec = CardStyle.SizeClasses[className] or CardStyle.SizeClasses.Standard
	tile:SetAttribute("SizeClass", className)
	for _, descendant in tile:GetDescendants() do
		if descendant:IsA("UITextSizeConstraint") and descendant.Name == "SizeLimit" then
			local label = descendant.Parent
			local kind = label and label:GetAttribute("TextRole")
			if kind == "Name" then
				descendant.MaxTextSize = spec.nameMax
			elseif kind == "Initial" then
				descendant.MaxTextSize = spec.nameMax * 4
			else
				descendant.MaxTextSize = spec.captionMax
			end
		end
	end
	local rarityLabel = tile:FindFirstChild("RarityLabel", true)
	if rarityLabel then
		(rarityLabel :: GuiObject).Visible = spec.showRarityLabel
	end
end

function CardTile.create(card, options: Options?): TextButton
	local opts = options or {}
	local style = CardStyle.resolve(card.rarity, opts.variant or VisualAssets.variant(card.id))
	local frame = style.frame
	local accent = hex(frame.accent)
	local artColor = if card.kind == "Fighter" then Theme.Element[card.element] else accent
	local budget = GraphicsQuality.budget()
	local layout = CardStyle.Layout

	local scale = new("UIScale")
	local stroke = new("UIStroke", {
		Name = "RarityStroke",
		Color = Theme.Colors.White,
		Thickness = frame.thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, {
		new("UIGradient", { Name = "BorderGradient", Color = colorSequence(frame.border), Rotation = 90 }),
	})

	local tile = new("TextButton", {
		Name = card.id,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Theme.Colors.White,
		LayoutOrder = opts.layoutOrder or 0,
		Size = UDim2.fromOffset(DEFAULT_SIZE.X, DEFAULT_SIZE.Y),
	}, {
		Components.corner(Theme.Radius.Medium),
		new("UIGradient", { Color = colorSequence(frame.background), Rotation = 90 }),
		stroke,
		scale,
	})
	tile:SetAttribute("Rarity", style.rarity)
	tile:SetAttribute("Variant", style.variant)

	-- Liseré intérieur lumineux (Rare et plus) : le halo reste dans la carte.
	if frame.glow and budget.rarityBurst then
		new("Frame", {
			Name = "InnerGlow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -4, 1, -4),
			BackgroundTransparency = 1,
			Parent = tile,
		}, { Components.corner(Theme.Radius.Medium), Components.stroke(hex(frame.glow), 2, 0.65) })
	end

	-- Fenêtre d'illustration
	local art = new("Frame", {
		Name = "Art",
		Position = UDim2.fromScale(layout.art.x, layout.art.y),
		Size = UDim2.fromScale(layout.art.width, layout.art.height),
		BackgroundColor3 = Theme.Colors.White,
		ClipsDescendants = true,
		Parent = tile,
	}, {
		Components.corner(Theme.Radius.Small),
		Components.gradient(artColor, Theme.Colors.Background, 120),
		Components.stroke(accent, 1, 0.35),
	})
	-- Repli : emblème circulaire, initiale, vignettage.
	new("Frame", {
		Name = "Emblem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromScale(0.7, 0.7),
		BackgroundTransparency = 1,
		Parent = art,
	}, {
		new("UIAspectRatioConstraint", { AspectRatio = 1 }),
		Components.corner(Theme.Radius.Pill),
		Components.stroke(Theme.Colors.White, 1.5, 0.7),
	})
	local initial = scaledLabel(art, "Initial", {
		Text = firstCharacter(card.name),
		FontFace = Theme.Fonts.Title,
		TextTransparency = 0.05,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		-- Michroma a une petite hauteur de capitale : la boîte est large exprès.
		Size = UDim2.fromScale(0.7, 0.66),
	})
	initial:SetAttribute("TextRole", "Initial")
	new("Frame", {
		Name = "Vignette",
		BackgroundColor3 = Theme.Colors.Background,
		Size = UDim2.fromScale(1, 1),
		Parent = art,
	}, {
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.6, 0.85),
				NumberSequenceKeypoint.new(1, 0.25),
			}),
		}),
	})
	local illustration = VisualAssets.cardArt(card.id)
	if illustration then
		new("ImageLabel", {
			Name = "Illustration",
			BackgroundTransparency = 1,
			Image = illustration,
			ScaleType = Enum.ScaleType.Crop,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Parent = art,
		}, { Components.corner(Theme.Radius.Small) })
	end

	-- Gemmes de rareté, à cheval sur le bas de l'illustration
	-- Largeur proportionnelle au nombre de gemmes (pas de taille automatique :
	-- elle ne fonctionne pas avec des enfants dimensionnés en proportion).
	local gems = new("Frame", {
		Name = "Gems",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, layout.gems.y),
		Size = UDim2.fromScale(0.07 * frame.gems + 0.07, layout.gems.height),
		BackgroundColor3 = hex(frame.plate),
		ZIndex = 3,
		Parent = tile,
	}, {
		Components.corner(Theme.Radius.Pill),
		Components.stroke(accent, 1, 0.3),
		new("UIPadding", { PaddingLeft = UDim.new(0.18, 0), PaddingRight = UDim.new(0.18, 0) }),
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index = 1, frame.gems do
		gem(gems, accent, index, frame.gems)
	end

	-- Nom, élément et rôle, rareté
	local namePosition, nameSize = region(layout.name)
	local nameLabel = scaledLabel(tile, "CardName", {
		Text = card.name,
		FontFace = Theme.Fonts.Bold,
		TextColor3 = Theme.Colors.Text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = namePosition,
		Size = nameSize,
	})
	nameLabel:SetAttribute("TextRole", "Name")

	local subtitle
	if card.kind == "Fighter" then
		local element = Elements.Info[card.element]
		local role = Roles.Info[card.role]
		subtitle = string.format(
			'<font color="#%s">%s</font> · %s',
			Theme.Element[card.element]:ToHex(),
			element and element.name or "?",
			role and role.name or "?"
		)
	else
		subtitle = "Objet"
	end
	local subtitlePosition, subtitleSize = region(layout.subtitle)
	scaledLabel(tile, "CardSubtitle", {
		Text = subtitle,
		RichText = true,
		TextColor3 = Theme.Colors.TextMuted,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = subtitlePosition,
		Size = subtitleSize,
	})

	local rarityText = Rarities.Info[style.rarity].name
	if style.variantLabel then
		rarityText ..= " · " .. style.variantLabel
	end
	local footerPosition, footerSize = region(layout.footer)
	scaledLabel(tile, "RarityLabel", {
		Text = Text.upper(rarityText),
		FontFace = Theme.Fonts.Bold,
		TextColor3 = accent,
		Position = footerPosition,
		Size = footerSize,
	})

	if frame.ornaments then
		for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
			ornament(tile, corner, accent)
		end
	end

	if style.foil and budget.rarityBurst then
		foil(tile)
	end

	if opts.quantity and opts.quantity > 1 then
		local badge = new("Frame", {
			Name = "Quantity",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromScale(0.27, 0.125),
			BackgroundColor3 = Theme.Colors.Background,
			BackgroundTransparency = 0.15,
			ZIndex = 7,
			Parent = tile,
		}, {
			Components.corner(Theme.Radius.Pill),
			Components.stroke(Theme.Colors.Gold, 1, 0.2),
		})
		local count = Components.label({
			Text = "x" .. opts.quantity,
			FontFace = Theme.Fonts.Bold,
			TextScaled = true,
			TextColor3 = Theme.Colors.Gold,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 7,
			Parent = badge,
		})
		new("UITextSizeConstraint", { MaxTextSize = 13, Parent = count })
	end

	if opts.owned == false then
		-- Carte non obtenue : voile sombre, cadre atténué, texte toujours lisible.
		new("Frame", {
			Name = "Locked",
			BackgroundColor3 = Theme.Colors.Background,
			BackgroundTransparency = 0.45,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 8,
			Parent = tile,
		}, { Components.corner(Theme.Radius.Medium) })
		stroke.Transparency = 0.5
	end

	-- Classe de taille : imposée, ou déduite de la taille en pixels de la vignette.
	local function refreshSizeClass()
		local className = opts.sizeClass
		if not className then
			local width = tile.Size.X.Offset
			className = if width > 0 then CardStyle.sizeClass(width) else "Standard"
		end
		applySizeClass(tile, className)
	end
	refreshSizeClass()
	if not opts.sizeClass then
		tile:GetPropertyChangedSignal("Size"):Connect(refreshSizeClass)
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

-- Sélection : contour cyan uni et épais ; sinon, le cadre de la rareté.
function CardTile.setSelected(tile: TextButton, card, selected: boolean)
	local stroke = tile:FindFirstChild("RarityStroke") :: UIStroke?
	if not stroke then
		return
	end
	local frame = CardStyle.frame(card.rarity)
	local gradient = stroke:FindFirstChild("BorderGradient") :: UIGradient?
	if gradient then
		gradient.Enabled = not selected
	end
	stroke.Color = if selected then Theme.Colors.Cyan else Theme.Colors.White
	stroke.Thickness = if selected then frame.thickness + 1.5 else frame.thickness
	stroke.Transparency = 0
end

return CardTile
