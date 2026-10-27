-- Profil joueur par défaut, versionné (schemaVersion).
-- Toute évolution du format devra incrémenter GameConfig.Save.SchemaVersion
-- et ajouter une migration au jalon 4 (PlayerDataService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local TeamRules = require(Shared.Battle.TeamRules)

local ProfileTemplate = {}

function ProfileTemplate.create()
	local progression = GameConfig.Progression
	local unlocked = {}
	local cards = {}
	for _, id in progression.StarterFighters do
		unlocked[id] = true
		cards[id] = 1
	end
	-- Copie explicite : la configuration est gelée, le profil doit rester modifiable
	-- (on ne présume pas que table.clone renvoie une copie dégelée).
	-- selene: allow(manual_table_clone)
	local boosters = {}
	for boosterId, quantity in progression.FirstLaunchBoosters do
		boosters[boosterId] = quantity
	end

	return {
		schemaVersion = GameConfig.Save.SchemaVersion,
		unlockedFighters = unlocked, -- { [fighterId] = true }
		cards = cards, -- { [cardId] = exemplaires possédés }
		boosters = boosters, -- { [boosterId] = quantité }
		team = TeamRules.suggest(progression.StarterFighters),
		stats = {
			battlesWon = 0,
			battlesLost = 0,
			battlesDrawn = 0,
			boostersOpened = 0,
		},
		-- Préférences de présentation ; seules les clés choisies par le joueur sont présentes.
		settings = {},
	}
end

-- Préférences acceptées (toutes booléennes).
ProfileTemplate.SettingKeys = { reducedMotion = true, skipSummons = true, lowEffects = true }

return ProfileTemplate
