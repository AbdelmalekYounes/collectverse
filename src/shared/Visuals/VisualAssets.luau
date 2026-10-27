-- Registre central des assets visuels (préparation V0.2).
--
-- Une entrée par id de carte, entièrement facultative. Tout ce qui manque utilise
-- le visuel provisoire actuel (fallback) : dégradé et initiale pour les cartes,
-- modèle en primitives (ModelFactory), mouvements génériques (BattleFx).
--
--   F001 = {
--       art = "rbxassetid://123456",          -- illustration de carte (ImageLabel)
--       model = "F001_Kael",                  -- Model dans ReplicatedStorage.Assets.Fighters
--       animations = {                         -- AnimationIds, joués par FighterAnimator
--           Idle = "rbxassetid://…", Attack = "rbxassetid://…", Skill = "rbxassetid://…",
--           Ultimate = "rbxassetid://…", Defend = "rbxassetid://…", Hit = "rbxassetid://…",
--           Defeat = "rbxassetid://…",
--       },
--   },
--
-- Contrat d'un modèle 3D final (vérifié par ModelFactory.validateAsset) :
--  - un Model avec une PrimaryPart ancrée, placée aux pieds, l'avant tourné vers −Z ;
--  - les autres pièces non ancrées, reliées à la PrimaryPart (soudures ou Motor6D),
--    pour que déplacer la PrimaryPart déplace tout le personnage ;
--  - pour les animations : un AnimationController (ou Humanoid) contenant un Animator.
-- Un modèle qui ne respecte pas ce contrat est ignoré (avertissement) au profit du
-- modèle provisoire.
--
-- Ce module ne fait que décrire : aucune requête réseau, utilisable par les tests.

local Freeze = require(script.Parent.Parent.Util.Freeze)

local VisualAssets = {}

-- Animations reconnues, dans l'ordre de priorité de chargement.
VisualAssets.AnimationKinds = Freeze.deep({ "Idle", "Attack", "Skill", "Ultimate", "Defend", "Hit", "Defeat" })

-- Action de combat (emplacement du moteur) → animation à jouer.
VisualAssets.ActionAnimation = Freeze.deep({
	basic = "Attack",
	skill = "Skill",
	ultimate = "Ultimate",
	defend = "Defend",
})

-- Aucun asset final pour l'instant : tout passe par le fallback.
local Cards: { [string]: any } = {}

VisualAssets.Cards = Freeze.deep(Cards)

local ASSET_PATTERN = "^rbxassetid://%d+$"

local function entry(cardId: string)
	return VisualAssets.Cards[cardId]
end

-- Illustration de la carte, ou nil (fallback : dégradé et initiale).
function VisualAssets.cardArt(cardId: string): string?
	local data = entry(cardId)
	return data and data.art
end

-- Nom du Model à chercher dans ReplicatedStorage.Assets.Fighters (par défaut l'id).
function VisualAssets.modelName(fighterId: string): string
	local data = entry(fighterId)
	return data and data.model or fighterId
end

-- AnimationId d'une animation spécifique, ou nil (fallback : mouvement générique).
function VisualAssets.animation(fighterId: string, kind: string): string?
	local data = entry(fighterId)
	return data and data.animations and data.animations[kind]
end

-- Vérifie un registre (par défaut celui du jeu) ; renvoie la liste des erreurs.
-- isKnownCard(id) -> boolean permet de signaler les entrées orphelines.
function VisualAssets.validate(isKnownCard: (string) -> boolean, cards: { [string]: any }?): { string }
	local errors = {}
	local kinds = {}
	for _, kind in VisualAssets.AnimationKinds do
		kinds[kind] = true
	end
	for id, data in cards or VisualAssets.Cards do
		local function fail(message: string)
			table.insert(errors, string.format("%s : %s", tostring(id), message))
		end
		if not isKnownCard(id) then
			fail("carte inconnue du catalogue")
		end
		if type(data) ~= "table" then
			fail("entrée invalide")
			continue
		end
		if data.art ~= nil and (type(data.art) ~= "string" or not string.match(data.art, ASSET_PATTERN)) then
			fail("illustration invalide (attendu rbxassetid://<nombre>)")
		end
		if data.model ~= nil and (type(data.model) ~= "string" or data.model == "") then
			fail("nom de modèle invalide")
		end
		if data.animations ~= nil then
			if type(data.animations) ~= "table" then
				fail("animations invalides")
			else
				for kind, animationId in data.animations do
					if not kinds[kind] then
						fail("animation inconnue " .. tostring(kind))
					elseif type(animationId) ~= "string" or not string.match(animationId, ASSET_PATTERN) then
						fail("AnimationId invalide pour " .. kind)
					end
				end
			end
		end
	end
	return errors
end

return VisualAssets
