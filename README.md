# COLLECTVERSE: Echoes of the Rift

Prototype Roblox (V0.1) : collection de cartes, boosters gratuits et combats stratégiques au tour par tour.

> **État : prototype V0.1 terminé (jalon 5 sur 5).** Le parcours complet a été joué dans Studio, avec la sauvegarde DataStore réelle : Hub → Collection → Équipe → Combat 3D → Victoire → Booster → Ouverture → Collection mise à jour.
>
> - Récapitulatif des livrables (modules, tests et résultats, vérifications manuelles, limitations) : [docs/LIVRABLES.md](docs/LIVRABLES.md).
> - **Audit et stabilisation (version 0.5.1-audit)** : verrou de session des sauvegardes, combats adaptés à l'écran, architecture visuelle V0.2. Voir [docs/AUDIT_V01.md](docs/AUDIT_V01.md).
> - **V0.2.5 — Kael Anime Fantasy (version 0.6.4-af, candidat validé dans Studio, non intégré)** : nouveau modèle 3D complet (≈ 7,3 têtes, armure, épée des braises, cape, atlas cuit, 7 animations reconstruites) et sa variante allégée, contour fin des alliés, lumière d'arène en effets réduits, plaques des alliés avant au sol, sonde de performance de test. Voir [docs/KAEL_ANIME_FANTASY_PRODUCTION.md](docs/KAEL_ANIME_FANTASY_PRODUCTION.md), [docs/KAEL_ANIME_FANTASY_STUDIO_VALIDATION.md](docs/KAEL_ANIME_FANTASY_STUDIO_VALIDATION.md), [docs/KAEL_ANIME_FANTASY_INTEGRATION.md](docs/KAEL_ANIME_FANTASY_INTEGRATION.md) et [docs/KAEL_ANIME_FANTASY_PREVALIDATION.md](docs/KAEL_ANIME_FANTASY_PREVALIDATION.md).
> - **V0.2.4 — passe artistique premium de Kael (version 0.6.3-art)** : animations revalidées en combat réel, modèle premium sur une copie (même rig, mêmes animations), rendus avant / après, proposition d'illustration de carte, effets de braise. Voir [docs/V024_KAEL_ART_PASS.md](docs/V024_KAEL_ART_PASS.md).
> - **V0.2.3 — animations 3D (version 0.6.2-anim)** : les 7 animations de Kael converties de Blender en KeyframeSequence, validées, publiées et jouées en combat. Voir [docs/V023_ANIMATION_PIPELINE.md](docs/V023_ANIMATION_PIPELINE.md).
> - **V0.2.2 — premier personnage 3D (version 0.6.1-kael)** : pipeline Blender → Roblox de Kael (modèle riggé, rendus, import, contrat, versionnement). Voir [docs/V022_KAEL_PIPELINE.md](docs/V022_KAEL_PIPELINE.md).
> - **V0.2.1 — fondations visuelles (version 0.6.0-visual)** : cartes premium (cadres par rareté, variantes, holo), ouverture de booster retravaillée, personnage pilote Kael et pipeline Blender → Roblox. Voir [docs/V02_VISUAL_PIPELINE.md](docs/V02_VISUAL_PIPELINE.md).
> - Détail jalon par jalon : [docs/JALONS.md](docs/JALONS.md). Catalogue : [docs/CATALOGUE.md](docs/CATALOGUE.md).

## Installation

Prérequis : Roblox Studio, [Rokit](https://github.com/rojo-rbx/rokit) (ou Aftman), Git.

```bash
rokit install
```

Cette commande installe Rojo, selene et StyLua aux versions de `rokit.toml`. Installez ensuite le plugin Studio de Rojo :

```bash
rojo plugin install
```

Si cette commande échoue avec « Couldn't find registry keys », Studio est bien installé, mais Rojo ne trouve pas la clé de registre qu'il attend. Deux solutions :

- installer le plugin **Rojo** depuis le Creator Store, dans Studio (**Toolbox → Plugins**) ;
- ou se passer du plugin et utiliser `rojo build` (voir plus bas).

## Synchroniser avec Studio

1. Dans Studio, créez une place vide (modèle **Baseplate**).
2. Dans le dossier du projet :

   ```bash
   rojo serve
   ```

3. Dans Studio : onglet **Plugins → Rojo → Connect**.

Autre méthode, sans serveur : générez un fichier de place, puis ouvrez-le dans Studio.

```bash
rojo build -o Collectverse.rbxlx
```

Pour inclure les modèles 3D finaux (`assets/`, par exemple Kael), utilisez le projet de build :

```bash
rojo build build.project.json -o Collectverse.rbxlx
lune run tools/lune/check-fighter-asset -- Collectverse.rbxlx F001_Kael
```

`default.project.json` ne synchronise pas `assets/` en direct : le plugin ne sait pas définir le maillage d'une MeshPart. Les modèles importés dans la place sont conservés par `rojo serve`.

### Réglages Studio recommandés

- **Lighting → Technology : Future** (non modifiable par script).
- **Sauvegarde réelle** : la place doit être publiée sur Roblox (**Fichier → Publier**), avec l'accès API activé : **Fichier → Paramètres d'expérience → Sécurité → Permettre à Studio d'accéder aux services API**, puis **Enregistrer**.
  - Si les interrupteurs de l'onglet Sécurité ne s'affichent pas (sortie : « Failed to parse secrets: Can't parse JSON »), le réglage n'est pas enregistré : fermez toutes les fenêtres Studio, relancez, rouvrez uniquement la place, puis recommencez.
  - Sinon, le serveur passe automatiquement en **mode test local** : la sortie l'indique, le HUD affiche « Mode test : sauvegarde inactive », et rien n'est persisté.
  - Les données d'un test Studio avec accès API sont de vraies données DataStore : utilisez une place de test, pas la place publique.

Le Hub est construit par script au lancement, dans `Workspace.CollectverseHub`. Les autres `SpawnLocation` de la place sont désactivées pour la session uniquement (rien n'est modifié dans le fichier).

## Lancer

**Play (F5)** dans Studio. Approchez-vous d'une zone et appuyez sur **E** (ou touchez l'invite sur mobile), ou utilisez la barre de navigation à droite.

## Tester

### Dans Studio

Les tests Luau (`tests/Specs`) s'exécutent automatiquement à chaque **Play** en Studio, jamais sur les serveurs publiés. Les résultats s'affichent dans la sortie (Output) :

```
[Tests] N réussi(s), 0 échec(s)
```

Ils sont aussi copiés dans les attributs `TestsPassed` / `TestsFailed` de `Workspace`. Pour les désactiver : `GameConfig.Debug.RunTestsInStudio = false`.

### Hors Studio

Les tests de logique pure (catalogue, règles, combat, IA, sécurité) tournent avec [Lune](https://github.com/lune-org/lune), installé par `rokit install` :

```bash
lune run tools/lune/run-tests
```

Pour ne lancer que certaines specs :

```bash
lune run tools/lune/run-tests -- BattleEngineSpec CombatAISpec
```

Le script charge les modules tels quels, dans une imitation minimale de l'arbre Rojo. `ModelFactorySpec` et `SummonSpec`, qui créent des Instances Roblox, restent réservées à Studio. Les fixtures partagées (tirages déterministes) sont dans `tests/Fixtures`.

### Outils de test dans Studio

`server/Dev/StudioDebug` n'est actif qu'en Studio (`RunService:IsStudio()`). Pendant un Play, dans la barre de commande en contexte **Serveur** :

```lua
-- Crédite 3 boosters First Rift
game.Players:GetPlayers()[1]:SetAttribute("DebugGrantBoosters", 3)
-- Le prochain booster donne exactement ces cartes (vrais taux, tirage impossible refusé)
game.Players:GetPlayers()[1]:SetAttribute("DebugNextBooster", "F001,F002,F003,I001,F006")
``` Le code de sortie vaut 1 en cas d'échec.

```bash
python tools/static_check.py
```

Ce script vérifie l'équilibre des blocs et des parenthèses et la résolution des `require` dans l'arbre Rojo. Il ne remplace pas une vraie analyse Luau :

```bash
selene src tests
```

## Architecture

```
src/shared   → ReplicatedStorage.Shared          (client + serveur)
  Config/      Theme (palette, polices), GameConfig (règles et équilibrage)
  Catalog/     données déclaratives + validation + textes générés
  Battle/      règles d'équipe, ciblage, effets, moteur, IA (logique pure)
  Net/         liste des remotes
  Visuals/     apparences des combattants, séparées du gameplay
  Util/        Freeze (gel des données), Signal (événements purs), Text (majuscules accentuées)
  Visuals/     VisualAssets (registre V0.2 : illustrations, variantes, modèles, animations),
               CardStyle (cadres par rareté, tailles, mise en page des cartes),
               EffectsPolicy (niveau d'effets graphiques)
src/server   → ServerScriptService.Server
  World/       HubBuilder (scène), LightingSetup
  Services/    PlayerDataService, TeamService, BattleService, BoosterService
  Net/         RemoteGuard, RateLimiter
  Data/        ProfileTemplate, ProfileSchema (versions, réparation), ProfileStore
               (chargement/sauvegarde), DataStoreAdapter, MemoryAdapter
  Logic/       BoosterLogic (tirage), Inventory (cartes, doublons, déblocages),
               BattleRewards (issue d'un combat), BattleSessions (combats en cours)
               — logique pure, testée avec Lune
  Dev/         StudioDebug (outils de test, Studio uniquement),
               FighterAssetPrep (mise au contrat d'un combattant importé),
               KeyframeBuilder (animations Blender → KeyframeSequence), AnimationData
src/client   → StarterPlayerScripts.Client
  Controllers/ UIController (navigation), ZoneController, HubAmbience,
               DataController, BattleController, BattleDirector (mise en scène),
               BattlePlanner et BattleReplay (logique pure, testées avec Lune)
  Battle/      Arena, BattleCamera, SummonController, BattleFx (présentation 3D),
               BattleLayout (mise en page selon l'écran), FighterAnimator (animations V0.2)
  State/       ClientSettings (préférences de présentation), GraphicsQuality
  UI/          Components, CardTile (carte premium), RevealTimeline (ouverture des boosters),
               Hud, Motion, Screens/
tests        → ServerScriptService.Tests         (Studio uniquement)
tools        → scripts hors Roblox (Lune : tests, check-fighter-asset)
art          → production 3D (Blender), hors du jeu : art/kael
assets       → modèles finaux versionnés (.rbxm), inclus par build.project.json
```

Correspondance avec l'architecture cible :

| Module de référence | Emplacement | Jalon |
|---|---|---|
| CardCatalog | `shared/Catalog/CardCatalog` | 1 ✅ |
| UIController | `client/Controllers/UIController` | 1 ✅ |
| TeamService | `server/Services/TeamService` + `shared/Battle/TeamRules` | 2 ✅ |
| BattleEngine, AbilitySystem, CombatAI | `shared/Battle` (logique pure) + `server/Services/BattleService` | 2 ✅ |
| PlayerDataService | `server/Services/PlayerDataService` + `server/Data/ProfileStore` (verrou de session depuis l'audit) | 4 ✅ |
| SummonController | `client/Battle/SummonController` + `shared/Visuals/ModelFactory` | 3 ✅ |
| Interface de combat | `client/Controllers/BattleDirector`, `BattlePlanner`, `BattleReplay` + `client/UI/BattleHud`, `UnitPlate` | 3 ✅ |
| CollectionService → `Inventory` (nom du service Roblox évité), BoosterService | `server/Logic`, `server/Services/BoosterService` | 4 ✅ |
| Récompenses de combat | `server/Logic/BattleRewards`, appelé par `BattleService` | 5 ✅ |
| Sessions de combat | `server/Logic/BattleSessions`, branché par `BattleService` | Audit ✅ |
| Assets visuels V0.2 | `shared/Visuals/VisualAssets`, `ModelFactory.validateAsset`, `client/Battle/FighterAnimator` | Audit ✅ |

Principes :

- **Données déclaratives.** Un combattant se définit uniquement dans `Catalog/Fighters.luau`. Les actions sont des listes d'effets (`Damage`, `Heal`, `Shield`, `Status`) que le moteur interprète de façon générique. Voir [docs/CATALOGUE.md](docs/CATALOGUE.md).
- **Validation au démarrage.** Le serveur refuse de démarrer si `CatalogValidator` trouve une incohérence.
- **Textes générés.** Les descriptions des actions viennent des effets réels (`AbilityText`) : elles ne peuvent pas diverger du combat.
- **Assets remplaçables.** Illustrations, modèles et animations se déclarent dans `shared/Visuals/VisualAssets` (contrat détaillé en tête du fichier). Un modèle se place dans `ReplicatedStorage.Assets.Fighters` : `PrimaryPart` ancrée aux pieds, avant tourné vers −Z, autres pièces non ancrées et reliées à elle. Tout asset absent ou non conforme est remplacé par le visuel provisoire.
- **Serveur autoritaire** : le client n'envoie que des intentions, validées côté serveur (types, valeurs, fréquence, état).
