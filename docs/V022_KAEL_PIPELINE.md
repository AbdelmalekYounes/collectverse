# V0.2.2 : premier personnage 3D (Kael, F001)

Version `0.6.1-kael`. Objectif : un pipeline de production d'un combattant 3D, complet et réutilisable, validé de bout en bout sur Kael.

Le gameplay, les données de cartes, les sauvegardes et le réseau ne sont pas modifiés. Les cinq autres personnages ne sont pas traités.

## 1. Résumé

| Étape | État |
|---|---|
| Spécifications artistiques et techniques | ✅ `art/kael/KAEL_SPEC.md` |
| Workflow Blender reproductible | ✅ `art/kael/kael_build.py` : Blender 4.2.23 LTS, une commande, environ 30 s |
| Modèle 3D exploitable | ✅ produit, budget respecté (2 892 triangles, 17 os) ; **modèle pilote stylisé, pas une version artiste finale** |
| Vrai rig animable | ✅ maillage skinné sur une armature R15, vérifié comme `Skinned` et animable dans Studio |
| Rendus de contrôle | ✅ 4 vues + 7 poses + planche (`art/kael/build/renders/`) |
| Animations | ⚠️ 7 animations **créées dans Blender** et exportées en FBX ; **l'import dans l'éditeur d'animation Roblox a échoué** (§ 5) ; aucune publiée |
| Import Roblox Studio | ✅ importé dans la place de test, mis au contrat, validé |
| Versionnement avec Rojo | ✅ `assets/Fighters/F001_Kael.rbxm` + `build.project.json` ; Rojo passé en 7.7.1 |
| Intégration avec fallback | ✅ Kael utilise le vrai modèle (statue du Hub, invocation en combat) ; si le modèle est absent ou non conforme, le provisoire reprend |
| Illustration officielle | ⏳ emplacement prêt (`VisualAssets.Cards.F001.art`), aucun Asset ID inventé |
| Variantes dans l'inventaire | 📝 analyse uniquement, aucune modification des sauvegardes (§ 7) |

## 2. Production dans Blender

Blender n'était pas installé. Avec votre accord, j'ai téléchargé la **version portable officielle Blender 4.2.23 LTS** (zip de 383 Mo, `download.blender.org`) dans `D:\Tools`, hors du projet. Son empreinte SHA-256 a été vérifiée avant l'extraction ; rien n'a été installé au niveau du système.

```bash
"D:\Tools\blender-4.2.23-windows-x64\blender.exe" -b --factory-startup --python art/kael/kael_build.py -- --out art/kael/build
python art/kael/contact_sheet.py art/kael/build
```

Le script construit tout à partir de primitives paramétrées, puis il vérifie et exporte :

1. **Maillage** : un seul maillage, avec corps, armure, tête anime, mèches de cheveux et épée.
2. **Texture palette** : 64 × 64 px.
3. **Armature R15** : 17 os.
4. **Poids de skinning** : calculés, avec un fondu aux articulations.
5. **Animations** : 7, en images-clés.
6. **Exports** : FBX, GLB et une animation par FBX.
7. **Rendus** Workbench.
8. **Rapport JSON** : budget, influences, sommets sans poids, pieds au sol, hauteur.

Rapport de la dernière production :

| Mesure | Valeur |
|---|---|
| Hauteur | 6,60 studs, pieds à Z = 0 |
| Sommets | 1 560 |
| Triangles | 2 892 (budget de 6 000) |
| Os | 17 (budget de 20) |
| Influences max. par sommet | 2 (budget de 4) |
| Sommets sans poids | 0 |
| Matériaux / texture | 1 / 64 × 64 |
| Validation | `valide = True` |

**Défauts corrigés pendant la production**, constatés sur les rendus :

- **Poses d'animation fausses à la première version** : le buste se penchait sur le côté au lieu de pivoter, et les bras ne se levaient pas. Les angles étaient donnés dans le repère local de chaque os, dont l'orientation dépend de sa direction. Les poses sont maintenant décrites dans les axes du personnage, puis converties pour chaque os (`local_rotation`). Les rendus confirment le résultat :
  - frappe vers l'avant ;
  - bras écartés pendant le tour ;
  - saut ;
  - garde ;
  - recul ;
  - chute à genoux.
- **Surfaces confondues** (taches) sur le plastron, les tassettes et les cheveux, **genouillères en boules** et **lame couleur bois** : géométrie et couleurs corrigées.

**Limite honnête** : le modèle est un **pilote stylisé fait de primitives**. Il valide la chaîne complète (rig, poids, export, import, contrat, jeu), mais il n'a pas la finition d'un modèle « premium » sculpté par un artiste. La version artiste devra respecter `KAEL_SPEC.md` et passer les mêmes vérifications.

## 3. Import Roblox Studio (procédure réellement suivie)

Place de test privée « Collectverse Test », avec votre accord explicite pour le téléversement.

1. ***Accueil → Importer*** : choisir `art/kael/build/F001_Kael.fbx`.
2. **Aperçu de l'importateur**, constaté :
   - personnage texturé, armature détectée (`F001_Kael`, `F001_Kael_Mesh`) ;
   - type de rig « Personnaliser » ;
   - transformation : *Avant* / *Haut* ;
   - **unité d'échelle « Stud », facteur 1** ;
   - **dimensions 3,21 × 6,60 × 2,47** ;
   - **2 892 polygones**.
3. **Importer**. Les options « Importer sur Roblox » et créateur « Moi » sont laissées par défaut. Le maillage et la texture deviennent des **assets privés** sur votre compte : le maillage porte l'identifiant `rbxassetid://138475817837268`, attribué par Roblox et non inventé.
4. **Mise au contrat**, dans la barre de commande, hors Play :
   ```lua
   local Prep = require(game.ServerScriptService.Server.Dev.FighterAssetPrep)
   print(Prep.describe(Prep.prepare(workspace.F001_Kael, "F001_Kael")))
   ```
   L'outil effectue les opérations suivantes :
   - il crée une pièce **`AssetPivot`** ancrée aux pieds, tournée vers −Z, comme PrimaryPart ;
   - il désancre et soude le maillage au pivot ;
   - il ajoute l'**`Animator`** dans l'`AnimationController` créé par l'importateur, qui en était dépourvu ;
   - il range le modèle dans `ReplicatedStorage.Assets.Fighters`.

   Résultat obtenu : `contrat OK | rig Skinned (os 17, Animator true, animable true) | pièces 1 | avant vers −Z true`.
5. ***Clic droit → Sauvegarder/Exporter → Sauvegarder dans un fichier*** : enregistrer vers `assets/Fighters/F001_Kael.rbxm`.
6. **Vérification hors Studio** :
   ```bash
   lune run tools/lune/check-fighter-asset -- assets/Fighters/F001_Kael.rbxm
   ```
   Résultat : `Contrat : OK` (PrimaryPart `AssetPivot`, rig Skinned, 17 os, animable).

**Pourquoi « AssetPivot » et pas « Root »** : la première version de l'outil appelait la pièce de pivot `Root`, comme l'os racine de l'armature. L'éditeur d'animation refuse alors le rig, avec le message « une pièce et un os qui portent le même nom ». La pièce a été renommée, l'outil renomme aussi les anciens pivots, et les deux vérificateurs (`FighterAssetPrep`, `check-fighter-asset`) signalent maintenant tout nom partagé entre une pièce et un os.

## 4. Intégration en jeu et fallback

- `VisualAssets.Cards.F001 = { variant = "Holo", model = "F001_Kael" }`.
- `ModelFactory` cherche `ReplicatedStorage.Assets.Fighters.F001_Kael`. Si ce modèle est **présent et conforme**, il est utilisé. S'il est **absent ou non conforme**, le modèle provisoire prend le relais, avec un avertissement.
- **Vérifié dans Studio**, en Play, DataStore actif :
  - la **statue de Kael** dans le Hub est le vrai modèle, debout sur son socle, face au joueur, avec son panneau ;
  - **en combat**, l'Écho de Kael est invoqué avec le vrai modèle, à la bonne place et avec la teinte corail. Un tour s'est joué sans erreur, avec les mouvements génériques, puisqu'aucune animation n'est déclarée.
- **Problème trouvé et corrigé** : les tests Studio s'exécutent pendant le démarrage du jeu. L'ancien test remplaçait temporairement le vrai modèle par un modèle de test dans `ReplicatedStorage`, et le Hub avait construit la statue avec ce dernier. Désormais :
  - `ModelFactory.build` et `SummonController.summon` acceptent un **dossier d'assets injecté** (`assetsFolder`) ;
  - les tests utilisent un dossier isolé et ne touchent plus jamais au vrai.

## 5. Animations : état précis

> **Résolu en V0.2.3** ([V023_ANIMATION_PIPELINE.md](V023_ANIMATION_PIPELINE.md)). Le rig était animable : l'Animator associe les poses aux os par leur nom, et l'échec venait de l'import FBX de l'éditeur d'animation. Les 7 animations sont désormais converties en KeyframeSequence, validées, publiées et jouées en combat. Le tableau ci-dessous décrit l'état à la fin de la V0.2.2.

| Animation | Créée (Blender) | Pose vérifiée (rendu) | Exportée (FBX) | Importée dans Roblox | Publiée (AnimationId) |
|---|---|---|---|---|---|
| Idle | ✅ | ✅ | ✅ | ❌ | ❌ |
| Attack | ✅ | ✅ | ✅ | ❌ (essai échoué) | ❌ |
| Skill | ✅ | ✅ | ✅ | ❌ | ❌ |
| Ultimate | ✅ | ✅ | ✅ | ❌ | ❌ |
| Defend | ✅ | ✅ | ✅ | ❌ | ❌ |
| Hit | ✅ | ✅ | ✅ | ❌ | ❌ |
| Defeat | ✅ | ✅ | ✅ | ❌ | ❌ |

**Essai d'import d'Attack** dans l'éditeur d'animation de Studio, via *… → Importer → Depuis un fichier*, type de plateforme « Personnalisé » :
- le clip est créé ;
- mais **aucune piste d'os n'est associée** au rig ;
- le personnage apparaît replié tant que l'éditeur est ouvert, puis reprend sa pose une fois l'éditeur fermé.

Rien n'a été enregistré ni publié.

La hiérarchie des os importée est pourtant correcte : `F001_Kael_Mesh > Root > HumanoidRootPart > LowerTorso > UpperTorso > Head…`.

Hypothèses à tester, dans cet ordre :
1. **Nœud d'armature en trop.** Le FBX d'animation contient l'objet armature `F001_Kael` au-dessus de l'os `Root`, alors que le rig importé place les os sous la pièce `F001_Kael_Mesh` : les chemins ne correspondent pas. Essai : nommer l'objet armature comme le maillage, ou exporter avec *Armature FBXNode Type* = *Root* ou *Null*.
2. **Échelle des translations.** Les déplacements d'os de l'animation sont interprétés dans une autre unité que celle du modèle (réglé en « Stud » à l'import), d'où le personnage replié. Essai : exporter les animations avec la même échelle que le modèle importé, ou réimporter le modèle avec l'échelle par défaut du FBX.
3. **Alternative sans FBX** : exporter les images-clés de Blender en données JSON, puis construire une `KeyframeSequence` dans Studio par script (poses par os). C'est plus fiable, mais demande une conversion soignée des repères.

Une fois une animation importée, il faudra la **publier** (*… → Publier sur Roblox*), ce qui crée un asset sur votre compte, puis déclarer son AnimationId réel dans `VisualAssets.Cards.F001.animations`. D'ici là, `FighterAnimator` garde les mouvements génériques.

## 6. Versionnement avec Rojo

- **Le modèle** est versionné en binaire dans `assets/Fighters/F001_Kael.rbxm`. Il contient les références vers les assets téléversés, pas le maillage lui-même. `.gitignore` le laisse passer, et `.gitattributes` traite `rbxm`, `fbx`, `glb`, `blend` et `png` comme binaires.
- **`build.project.json`** mappe `ReplicatedStorage.Assets` sur `assets/` :
  ```bash
  rojo build build.project.json -o Collectverse.rbxlx
  lune run tools/lune/check-fighter-asset -- Collectverse.rbxlx F001_Kael
  ```
  Vérifié : la place construite contient Kael, et son contrat est OK.
- **`default.project.json` ne mappe pas les assets, volontairement.** La synchronisation en direct du plugin ne sait pas définir le maillage d'une MeshPart, et risquerait d'abîmer le modèle de la place. Les instances non gérées par Rojo, comme le modèle importé, sont conservées lors de `rojo serve`.
- **Rojo 7.4.4 → 7.7.1** dans `rokit.toml` : la version 7.4.4 ne savait pas lire la propriété `Tags` des fichiers enregistrés par la version actuelle de Studio, et le build échouait.
  - Le **plugin Rojo 7.7.1** de Studio a demandé la permission de modifier les scripts du jeu. **J'ai refusé** : c'est une permission de sécurité, qui vous revient. Pour l'accorder : *Plugins → Gérer les plugins*.
  - En attendant, la synchronisation en direct fonctionne avec le binaire 7.4.4, encore présent dans Rokit, et son plugin déjà autorisé :
    ```bash
    ~/.rokit/tool-storage/rojo-rbx/rojo/7.4.4/rojo.exe serve
    ```

## 7. Variantes d'un même personnage dans l'inventaire (analyse, rien n'est modifié)

Aujourd'hui, `profile.cards[id] = nombre` et la variante est seulement **visuelle** et globale (`VisualAssets.Cards[id].variant`). Pour posséder un jour plusieurs variantes d'un même personnage (Kael standard, Kael Holo…), il faudra :

1. **Sauvegarde, schéma 2, additif.** Ajouter `profile.variants[id][variantId] = nombre`, sans toucher à `cards[id]`, qui reste le total : les combats, l'équipe et la collection restent compatibles. La migration 1 → 2 crée une table vide. `ProfileSchema.reconcile` vérifie que chaque variante est connue et que la somme ne dépasse pas `cards[id]`.
2. **Équipe** : ajouter `profile.teamVariants[slot] = variantId`, une préférence d'affichage validée par le serveur (variante possédée). `TeamRules` n'est pas concerné.
3. **Attribution** : `BoosterLogic` (ou une autre source) tire la variante côté serveur. Un tirage de variante doit avoir des **taux publiés**, comme les raretés. `Inventory.grant` renvoie la variante obtenue.
4. **Registre visuel** : clé `id` et sous-table `variants[variantId] = { art, model, animations }`, avec repli vers l'entrée de base. `ModelFactory.build(id, { variant })` et `CardTile.create(card, { variant })` existent déjà côté interface.
5. **Interface** : la Collection affiche les variantes possédées d'une carte, et le Team Builder propose de choisir la variante équipée.
6. **Tests** : migration 1 → 2 sans perte, réparation des incohérences, variante non possédée refusée en équipe, taux de variante publiés.

## 8. Tests

| Exécution | Résultat |
|---|---|
| Lune | **124 réussis, 0 échec** (les nouvelles specs Studio ne s'exécutent pas sous Lune) |
| Studio, avec le vrai modèle de Kael dans la place | **141 réussis, 0 échec** (137 avant) |
| selene, StyLua, vérification statique | Conformes |
| `check-fighter-asset` sur le `.rbxm` et sur la place construite | Contrat OK |
| Validation Blender (`kael_report.json`) | `valide = True` |

Ajouts :
- **`FighterAssetPrepSpec`** (4, Studio) : pivot aux pieds, soudure, Animator, orientation, contrat ; relance sans effet ; conflit pièce/os refusé ; ancien pivot `Root` renommé.
- **`ModelFactorySpec`** : utilise désormais un dossier d'assets isolé.
- **`VisualAssetsSpec`** : prend en compte le nom de modèle de Kael.

**Systèmes de combat et de collection** : toutes les specs existantes passent (moteur, IA, boosters, sauvegardes, équipe, invocations). Un combat a été lancé et un tour joué avec le vrai modèle.

## 9. Étapes manuelles restantes

1. **Animations dans Roblox** : lever l'échec d'import (§ 5, hypothèses 1 à 3), importer les 7 animations, les **publier** et déclarer leurs AnimationId réels.
2. **Vérifier en combat** que chaque action joue son animation (`FighterAnimator`) et que l'Idle tourne en boucle.
3. **Permission du plugin Rojo 7.7.1** (*Plugins → Gérer les plugins*), puis revenir à un seul serveur Rojo 7.7.1.
4. **Version artiste du modèle**, selon `KAEL_SPEC.md`, en gardant les mêmes noms d'os, la même palette ou une texture dédiée, et les mêmes vérifications (rapport Blender, `FighterAssetPrep`, `check-fighter-asset`).
5. **Illustration officielle de Kael** : téléverser l'image, puis déclarer `art = "rbxassetid://<id réel>"`.
6. **Vrai téléphone** : lisibilité du modèle à petite taille et coût d'affichage dans l'arène.
7. **Contrôle de modération** des assets téléversés : maillage et texture, sur le Creator Dashboard.
