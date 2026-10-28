-- Registre central des assets visuels (préparation V0.2).
--
-- Une entrée par id de carte, entièrement facultative. Tout ce qui manque utilise
-- le visuel provisoire actuel (fallback) : dégradé et initiale pour les cartes,
-- modèle en primitives (ModelFactory), mouvements génériques (BattleFx).
--
--   F001 = {
--       variant = "Holo",                     -- variante visuelle (CardStyle.Variants)
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
local CardStyle = require(script.Parent.CardStyle)

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

-- Aucun asset final pour l'instant : illustrations, modèles et animations passent
-- par le fallback. Aucun Asset ID n'est inventé : chaque champ sera rempli avec
-- l'identifiant réel obtenu à l'importation dans Roblox (voir V02_VISUAL_PIPELINE).
local Cards: { [string]: any } = {
	-- Personnage pilote V0.2 : carte premium à reflet holographique (variante
	-- d'édition, la rareté affichée reste Commune) et premier modèle 3D riggé
	-- (art/kael, importé puis mis au contrat par Dev/FighterAssetPrep). Le modèle
	-- vit dans ReplicatedStorage.Assets.Fighters (assets/Fighters/F001_Kael.rbxm) ;
	-- absent ou non conforme, le modèle provisoire est utilisé.
	-- Animations (V0.2.3) : converties depuis Blender (art/kael/kael_anim_export.py
	-- → Dev/KeyframeBuilder), validées dans Studio, publiées sur le compte du
	-- créateur ; identifiants vérifiés en rechargeant chaque animation.
	-- À ajouter quand elle existera (identifiant réel uniquement) :
	--   art = "rbxassetid://…" (illustration officielle).
	F001 = {
		variant = "Holo",
		model = "F001_Kael",
		animations = {
			Idle = "rbxassetid://139388493488767",
			Attack = "rbxassetid://85859268098888",
			Skill = "rbxassetid://138516128631569",
			Ultimate = "rbxassetid://128975789100207",
			Defend = "rbxassetid://108376040520289",
			Hit = "rbxassetid://90520511069344",
			Defeat = "rbxassetid://115751158976399",
		},
	},
}

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

-- Variante visuelle de la carte (par défaut "Standard").
function VisualAssets.variant(cardId: string): string
	local data = entry(cardId)
	return data and data.variant or "Standard"
end

-- Nom du Model à chercher dans ReplicatedStorage.Assets.Fighters (par défaut l'id).
function VisualAssets.modelName(fighterId: string): string
	local data = entry(fighterId)
	return data and data.model or fighterId
end

-- Variante allégée (LOD) d'un modèle : même dossier, même rig, nom suffixé « _LOD ».
-- Roblox ne choisit jamais lui-même ce modèle (RenderFidelity ne simplifie que le
-- maillage d'une même MeshPart) : ModelFactory le prend quand le budget d'effets
-- demande le détail bas (EffectsPolicy.modelDetail), sinon le modèle principal.
VisualAssets.LodSuffix = "_LOD"

function VisualAssets.lodModelName(fighterId: string): string
	return VisualAssets.modelName(fighterId) .. VisualAssets.LodSuffix
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
		if data.variant ~= nil and not CardStyle.Variants[data.variant] then
			fail("variante inconnue " .. tostring(data.variant))
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
