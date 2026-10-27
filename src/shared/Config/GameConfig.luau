-- Paramètres de gameplay centralisés. Toute valeur d'équilibrage vit ici,
-- pour que le serveur, le client et les tests partagent les mêmes règles.

local Freeze = require(script.Parent.Parent.Util.Freeze)

local GameConfig = {
	Version = "0.6.1-kael",

	Team = {
		Size = 5,
		FrontSlots = 3, -- emplacements 1 à 3 : ligne avant
		BackSlots = 2, -- emplacements 4 et 5 : ligne arrière
	},

	Battle = {
		StartingEnergy = 3,
		EnergyPerTurn = 3,
		MaxEnergy = 10,
		DefendEnergyGain = 1, -- se défendre rend de l'énergie à l'équipe

		UltimateChargeMax = 100,
		ChargeOnAction = 25,
		ChargeOnDamageTaken = 10,

		GuardDamageTakenMultiplier = 0.5,
		-- Dégâts = puissance × stat du lanceur × K / (K + DÉF de la cible)
		DefenseConstant = 100,
		ElementAdvantage = 1.25,
		ElementDisadvantage = 0.85,
		MinDamage = 1,
		MaxTurns = 30,
	},

	Progression = {
		-- Combattants offerts à la création du profil (assez pour une équipe complète)
		StarterFighters = { "F001", "F002", "F003", "F004", "F005" },
		FirstLaunchBoosters = { FirstRift = 1 },
		VictoryBoosters = { FirstRift = 1 },
	},

	Save = {
		SchemaVersion = 1,
		DataStoreName = "CollectverseProfiles",
		AutosaveIntervalSeconds = 120,
		-- Verrou de session (voir ProfileStore) : un verrou non renouvelé depuis ce
		-- délai est repris sans attendre (serveur arrêté brutalement). Il est renouvelé
		-- par les sauvegardes, au plus tard tous les LockTimeoutSeconds / 3.
		LockTimeoutSeconds = 600,
		-- Face à un verrou actif : tentatives espacées, puis reprise forcée à la dernière
		-- (environ 16 s d'attente, le temps qu'un ancien serveur termine sa sauvegarde).
		LockAttempts = 5,
		LockRetryDelaySeconds = 4,
		-- Roblox limite les écritures sur une même clé (environ une toutes les 6 s).
		MinSaveIntervalSeconds = 7,
	},

	Summon = {
		DurationSeconds = 1.3,
		StaggerSeconds = 0.15,
		ReducedDurationSeconds = 0.35,
	},

	Debug = {
		RunTestsInStudio = true,
	},
}

return Freeze.deep(GameConfig)
