-- Mise en page du combat selon la taille de l'écran. Calculs purs (sans types
-- Roblox), testés avec Lune ; BattleCamera et UnitPlate les appliquent, au début
-- du combat puis à chaque changement de résolution ou d'orientation.

local BattleLayout = {}

-- L'arène (Arena : ROW_X, ROW_Z, caméra) est réglée pour ce champ vertical en 16:9.
BattleLayout.BaseFieldOfView = 42
BattleLayout.DesignAspect = 16 / 9
local MAX_FIELD_OF_VIEW = 110

-- Champ de vision vertical (degrés) pour un rapport largeur / hauteur donné.
-- Plus large que 16:9 : champ de base (l'arène tient déjà en largeur).
-- Plus étroit (4:3, portrait) : on élargit le champ vertical pour conserver le
-- champ horizontal conçu, sinon les combattants des bords sortent de l'écran.
function BattleLayout.fieldOfView(aspect: number): number
	if aspect ~= aspect or aspect <= 0 then
		return BattleLayout.BaseFieldOfView
	end
	if aspect >= BattleLayout.DesignAspect then
		return BattleLayout.BaseFieldOfView
	end
	local halfBase = math.rad(BattleLayout.BaseFieldOfView / 2)
	local halfHorizontal = math.atan(math.tan(halfBase) * BattleLayout.DesignAspect)
	local vertical = 2 * math.deg(math.atan(math.tan(halfHorizontal) / aspect))
	return math.min(vertical, MAX_FIELD_OF_VIEW)
end

-- Plaques : taille en studs (suit la perspective) + marge en pixels pour la
-- lisibilité. La marge est prévue pour un écran d'au moins MARGIN_REFERENCE_HEIGHT
-- pixels de haut ; sur un écran plus petit (téléphone), la scène 3D rétrécit mais
-- pas les pixels : la marge est réduite d'autant, sinon les plaques se chevauchent.
local PLATE_STUDS = { width = 4.4, height = 2 }
local PLATE_PIXELS = { width = 36, height = 10 }
local MARGIN_REFERENCE_HEIGHT = 800
local MARGIN_MIN_FACTOR = 0.35

function BattleLayout.plateMarginFactor(viewportHeight: number): number
	if viewportHeight ~= viewportHeight then
		return 1
	end
	return math.clamp(viewportHeight / MARGIN_REFERENCE_HEIGHT, MARGIN_MIN_FACTOR, 1)
end

-- Renvoie (studs en largeur, pixels en largeur, studs en hauteur, pixels en hauteur).
function BattleLayout.plateSize(viewportHeight: number): (number, number, number, number)
	local factor = BattleLayout.plateMarginFactor(viewportHeight)
	return PLATE_STUDS.width,
		math.round(PLATE_PIXELS.width * factor),
		PLATE_STUDS.height,
		math.round(PLATE_PIXELS.height * factor)
end

-- Hauteur des plaques (centre, en studs au-dessus des pieds du combattant).
-- La caméra est derrière les alliés : la plaque d'un allié de la ligne avant,
-- posée au-dessus de sa tête, se projetait sur l'Écho qui lui fait face et en
-- masquait jusqu'à 41 % (V0.2.5, art/kael/anime_fantasy/plate_layout.py). Elle est
-- posée au sol, devant ses pieds. Les autres plaques restent au-dessus des têtes,
-- à une hauteur commune par ligne (le plus grand modèle prévu) : avec des modèles
-- de tailles différentes, une plaque plus haute que ses voisines chevauchait la
-- ligne arrière.
BattleLayout.PlateReferenceHeight = 7.4 -- plus grand combattant prévu (Kael Anime Fantasy : 7,38)
BattleLayout.PlateGapAbove = 2.4
BattleLayout.PlateBelowFeet = -1.3 -- plaque de 2 studs : son haut reste juste sous le sol

function BattleLayout.plateOffset(side: string, row: string, modelHeight: number): number
	if side == "Ally" and row == "Front" then
		return BattleLayout.PlateBelowFeet
	end
	local height = if modelHeight == modelHeight then modelHeight else 0
	return math.max(height, BattleLayout.PlateReferenceHeight) + BattleLayout.PlateGapAbove
end

return BattleLayout
