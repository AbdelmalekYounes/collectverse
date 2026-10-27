-- Outils de vérification manuelle, actifs UNIQUEMENT dans Roblox Studio
-- (RunService:IsStudio() est toujours faux sur un serveur publié).
--
-- Depuis la barre de commande, contexte Serveur, pendant un Play :
--   game.Players.<Nom>:SetAttribute("DebugGrantBoosters", 3)
--       crédite 3 boosters First Rift (1 à 20) ;
--   game.Players.<Nom>:SetAttribute("DebugNextBooster", "F001,F002,F003,I001,F006")
--       le prochain booster ouvert donne exactement ces cartes, via la fixture
--       de test BoosterFixtures (vrais poids de production, tirage impossible refusé).
-- Chaque attribut est consommé puis remis à nil. Rien n'est modifié dans les taux.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Boosters = require(ReplicatedStorage.Shared.Catalog.Boosters)

local Services = script.Parent.Parent.Services
local PlayerDataService = require(Services.PlayerDataService)
local BoosterService = require(Services.BoosterService)

local StudioDebug = {}

local MAX_GRANT = 20

local function grantBoosters(player: Player, amount: any)
	if type(amount) ~= "number" or amount < 1 or amount > MAX_GRANT or math.floor(amount) ~= amount then
		warn("[StudioDebug] DebugGrantBoosters attend un entier de 1 à " .. MAX_GRANT)
		return
	end
	local ok = PlayerDataService.update(player, function(profile)
		profile.boosters.FirstRift = (profile.boosters.FirstRift or 0) + amount
	end)
	print(string.format("[StudioDebug] %d booster(s) crédité(s) à %s : %s", amount, player.Name, tostring(ok)))
end

local function scriptNextBooster(player: Player, list: any)
	if type(list) ~= "string" then
		return
	end
	local tests = ServerScriptService:FindFirstChild("Tests")
	local fixtures = tests and tests:FindFirstChild("Fixtures")
	local module = fixtures and fixtures:FindFirstChild("BoosterFixtures")
	if not module then
		warn("[StudioDebug] Fixture BoosterFixtures introuvable")
		return
	end
	local ids = string.split(list, ",")
	for index, id in ids do
		ids[index] = string.gsub(id, "%s", "")
	end
	local ok, rng = pcall(require(module :: ModuleScript).scripted, Boosters.FirstRift, ids)
	if not ok then
		warn("[StudioDebug] Tirage refusé : " .. tostring(rng))
		return
	end
	BoosterService.setNextRoll(player, rng)
	print(string.format("[StudioDebug] Prochain booster de %s : %s", player.Name, table.concat(ids, ", ")))
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("DebugGrantBoosters"):Connect(function()
		local value = player:GetAttribute("DebugGrantBoosters")
		if value ~= nil then
			player:SetAttribute("DebugGrantBoosters", nil)
			grantBoosters(player, value)
		end
	end)
	player:GetAttributeChangedSignal("DebugNextBooster"):Connect(function()
		local value = player:GetAttribute("DebugNextBooster")
		if value ~= nil then
			player:SetAttribute("DebugNextBooster", nil)
			scriptNextBooster(player, value)
		end
	end)
end

function StudioDebug.start()
	if not RunService:IsStudio() then
		return
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	print("[StudioDebug] Outils de test Studio actifs (DebugGrantBoosters, DebugNextBooster)")
end

return StudioDebug
