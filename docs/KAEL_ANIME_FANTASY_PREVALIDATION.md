# Kael Anime Fantasy : prévalidation de l'intégration (V0.2.5, version 0.6.4-af)

Ce rapport part du commit `aaab24d` et complète [KAEL_ANIME_FANTASY_INTEGRATION.md](KAEL_ANIME_FANTASY_INTEGRATION.md).

Kael n'est **pas remplacé** : `assets/Fighters/F001_Kael.rbxm` est inchangé et son contrat est vérifié OK. **Aucune** place, aucun asset et aucune animation n'ont été publiés. Les autres personnages ne sont pas commencés.

## Synthèse

| Contrôle | Résultat |
|---|---|
| PerfProbe | Mesure par phase (Summoning, Planning, Resolving). Le rapport est écrit dès l'entrée dans Finished : l'écran de résultat n'est jamais mesuré. Active seulement en environnement de test (Studio ou PlaceId déclaré). Suivi des phases vérifié en vrai combat dans Studio |
| Politique LOD | Inchangée : LOD seulement en effets réduits. Pas de LOD imposé aux appareils tactiles. Stratégie d'ajustement prête pour les mesures (§ 2) |
| Test privé | Procédure prête (§ 3). Réglage `ForceModelDetail`, réservé aux tests, pour comparer principal et LOD à effets égaux |
| Attack (main gauche / cape) | Visible seulement en gros plan latéral, invisible à la caméra de combat : **pas de correction**, comme demandé (§ 4) |
| Outil de publication | `Dev/AnimationPublishing` testé dans Studio : 7 séquences préparées conformes ; contrôle des 7 animations publiées en V0.2.3 : conforme |
| Version | `GameConfig.Version` passe de `0.6.3-art` (V0.2.4) à **`0.6.4-af`**. Affichée en jeu (« Serveur prêt (version 0.6.4-af) ») et dans le README |
| Tests | Lune **135 / 135** ; Studio **162 / 162** ; selene et StyLua conformes ; `rojo build` avec et sans assets OK |

## 1. PerfProbe

### Problème

La version précédente mesurait du début à la fin du mode combat, écran de résultat compris. Le temps passé à lire le résultat, souvent long et sans charge, faussait la moyenne.

### Correction

- **`BattleDirector.PhaseChanged`** (nouveau signal) : émis à chaque changement de phase (Summoning, Planning, Resolving, Finished), puis Idle à la sortie.
- **`Util/FrameStats`** (logique pure, testée sous Lune) : un enregistreur par phase. Les images en Finished et Idle sont ignorées.
- **Rapport** :
  - **combat hors résultat** : invocations, planification et résolution réunies ;
  - **Summoning** : animation d'invocation ;
  - **Planning** : attente du joueur, boucle Idle ;
  - **Resolving** : résolution animée des tours, avec les animations d'action, les impacts et les effets. C'est la mesure de charge principale ;
  - pour chaque mesure : moyenne, i/s, p50, p95, p99, max et part des images sous 30 i/s ;
  - **mémoire** : maximum échantillonné chaque seconde pendant le combat, plus mémoire des maillages et des textures, niveau d'effets, détail des modèles, écran et entrée.
- **Déclenchement** : le rapport est écrit dès l'entrée dans Finished. Un combat quitté avant la fin donne un rapport marqué « interrompu ».
- **Activation** : seulement si `GameConfig.Debug.PerfProbe = true` **et** que l'environnement est de test (`Util/TestEnvironment`) :
  - Studio ;
  - ou une place dont le PlaceId est listé dans `GameConfig.Debug.TestPlaceIds`, vide par défaut.

  Une place publiée qui n'y figure pas, comme l'expérience publique, ne l'active jamais, même si l'option est restée à `true`.

### Vérifié dans Studio (vrai combat, Play, sonde activée temporairement puis remise à `false`)

- La sonde s'annonce « actif (environnement de test) ».
- L'étiquette en direct suit les phases : `Summoning · 60 i/s` → `Planning` → `Resolving` (tour 1) → `Planning` (tour 2). Captures : `build/studio/probe_*.jpg`.
- **Non vu en conditions réelles** : le rapport de fin, qui suppose de terminer un combat. Je ne l'ai pas fait, pour ne pas enregistrer de résultat dans la sauvegarde de test : en Studio, la sauvegarde DataStore est active, et la couper est un réglage de sécurité qui vous revient. Le découpage par phase et l'exclusion du résultat sont couverts par `FrameStatsSpec`.

## 2. Politique LOD

### Comportement actuel

| Situation | Niveau d'effets | Détail des modèles |
|---|---|---|
| Option « Effets réduits » activée | Reduced | **Low** : LOD s'il existe |
| Qualité graphique Roblox réglée à la main entre 1 et 3 | Reduced | **Low** |
| Qualité réglée à la main entre 4 et 10 | Full | High |
| **Qualité automatique**, réglage par défaut sur mobile | **Full** | **High** |

**Le mode automatique sur mobile.** `UserGameSettings.SavedQualityLevel` renvoie seulement `Automatic`. Le niveau réellement choisi par le moteur, qu'il ajuste en continu selon l'appareil et la charge, **n'est pas lisible par un script de jeu**. En qualité automatique, un téléphone faible reste donc en détail High, sauf si le joueur active « Effets réduits ».

C'est voulu tant qu'il n'y a pas de mesures. Le jeu **n'active pas le LOD sur tous les appareils tactiles** : un iPhone récent n'en a probablement pas besoin, et le critère « tactile » regroupe aussi les tablettes et certains PC.

### Stratégie d'ajustement, selon les mesures du § 3

À décider avec les rapports PerfProbe. Le seul point d'entrée à modifier est `GraphicsQuality.modelDetail()` ; rien d'autre ne change.

| Mesures sur téléphone d'entrée de gamme (scénarios B et C, § 3) | Décision proposée |
|---|---|
| B (principal) : combat ≥ 30 i/s et p95 de Resolving ≤ 50 ms | **Aucun changement** : LOD seulement en effets réduits |
| B échoue, C (LOD) réussit | **Détail adaptatif par session** : mesurer les i/s pendant la planification du premier combat ; sous un seuil (par exemple p50 < 40 i/s sur 5 s), les combats suivants prennent le LOD. Le seuil sera fixé d'après les mesures |
| B et C échouent | Le LOD ne suffit pas : alléger ailleurs (contours, nombre de modèles 3D, ombres) avant d'aller plus loin |
| Mémoire : écart B − A > 30 Mo sur l'appareil faible | LOD aussi pour la mémoire ; et pour les futurs combattants, budget à revoir |

Aucun seuil n'est inventé avant les mesures. Le réglage `ForceModelDetail` (§ 3) ne sert qu'aux tests.

## 3. Procédure du test privé

### But

Comparer, **dans les mêmes conditions de combat**, sur le même téléphone :

| | Kael | Détail | Effets |
|---|---|---|---|
| **A** | V0.2.2 (production actuelle) | — | complets |
| **B** | Anime Fantasy, modèle principal | `ForceModelDetail = "High"` | complets |
| **C** | Anime Fantasy, LOD | `ForceModelDetail = "Low"` | complets |

Les effets restent complets dans les trois cas, pour isoler l'effet du modèle. Une série optionnelle refait A à C avec « Effets réduits ».

### Prérequis, à faire par vous

1. **Place de test privée**, distincte de l'expérience publique : une nouvelle place privée, ou une copie dans une expérience de test. **Je ne l'ai pas créée ni publiée.** Notez son PlaceId.
2. **Animations Anime Fantasy publiées** (§ 5, étapes 1 à 3) : sans elles, le modèle AF jouerait les animations V0.2.3, calculées pour l'ancien squelette, donc des poses fausses.
   - Elles sont publiées sur votre compte, non publiques, et utilisables seulement dans vos expériences.
   - Si vous voulez tester avant toute publication, l'alternative est de retirer temporairement `animations` de `F001` dans la copie de test. Kael fait alors des mouvements génériques ; la mesure est valable pour le rendu, mais sous-estime le coût d'animation.

### Préparer une branche de test, sans toucher à `main`

```bash
git switch -c test/kael-af-perf
```

Dans cette branche uniquement :

1. `GameConfig.Debug.PerfProbe = true` ; `GameConfig.Debug.TestPlaceIds = { <PlaceId de la place de test> }`.
2. **Assets** (le dossier `assets/Fighters` de la branche) :
   - **A** : laisser `F001_Kael.rbxm`, le V0.2.2 actuel ;
   - **B et C** : copier `art/kael/anime_fantasy/build/F001_Kael_AF_candidate.rbxm` vers `assets/Fighters/F001_Kael.rbxm`, et `F001_Kael_AF_LOD_candidate.rbxm` vers `assets/Fighters/F001_Kael_LOD.rbxm`.
3. **B et C** : dans `VisualAssets.Cards.F001.animations`, les 7 identifiants Anime Fantasy publiés.
4. **B** : `ForceModelDetail = "High"`. **C** : `ForceModelDetail = "Low"`.
5. Construire la place :
   ```bash
   rojo build build.project.json -o kael_perf_test.rbxlx
   ```
   Vérifier avec `lune run tools/lune/check-fighter-asset -- kael_perf_test.rbxlx F001_Kael` (et `F001_Kael_LOD` pour C). Ouvrir la place dans Studio et la publier vers **la place de test privée**, jamais l'expérience publique.

Pour passer d'un scénario à l'autre, modifier seulement les points 2 à 4, reconstruire et republier la place de test.

### Mesure, identique pour chaque scénario

1. **Appareil** :
   - un Android d'entrée de gamme (3 Go de RAM ou moins) et un iPhone récent ;
   - batterie au-dessus de 50 %, hors charge, appareil froid ;
   - autres applications fermées ;
   - qualité graphique Roblox sur **Automatique** ;
   - « Effets réduits » désactivé.
2. **Combat** : rencontre 1 « Faille instable », même équipe avec Kael en ligne avant, invocations normales (« Invocations rapides » désactivé).
3. **Jouer 3 tours**, en validant les mêmes ordres par défaut, puis **terminer le combat**, victoire ou défaite.
4. À l'écran de résultat, **capturer le rapport `[PerfProbe]` à l'écran**, et le recopier depuis la console développeur (`/console` ou F9, onglet Log).
5. **3 essais par scénario**, en gardant la **médiane**. Fermer et relancer l'application entre deux scénarios.

### Tableau à remplir

| Appareil | Scénario | Combat : i/s moyen | Combat : p95 (ms) | Resolving : i/s moyen | Resolving : p95 (ms) | Mémoire max (Mo) | Maillages (Mo) | Textures (Mo) |
|---|---|---|---|---|---|---|---|---|
| Android d'entrée de gamme | A | | | | | | | |
| | B | | | | | | | |
| | C | | | | | | | |
| iPhone | A | | | | | | | |
| | B | | | | | | | |
| | C | | | | | | | |

### Complément facultatif

MicroProfiler du téléphone :

1. *Paramètres Roblox → MicroProfiler* activé sur le téléphone.
2. Depuis un PC du même réseau, `http://<IP du téléphone>:1338`.
3. Capturer pendant la résolution d'un tour.

### Après le test

Ne pas fusionner la branche `test/kael-af-perf`. Me transmettre le tableau et les captures. J'appliquerai alors la décision du § 2.

**Le simulateur d'appareil de Studio ne remplace pas cette mesure** : le rendu y est fait par la carte graphique du PC.

## 4. Attack : main gauche contre la cape

`af_cape_check` mesure, aux images 12 à 22, la main et l'avant-bras gauches qui croisent le flanc de la cape à hauteur de hanche. Le buste pivote de 25° et la cape, pesée sur le bassin, ne suit pas.

**Contrôle visuel** sur le maillage déformé (Blender, rendus `build/renders/attack_check_angles.png` et `attack_check_closeups.png`, images 1, 9, 13, 16, 19 et 22, quatre angles), et dans Studio (Attack en lecture réelle, `build/studio/live_Attack.jpg`) :

| Vue | Visible ? |
|---|---|
| Gros plan latéral gauche, images 13 à 19 | **Oui, légèrement** : le bord avant de la cape coupe le bas du gantelet |
| Trois-quarts arrière et arrière (caméra des alliés) | Non : la main reste couverte par la cape, sans saillie |
| Trois-quarts avant (ennemi vu par la caméra) | Non : le bras passe devant le bord de la cape |
| Caméra de combat dans Studio (PC 1080p, mobile) | Non |

**Décision : pas de correction.** Le défaut n'est visible qu'en gros plan latéral, un angle que le jeu n'emploie pas, et il ne gêne pas la lecture de l'attaque. Si une caméra rapprochée est ajoutée un jour, la même méthode que pour Skill s'appliquerait : bras gauche avancé aux images 7 et 12.

## 5. Publication des animations et remplacement des modèles

À exécuter **seulement après votre autorisation explicite**, dans la place de test ouverte dans Studio. **Relancer Studio avant**, car les modules sont gardés en cache.

### A. Publier les 7 animations Anime Fantasy

1. Préparer les sources, sans rien publier :
   ```lua
   local Dev = game.ServerScriptService.Server.Dev
   local AP = require(Dev.AnimationPublishing)
   print(AP.describe(AP.prepare(game.ServerStorage.KaelBench.P3.F001_Kael, Dev.AnimationData.F001_Kael_AF, "F001_Kael_AF")))
   ```
   Attendu : 7 lignes `OK`, avec écart au repos et dérive à 0,0000, puis `=> tout est conforme`.

   Les séquences sont créées dans `ServerStorage.AnimationSources.F001_Kael_AF` (`F001_Kael_AF_Idle`, …). Je les ai déjà préparées une fois, à titre de test.
2. Pour **chacune des 7** séquences :
   - *clic droit → Sauvegarder/Exporter → Sauvegarder sur Roblox* ;
   - créateur « Moi » ;
   - **« Supprimer les instances locales » désactivé** ;
   - noter l'identifiant affiché.
3. Vérifier les identifiants contre leurs données :
   ```lua
   print(AP.describe(AP.check({
       Idle = "rbxassetid://…", Attack = "rbxassetid://…", Skill = "rbxassetid://…",
       Ultimate = "rbxassetid://…", Defend = "rbxassetid://…", Hit = "rbxassetid://…",
       Defeat = "rbxassetid://…",
   }, Dev.AnimationData.F001_Kael_AF)))
   ```
   Attendu : `=> tout est conforme`. En cas d'échec, l'identifiant est faux ou l'animation est encore en modération : attendre et revérifier.

### B. Remplacer les modèles de production (dépôt)

4. Copier les fichiers :
   ```bash
   cp art/kael/anime_fantasy/build/F001_Kael_AF_candidate.rbxm assets/Fighters/F001_Kael.rbxm
   ```
   ```bash
   cp art/kael/anime_fantasy/build/F001_Kael_AF_LOD_candidate.rbxm assets/Fighters/F001_Kael_LOD.rbxm
   ```
5. Vérifier les deux contrats :
   ```bash
   lune run tools/lune/check-fighter-asset -- assets/Fighters/F001_Kael.rbxm
   ```
   ```bash
   lune run tools/lune/check-fighter-asset -- assets/Fighters/F001_Kael_LOD.rbxm F001_Kael_LOD
   ```
6. **Code** :
   - `src/shared/Visuals/VisualAssets.luau` : remplacer les 7 identifiants de `F001.animations` par ceux de l'étape 3, et mettre à jour le commentaire de l'entrée F001 ;
   - `tests/Specs/KeyframeBuilderSpec.luau` (test « Kael : les 7 animations… ») : `Dev.AnimationData.F001_Kael` devient `Dev.AnimationData.F001_Kael_AF`, puisque les données `F001_Kael` sont celles de l'ancien squelette.
7. **Tests** :
   ```bash
   lune run tools/lune/run-tests
   ```
   ```bash
   rojo build build.project.json -o Collectverse.rbxlx
   ```
   ```bash
   lune run tools/lune/check-fighter-asset -- Collectverse.rbxlx F001_Kael
   ```

### C. Mettre à jour les places

8. **Place de test** : `default.project.json` ne synchronise pas `assets/`, volontairement.
   - Remplacer `ReplicatedStorage.Assets.Fighters.F001_Kael` par le contenu de `assets/Fighters/F001_Kael.rbxm` (*clic droit sur Fighters → Insérer depuis un fichier*).
   - Ajouter `F001_Kael_LOD`.
   - Garder l'ancien modèle dans `ServerStorage`, renommé `F001_Kael_V022`, jusqu'à validation finale.
9. **Contrôle dans Studio** :
   - tests au lancement : 0 échec attendu ;
   - un combat avec Kael allié et ennemi, en effets complets puis réduits ; vérifier le LOD avec `ForceModelDetail` ou « Effets réduits » ;
   - la statue du Hub.
10. **Expérience publique** : publication de la place **seulement sur votre décision**, après les points 8 et 9.

### Retour arrière

- Pour le dépôt : `git revert` du commit de remplacement.
- Pour la place : restaurer `F001_Kael_V022` sous le nom `F001_Kael`.
- Les animations V0.2.3 restent publiées et compatibles avec l'ancien modèle.
- Le repli sur le modèle provisoire et les mouvements génériques reste actif si un asset manque.

## 6. Tests

| Exécution | Résultat |
|---|---|
| Lune | **135 / 135**. Nouveaux tests : enregistreur par phase (le résultat et la sortie sont exclus, enregistreur borné) ; environnement de test (Studio, PlaceId déclaré, production refusée, place non publiée refusée) |
| Studio, au lancement du jeu | **162 / 162** |
| `AnimationPublishing.prepare` / `check` (Studio) | 7/7 conformes / 7/7 conformes (animations V0.2.3) |
| `check-fighter-asset` (production, candidat, LOD) | OK |
| `rojo build` (`build.project.json`, `default.project.json`) | OK |
| selene, StyLua | Conformes |

## 7. Fichiers modifiés ou ajoutés

| Fichier | Rôle |
|---|---|
| `src/client/Controllers/BattleDirector.luau` | Signal `PhaseChanged` |
| `src/client/Controllers/PerfProbe.luau` | Mesure par phase, activation en environnement de test seulement |
| `src/shared/Util/FrameStats.luau` | Enregistreur par phase, rapport |
| `src/shared/Util/TestEnvironment.luau` | Studio ou PlaceId de test |
| `src/client/State/GraphicsQuality.luau`, `src/client/Battle/SummonController.luau` | `modelDetail()` et réglage `ForceModelDetail` réservé aux tests |
| `src/shared/Config/GameConfig.luau` | Version `0.6.4-af`, `TestPlaceIds`, `ForceModelDetail` |
| `src/server/Dev/AnimationPublishing.luau` | Préparation et contrôle de la publication |
| `tests/Specs/FrameStatsSpec.luau` | Tests de la sonde et de l'environnement |
| `art/kael/anime_fantasy/build/renders/attack_check_*.png` | Contrôle visuel d'Attack |
