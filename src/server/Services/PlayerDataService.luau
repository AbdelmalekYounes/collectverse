-- Profils des joueurs, détenus et sauvegardés par le serveur.
--
-- Au démarrage, DataStoreAdapter.probe vérifie que les DataStores sont utilisables.
-- Sinon (place non publiée, accès API désactivé dans Studio…), le serveur passe en
-- mode test local : MemoryAdapter, rien n'est persisté, et le joueur en est averti
-- (persistence = "Session"). Si le chargement d'un profil échoue, la session est
-- en lecture seule (persistence = "Unavailable") pour ne jamais écraser ses données.
--
-- Verrou de session (voir ProfileStore) : un profil n'est écrit que par le serveur
-- qui l'a chargé. Une session en lecture seule refuse toute modification : le
-- joueur ne voit jamais une progression (booster, récompense) qui ne serait pas
-- enregistrée.
--
-- Sauvegardes, une seule à la fois par joueur :
--  - périodiques si le profil a changé, ou pour renouveler le verrou ;
--  - rapides après un changement important (ouverture de booster, récompense),
--    au plus une toutes les MinSaveIntervalSeconds (limite d'écriture par clé) ;
--  - au départ du joueur et à l'arrêt du serveur, en libérant le verrou.

local HttpService = game:GetService("HttpService")
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
-- Attente maximale d'une sauvegarde de départ encore en cours sur ce serveur
-- quand le même joueur revient aussitôt.
local REJOIN_WAIT = 30

local store
local sessions: { [Player]: any } = {}
local releasing: { [string]: boolean } = {} -- clés dont la sauvegarde de départ est en cours
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

-- Le profil peut-il être modifié ? Faux s'il est en lecture seule, en cours de
-- départ, ou pas encore chargé. Les services l'utilisent pour refuser une action
-- avec un message clair plutôt que de l'appliquer sans pouvoir l'enregistrer.
function PlayerDataService.canModify(player: Player): (boolean, string?)
	local session = sessions[player]
	if not session then
		return false, "Profil en cours de chargement"
	end
	if session.closing or not store:canModify(session) then
		return false, "Sauvegarde indisponible : progression non modifiable pour cette session"
	end
	return true, nil
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

-- Sauvegarde sérialisée : attend la fin d'une sauvegarde déjà en cours pour ce profil.
local function saveSession(session, label: string, options: ProfileStore.SaveOptions?): boolean
	while session.saving do
		task.wait()
	end
	-- Verrou libéré ou perdu pendant l'attente (ex. départ puis arrêt du serveur) :
	-- plus rien à écrire, et ce n'est pas un échec.
	if not store:canModify(session) then
		return false
	end
	session.saving = true
	session.lastSaveAt = os.clock()
	savingCount += 1
	local ok, reason = store:save(session, options)
	savingCount -= 1
	session.saving = false
	if not ok then
		warn(string.format("[Collectverse] Sauvegarde %s échouée (%s) : %s", label, session.key, tostring(reason)))
	end
	return ok
end

-- Sauvegarde rapide, regroupée : au plus une écriture par intervalle minimal.
local function requestSave(session)
	if session.saveScheduled then
		return
	end
	session.saveScheduled = true
	local delay = math.max(0, (session.lastSaveAt or -math.huge) + GameConfig.Save.MinSaveIntervalSeconds - os.clock())
	task.delay(delay, function()
		session.saveScheduled = false
		if not session.closing and store:canModify(session) then
			saveSession(session, "rapide")
		end
	end)
end

export type UpdateOptions = {
	saveNow: boolean?, -- changement important : sauvegarde rapide
}

-- Point unique de modification d'un profil. Le mutateur peut renvoyer false
-- pour signaler qu'il n'a rien changé (pas de sauvegarde ni de notification).
-- Renvoie false sans appeler le mutateur si le profil n'est pas modifiable.
function PlayerDataService.update(player: Player, mutator: (profile: any) -> boolean?, options: UpdateOptions?): boolean
	if not PlayerDataService.canModify(player) then
		return false
	end
	local session = sessions[player]
	if mutator(session.data) == false then
		return false
	end
	store:markDirty(session)
	notify(player)
	if options and options.saveNow then
		requestSave(session)
	end
	return true
end

local function onPlayerAdded(player: Player)
	if sessions[player] then
		return
	end
	local key = keyFor(player)
	-- Retour immédiat sur ce même serveur : on attend la fin de la sauvegarde de
	-- départ, sinon on chargerait des données antérieures à celle-ci.
	local waitStart = os.clock()
	while releasing[key] and os.clock() - waitStart < REJOIN_WAIT do
		task.wait(0.2)
	end

	local session = store:load(key)
	-- Le chargement vient d'écrire (verrou) : compte pour la limite d'écriture par clé.
	session.lastSaveAt = os.clock()
	if not player.Parent then
		-- Parti pendant le chargement : on libère aussitôt le verrou acquis.
		if store:canModify(session) then
			saveSession(session, "de départ", { release = true })
		end
		return
	end
	sessions[player] = session
	if session.mode == "Unavailable" then
		warn(string.format("[Collectverse] Profil de %s en lecture seule : %s", player.Name, tostring(session.reason)))
	end
	if session.stolenFrom then
		warn(
			string.format(
				"[Collectverse] Verrou du profil de %s repris au serveur %s (sans réponse)",
				player.Name,
				session.stolenFrom
			)
		)
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
	session.closing = true -- plus aucune modification à partir d'ici
	local key = session.key
	releasing[key] = true
	if store:canModify(session) then
		saveSession(session, "de départ", { release = true })
	end
	releasing[key] = nil
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
	local modifiable, reason = PlayerDataService.canModify(player)
	if not modifiable then
		return { ok = false, reason = reason }
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
	-- JobId est vide en Studio : un identifiant unique par démarrage le remplace.
	local jobId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)
	local save = GameConfig.Save
	store = ProfileStore.new(adapter, {
		retries = 3,
		sleep = task.wait,
		jobId = jobId,
		lockTimeout = save.LockTimeoutSeconds,
		lockAttempts = save.LockAttempts,
		lockRetryDelay = save.LockRetryDelaySeconds,
	})

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

	-- Sauvegarde périodique : profils modifiés, et renouvellement des verrous.
	task.spawn(function()
		while true do
			task.wait(save.AutosaveIntervalSeconds)
			for _, session in sessions do
				if not session.closing and store:canModify(session) then
					if session.dirty then
						task.spawn(saveSession, session, "périodique")
					elseif store:needsHeartbeat(session) then
						task.spawn(saveSession, session, "de renouvellement", { force = true })
					end
				end
			end
		end
	end)

	game:BindToClose(function()
		for _, session in sessions do
			session.closing = true
			if store:canModify(session) then
				task.spawn(saveSession, session, "d'arrêt", { release = true })
			end
		end
		local started = os.clock()
		task.wait()
		while savingCount > 0 and os.clock() - started < SHUTDOWN_TIMEOUT do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService
