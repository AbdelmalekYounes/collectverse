-- Sauvegarde et chargement avec des adaptateurs simulés (aucun accès DataStore).

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local TeamRules = require(ReplicatedStorage.Shared.Battle.TeamRules)
local Data = ServerScriptService.Server.Data
local MemoryAdapter = require(Data.MemoryAdapter)
local ProfileStore = require(Data.ProfileStore)
local ProfileTemplate = require(Data.ProfileTemplate)

local KEY = "player_1"

local function newStore(adapter)
	return ProfileStore.new(adapter, { retries = 3 })
end

return function(test, expect)
	test("nouveau joueur : profil par défaut, écrit à la première sauvegarde", function()
		local adapter = MemoryAdapter.new()
		local store = newStore(adapter)
		local session = store:load(KEY)
		expect.equal(session.mode, "Session", "adaptateur mémoire = mode test")
		expect.truthy(session.dirty, "à écrire")
		expect.truthy(store:save(session), "sauvegarde")
		expect.equal(adapter.writes, 1, "une écriture")
		expect.equal(session.revision, 1, "révision")
		expect.falsy(session.dirty, "plus rien à écrire")
	end)

	test("aller-retour : les données sauvegardées sont rechargées à l'identique", function()
		local adapter = MemoryAdapter.new()
		local store = newStore(adapter)
		local session = store:load(KEY)
		session.data.cards.F006 = 3
		session.data.unlockedFighters.F006 = true
		session.data.boosters.FirstRift = 4
		session.data.team = { "F001", "F002", "F004", "F006", "F005" }
		session.data.stats.battlesWon = 7
		session.data.settings.reducedMotion = true
		store:markDirty(session)
		store:save(session)

		local reloaded = newStore(adapter):load(KEY)
		expect.equal(#reloaded.repairs, 0, "aucune réparation")
		expect.equal(reloaded.data.cards.F006, 3, "exemplaires")
		expect.truthy(reloaded.data.unlockedFighters.F006, "déblocage")
		expect.equal(reloaded.data.boosters.FirstRift, 4, "boosters")
		expect.equal(reloaded.data.team[4], "F006", "équipe")
		expect.equal(reloaded.data.stats.battlesWon, 7, "statistiques")
		expect.equal(reloaded.data.settings.reducedMotion, true, "préférences")
		expect.equal(reloaded.revision, session.revision, "révision")
	end)

	test("aucune écriture inutile", function()
		local adapter = MemoryAdapter.new()
		local store = newStore(adapter)
		local session = store:load(KEY)
		store:save(session)
		store:save(session)
		store:save(session)
		expect.equal(adapter.writes, 1, "profil inchangé : une seule écriture")
		store:markDirty(session)
		store:save(session)
		expect.equal(adapter.writes, 2, "modification : une écriture de plus")
	end)

	test("une modification pendant l'écriture reste à sauvegarder", function()
		local adapter = MemoryAdapter.new()
		local store = newStore(adapter)
		local session = store:load(KEY)
		local original = adapter.update
		adapter.update = function(self, key, transform)
			store:markDirty(session) -- arrive pendant l'appel au stockage
			return original(self, key, transform)
		end
		store:save(session)
		expect.truthy(session.dirty, "toujours à sauvegarder")
	end)

	test("lecture : échecs passagers rattrapés, échec persistant en lecture seule", function()
		local adapter = MemoryAdapter.new()
		adapter.failReads = 2
		local recovered = newStore(adapter):load(KEY)
		expect.equal(recovered.mode, "Session", "rattrapé au 3e essai")

		adapter.failReads = 3
		local failed = newStore(adapter):load(KEY)
		expect.equal(failed.mode, "Unavailable", "indisponible")
		expect.truthy(failed.readonly, "lecture seule")
		local ok = newStore(adapter):save(failed, true)
		expect.falsy(ok, "sauvegarde refusée")
		expect.equal(adapter.writes, 0, "rien n'a été écrit")
	end)

	test("écriture en échec : le profil reste à sauvegarder", function()
		local adapter = MemoryAdapter.new()
		local store = newStore(adapter)
		local session = store:load(KEY)
		adapter.failWrites = 3
		expect.falsy(store:save(session), "échec")
		expect.truthy(session.dirty, "toujours à sauvegarder")
		expect.truthy(store:save(session), "réussite au tour suivant")
	end)

	test("conflit : des données plus récentes ne sont jamais écrasées", function()
		local adapter = MemoryAdapter.new()
		local seed = newStore(adapter)
		local first = seed:load(KEY)
		seed:save(first)

		-- Deux serveurs chargent la même révision ; le premier sauvegarde.
		local serverA, serverB = newStore(adapter), newStore(adapter)
		local sessionA, sessionB = serverA:load(KEY), serverB:load(KEY)
		sessionA.data.stats.battlesWon = 10
		serverA:markDirty(sessionA)
		expect.truthy(serverA:save(sessionA), "A sauvegarde")

		sessionB.data.stats.battlesWon = 1
		serverB:markDirty(sessionB)
		expect.falsy(serverB:save(sessionB), "B refusé")
		expect.truthy(sessionB.readonly, "B en lecture seule")
		expect.equal(sessionB.mode, "Unavailable")
		expect.equal(adapter.records[KEY].data.stats.battlesWon, 10, "les données de A sont conservées")
	end)

	test("un profil d'une version plus récente n'est ni chargé ni écrasé", function()
		local adapter = MemoryAdapter.new()
		local future = ProfileTemplate.create()
		future.schemaVersion = GameConfig.Save.SchemaVersion + 1
		adapter.records[KEY] = { revision = 5, data = future }
		local session = newStore(adapter):load(KEY)
		expect.equal(session.mode, "Unavailable")
		expect.falsy(newStore(adapter):save(session, true), "sauvegarde refusée")
		expect.equal(adapter.records[KEY].revision, 5, "enregistrement intact")
	end)

	test("un profil corrompu est réparé sans perdre les cartes valides", function()
		local adapter = MemoryAdapter.new()
		adapter.records[KEY] = {
			revision = 2,
			data = {
				schemaVersion = GameConfig.Save.SchemaVersion,
				unlockedFighters = { F001 = true, F999 = true, F002 = "oui" },
				cards = { F001 = 2, I003 = 1, F003 = -4, F004 = 1.5 },
				boosters = { FirstRift = -1 },
				team = { "F001", "F001" },
				stats = { battlesWon = -3, battlesLost = "beaucoup" },
				settings = { reducedMotion = "oui", inconnu = true },
			},
		}
		local session = newStore(adapter):load(KEY)
		local data = session.data
		expect.truthy(#session.repairs > 0, "réparations signalées")
		expect.truthy(session.dirty, "réparations à sauvegarder")
		expect.equal(data.cards.F001, 2, "carte valide conservée")
		expect.equal(data.cards.I003, 1, "objet conservé")
		expect.equal(data.cards.F003 ~= -4, true, "quantité négative retirée")
		expect.falsy(data.unlockedFighters.F999, "déblocage inconnu retiré")
		expect.equal(data.boosters.FirstRift, nil, "boosters invalides retirés")
		expect.equal(data.stats.battlesWon, 0, "statistique réinitialisée")
		expect.equal(data.stats.battlesLost, 0, "statistique réinitialisée")
		expect.equal(next(data.settings), nil, "préférences invalides retirées")
		local valid, reason = TeamRules.validate(data.team, data.unlockedFighters)
		expect.truthy(valid, reason)
	end)

	test("un adaptateur persistant active le mode DataStore", function()
		local adapter = MemoryAdapter.new()
		adapter.persistent = true
		expect.equal(newStore(adapter):load(KEY).mode, "DataStore")
	end)
end
