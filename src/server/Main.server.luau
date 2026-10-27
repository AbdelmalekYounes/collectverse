-- Point d'entrée serveur.
-- Jalon 1 : validation du catalogue, ambiance et construction du Hub.
-- Les services de jeu (équipes, combat, boosters, sauvegarde) arrivent aux jalons 2 et 4.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local CatalogValidator = require(Shared.Catalog.CatalogValidator)

local World = script.Parent.World
local LightingSetup = require(World.LightingSetup)
local HubBuilder = require(World.HubBuilder)

-- Un catalogue incohérent ne doit jamais atteindre les joueurs : on s'arrête net.
local errors = CatalogValidator.validateAll()
if #errors > 0 then
	for _, message in errors do
		warn("[Collectverse] Catalogue : " .. message)
	end
	error(string.format("[Collectverse] Catalogue invalide (%d erreur(s)), démarrage interrompu", #errors))
end

LightingSetup.apply()
HubBuilder.build()

print(string.format("[Collectverse] Serveur prêt (version %s)", GameConfig.Version))
