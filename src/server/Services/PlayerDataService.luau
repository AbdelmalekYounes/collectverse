-- Profils des joueurs, détenus et sauvegardés par le serveur.
--
-- Au démarrage, DataStoreAdapter.probe vérifie que les DataStores sont utilisables.
-- Sinon (place non publiée, accès API désactivé dans Studio…), le serveur passe en
-- mode test local : MemoryAdapter, rien n'est persisté, et le joueur en est averti
-- (persistence = "Session"). Si le chargement d'un profil échoue, la session est
-- en lecture seule (persistence = "Unavailable") pour ne jamais écraser ses données.
--
-- Sauvegardes : périodiques si le profil a changé, au départ du joueur et à
-- l'arrêt du serveur. Une seule sauvegarde à la fois par joueur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Net.Remotes)

local Server = script.Parent.Parent
local DataStoreAdapter = require(Server.Data.DataStoreAdapter)
local MemoryAdapter = require(Server.Data.MemoryAdapter)
local ProfileStore = require(Server.Data.ProfileStore)
local ProfileTemplate = require(Server.Data.ProfileTemplate)
local RemoteGuard = require(Server.Net.RemoteGuard)

local PlayerDataService = {}

local SHUTDOWN_TIMEOUT = 25

local store
local sessions: { [Player]: any } = {}
local savingCount = 0
local profileUpdated: RemoteEvent

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

function PlayerDataService.getProfile(player: Player)
	local session = sessions[player]
	return session and session.data
end

-- Vue envoyée au client : une copie, jamais la table du serveur.
local function clientView(session)
	local view = deepCopy(session.data)
	view.persistence = session.mode
	return view
end

local function notify(player: Player)
	local session = sessions[player]
	if session and player.Parent then
		profileUpdated:FireClient(player, clientView(session))
	end
end

-- Point unique de modification d'un profil. Le mutateur peut renvoyer false
-- pour signaler qu'il n'a rien changé (pas de sauvegarde ni de notification).
function PlayerDataService.update(player: Player, mutator: (profile: any) -> boolean?): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	if mutator(session.data) == false then
		return false
	end
	store:markDirty(session)
	notify(player)
	return true
end

-- Sauvegarde sérialisée : attend la fin d'une sauvegarde déjà en cours pour ce profil.
local function saveSession(session, label: string)
	while session.saving do
		task.wait()
	end
	session.saving = true
	savingCount += 1
	local ok, reason = store:save(session)
	savingCount -= 1
	session.saving = false
	if not ok and session.mode ~= "Unavailable" then
		warn(string.format("[Collectverse] Sauvegarde %s échouée (%s) : %s", label, session.key, tostring(reason)))
	elseif not ok then
		warn(string.format("[Collectverse] Sauvegarde ignorée (%s) : %s", session.key, tostring(reason)))
	end
	return ok
end

local function onPlayerAdded(player: Player)
	if sessions[player] then
		return
	end
	local session = store:load(keyFor(player))
	if not player.Parent then
		return -- parti pendant le chargement : rien n'a été modifié
	end
	sessions[player] = session
	if session.mode == "Unavailable" then
		warn(string.format("[Collectverse] Profil de %s en lecture seule : %s", player.Name, tostring(session.reason)))
	end
	for _, repair in session.repairs do
		warn(string.format("[Collectverse] Profil de %s réparé : %s", player.Name, repair))
	end
	notify(player)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	saveSession(session, "de départ")
	sessions[player] = nil
end

local function setSettings(player: Player, settings: any)
	if type(settings) ~= "table" then
		return { ok = false, reason = "Préférences invalides" }
	end
	local clean = {}
	local count = 0
	for key, value in settings do
		count += 1
		if count > 8 or not ProfileTemplate.SettingKeys[key] or type(value) ~= "boolean" then
			return { ok = false, reason = "Préférences invalides" }
		end
		clean[key] = value
	end
	local updated = PlayerDataService.update(player, function(profile)
		local changed = false
		for key, value in clean do
			if profile.settings[key] ~= value then
				profile.settings[key] = value
				changed = true
			end
		end
		return changed
	end)
	return { ok = true, changed = updated }
end

function PlayerDataService.start()
	profileUpdated = Remotes.getEvent("ProfileUpdated")

	local adapter, reason = DataStoreAdapter.probe(GameConfig.Save.DataStoreName)
	if not adapter then
		adapter = MemoryAdapter.new()
		warn(
			"[Collectverse] MODE TEST LOCAL : DataStore indisponible ("
				.. tostring(reason)
				.. "). Les profils ne sont PAS sauvegardés."
		)
	else
		print("[Collectverse] Sauvegarde DataStore active")
	end
	store = ProfileStore.new(adapter, { retries = 3, sleep = task.wait })

	RemoteGuard.bindFunction(
		Remotes.getFunction("GetProfile"),
		{ maxRequests = 10, windowSeconds = 10 },
		function(player)
			local session = sessions[player]
			if not session then
				return { ok = false, reason = "Profil en cours de chargement" }
			end
			return { ok = true, profile = clientView(session) }
		end
	)
	RemoteGuard.bindFunction(Remotes.getFunction("SetSettings"), { maxRequests = 10, windowSeconds = 10 }, setSettings)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Sauvegarde périodique des seuls profils modifiés
	task.spawn(function()
		while true do
			task.wait(GameConfig.Save.AutosaveIntervalSeconds)
			for _, session in sessions do
				if session.dirty and not session.readonly then
					task.spawn(saveSession, session, "périodique")
				end
			end
		end
	end)

	game:BindToClose(function()
		for player, session in sessions do
			task.spawn(function()
				saveSession(session, "d'arrêt")
				sessions[player] = nil
			end)
		end
		local started = os.clock()
		task.wait()
		while savingCount > 0 and os.clock() - started < SHUTDOWN_TIMEOUT do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService
