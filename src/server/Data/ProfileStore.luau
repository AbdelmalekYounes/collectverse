-- Chargement et sauvegarde des profils au-dessus d'un adaptateur de stockage
-- (DataStoreAdapter en jeu, MemoryAdapter en mode test local et dans les tests).
--
-- Enregistrement stocké :
--   { revision = n, data = profil, savedAt = horodatage, lock = { jobId, at } ou nil }
-- Les enregistrements V0.1 (sans champ lock) restent lisibles tels quels.
--
-- Verrou de session (un seul serveur écrit un profil à la fois) :
--  - le chargement acquiert le verrou dans la même transaction UpdateAsync que la
--    lecture : deux serveurs ne peuvent pas le prendre en même temps ;
--  - si un autre serveur le détient, on réessaie : c'est le cas normal d'un joueur
--    qui change de serveur pendant que l'ancien termine sa sauvegarde de départ.
--    Au dernier essai, le verrou est repris de force (serveur arrêté brutalement) ;
--    un verrou non renouvelé depuis lockTimeout secondes est repris aussitôt ;
--  - chaque sauvegarde renouvelle le verrou ; celle du départ le libère ;
--  - une sauvegarde n'aboutit que si la révision ET le verrou sont toujours les
--    nôtres. Sinon (verrou repris par un autre serveur), la session passe en
--    lecture seule et n'écrase jamais les données plus récentes.
--
-- Autres protections :
--  - enregistrement illisible ou d'un format plus récent : session en lecture seule,
--    l'enregistrement n'est jamais modifié (pas même pour poser le verrou) ;
--  - écriture uniquement si le profil a changé (drapeau dirty), sauf renouvellement
--    du verrou ou libération ;
--  - une modification faite pendant une sauvegarde reste marquée à sauvegarder.
-- Logique pure (adaptateur, horloge, attente et identifiant de serveur injectés),
-- testée avec Lune.

local ProfileTemplate = require(script.Parent.ProfileTemplate)
local ProfileSchema = require(script.Parent.ProfileSchema)

local ProfileStore = {}
ProfileStore.__index = ProfileStore

export type Adapter = {
	persistent: boolean,
	read: (self: any, key: string) -> (boolean, any),
	update: (self: any, key: string, transform: (old: any) -> any) -> (boolean, any),
}

export type Session = {
	key: string,
	data: any,
	revision: number,
	dirty: boolean,
	changes: number,
	readonly: boolean,
	closed: boolean, -- verrou libéré : plus aucune modification ni écriture
	mode: string, -- "DataStore" | "Session" | "Unavailable"
	reason: string?,
	repairs: { string },
	lockAt: number, -- dernier renouvellement du verrou (horloge du store)
	stolenFrom: string?, -- serveur dont le verrou a été repris, le cas échéant
}

export type Options = {
	retries: number?,
	sleep: ((seconds: number) -> ())?,
	clock: (() -> number)?,
	jobId: string?, -- identifiant unique de ce serveur
	lockTimeout: number?, -- secondes sans renouvellement avant qu'un verrou soit considéré abandonné
	lockAttempts: number?, -- tentatives de chargement face à un verrou actif (la dernière force)
	lockRetryDelay: number?, -- attente entre deux tentatives, en secondes
}

export type SaveOptions = {
	force: boolean?, -- écrire même sans modification (renouvellement du verrou)
	release: boolean?, -- libérer le verrou (départ du joueur, arrêt du serveur)
}

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

function ProfileStore.new(adapter: Adapter, options: Options?)
	local opts = options or {}
	return setmetatable({
		adapter = adapter,
		retries = opts.retries or 3,
		sleep = opts.sleep or function() end,
		clock = opts.clock or os.time,
		jobId = opts.jobId or "local",
		lockTimeout = opts.lockTimeout or 600,
		lockAttempts = math.max(1, opts.lockAttempts or 5),
		lockRetryDelay = opts.lockRetryDelay or 4,
	}, ProfileStore)
end

-- Appelle `operation` jusqu'à `retries` fois, avec une attente croissante.
local function withRetries(self, operation: () -> (boolean, any)): (boolean, any)
	local ok, result = false, nil
	for attempt = 1, self.retries do
		ok, result = operation()
		if ok then
			return true, result
		end
		if attempt < self.retries then
			self.sleep(attempt)
		end
	end
	return false, result
end

local function unavailable(key: string, reason: string): Session
	return {
		key = key,
		data = ProfileTemplate.create(),
		revision = 0,
		dirty = false,
		changes = 0,
		readonly = true,
		closed = false,
		mode = "Unavailable",
		reason = reason,
		repairs = {},
		lockAt = 0,
		stolenFrom = nil,
	}
end

local function revisionOf(record: any): number
	return if type(record) == "table" and type(record.revision) == "number" then record.revision else 0
end

-- Le verrou est-il détenu par un autre serveur, et encore renouvelé récemment ?
local function heldByOther(self, lock: any, now: number): boolean
	if type(lock) ~= "table" or lock.jobId == self.jobId then
		return false
	end
	return type(lock.at) == "number" and now - lock.at < self.lockTimeout
end

local function ownLock(self, now: number)
	return { jobId = self.jobId, at = now }
end

-- Charge un profil et acquiert son verrou. Ne lève jamais d'erreur : en cas
-- d'échec, la session renvoyée est en lecture seule (mode "Unavailable").
function ProfileStore.load(self, key: string): Session
	local adapter = self.adapter
	local mode = if adapter.persistent then "DataStore" else "Session"

	for attempt = 1, self.lockAttempts do
		local force = attempt == self.lockAttempts
		-- Résultat de la dernière exécution de la transformation (UpdateAsync peut
		-- l'appeler plusieurs fois : chaque appel réinitialise ces valeurs).
		local outcome, reason, data, revision, lockAt, stolenFrom

		local ok, failure = withRetries(self, function()
			return adapter:update(key, function(old)
				local now = self.clock()
				outcome, reason, data, revision, lockAt, stolenFrom = nil, nil, nil, nil, nil, nil

				if old == nil then
					-- Nouveau joueur : le profil par défaut est écrit avec le verrou.
					outcome, data, revision, lockAt = "acquired", ProfileTemplate.create(), 1, now
					return { revision = 1, data = deepCopy(data), savedAt = now, lock = ownLock(self, now) }
				end
				if type(old) ~= "table" or type(old.data) ~= "table" then
					outcome, reason = "invalid", "enregistrement illisible"
					return nil
				end
				local migrated, result = ProfileSchema.migrate(deepCopy(old.data))
				if not migrated then
					outcome, reason = "invalid", result
					return nil -- format inconnu ou plus récent : on n'y touche pas
				end
				if heldByOther(self, old.lock, now) then
					if not force then
						outcome, reason = "locked", tostring(old.lock.jobId)
						return nil
					end
					stolenFrom = tostring(old.lock.jobId)
				end

				outcome, data, revision, lockAt = "acquired", result, revisionOf(old) + 1, now
				-- Les données stockées sont conservées telles quelles : seule la
				-- première sauvegarde écrira la version migrée et réparée.
				return { revision = revision, data = old.data, savedAt = old.savedAt, lock = ownLock(self, now) }
			end)
		end)

		if not ok then
			return unavailable(key, "lecture impossible : " .. tostring(failure))
		end
		if outcome == "invalid" then
			return unavailable(key, reason)
		end
		if outcome == "acquired" then
			local repaired, repairs = ProfileSchema.reconcile(data)
			return {
				key = key,
				data = repaired,
				revision = revision,
				dirty = #repairs > 0,
				changes = if #repairs > 0 then 1 else 0,
				readonly = false,
				closed = false,
				mode = mode,
				reason = nil,
				repairs = repairs,
				lockAt = lockAt,
				stolenFrom = stolenFrom,
			}
		end
		-- Verrou détenu ailleurs : on laisse à l'autre serveur le temps de le libérer.
		if attempt < self.lockAttempts then
			self.sleep(self.lockRetryDelay)
		end
	end

	-- Inatteignable : la dernière tentative force le verrou.
	return unavailable(key, "verrou de session non acquis")
end

-- Une session peut-elle encore être modifiée (et donc sauvegardée) ?
function ProfileStore.canModify(_self, session: Session): boolean
	return not session.readonly and not session.closed
end

-- À appeler après toute modification de session.data.
function ProfileStore.markDirty(_self, session: Session)
	session.dirty = true
	session.changes += 1
end

-- Le verrou doit-il être renouvelé (même sans modification) ?
function ProfileStore.needsHeartbeat(self, session: Session): boolean
	return self:canModify(session) and self.clock() - session.lockAt >= self.lockTimeout / 3
end

-- Renvoie (true) si le profil est à jour dans le stockage, (false, raison) sinon.
-- Compatibilité : save(session, true) équivaut à save(session, { force = true }).
function ProfileStore.save(self, session: Session, options: (SaveOptions | boolean)?): (boolean, string?)
	local opts: SaveOptions = if type(options) == "table" then options else { force = options == true }
	if session.readonly or session.closed then
		return false, "session en lecture seule"
	end
	if not session.dirty and not opts.force and not opts.release then
		return true, nil
	end

	local expected = session.revision
	local changesAtStart = session.changes
	local snapshot = deepCopy(session.data)
	local now = self.clock()
	local conflict = false

	local adapter = self.adapter
	local ok, result = withRetries(self, function()
		return adapter:update(session.key, function(old)
			local lock = if type(old) == "table" then old.lock else nil
			if revisionOf(old) ~= expected or type(lock) ~= "table" or lock.jobId ~= self.jobId then
				conflict = true
				return nil -- annule l'écriture : un autre serveur a repris le profil
			end
			conflict = false
			return {
				revision = expected + 1,
				data = snapshot,
				savedAt = now,
				lock = if opts.release then nil else ownLock(self, now),
			}
		end)
	end)

	if not ok then
		return false, "écriture impossible : " .. tostring(result)
	end
	if conflict then
		session.readonly = true
		session.mode = "Unavailable"
		session.reason = "profil repris par un autre serveur"
		return false, session.reason
	end
	session.revision = expected + 1
	session.lockAt = now
	-- Une modification arrivée pendant l'écriture reste à sauvegarder.
	session.dirty = session.changes ~= changesAtStart
	if opts.release then
		session.closed = true
	end
	return true, nil
end

return ProfileStore
