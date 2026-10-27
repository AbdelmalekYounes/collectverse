-- Versionnement et réparation des profils chargés.
--
-- migrate : fait passer un profil d'une version de schéma à la suivante, jusqu'à
--   la version courante. Un profil d'une version plus récente que le jeu est refusé
--   (le réécrire avec un ancien format détruirait des données).
-- reconcile : complète les champs manquants et remplace les valeurs invalides,
--   en renvoyant la liste des réparations effectuées.
-- Logique pure, testée avec Lune.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local CardCatalog = require(Shared.Catalog.CardCatalog)
local TeamRules = require(Shared.Battle.TeamRules)
local ProfileTemplate = require(script.Parent.ProfileTemplate)

local ProfileSchema = {}

ProfileSchema.CurrentVersion = GameConfig.Save.SchemaVersion

-- [version de départ] = fonction(profil) -> profil au format version + 1.
-- Exemple à suivre lors d'une évolution du format :
--   [1] = function(data) data.newField = {} return data end
ProfileSchema.Migrations = {}

function ProfileSchema.migrate(data: any): (boolean, any)
	if type(data) ~= "table" then
		return false, "Profil illisible"
	end
	local version = data.schemaVersion
	if type(version) ~= "number" or version < 1 or math.floor(version) ~= version then
		return false, "Version de schéma absente ou invalide"
	end
	if version > ProfileSchema.CurrentVersion then
		return false,
			string.format("Profil au format %d, plus récent que le jeu (%d)", version, ProfileSchema.CurrentVersion)
	end
	while version < ProfileSchema.CurrentVersion do
		local step = ProfileSchema.Migrations[version]
		if not step then
			return false, "Migration manquante depuis la version " .. version
		end
		data = step(data)
		version += 1
		data.schemaVersion = version
	end
	return true, data
end

local function isCount(value: any): boolean
	return type(value) == "number" and value >= 0 and math.floor(value) == value and value == value
end

-- Remplace ce qui est invalide, sans jamais supprimer de cartes valides.
function ProfileSchema.reconcile(data)
	local template = ProfileTemplate.create()
	local repairs = {}
	local function repair(message: string)
		table.insert(repairs, message)
	end

	for key, value in template do
		if type(value) == "table" and type(data[key]) ~= "table" then
			data[key] = value
			repair("champ " .. key .. " recréé")
		end
	end

	for id, value in data.unlockedFighters do
		if value ~= true or not CardCatalog.getFighter(id) then
			data.unlockedFighters[id] = nil
			repair("déblocage invalide retiré : " .. tostring(id))
		end
	end
	-- Un profil sans assez de combattants ne pourrait plus jouer : on rend ceux de départ.
	local unlockedCount = 0
	for _ in data.unlockedFighters do
		unlockedCount += 1
	end
	if unlockedCount < GameConfig.Team.Size then
		for _, id in GameConfig.Progression.StarterFighters do
			data.unlockedFighters[id] = true
		end
		repair("combattants de départ rétablis")
	end

	-- Les ids inconnus sont conservés (carte retirée temporairement du catalogue) ;
	-- seules les quantités invalides sont corrigées.
	for id, count in data.cards do
		if type(id) ~= "string" or not isCount(count) or count == 0 then
			data.cards[id] = nil
			repair("quantité invalide retirée : " .. tostring(id))
		end
	end
	for id in data.unlockedFighters do
		if (data.cards[id] or 0) < 1 then
			data.cards[id] = 1
			repair("exemplaire manquant ajouté : " .. id)
		end
	end

	for id, count in data.boosters do
		if type(id) ~= "string" or not isCount(count) then
			data.boosters[id] = nil
			repair("boosters invalides retirés : " .. tostring(id))
		end
	end

	for key, default in template.stats do
		if not isCount(data.stats[key]) then
			data.stats[key] = default
			repair("statistique réinitialisée : " .. key)
		end
	end

	for key, value in data.settings do
		if not ProfileTemplate.SettingKeys[key] or type(value) ~= "boolean" then
			data.settings[key] = nil
			repair("préférence invalide retirée : " .. tostring(key))
		end
	end

	if not TeamRules.validate(data.team, data.unlockedFighters) then
		local unlocked = {}
		for id in data.unlockedFighters do
			table.insert(unlocked, id)
		end
		data.team = TeamRules.suggest(unlocked)
		repair("équipe invalide remplacée")
	end

	data.schemaVersion = ProfileSchema.CurrentVersion
	return data, repairs
end

return ProfileSchema
