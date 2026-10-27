-- Point d'entrée serveur.
-- Jalon 1 : validation du catalogue, ambiance et construction du Hub.
-- Jalon 2 : remotes, équipes et combats PvE. Jalon 4 : sauvegarde et boosters.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local CatalogValidator = require(Shared.Catalog.CatalogValidator)
local CardCatalog = require(Shared.Catalog.CardCatalog)
local VisualAssets = require(Shared.Visuals.VisualAssets)
local Remotes = require(Shared.Net.Remotes)

local Server = script.Parent
local LightingSetup = require(Server.World.LightingSetup)
local HubBuilder = require(Server.World.HubBuilder)
local PlayerDataService = require(Server.Services.PlayerDataService)
local TeamService = require(Server.Services.TeamService)
local BattleService = require(Server.Services.BattleService)
local BoosterService = require(Server.Services.BoosterService)
local StudioDebug = require(Server.Dev.StudioDebug)

-- Un catalogue incohérent ne doit jamais atteindre les joueurs : on s'arrête net.
local errors = CatalogValidator.validateAll()
if #errors > 0 then
	for _, message in errors do
		warn("[Collectverse] Catalogue : " .. message)
	end
	error(string.format("[Collectverse] Catalogue invalide (%d erreur(s)), démarrage interrompu", #errors))
end

-- Registre d'assets visuels : une entrée invalide n'empêche pas de jouer (le visuel
-- provisoire la remplace), mais doit être corrigée.
for _, message in
	VisualAssets.validate(function(id)
		return CardCatalog.get(id) ~= nil
	end)
do
	warn("[Collectverse] Assets visuels : " .. message)
end

Remotes.createServer()
-- PlayerDataService.start interroge le DataStore (attente possible) : les invocations
-- des clients arrivées entre-temps sont mises en file par Roblox.
PlayerDataService.start()
TeamService.start()
BattleService.start()
BoosterService.start()
StudioDebug.start() -- sans effet hors de Studio

LightingSetup.apply()
HubBuilder.build()

print(string.format("[Collectverse] Serveur prêt (version %s)", GameConfig.Version))
