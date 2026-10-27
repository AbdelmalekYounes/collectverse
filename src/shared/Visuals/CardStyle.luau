-- Système visuel des cartes (V0.2) : cadres par rareté, variantes, tailles et
-- mise en page. Données pures (couleurs en hexadécimal, proportions), testées
-- avec Lune ; CardTile les traduit en interface Roblox.
--
-- Principes de la direction artistique (Stylized Premium Fantasy / Anime) :
--  - fond bleu nuit #101426, accents violet #7858EB, cyan #39CBE7, or #F0BF61,
--    corail #F36D79 ;
--  - la rareté se lit de trois façons redondantes (accessibilité) : couleur et
--    épaisseur du cadre, nombre de gemmes, libellé écrit ;
--  - plus la carte est rare, plus le cadre est riche (dégradé, ornements, halo),
--    mais le texte reste toujours sur un fond sombre et uni (contraste vérifié).
--
-- Aucune donnée de gameplay ici : seulement l'apparence.

local Freeze = require(script.Parent.Parent.Util.Freeze)

local CardStyle = {}

CardStyle.Palette = Freeze.deep({
	Night = "#101426",
	Violet = "#7858EB",
	Cyan = "#39CBE7",
	Gold = "#F0BF61",
	Coral = "#F36D79",
	Text = "#EEF0FF",
	TextMuted = "#9AA2CC",
})

-- Cadre de chaque rareté.
--  border : couleurs du dégradé du contour (du haut vers le bas)
--  thickness : épaisseur du contour (pixels, à la taille Standard)
--  background : dégradé du corps de la carte (haut, bas)
--  plate : fond du bandeau de nom (uni, sombre : lisibilité)
--  gems : nombre de gemmes de rareté (= rang)
--  ornaments : coins décorés
--  glow : halo extérieur (nil = aucun)
--  foil : reflet holographique par défaut
CardStyle.Frames = Freeze.deep({
	Common = {
		border = { "#C9CFEA", "#7E87B5" },
		thickness = 1.5,
		background = { "#232A52", "#101426" },
		plate = "#151A33",
		accent = "#AEB6D9",
		gems = 1,
		ornaments = false,
		glow = nil,
		foil = false,
	},
	Rare = {
		border = { "#A8F1FF", "#39CBE7", "#1C7187" },
		thickness = 2,
		background = { "#1B3557", "#101426" },
		plate = "#121C33",
		accent = "#39CBE7",
		gems = 2,
		ornaments = false,
		glow = "#39CBE7",
		foil = false,
	},
	Epic = {
		border = { "#D2C4FF", "#7858EB", "#3A2690" },
		thickness = 2.5,
		background = { "#2C2264", "#101426" },
		plate = "#17143A",
		accent = "#9C84F5",
		gems = 3,
		ornaments = true,
		glow = "#7858EB",
		foil = false,
	},
	Legendary = {
		border = { "#FFF4D1", "#F0BF61", "#A8711C" },
		thickness = 3,
		background = { "#3D2E52", "#101426" },
		plate = "#1E1830",
		accent = "#F0BF61",
		gems = 4,
		ornaments = true,
		glow = "#F0BF61",
		foil = true,
	},
})

-- Variantes visuelles d'une même carte (identifiant et données inchangés).
-- Une variante peut ajouter le reflet holographique ou d'autres décorations,
-- jamais changer la rareté affichée (cadre, gemmes et libellé restent ceux de
-- la rareté réelle).
CardStyle.Variants = Freeze.deep({
	Standard = { foil = false, label = nil },
	Holo = { foil = true, label = "HOLO" }, -- édition spéciale à reflet
})

-- Classes de taille, selon la largeur réelle de la vignette (pixels logiques).
-- Compact : vignettes d'équipe ; Standard : grilles ; Large : fiche, révélation.
CardStyle.SizeClasses = Freeze.deep({
	Compact = { maxWidth = 105, showSubtitle = true, showRarityLabel = false, nameMax = 13, captionMax = 10 },
	Standard = { maxWidth = 150, showSubtitle = true, showRarityLabel = true, nameMax = 15, captionMax = 11 },
	Large = { maxWidth = math.huge, showSubtitle = true, showRarityLabel = true, nameMax = 24, captionMax = 15 },
})
CardStyle.SizeOrder = Freeze.deep({ "Compact", "Standard", "Large" })

-- Rapport largeur / hauteur de toutes les cartes.
CardStyle.AspectRatio = 112 / 158

-- Mise en page proportionnelle (fractions de la carte) : identique à toutes les
-- tailles, seules les tailles de texte maximales changent avec la classe.
CardStyle.Layout = Freeze.deep({
	art = { x = 0.07, y = 0.05, width = 0.86, height = 0.55 },
	gems = { y = 0.6, height = 0.075 }, -- à cheval sur le bas de l'illustration
	name = { y = 0.655, height = 0.1 },
	subtitle = { y = 0.755, height = 0.075 },
	footer = { y = 0.855, height = 0.08 },
})

function CardStyle.frame(rarity: string)
	return CardStyle.Frames[rarity] or CardStyle.Frames.Common
end

-- Style final d'une carte : cadre de sa rareté + variante éventuelle.
function CardStyle.resolve(rarity: string, variant: string?)
	local frame = CardStyle.frame(rarity)
	local variantSpec = CardStyle.Variants[variant or "Standard"] or CardStyle.Variants.Standard
	return {
		rarity = if CardStyle.Frames[rarity] then rarity else "Common",
		frame = frame,
		variant = if CardStyle.Variants[variant or ""] then variant else "Standard",
		foil = frame.foil or variantSpec.foil,
		variantLabel = variantSpec.label,
	}
end

function CardStyle.sizeClass(width: number): string
	for _, name in CardStyle.SizeOrder do
		if width <= CardStyle.SizeClasses[name].maxWidth then
			return name
		end
	end
	return "Large"
end

-- Luminance relative (WCAG) d'une couleur "#RRGGBB".
function CardStyle.luminance(hex: string): number
	local function channel(offset: number): number
		local value = tonumber(string.sub(hex, offset, offset + 1), 16) / 255
		return if value <= 0.03928 then value / 12.92 else ((value + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * channel(2) + 0.7152 * channel(4) + 0.0722 * channel(6)
end

-- Rapport de contraste WCAG entre deux couleurs (1 à 21).
function CardStyle.contrast(a: string, b: string): number
	local la, lb = CardStyle.luminance(a), CardStyle.luminance(b)
	local light, dark = math.max(la, lb), math.min(la, lb)
	return (light + 0.05) / (dark + 0.05)
end

return CardStyle
