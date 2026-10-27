-- Sauvegarde et chargement avec des adaptateurs simulés (aucun accès DataStore) :
-- format, pannes, verrou de session et serveurs concurrents.
-- Plusieurs ProfileStore partageant un même MemoryAdapter simulent plusieurs
-- serveurs Roblox ; l'horloge et l'attente sont contrôlées par le test.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local TeamRules = require(ReplicatedStorage.Shared.Battle.TeamRules)
local Server = ServerScriptService.Server
local Data = Server.Data
local MemoryAdapter = require(Data.MemoryAdapter)
local ProfileStore = require(Data.ProfileStore)
local ProfileTemplate = require(Data.ProfileTemplate)
local BoosterLogic = require(Server.Logic.BoosterLogic)
local Inventory = require(Server.Logic.Inventory)

local KEY = "player_1"
local LOCK_TIMEOUT = 600

-- Monde simulé : une horloge partagée par tous les « serveurs ».
local function newWorld()
	local world = { now = 1000, adapter = MemoryAdapter.new(), sleeps = 0 }
	function world.server(jobId: string, options)
		local opts = options or {}
		return ProfileStore.new(world.adapter, {
			retries = 3,
			jobId = jobId,
			lockTimeout = LOCK_TIMEOUT,
			lockAttempts = opts.lockAttempts or 3,
			lockRetryDelay = 4,
			clock = function()
				return world.now
			end,
			sleep = function(seconds)
				world.sleeps += 1
				world.now += seconds
				if opts.onSleep then
					opts.onSleep()
				end
			end,
		})
	end
	return world
end

local function rng(seed: number)
	local state = seed
	return function(min: number, max: number): number
		state = bit32.bxor(state, bit32.lshift(state, 13))
		state = bit32.bxor(state, bit32.rshift(state, 17))
		state = bit32.bxor(state, bit32.lshift(state, 5))
		return min + state % (max - min + 1)
	end
end

return function(test, expect)
	test("nouveau joueur : profil par défaut écrit avec le verrou dès le chargement", function()
		local world = newWorld()
		local store = world.server("A")
		local session = store:load(KEY)
		expect.equal(session.mode, "Session", "adaptateur mémoire = mode test")
		expect.equal(world.adapter.writes, 1, "une écriture (profil + verrou)")
		expect.equal(world.adapter.records[KEY].lock.jobId, "A", "verrou posé")
		expect.falsy(session.dirty, "rien d'autre à écrire")
		expect.truthy(store:save(session), "sauvegarde sans modification")
		expect.equal(world.adapter.writes, 1, "aucune écriture inutile")
	end)

	test("aller-retour : les données sauvegardées sont rechargées à l'identique", function()
		local world = newWorld()
		local store = world.server("A")
		local session = store:load(KEY)
		session.data.cards.F006 = 3
		session.data.unlockedFighters.F006 = true
		session.data.boosters.FirstRift = 4
		session.data.team = { "F001", "F002", "F004", "F006", "F005" }
		session.data.stats.battlesWon = 7
		session.data.settings.reducedMotion = true
		store:markDirty(session)
		expect.truthy(store:save(session, { release = true }), "sauvegarde de départ")

		local reloaded = world.server("B"):load(KEY)
		expect.equal(#reloaded.repairs, 0, "aucune réparation")
		expect.equal(reloaded.data.cards.F006, 3, "exemplaires")
		expect.truthy(reloaded.data.unlockedFighters.F006, "déblocage")
		expect.equal(reloaded.data.boosters.FirstRift, 4, "boosters")
		expect.equal(reloaded.data.team[4], "F006", "équipe")
		expect.equal(reloaded.data.stats.battlesWon, 7, "statistiques")
		expect.equal(reloaded.data.settings.reducedMotion, true, "préférences")
		expect.equal(world.sleeps, 0, "verrou libéré : aucune attente")
	end)

	test("aucune écriture inutile", function()
		local world = newWorld()
		local store = world.server("A")
		local session = store:load(KEY)
		store:save(session)
		store:save(session)
		expect.equal(world.adapter.writes, 1, "profil inchangé : seulement l'écriture du chargement")
		store:markDirty(session)
		store:save(session)
		expect.equal(world.adapter.writes, 2, "modification : une écriture de plus")
	end)

	test("une modification pendant l'écriture reste à sauvegarder", function()
		local world = newWorld()
		local store = world.server("A")
		local session = store:load(KEY)
		store:markDirty(session)
		local original = world.adapter.update
		world.adapter.update = function(self, key, transform)
			store:markDirty(session) -- arrive pendant l'appel au stockage
			return original(self, key, transform)
		end
		store:save(session)
		expect.truthy(session.dirty, "toujours à sauvegarder")
	end)

	test("chargement : échecs passagers rattrapés, échec persistant en lecture seule", function()
		local world = newWorld()
		world.adapter.failWrites = 2
		local recovered = world.server("A"):load(KEY)
		expect.equal(recovered.mode, "Session", "rattrapé au 3e essai")

		local other = newWorld()
		other.adapter.failWrites = 3
		local failed = other.server("A"):load(KEY)
		expect.equal(failed.mode, "Unavailable", "indisponible")
		expect.truthy(failed.readonly, "lecture seule")
		expect.falsy(other.server("A"):canModify(failed), "modification refusée")
		expect.falsy(other.server("A"):save(failed, true), "sauvegarde refusée")
		expect.equal(other.adapter.writes, 0, "rien n'a été écrit")
	end)

	test("écriture en échec : le profil reste à sauvegarder", function()
		local world = newWorld()
		local store = world.server("A")
		local session = store:load(KEY)
		store:markDirty(session)
		world.adapter.failWrites = 3
		expect.falsy(store:save(session), "échec")
		expect.truthy(session.dirty, "toujours à sauvegarder")
		expect.truthy(store:canModify(session), "la session reste utilisable")
		expect.truthy(store:save(session), "réussite au tour suivant")
	end)

	test("verrou : le nouveau serveur attend la sauvegarde de départ de l'ancien", function()
		local world = newWorld()
		local serverA = world.server("A")
		local sessionA = serverA:load(KEY)
		sessionA.data.boosters.FirstRift = 9 -- progression faite sur A
		serverA:markDirty(sessionA)

		-- Le joueur rejoint B pendant que A n'a pas encore sauvegardé : A termine
		-- sa sauvegarde de départ pendant la première attente de B.
		local serverB = world.server("B", {
			onSleep = function()
				if not sessionA.closed then
					expect.truthy(serverA:save(sessionA, { release = true }), "départ de A")
				end
			end,
		})
		local sessionB = serverB:load(KEY)
		expect.equal(world.sleeps, 1, "une attente")
		expect.equal(sessionB.data.boosters.FirstRift, 9, "B charge les données finales de A")
		expect.falsy(sessionB.stolenFrom, "verrou obtenu normalement")
		expect.equal(world.adapter.records[KEY].lock.jobId, "B")

		sessionB.data.boosters.FirstRift = 3
		serverB:markDirty(sessionB)
		expect.truthy(serverB:save(sessionB), "B sauvegarde ensuite sans conflit")
	end)

	test("verrou abandonné (serveur arrêté brutalement) : repris sans attendre", function()
		local world = newWorld()
		local crashed = world.server("A")
		crashed:load(KEY)
		world.now += LOCK_TIMEOUT + 1 -- aucun renouvellement depuis
		local session = world.server("B"):load(KEY)
		expect.equal(world.sleeps, 0, "aucune attente")
		expect.truthy(world.server("B"):canModify(session), "profil modifiable")
		expect.equal(world.adapter.records[KEY].lock.jobId, "B")
	end)

	test(
		"verrou actif jamais libéré : repris à la dernière tentative, l'ancien serveur ne peut plus écrire",
		function()
			local world = newWorld()
			local serverA = world.server("A")
			local sessionA = serverA:load(KEY)
			local serverB = world.server("B", { lockAttempts = 3 })
			local sessionB = serverB:load(KEY)
			expect.equal(world.sleeps, 2, "deux attentes avant la reprise")
			expect.equal(sessionB.stolenFrom, "A", "reprise signalée")

			sessionB.data.stats.battlesWon = 5
			serverB:markDirty(sessionB)
			expect.truthy(serverB:save(sessionB), "B sauvegarde")

			-- A se réveille et tente d'écrire ses données périmées.
			sessionA.data.stats.battlesWon = 99
			serverA:markDirty(sessionA)
			local ok, reason = serverA:save(sessionA, { release = true })
			expect.falsy(ok, "A refusé")
			expect.contains(tostring(reason), "autre serveur")
			expect.truthy(sessionA.readonly, "A en lecture seule")
			expect.equal(world.adapter.records[KEY].data.stats.battlesWon, 5, "les données de B sont conservées")
			expect.equal(world.adapter.records[KEY].lock.jobId, "B", "le verrou de B est intact")
		end
	)

	test("deux serveurs ne peuvent pas détenir le verrou en même temps", function()
		local world = newWorld()
		world.server("A"):load(KEY)
		-- B n'a qu'une tentative sans forçage possible : il n'acquiert rien tant que
		-- le verrou est actif (vérifié sur la transformation elle-même).
		local serverB = world.server("B", { lockAttempts = 2 })
		local before = world.adapter.writes
		local transformCalls = 0
		local original = world.adapter.update
		world.adapter.update = function(self, key, transform)
			transformCalls += 1
			return original(self, key, transform)
		end
		serverB:load(KEY)
		expect.equal(transformCalls, 2, "une tentative refusée, puis la reprise")
		expect.equal(world.adapter.writes, before + 1, "une seule écriture : la reprise finale")
	end)

	test("défense en profondeur : verrou changé sans nouvelle révision, écriture refusée", function()
		-- Cas anormal (outil externe, écriture manuelle) : la révision seule ne suffit pas.
		local world = newWorld()
		local store = world.server("A")
		local session = store:load(KEY)
		world.adapter.records[KEY].lock = { jobId = "X", at = world.now }
		store:markDirty(session)
		expect.falsy(store:save(session), "refusé")
		expect.equal(world.adapter.records[KEY].lock.jobId, "X", "enregistrement non modifié")
	end)

	test("libération : verrou retiré, plus aucune écriture ni modification", function()
		local world = newWorld()
		local store = world.server("A")
		local session = store:load(KEY)
		expect.truthy(store:save(session, { release = true }), "libération")
		expect.equal(world.adapter.records[KEY].lock, nil, "verrou retiré")
		expect.truthy(session.closed, "session close")
		expect.falsy(store:canModify(session), "plus de modification")
		local writes = world.adapter.writes
		store:markDirty(session)
		expect.falsy(store:save(session), "écriture refusée")
		expect.equal(world.adapter.writes, writes, "rien n'a été écrit")
	end)

	test("renouvellement du verrou sans modification", function()
		local world = newWorld()
		local store = world.server("A")
		local session = store:load(KEY)
		expect.falsy(store:needsHeartbeat(session), "verrou récent")
		world.now += LOCK_TIMEOUT / 3
		expect.truthy(store:needsHeartbeat(session), "à renouveler")
		expect.truthy(store:save(session, { force = true }), "renouvelé")
		expect.equal(world.adapter.records[KEY].lock.at, world.now, "horodatage du verrou à jour")
		-- Un autre serveur doit donc encore attendre.
		world.now += LOCK_TIMEOUT - 10 -- l'attente de B (4 s) ne le rend pas encore périmé
		local sessionB = world.server("B", { lockAttempts = 2 }):load(KEY)
		expect.equal(sessionB.stolenFrom, "A", "toujours actif : B a dû attendre puis forcer")
	end)

	test("un profil d'une version plus récente n'est ni chargé ni modifié, même pour le verrou", function()
		local world = newWorld()
		local future = ProfileTemplate.create()
		future.schemaVersion = GameConfig.Save.SchemaVersion + 1
		world.adapter.records[KEY] = { revision = 5, data = future }
		local session = world.server("A"):load(KEY)
		expect.equal(session.mode, "Unavailable")
		expect.falsy(world.server("A"):save(session, true), "sauvegarde refusée")
		expect.equal(world.adapter.writes, 0, "aucune écriture")
		expect.equal(world.adapter.records[KEY].revision, 5, "enregistrement intact")
		expect.equal(world.adapter.records[KEY].lock, nil, "aucun verrou posé")
	end)

	test("un enregistrement illisible n'est jamais écrasé", function()
		local world = newWorld()
		world.adapter.records[KEY] = { revision = 3, data = "corrompu" }
		local session = world.server("A"):load(KEY)
		expect.equal(session.mode, "Unavailable")
		expect.equal(world.adapter.writes, 0, "aucune écriture")
		expect.equal(world.adapter.records[KEY].data, "corrompu", "enregistrement intact")
	end)

	test("un profil V0.1 (sans verrou) est chargé sans perte", function()
		local world = newWorld()
		local legacy = ProfileTemplate.create()
		legacy.cards.I002 = 2
		legacy.boosters.FirstRift = 3
		world.adapter.records[KEY] = { revision = 12, data = legacy, savedAt = 1 }
		local session = world.server("A"):load(KEY)
		expect.equal(#session.repairs, 0, "aucune réparation")
		expect.equal(session.data.cards.I002, 2, "cartes conservées")
		expect.equal(session.data.boosters.FirstRift, 3, "boosters conservés")
		expect.equal(session.revision, 13, "révision suivante")
		expect.equal(world.adapter.records[KEY].data.cards.I002, 2, "données stockées inchangées")
	end)

	test("un profil corrompu est réparé sans perdre les cartes valides", function()
		local world = newWorld()
		world.adapter.records[KEY] = {
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
		local session = world.server("A"):load(KEY)
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

	test("booster : ouverture et cartes enregistrées d'un bloc, jamais l'une sans l'autre", function()
		local world = newWorld()
		local store = world.server("A")
		local session = store:load(KEY)
		session.data.boosters.FirstRift = 2
		store:markDirty(session)
		store:save(session)
		local _, copiesStored = Inventory.summary(session.data)

		-- Ouverture puis panne d'écriture et arrêt brutal : rien n'est perdu ni dupliqué.
		expect.truthy(BoosterLogic.open(session.data, "FirstRift", rng(5)), "ouverture")
		store:markDirty(session)
		world.adapter.failWrites = 3
		expect.falsy(store:save(session), "écriture en échec")
		world.now += LOCK_TIMEOUT + 1 -- le serveur s'arrête sans libérer le verrou
		local afterCrash = world.server("B"):load(KEY)
		local _, copiesAfterCrash = Inventory.summary(afterCrash.data)
		expect.equal(afterCrash.data.boosters.FirstRift, 2, "booster non consommé")
		expect.equal(copiesAfterCrash, copiesStored, "aucune carte en plus")

		-- Même ouverture enregistrée normalement : booster consommé ET 5 cartes.
		local serverB = world.server("B")
		expect.truthy(BoosterLogic.open(afterCrash.data, "FirstRift", rng(5)), "ouverture sur B")
		serverB:markDirty(afterCrash)
		expect.truthy(serverB:save(afterCrash, { release = true }), "sauvegarde")
		local final = world.server("C"):load(KEY)
		local _, copiesFinal = Inventory.summary(final.data)
		expect.equal(final.data.boosters.FirstRift, 1, "un booster consommé")
		expect.equal(copiesFinal, copiesStored + 5, "exactement 5 cartes ajoutées")
	end)

	test("booster ouvert sur un serveur qui a perdu le verrou : jamais enregistré", function()
		local world = newWorld()
		local serverA = world.server("A")
		local sessionA = serverA:load(KEY)
		local boostersBefore = sessionA.data.boosters.FirstRift
		world.server("B", { lockAttempts = 1 }):load(KEY) -- B reprend le profil
		expect.truthy(BoosterLogic.open(sessionA.data, "FirstRift", rng(9)), "ouverture en mémoire sur A")
		serverA:markDirty(sessionA)
		expect.falsy(serverA:save(sessionA), "refusé")
		expect.equal(
			world.adapter.records[KEY].data.boosters.FirstRift,
			boostersBefore,
			"le booster n'est ni consommé ni dupliqué dans le stockage"
		)
	end)

	test("un adaptateur persistant active le mode DataStore", function()
		local world = newWorld()
		world.adapter.persistent = true
		expect.equal(world.server("A"):load(KEY).mode, "DataStore")
	end)
end
