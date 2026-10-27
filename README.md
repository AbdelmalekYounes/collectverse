# COLLECTVERSE: Echoes of the Rift

Prototype Roblox (V0.1) : collection de cartes, boosters gratuits et combats stratégiques au tour par tour.

> **État : jalon 2 sur 5.** Hub, collection, Team Builder et combat PvE 5 contre 5 contre l'IA.
> L'arène 3D, l'ouverture des boosters et la sauvegarde ne sont pas encore disponibles. Voir [docs/JALONS.md](docs/JALONS.md).

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

### Réglages Studio recommandés

- **Lighting → Technology : Future** (non modifiable par script).
- **Game Settings → Security → Enable Studio Access to API Services** : requis pour la sauvegarde (jalon 4).

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

Le script charge les modules tels quels, dans une imitation minimale de l'arbre Rojo. `ModelFactorySpec`, qui crée des Instances Roblox, reste réservée à Studio. Le code de sortie vaut 1 en cas d'échec.

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
  Util/        Freeze (gel des données)
src/server   → ServerScriptService.Server
  World/       HubBuilder (scène), LightingSetup
  Services/    PlayerDataService, TeamService, BattleService
  Net/         RemoteGuard, RateLimiter
  Data/        ProfileTemplate (profil versionné)
src/client   → StarterPlayerScripts.Client
  Controllers/ UIController (navigation), ZoneController, HubAmbience
  State/       ClientSettings (préférences de présentation)
  UI/          Components, CardTile, Hud, Motion, Screens/
tests        → ServerScriptService.Tests         (Studio uniquement)
tools        → scripts hors Roblox
```

Correspondance avec l'architecture cible :

| Module de référence | Emplacement | Jalon |
|---|---|---|
| CardCatalog | `shared/Catalog/CardCatalog` | 1 ✅ |
| UIController | `client/Controllers/UIController` | 1 ✅ |
| TeamService | `server/Services/TeamService` + `shared/Battle/TeamRules` | 2 ✅ |
| BattleEngine, AbilitySystem, CombatAI | `shared/Battle` (logique pure) + `server/Services/BattleService` | 2 ✅ |
| PlayerDataService | `server/Services/PlayerDataService` (session ; DataStore au jalon 4) | 2 ◐ |
| SummonController | `client/Controllers` + `shared/Visuals/ModelFactory` (modèles prêts) | 3 |
| CollectionService, BoosterService | `server/Services` | 4 |

Principes :

- **Données déclaratives.** Un combattant se définit uniquement dans `Catalog/Fighters.luau`. Les actions sont des listes d'effets (`Damage`, `Heal`, `Shield`, `Status`) que le moteur interprète de façon générique. Voir [docs/CATALOGUE.md](docs/CATALOGUE.md).
- **Validation au démarrage.** Le serveur refuse de démarrer si `CatalogValidator` trouve une incohérence.
- **Textes générés.** Les descriptions des actions viennent des effets réels (`AbilityText`) : elles ne peuvent pas diverger du combat.
- **Assets remplaçables.** Placez un `Model` nommé d'après l'id (ex. `F001`) dans `ReplicatedStorage.Assets.Fighters`, avec une `PrimaryPart` aux pieds et l'avant tourné vers −Z. Il remplacera automatiquement le modèle provisoire.
- **Serveur autoritaire** (jalons 2 et 4) : le client n'envoie que des intentions, validées côté serveur (types, valeurs, fréquence, état).
