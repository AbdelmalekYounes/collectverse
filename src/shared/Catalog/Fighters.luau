-- Définitions déclaratives des combattants.
--
-- Aucune logique de combat ici : l'AbilitySystem (jalon 2) interprète ces effets
-- de manière générique. Ajouter un combattant = ajouter une entrée, sans code.
-- Les apparences 3D sont séparées, dans Visuals/FighterVisuals.
--
-- Chaque combattant déclare quatre actions : basic, skill, ultimate, defend.
-- Vocabulaire des effets :
--   { type = "Damage", power, scaling? }            dégâts = power × stat du lanceur
--   { type = "Heal",   power, scaling? }            soin
--   { type = "Shield", power, scaling? }            bouclier absorbant
--   { type = "Status", status, duration, power? }   effet temporaire (voir Statuses)
-- scaling vaut "attack" par défaut ("defense" et "maxHp" possibles).
-- target = "Self" sur un effet le redirige vers le lanceur ; sinon il touche
-- les cibles de l'action (règles dans Targets).

return {
	{
		id = "F001",
		name = "Kael",
		title = "Lame des Braises",
		element = "Fire",
		role = "Warrior",
		rarity = "Common",
		preferredRow = "Front",
		lore = "Forgeron devenu guerrier le jour où une faille a embrasé sa ville. Sa lame garde la chaleur de cette nuit-là.",
		stats = { maxHp = 1150, attack = 135, defense = 85, speed = 100 },
		actions = {
			basic = {
				name = "Taille ardente",
				cost = 0,
				target = "SingleEnemy",
				effects = { { type = "Damage", power = 1.0 } },
			},
			skill = {
				name = "Brasier croisé",
				cost = 3,
				target = "SingleEnemy",
				effects = {
					{ type = "Damage", power = 1.5 },
					{ type = "Status", status = "Burn", duration = 2, power = 0.2 },
				},
			},
			ultimate = {
				name = "Nova des braises",
				cost = 5,
				target = "AllEnemies",
				effects = {
					{ type = "Damage", power = 1.2 },
					{ type = "Status", status = "Burn", duration = 2, power = 0.25 },
				},
			},
			defend = {
				name = "Garde incandescente",
				cost = 0,
				target = "Self",
				effects = {
					{ type = "Status", status = "Guard", duration = 1 },
					{ type = "Status", status = "AttackUp", duration = 2, power = 0.15 },
				},
			},
		},
	},
	{
		id = "F002",
		name = "Terra",
		title = "Bastion des Cimes",
		element = "Earth",
		role = "Tank",
		rarity = "Common",
		preferredRow = "Front",
		lore = "Gardienne d'un col de montagne arraché à son monde. Elle porte un bouclier taillé dans la roche de son foyer.",
		stats = { maxHp = 1600, attack = 90, defense = 140, speed = 80 },
		actions = {
			basic = {
				name = "Coup de roche",
				cost = 0,
				target = "SingleEnemy",
				effects = { { type = "Damage", power = 1.0 } },
			},
			skill = {
				name = "Rempart vivant",
				cost = 3,
				target = "AllAllies",
				effects = { { type = "Shield", power = 1.2, scaling = "defense" } },
			},
			ultimate = {
				name = "Séisme",
				cost = 5,
				target = "AllEnemies",
				effects = {
					{ type = "Damage", power = 0.9 },
					{ type = "Status", status = "DefenseDown", duration = 2, power = 0.2 },
				},
			},
			defend = {
				name = "Provocation tellurique",
				cost = 0,
				target = "Self",
				effects = {
					{ type = "Status", status = "Taunt", duration = 2 },
					{ type = "Status", status = "Guard", duration = 1 },
				},
			},
		},
	},
	{
		id = "F003",
		name = "Lyra",
		title = "Voix des Marées",
		element = "Water",
		role = "Healer",
		rarity = "Rare",
		preferredRow = "Back",
		lore = "Prêtresse d'un océan suspendu entre deux dimensions. Son chant referme les blessures comme la marée efface le sable.",
		stats = { maxHp = 1000, attack = 110, defense = 75, speed = 110 },
		actions = {
			basic = {
				name = "Onde",
				cost = 0,
				target = "SingleEnemy",
				effects = { { type = "Damage", power = 1.0 } },
			},
			skill = {
				name = "Marée apaisante",
				cost = 3,
				target = "LowestHpAlly",
				effects = {
					{ type = "Heal", power = 2.0 },
					{ type = "Status", status = "Regen", duration = 2, power = 0.3 },
				},
			},
			ultimate = {
				name = "Source éternelle",
				cost = 6,
				target = "AllAllies",
				effects = {
					{ type = "Heal", power = 1.5 },
					{ type = "Status", status = "Regen", duration = 2, power = 0.3 },
				},
			},
			defend = {
				name = "Voile d'écume",
				cost = 0,
				target = "Self",
				effects = {
					{ type = "Status", status = "Guard", duration = 1 },
					{ type = "Shield", power = 0.8 },
				},
			},
		},
	},
	{
		id = "F004",
		name = "Nox",
		title = "Murmure du Néant",
		element = "Shadow",
		role = "Assassin",
		rarity = "Epic",
		preferredRow = "Front",
		lore = "Personne ne connaît son vrai visage. On dit qu'il traverse les failles comme d'autres franchissent une porte.",
		stats = { maxHp = 950, attack = 165, defense = 65, speed = 130 },
		actions = {
			basic = {
				name = "Lame d'ombre",
				cost = 0,
				target = "SingleEnemy",
				effects = { { type = "Damage", power = 1.0 } },
			},
			skill = {
				name = "Pas de l'ombre",
				cost = 3,
				target = "SingleEnemyAny",
				effects = { { type = "Damage", power = 1.7 } },
			},
			ultimate = {
				name = "Éclipse fatale",
				cost = 5,
				target = "SingleEnemyAny",
				effects = {
					{ type = "Damage", power = 2.8 },
					{ type = "Status", status = "DefenseDown", duration = 2, power = 0.25 },
				},
			},
			defend = {
				name = "Fondu nocturne",
				cost = 0,
				target = "Self",
				effects = {
					{ type = "Status", status = "Guard", duration = 1 },
					{ type = "Status", status = "AttackUp", duration = 1, power = 0.25 },
				},
			},
		},
	},
	{
		id = "F005",
		name = "Astra",
		title = "Étoile Fulgurante",
		element = "Lightning",
		role = "Mage",
		rarity = "Rare",
		preferredRow = "Back",
		lore = "Étudiante d'une académie céleste, elle a appris à capturer la foudre des failles dans de petites sphères dociles.",
		stats = { maxHp = 900, attack = 160, defense = 60, speed = 115 },
		actions = {
			basic = {
				name = "Étincelle",
				cost = 0,
				target = "SingleEnemy",
				effects = { { type = "Damage", power = 1.0 } },
			},
			skill = {
				name = "Arc voltaïque",
				cost = 4,
				target = "SingleEnemy",
				effects = {
					{ type = "Damage", power = 1.2 },
					{ type = "Status", status = "Stun", duration = 1 },
				},
			},
			ultimate = {
				name = "Tempête céleste",
				cost = 6,
				target = "AllEnemies",
				effects = {
					{ type = "Damage", power = 1.4 },
					{ type = "Status", status = "DefenseDown", duration = 1, power = 0.15 },
				},
			},
			defend = {
				name = "Condensateur",
				cost = 0,
				target = "Self",
				effects = {
					{ type = "Status", status = "Guard", duration = 1 },
					{ type = "Shield", power = 0.6 },
				},
			},
		},
	},
	{
		id = "F006",
		name = "Oris",
		title = "Héraut de l'Aube",
		element = "Light",
		role = "Support",
		rarity = "Legendary",
		preferredRow = "Back",
		lore = "Dernier gardien d'un sanctuaire lumineux. Son halo s'intensifie à chaque allié qu'il protège.",
		stats = { maxHp = 1050, attack = 115, defense = 90, speed = 120 },
		actions = {
			basic = {
				name = "Rayon",
				cost = 0,
				target = "SingleEnemy",
				effects = { { type = "Damage", power = 1.0 } },
			},
			skill = {
				name = "Bénédiction",
				cost = 2,
				target = "AllAllies",
				effects = { { type = "Status", status = "AttackUp", duration = 2, power = 0.2 } },
			},
			ultimate = {
				name = "Aube souveraine",
				cost = 6,
				target = "AllAllies",
				effects = {
					{ type = "Shield", power = 1.2 },
					{ type = "Heal", power = 0.8 },
				},
			},
			defend = {
				name = "Halo protecteur",
				cost = 0,
				target = "Self",
				effects = {
					{ type = "Status", status = "Guard", duration = 1 },
					{ type = "Status", status = "Regen", duration = 2, power = 0.25 },
				},
			},
		},
	},
}
