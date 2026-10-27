# Livrables du prototype V0.1

Récapitulatif final de **COLLECTVERSE: Echoes of the Rift**, selon la section 13 de la spécification. Version `0.5.0-jalon5`.

> **Mise à jour 0.5.1-audit :** l'audit de stabilisation ajoute le verrou de session des sauvegardes, adapte le combat aux changements de résolution et prépare les visuels V0.2. Les tests passent à 115 (Lune) et 125 (Studio). Le détail, les risques restants et les vérifications manuelles à jour sont dans [AUDIT_V01.md](AUDIT_V01.md). Les sections ci-dessous décrivent l'état à la fin du jalon 5, sauf les limitations corrigées, signalées ci-dessous.

Le critère d'achèvement est rempli : le parcours **Lancement → Hub → Collection → Équipe → Combat → Victoire → Booster → Ouverture → Mise à jour de collection** a été joué de bout en bout dans Studio, sur une place privée publiée, avec la sauvegarde DataStore active (voir [JALONS.md](JALONS.md), jalon 5).

## 1. Projet source organisé

Projet Rojo en trois couches, plus les tests et les outils. L'arborescence détaillée est dans le [README](../README.md#architecture).

| Dossier | Destination Roblox | Rôle |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | Données, règles et logique pure, communes au client et au serveur |
| `src/server` | `ServerScriptService.Server` | Autorité : profils, combats, boosters, scène du Hub |
| `src/client` | `StarterPlayerScripts.Client` | Présentation : interfaces, mise en scène 3D, contrôleurs |
| `tests` | `ServerScriptService.Tests` | Specs exécutées en Studio (et par Lune pour la logique pure) |
| `tools` | — | Lanceur Lune, vérification statique |

Historique Git : un commit par jalon.

## 2. Configuration Rojo

- `default.project.json`, outils épinglés dans `rokit.toml` : Rojo 7.4.4, selene 0.27.1, StyLua 0.20.0, Lune 0.11.1.
- Vérifié : `rojo build -o Collectverse.rbxlx` produit une place jouable, et `rojo serve` avec le plugin Rojo 7.4.4 synchronise la place publiée de test. Au jalon 5, la synchronisation a été acceptée dans Studio, puis le jeu lancé.
- `rojo plugin install` échoue sur cette machine (« Couldn't find registry keys »). Le README indique les deux solutions de rechange.

## 3. Utilisation dans Roblox Studio

Voir le [README](../README.md) : installation, synchronisation, réglages (Lighting Future, accès API pour la sauvegarde réelle), lancement et tests.

## 4. Modules développés

| Domaine | Modules | Rôle |
|---|---|---|
| Configuration | `shared/Config/GameConfig`, `Theme` | Règles, équilibrage, progression, sauvegarde ; palette, polices, animations |
| Catalogue | `shared/Catalog/*` : `Fighters`, `Items`, `Boosters`, `Encounters`, `CardCatalog`, `CatalogValidator`, `AbilityText`, `BoosterOdds` | 6 combattants et 4 objets déclaratifs, validés au démarrage ; descriptions et taux générés depuis les données |
| Combat (logique pure) | `shared/Battle/*` : `TeamRules`, `Units`, `Targeting`, `AbilitySystem`, `BattleEngine`, `CombatAI`, `PlanSanitizer` | Équipes 5 combattants sur 2 lignes, ciblage et protection, effets génériques, résolution déterministe par vitesse, énergie commune, ultimes, IA |
| Visuels | `shared/Visuals/FighterVisuals`, `ModelFactory` | Personnages provisoires en primitives, séparés du gameplay ; remplaçables par des assets |
| Réseau | `shared/Net/Remotes`, `server/Net/RemoteGuard`, `RateLimiter` | Remotes déclarés, validation, limitation de fréquence, réponses `{ok, reason}` |
| Profils | `server/Data/ProfileTemplate`, `ProfileSchema`, `ProfileStore`, `DataStoreAdapter`, `MemoryAdapter` ; `server/Services/PlayerDataService` | Profil versionné, migration et réparation, détection de conflit, écritures seulement si modifié, mode test local signalé |
| Progression | `server/Logic/Inventory`, `BoosterLogic`, `BattleRewards` ; `server/Services/BoosterService`, `TeamService`, `BattleService` | Doublons conservés, déblocages, tirage First Rift (≥ 1 Rare garantie), booster par victoire, autorité du serveur |
| Scène | `server/World/HubBuilder`, `LightingSetup` ; `client/Controllers/HubAmbience`, `ZoneController` | Hub 3D à trois zones, animations décoratives locales |
| Interfaces | `client/Controllers/UIController`, `DataController`, `SettingsSync` ; `client/UI/*` | Navigation PC/mobile (mise à l'échelle 960 × 540), Collection, Équipe, Boosters (révélation passable), Options, HUD |
| Combat (présentation) | `client/Controllers/BattleController`, `BattleDirector`, `BattlePlanner`, `BattleReplay` ; `client/Battle/*` ; `client/UI/BattleHud`, `UnitPlate`, `BattleLog` | Arène 3D, invocations carte → personnage (~1,3 s, passables ou réduites), lecture des tours depuis les événements du serveur |

## 5. Tests exécutés et résultats

### Tests automatisés

| Exécution | Résultat |
|---|---|
| Studio (à chaque Play), version 0.5.0 | **94 réussis, 0 échec** |
| Lune hors Studio (`lune run tools/lune/run-tests`) | **87 réussis, 0 échec** (sans `ModelFactorySpec` ni `SummonSpec`, qui créent des Instances) |
| selene (`selene src tests`) | 0 erreur, 0 avertissement |
| Vérification statique (`python tools/static_check.py`) | 88 fichiers, 276 `require` résolus, aucune erreur |

À chaque jalon, des défauts ont été injectés volontairement dans le code pour vérifier que les tests les détectent, puis retirés.

Couverture des points demandés par la spécification :

| Exigence | Specs |
|---|---|
| Validité des compositions d'équipe | `TeamRulesSpec` (7) |
| Calculs des dégâts | `BattleEngineSpec` |
| Soins et boucliers | `BattleEngineSpec` |
| Consommation d'énergie | `BattleEngineSpec`, `BattlePlannerSpec` (8), `CombatAISpec` (6) |
| Résolution des tours | `BattleEngineSpec` (20 au total), `BattleReplaySpec` (2) |
| Probabilités des boosters | `RulesDataSpec` (9), `BoosterLogicSpec` (8) |
| Attribution correcte des cartes | `BoosterLogicSpec`, `ProgressionSpec` (2) |
| Refus des actions invalides | `BattleEngineSpec`, `SecuritySpec` (3), `BoosterLogicSpec` |
| Sauvegarde et chargement avec adaptateurs simulés | `ProfileStoreSpec` (10) |
| Autres | `CatalogSpec` (10), `ModelFactorySpec` (4), `SummonSpec` (3), `TextSpec` (2) |

### Vérifications manuelles réalisées dans Studio

- **Jalons 1 à 3 :**
  - Hub, statues et panneaux ;
  - Équipe (échange de places) ;
  - combat contre l'IA, avec les invocations ;
  - mise en page de l'arène, corrigée sur captures.
- **Jalon 4 :**
  - révélation d'un booster et collection en mode test local ;
  - sauvegarde DataStore réelle sur deux sessions : collection, boosters, équipe et préférences conservés.
- **Jalon 5 :**
  - parcours complet jusqu'à la victoire au tour 23, puis ouverture du booster gagné et collection passée de 6 à 7 / 10 ;
  - émulateur mobile (iPhone XR) : écrans principaux et combat ; correction des plaques de combat.

## 6. Points à vérifier manuellement

Ces points n'ont pas pu être exécutés ici :

1. **Sur un vrai téléphone** :
   - lisibilité des textes et des plaques réduites ;
   - joystick, bouton de saut et invites tactiles. Ils ne sont pas apparus dans le Device Simulator ;
   - pas de chevauchement entre la navigation et le bouton de saut.
2. **Sur un serveur Roblox publié** (pas Studio) : chargement et sauvegarde, `BindToClose` à l'arrêt du serveur.
3. **Sauvegarde périodique** (toutes les 120 s) pendant une longue session, et le cas de deux serveurs ouvrant le même profil. Les deux ne sont couverts que par des adaptateurs simulés.
4. **Déblocage d'Oris** : badge « DÉBLOQUÉ » à l'ouverture, puis Oris sélectionnable dans l'Équipe. Oris est Légendaire (1 % par emplacement) : il n'est jamais sorti pendant les tests.
5. **Défaite et abandon** : résultat affiché, aucune récompense, statistiques mises à jour. Testés en logique (Lune), pas joués dans Studio.
6. **« Tout révéler » et « Ouvrir un autre »** à l'ouverture de plusieurs boosters à la suite.
7. **Reprise d'un combat** après fermeture puis réouverture de l'interface.
8. **Rendu** : `Lighting.Technology = Future`, intensité du bloom, polices Michroma et BuilderSans.
9. **Animations du Hub** après un combat (elles sont suspendues pendant le combat).

## 7. Limitations connues

- **Contenu** :
  - une seule rencontre PvE ;
  - les objets n'ont aucune mécanique de jeu ;
  - l'IA est simple : elle réserve l'énergie des ultimes, mais n'anticipe pas.
- **Combat** : aucun hasard (choix de conception), donc ni coup critique ni esquive. La caméra est placée derrière les alliés.
- **Visuels provisoires** :
  - personnages en primitives ;
  - cartes à l'initiale sur dégradé ;
  - animations d'action simples (élan, bond), sans animation propre à chaque compétence.
- **Sauvegarde** (corrigé par l'audit 0.5.1) :
  - verrou de session et sauvegarde rapide après un booster ou une récompense ;
  - reste : un crash du serveur peut annuler la progression non encore écrite (au plus une sauvegarde), sans jamais rien dupliquer. Voir [AUDIT_V01.md](AUDIT_V01.md).
- **Interface** (corrigé par l'audit 0.5.1) : la caméra et les plaques de combat suivent désormais les changements de résolution et d'orientation.
- **Performances** : les optimisations du jalon 5 retirent des coûts identifiés dans le code, sans mesure chiffrée au MicroProfiler.
- **Tests en Studio** : ils s'exécutent à chaque Play, jamais sur un serveur publié, et se désactivent avec `GameConfig.Debug.RunTestsInStudio`.
- **Studio** : l'onglet Sécurité des paramètres d'expérience peut ne pas afficher ses interrupteurs (« Failed to parse secrets »). Le README donne le contournement.
