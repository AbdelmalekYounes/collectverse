-- Chargement et sauvegarde des profils au-dessus d'un adaptateur de stockage
-- (DataStoreAdapter en jeu, MemoryAdapter en mode test local et dans les tests).
--
-- Enregistrement stocké : { revision = n, data = profil, savedAt = horodatage }.
-- Protections :
--  - lecture en échec (après plusieurs essais) ou profil illisible / plus récent :
--    session en lecture seule (mode "Unavailable"), rien n'est jamais réécrit ;
--  - écriture uniquement si le profil a changé (drapeau dirty) ;
--  - révision : si un autre serveur a sauvegardé entre-temps, on n'écrase pas ses
--    données plus récentes, la session passe en lecture seule ;
--  - une modification faite pendant une sauvegarde reste marquée à sauvegarder.
-- Logique pure (adaptateur, horloge et attente injectés), testée avec Lune.

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
	mode: string, -- "DataStore" | "Session" | "Unavailable"
	reason: string?,
	repairs: { string },
}

export type Options = {
	retries: number?,
	sleep: ((seconds: number) -> ())?,
	clock: (() -> number)?,
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
		mode = "Unavailable",
		reason = reason,
		repairs = {},
	}
end

function ProfileStore.load(self, key: string): Session
	local adapter = self.adapter
	local ok, record = withRetries(self, function()
		return adapter:read(key)
	end)
	if not ok then
		return unavailable(key, "lecture impossible : " .. tostring(record))
	end

	local mode = if adapter.persistent then "DataStore" else "Session"
	if record == nil then
		-- Nouveau joueur : profil par défaut, à écrire à la première sauvegarde.
		return {
			key = key,
			data = ProfileTemplate.create(),
			revision = 0,
			dirty = true,
			changes = 1,
			readonly = false,
			mode = mode,
			reason = nil,
			repairs = {},
		}
	end

	if type(record) ~= "table" or type(record.data) ~= "table" then
		return unavailable(key, "enregistrement illisible")
	end
	local migrated, data = ProfileSchema.migrate(deepCopy(record.data))
	if not migrated then
		return unavailable(key, data)
	end
	local repaired, repairs = ProfileSchema.reconcile(data)
	return {
		key = key,
		data = repaired,
		revision = if type(record.revision) == "number" then record.revision else 0,
		dirty = #repairs > 0,
		changes = if #repairs > 0 then 1 else 0,
		readonly = false,
		mode = mode,
		reason = nil,
		repairs = repairs,
	}
end

-- À appeler après toute modification de session.data.
function ProfileStore.markDirty(_self, session: Session)
	session.dirty = true
	session.changes += 1
end

-- Renvoie (true) si le profil est à jour dans le stockage, (false, raison) sinon.
function ProfileStore.save(self, session: Session, force: boolean?): (boolean, string?)
	if session.readonly then
		return false, "session en lecture seule"
	end
	if not session.dirty and not force then
		return true, nil
	end

	local expected = session.revision
	local changesAtStart = session.changes
	local snapshot = deepCopy(session.data)
	local savedAt = self.clock()
	local conflict = false

	local adapter = self.adapter
	local ok, result = withRetries(self, function()
		return adapter:update(session.key, function(old)
			local current = if type(old) == "table" and type(old.revision) == "number" then old.revision else 0
			if current ~= expected then
				conflict = true
				return nil -- annule l'écriture
			end
			conflict = false
			return { revision = expected + 1, data = snapshot, savedAt = savedAt }
		end)
	end)

	if not ok then
		return false, "écriture impossible : " .. tostring(result)
	end
	if conflict then
		session.readonly = true
		session.mode = "Unavailable"
		session.reason = "données plus récentes enregistrées par un autre serveur"
		return false, session.reason
	end
	session.revision = expected + 1
	-- Une modification arrivée pendant l'écriture reste à sauvegarder.
	session.dirty = session.changes ~= changesAtStart
	return true, nil
end

return ProfileStore
