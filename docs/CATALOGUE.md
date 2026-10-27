# Catalogue et règles de données

## Combattants

| ID | Nom | Élément | Rôle | Rareté | Ligne | PV | ATQ | DÉF | VIT |
|---|---|---|---|---|---|---|---|---|---|
| F001 | Kael | Feu | Guerrier | Commune | Avant | 1150 | 135 | 85 | 100 |
| F002 | Terra | Terre | Tank | Commune | Avant | 1600 | 90 | 140 | 80 |
| F003 | Lyra | Eau | Soigneur | Rare | Arrière | 1000 | 110 | 75 | 110 |
| F004 | Nox | Ombre | Assassin | Épique | Avant | 950 | 165 | 65 | 130 |
| F005 | Astra | Foudre | Mage | Rare | Arrière | 900 | 160 | 60 | 115 |
| F006 | Oris | Lumière | Support | Légendaire | Arrière | 1050 | 115 | 90 | 120 |

Combattants de départ : F001 à F005. Oris s'obtient uniquement en booster.

Chaque combattant déclare quatre actions : `basic` (gratuite), `skill`, `ultimate` (énergie + jauge personnelle pleine) et `defend` (gratuite, rend 1 énergie).

## Objets

| ID | Nom | Rareté | Usage prévu |
|---|---|---|---|
| I001 | Cristal fracturé | Commune | Matériau d'amélioration |
| I002 | Boussole dimensionnelle | Rare | Rencontres spéciales |
| I003 | Lanterne des Échos | Épique | Récits des Échos |
| I004 | Sceau ancestral | Légendaire | Récompenses rares |

Les objets sont collectionnables uniquement dans ce prototype.

## Vocabulaire des effets

| Effet | Champs | Sens |
|---|---|---|
| `Damage` | `power`, `scaling?` | Dégâts = power × stat du lanceur, réduits par la DÉF de la cible |
| `Heal` | `power`, `scaling?` | Soin |
| `Shield` | `power`, `scaling?` | Bouclier qui absorbe les dégâts |
| `Status` | `status`, `duration`, `power?` | Effet temporaire |

- `scaling` : `attack` (par défaut), `defense` ou `maxHp`.
- `target = "Self"` sur un effet le redirige vers le lanceur. Sinon, l'effet touche les cibles de l'action.

Statuts : `Burn` et `Regen` (par tour, en % de l'ATQ du lanceur), `Guard` (dégâts subis −50 %), `Taunt` (force le ciblage), `AttackUp`, `DefenseDown`, `Stun` (action perdue).

Ciblage des actions :

| Règle | Effet |
|---|---|
| `SingleEnemy` | Un ennemi ; la ligne avant protège la ligne arrière |
| `SingleEnemyAny` | Un ennemi au choix, même en ligne arrière (assassins) |
| `AllEnemies` | Tous les ennemis |
| `Self` | Le lanceur |
| `SingleAlly` | Un allié choisi |
| `LowestHpAlly` | L'allié avec le plus faible pourcentage de PV (choisi automatiquement) |
| `AllAllies` | Tous les alliés |

Le validateur impose par exemple que des dégâts visent des ennemis, que soins et boucliers ne visent pas d'ennemi, et qu'une action défensive ne vise pas l'adversaire.

## Règles de combat (jalon 2)

Les constantes sont dans `GameConfig.Battle`. Le combat ne comporte aucun hasard : un même plan donne toujours le même résultat.

- **Dégâts** : `power × stat × 100 / (100 + DÉF effective)`, multipliés par l'élément puis par la Garde (×0,5). Le résultat est arrondi, avec un minimum de 1.
- **Modificateurs** : Attaque renforcée et Armure brisée modifient l'ATQ et la DÉF effectives.
- **Éléments** : Eau > Feu > Terre > Foudre > Eau (×1,25 / ×0,85). Ombre et Lumière ont l'avantage l'une sur l'autre (×1,25).
- **Bouclier** : absorbe les dégâts avant les PV ; il se cumule, plafonné aux PV max.
- **Soins** : plafonnés aux PV max.
- **Énergie d'équipe** :
  - 3 au départ, +3 par tour, plafond de 10 ;
  - +1 quand un combattant se défend ;
  - dépensée au moment où l'action s'exécute.
- **Jauge d'ultime** : +25 par action, +10 par coup reçu ; elle doit être pleine (100) pour lancer l'ultime, puis retombe à 0.
- **Tour** :
  1. Le joueur donne un ordre par combattant ; sans ordre, le combattant fait une attaque normale.
  2. Les actions s'exécutent par vitesse décroissante. À égalité, le camp allié agit d'abord, puis le plus petit emplacement.
  3. En fin de tour : Brûlure et Régénération, puis les durées diminuent, puis l'énergie augmente.
- **Ciblage** :
  - La ligne avant protège la ligne arrière tant qu'il y reste un combattant debout.
  - La Provocation redirige toute attaque ciblée vers le provocateur.
  - Si la cible choisie est tombée avant l'action, celle-ci vise la première cible valide.
- **Étourdissement** : le combattant perd sa prochaine action, même si l'étourdissement est appliqué en cours de tour, après son action.
- **Fin du combat** : dès qu'un camp n'a plus de combattant debout ; égalité après 30 tours.

## Rencontres PvE

| ID | Nom | Échos (avant / arrière) | Statistiques |
|---|---|---|---|
| RiftEcho1 | Faille instable | Terra, Kael, Nox / Lyra, Astra | 85 % |

Récompense de victoire : 1 booster First Rift (`GameConfig.Progression.VictoryBoosters`).

## Booster First Rift : probabilités exactes

Cinq cartes par booster. Les emplacements 1 à 4 utilisent la table standard. L'emplacement 5 garantit une carte Rare ou supérieure. Pour chaque emplacement, le jeu tire d'abord la rareté, puis une carte uniformément parmi les cartes de cette rareté.

| Rareté | Cartes du pool | Emplacements 1-4 | Par carte | Emplacement 5 | Par carte |
|---|---|---|---|---|---|
| Commune | Kael, Terra, Cristal fracturé | 70 % | 23,33 % | — | — |
| Rare | Lyra, Astra, Boussole dimensionnelle | 23 % | 7,67 % | 80 % | 26,67 % |
| Épique | Nox, Lanterne des Échos | 6 % | 3 % | 17 % | 8,5 % |
| Légendaire | Oris, Sceau ancestral | 1 % | 0,5 % | 3 % | 1,5 % |

Conséquences par booster :

- Au moins une carte Légendaire : 1 − 0,99⁴ × 0,97 ≈ **6,82 %**.
- Au moins un Oris : 1 − 0,995⁴ × 0,985 ≈ **3,46 %**.

Les boosters sont gratuits et s'obtiennent en jeu (premier lancement, victoires PvE). Le jeu n'utilise ni Robux, ni mise, ni vente de tirages. Les taux affichés à l'écran sont calculés à partir de la même configuration que le tirage (`BoosterOdds`).
