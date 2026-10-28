# V0.2.4 : passe artistique premium de Kael (version 0.6.3-art)

Point de départ : commit `062107b` (V0.2.3, 0.6.2-anim). Le modèle utilisé en jeu (`assets/Fighters/F001_Kael.rbxm`) **n'est pas modifié**. Tout le travail artistique est fait sur une copie, dans `art/kael/premium/`.

## Où en est-on

| Étape | État |
|---|---|
| 1. Validation finale des animations en combat réel | ✅ 7/7 jouées par de vrais événements de combat, retour à Idle, aucune piste bloquée, animations réduites vérifiées |
| 2. Modèle premium (copie) | ✅ construit, budget mobile respecté, même rig, animations identiques ; **pas encore importé dans Roblox** (téléversement à autoriser) |
| 3. Rendus avant / après | ✅ Workbench (contrôle) et Eevee (même éclairage), 4 angles, distance, toutes les images-clés |
| 4. Illustration de carte | ✅ **proposition** : rendu 3D Blender Eevee (option B), maquette CardTile ; non téléversée, aucun Asset ID |
| 5. Effets de braise côté Roblox | ✅ outil `FighterEmberFx` + budget `modelParticles` ; testés sur des copies, pas encore posés sur un asset du jeu |
| 6. Tests | ✅ Lune 128/128, Studio 153/153, Selene, StyLua, contrôle statique |
| 7. Retouches après revue (premium **v2**) | ✅ visage, épée, matières, cape, lisibilité à la taille réelle de combat ; CardTile : rareté et finition distinctes, Compact plus lisible, recadrage vérifié — voir **§ 8** |

La direction artistique a été validée dans son ensemble après la première revue. Le modèle premium décrit aux § 2 et 3 est la **v1**. Les retouches demandées ensuite ont donné la **v2**, décrite au § 8 ; c'est la version actuelle de `art/kael/premium/build/`. La v1 est archivée dans `build/archive/`.

Les cinq autres combattants n'ont pas été commencés, et ces retouches ne leur sont pas appliquées : ils attendent la validation de la v2.

## 1. Validation finale des animations (avant tout travail artistique)

### Méthode

Test en jeu dans Studio (place « Test de Collectverse », Play), avec Kael dans l'équipe face à l'Écho de Kael.

Un espion, défini dans la barre de commande côté client, relève à chaque image (`Heartbeat`) les pistes en cours sur l'Animator de chaque Kael : nom, et vitesse dans le second passage. Il n'enregistre que les changements. Rien n'est forcé : les animations sont déclenchées par les ordres de combat et par les événements du serveur.

### Résultats

| Animation | Déclencheur réel | Observé (extrait du relevé) | Retour à Idle |
|---|---|---|---|
| Attack | ordre « Taille ardente » (allié) ; attaque de l'Écho | `30.67 E2 [Attack+Idle]` → `31.78 E2 [Idle]` ; aussi sur l'allié | ✅ |
| Skill | ordre « Brasier croisé » → Kael (Écho) | `27.87 A1 [Idle+Skill]` … `29.40 A1 [Idle]` | ✅ |
| Ultimate | ordre « Nova des braises » (allié) ; ultime de l'IA (Écho) | `77.50 A1 [Idle+Ultimate]` … `79.83 A1 [Hit+Idle]` ; `56.55 E2 [Idle+Ultimate]` | ✅ |
| Defend | ordre « Garde incandescente » | `53.75 A1 [Defend+Idle]` → `54.75 A1 [Idle]` ; aussi joué par l'Écho | ✅ |
| Hit | dégâts reçus (événement `Damage`) | `28.03 E2 [Hit+Idle]` → `28.83 E2 [Idle]`, et sur l'allié | ✅ |
| Defeat | Kael allié vaincu (événement `Defeated`) | `54.43 A1 [Defeat+Hit+Idle+Skill]` → `54.57` Idle arrêtée → `55.23 A1 [Defeat]` → `56.08 A1 []` | ✅ (aucune piste ensuite) |
| Idle | invocation | présente en continu, arrêtée seulement à la défaite | — |

**Animations réduites** : l'option « Animations réduites » a été activée par le vrai menu Options, puis un combat a été lancé. On observe `A1 [Idle@1+Skill@2.5]`, `E2 [Hit@2.5+Idle@1]` et `E2 [Attack@2.5+Idle@1]`. Les actions sont jouées à la vitesse 2,5 (`REDUCED_SPEED`), la boucle d'attente reste à 1, et tout revient à Idle. L'option a ensuite été désactivée pour rendre le profil de test dans son état initial.

**Place publiée** : la place ouverte est la place de test publiée sur Roblox (« Test de Collectverse »). Les 7 animations y sont chargées par leur identifiant publié et jouées en Play. Je n'ai pas fait de test sur un serveur en ligne : il faudrait publier la place, ce qui n'a pas été demandé.

### Anomalies relevées

Aucun bug prouvé, donc aucune correction du code de combat ou d'animation.

| # | Constat | Analyse | Suite |
|---|---|---|---|
| A1 | Au premier tour, un premier espion (`Animator.AnimationPlayed`) n'a rien affiché pour Defend et Hit. | Problème d'observation : l'espion a été redéfini en cours de tour. L'espion par relevé image par image confirme ensuite Defend et Hit, aux tours 3 à 7. | Aucune |
| A2 | Hit se superpose à Skill, Ultimate ou Defeat quand un coup arrive pendant l'action. | Même priorité `Action` : Roblox mélange les deux pistes. C'est le comportement attendu, et c'est bref (0,47 s). | À surveiller à l'œil |
| A3 | Defeat : le fondu (`BattleFx.defeat`, 0,9 s + 0,5 s) finit 0,07 s après la piste (1,33 s). En mode réduit : 0,56 s pour une piste de 0,53 s. | Pendant ces 0,07 s, le modèle est déjà transparent à plus de 85 %. Aucun relèvement visible n'a été constaté. | Si on le voit un jour : figer la dernière image (`AdjustSpeed(0)`) ou avancer le fondu |
| A4 | `require` dans la barre de commande ne partage pas l'instance de module du jeu : le réglage forcé ainsi n'a eu aucun effet. | Limite de l'outil de test, pas du jeu. | Test refait par le menu Options |

## 2. Modèle premium (copie de travail)

```bash
blender -b --factory-startup --python art/kael/premium/kael_premium_build.py -- --out art/kael/premium/build
```

Le script réutilise `art/kael/kael_build.py` pour deux choses seulement, l'**armature** (`BONES`) et les **actions** (`ANIMATIONS`). Il refait tout l'habillage.

### Ce qui change

| Axe | Production (V0.2.2) | Premium (V0.2.4) |
|---|---|---|
| Silhouette | épaulières rondes, épée courte | épaulières à deux étages avec **pointes dorées**, **cape à pans de braise**, lame plus longue (3,0 au lieu de 2,6), torse plus large que profond (le pilote était l'inverse, à cause de l'orientation des anneaux) |
| Armure | coque unique, plaques cubiques | plastron sculpté avec **filets dorés en V**, col doré, cœur de braise serti, plaque abdominale, tassettes inclinées sur deux rangs, cuissards, genouillères à aileron, bottes à revers doré et coque de pied, semelle |
| Visage | yeux noirs simples | **yeux anime** : blanc, iris en dégradé ambre, pupille, deux reflets ; sourcils décidés ; nez ; sourire en coin ; mâchoire affinée |
| Cheveux | calotte et 8 cônes | calotte, masse arrière, **16 mèches courbes** (frange, mèches latérales, couronne), dégradé racine sombre → pointe dorée, rubans de bandeau, gemme frontale |
| Matériaux | 15 aplats, texture 64 × 64 | **22 cases en dégradé** (éclairage peint, lisible sous tout éclairage), texture 128 × 128 ; carte d'émission pour Blender |
| Épée | lame à 4 faces, filet de braise | lame à arête (losange), **âme de braise** sur les deux faces, garde ailée, deux gemmes, poignée filetée, pommeau à pointe de braise |
| Braises | aucune émission | émission dans Blender ; dans Roblox, couleurs vives + `FighterEmberFx` (voir § 5) |

L'identité de `KAEL_SPEC.md` est conservée : guerrier du feu, 6,6 studs environ, environ 5 têtes, cheveux en pointes orangées vers le haut et l'arrière, bandeau doré, épée main droite lame vers l'avant et le haut, tassettes et tabard. Les teintes restent dans la même famille. Elles sont plus claires et plus contrastées, car le pilote était trop sombre à distance.

### Rig et animations

| Contrôle | Résultat |
|---|---|
| Os | **17**, mêmes noms, positions, parents et orientations que la production (`sameRigAsProduction = true`, vérifié par le script) |
| Influences par sommet | **3 au plus** (budget : 4). Le pan avant suit le bassin en haut et la moyenne des deux cuisses en bas, pour ne pas traverser les jambes accroupies |
| Sommets sans poids | 0 |
| Animations | Exportées du `.blend` premium avec `kael_anim_export.py`, puis comparées aux données de production : **7/7 identiques** (écart 0, repos identique). Les 7 animations publiées s'appliquent donc telles quelles, sans republication |
| Déformation | Rendu de chaque image-clé des 7 animations, en trois quarts et de profil (`sheets/poses_after.png`) : pas d'interpénétration nouvelle. La lame qui traverse le genou dans Defeat vient de l'animation existante, elle est aussi visible sur la production |

**Faut-il modifier le maillage, les poids ou les animations ?**

- **Maillage** : oui, c'est l'objet de la passe.
- **Poids** : seulement pour les nouvelles pièces (cape, pan avant).
- **Animations** : non. Elles restent valides telles quelles.

Une seule réserve : la confirmation finale se fait dans Roblox, après import. Il faudra lancer `KeyframeBuilder.verify` sur le modèle importé : dérive ≈ 0 et écart au repos ≈ 0 attendus, car le rig est identique.

### Budget et performances

| Mesure | Production | Premium | Budget |
|---|---|---|---|
| Triangles | 2 892 | **5 858** | ≤ 6 000 |
| Sommets | 1 560 | 3 145 | — |
| Os | 17 | 17 | ≤ 20 |
| Influences max | 2 | 3 | ≤ 4 |
| Maillages / matériaux | 1 / 1 | 1 / 1 | 1 / 1 |
| Texture | 64 × 64 (536 o) | 128 × 128 (1,4 ko) | — |
| FBX | 105 ko | 179 ko | — |
| Hauteur / largeur | 6,6 | 6,75 / 3,33 studs | ≈ 6,5 ± 0,6 |
| Effets en jeu | aucun | 2 PointLight + 1 émetteur (6 particules/s, 1,4 s de vie au plus, soit environ 8 à l'écran), tous coupés en « Effets réduits » | — |

Triangles par pièce : cheveux 956, armure 788, épaulières 688, bras 608, visage 468, bottes 432, épée 402, tête 348, cape 304, braises 292, torse 196, jambes 160, ceinture 156, pan 60.

Ce qui n'est **pas encore mesuré** : le coût réel dans Roblox (mémoire du maillage, images par seconde sur mobile), parce que le modèle n'est pas importé. Le double des triangles reste faible devant le budget d'une scène de combat. À mesurer avec le MicroProfiler après import.

## 3. Rendus

Tous dans `art/kael/premium/build/` :

| Fichier | Contenu |
|---|---|
| `sheets/compare_lookdev.png` | **Avant / après**, même scène Eevee : face, trois quarts, profil, dos |
| `sheets/compare_workbench.png` | Avant / après, rendus de contrôle Workbench identiques à ceux de la V0.2.2 |
| `sheets/compare_distance.png` | Vignettes 96 × 120, la taille d'un combattant sur mobile, agrandies sans lissage |
| `sheets/poses_after.png` | Toutes les images-clés des 7 animations (premium) |
| `renders/` | Contrôle Workbench premium (4 vues, une pose par animation, planche) |
| `lookdev/` | Rendus Eevee individuels `before_*` et `after_*` |

```bash
blender -b art/kael/build/F001_Kael.blend --python art/kael/premium/lookdev_render.py -- --out art/kael/premium/build/lookdev --tag before
blender -b art/kael/premium/build/F001_Kael_Premium.blend --python art/kael/premium/lookdev_render.py -- --out art/kael/premium/build/lookdev --tag after --poses
python art/kael/contact_sheet.py art/kael/premium/build
python art/kael/premium/compare_sheet.py
```

Les rendus Workbench sont des **contrôles de modèle**, pas des illustrations.

## 4. Illustration de carte : proposition (option B)

```bash
blender -b art/kael/premium/build/F001_Kael_Premium.blend --python art/kael/premium/card_render.py -- --out art/kael/premium/build/card
python art/kael/premium/card_mockup.py
```

**Mise en scène** (rendu Eevee 1024 × 1280, portrait) :

- **Pose et cadrage** : pose héroïque construite sur les os du rig ; caméra basse, profondeur de champ.
- **Lumières** : lumière de braise portée par la lame, contre-jours cyan et violet de la Faille.
- **Effets** :
  - langues de feu autour de la lame ;
  - braises en suspension, écartées du visage ;
  - anneau de la Faille en halo ;
  - brume volumétrique, halo et vignettage.

| Fichier | Contenu |
|---|---|
| `card/F001_Kael_card_proposal.png` | L'image, 1024 × 1280 |
| `card/card_crop_guides.png` | La zone affichée par CardTile. La fenêtre d'illustration a un rapport de 1,108 (0,86 × 112 / 0,55 × 158) en `ScaleType.Crop` : toute la largeur, et la bande centrale de 1024 × 923. Tête, lame et buste y tiennent ; pieds et pointes de flammes sont en débord |
| `card/card_mockup.png` | La carte simulée aux trois classes de taille du jeu : Large 336 px, Standard 150 px, Compact 100 px (vignettes d'équipe, mobile). Le recadrage est proportionnel, donc identique sur PC et mobile |
| `card/F001_Kael_Card.blend` | La scène de l'illustration, pour retouche |

**Limites, à dire clairement** :

- c'est un **rendu 3D du modèle de jeu**, pas une illustration peinte : le niveau de détail reste celui d'un modèle mobile ;
- c'est une **proposition de direction** (pose, lumière, palette, composition), qui peut servir de base à une version peinte (option A ou artiste) ;
- **rien n'est téléversé** et `VisualAssets.F001.art` n'est pas renseigné.

## 5. Effets de braise côté Roblox

- **`src/server/Dev/FighterEmberFx.luau`** (outil de production) : pose sur les **os existants** une PointLight de lame et des braises (`ParticleEmitter`) sur `RightHand`, et une PointLight de cœur sur `UpperTorso`.
  - Un Bone est une Attachment : les effets suivent les animations sans ajouter d'os ni de pièce.
  - La texture des particules est intégrée au client Roblox (`rbxasset://`), elle ne demande aucun téléversement.
  - L'outil est idempotent (préfixe `EmberFx_`) et signale les os manquants.
- **`EffectsPolicy`** : nouveau budget `modelParticles` (Full : oui, Reduced : non).
- **`GraphicsQuality.applyToModel`**, déjà appelée à chaque invocation, coupe désormais aussi les `ParticleEmitter` des modèles quand le budget l'exige, en plus des lumières.

Rien n'est encore posé sur un asset du jeu : l'outil servira au moment d'importer la copie premium.

## 6. Tests

| Suite | Résultat |
|---|---|
| Lune (`lune run tools/lune/run-tests`) | **125/125**. `VisualAssetsSpec` vérifie en plus le nouveau budget `modelParticles` |
| Studio (Play) | **150/150**. Les 146 tests existants, plus 4 nouveaux dans `FighterEmberFxSpec` : effets posés sur les os sans os ni pièce ajoutés, idempotence et retrait, os manquant signalé, et sur une **copie** du vrai Kael (17 os conservés, `validateAsset` valide, toujours animable) |
| Selene, StyLua, `tools/static_check.py` | 0 erreur |
| Contrôles du modèle premium (`kael_premium_report.json`) | `valid = true` : budget, même rig, influences, poids, pieds au sol, hauteur |
| Animations | 7 fichiers exportés du `.blend` premium identiques à `src/server/Dev/AnimationData/F001_Kael` |

Ce qui n'a pas été testé : le modèle premium **dans Roblox**. Il n'est pas importé, puisque l'import téléverse un maillage et une texture.

## 7. Ce qui reste, et ce qui demande votre accord

1. **Valider la direction artistique** : modèle (`compare_lookdev.png`) et illustration (`card_mockup.png`).
2. **Import de la copie dans Studio** (téléversement du maillage et de la texture : **autorisation nécessaire**) :
   1. importer `F001_Kael_Premium.fbx` ;
   2. `FighterAssetPrep.prepare(model, "F001_Kael", dossier de test)` ;
   3. `FighterEmberFx.apply(model, "F001")` ;
   4. `check-fighter-asset` ;
   5. `KeyframeBuilder.verify` avec les 7 animations ;
   6. combat de test avec `assetsFolder` (copie isolée) ;
   7. mesures MicroProfiler.

   Le `.rbxm` de production ne sera remplacé qu'après cette validation.
3. **Illustration** : version finale (peinte, ou rendu retouché), puis téléversement (**autorisation nécessaire**) et renseignement de `VisualAssets.F001.art`.
4. **`KAEL_SPEC.md`** : mettre à jour la palette (22 cases dégradées, 128 × 128) une fois la direction validée.
5. Les **cinq autres combattants**, sur le même modèle (`kael_premium_build.py` comme base), après validation.

## 8. Retouches après revue : premium v2

Revue des rendus et de la maquette : direction validée dans son ensemble, avec cinq retouches demandées avant d'en faire le standard des six combattants. Le travail porte uniquement sur la copie premium. La production, le gameplay, le rig et les animations ne changent pas.

```bash
blender -b --factory-startup --python art/kael/premium/kael_premium_build.py -- --out art/kael/premium/build
```

### Ce qui change (v1 → v2)

| Demande | Retouche |
|---|---|
| **1. Visage** | Yeux un peu plus grands (proportions inchangées), avec un **trait de paupière** épais qui finit en pointe vers l'extérieur (code anime, lisible de loin). Iris en quatre tons, reflets repositionnés. **Sourcils** épais et cassés, bas à l'intérieur : regard décidé. **Sourire en coin** asymétrique. L'expression est fixe : le modèle n'a ni os de visage ni texture de visage interchangeable. Des expressions animées demanderaient l'un ou l'autre, ce qui n'est pas prévu dans cette passe |
| **2. Épée des braises** | Lame **plus large** (0,24 au lieu de 0,21), **renflée avant la pointe puis taillée en croc** : silhouette propre à Kael. Lame **bicolore** : arête centrale en acier forgé plus sombre, fil clair, lisible à toutes les distances. **Âme incandescente discrète**, vive près de la garde et éteinte vers la pointe (émission réduite). **Garde en flammes** : barre dorée, deux ailes et deux pointes recourbées vers la lame, gemme de braise sertie sur chaque face |
| **3. Matières** | La texture peinte distingue désormais les matières, même sous l'éclairage plat de Roblox. **Métal** (armure, or, acier) : bandes franches et reflet net, aspect poli. **Tissu** (cape, pan, combinaison) : dégradé doux et sourd. **Cuir** : tons chauds mats. **Cheveux** : anneau de reflet anime sur chaque mèche et sur la calotte. Pour les rendus Blender s'ajoutent des cartes de **métal et de rugosité**, dans la même disposition que la texture. Dans Roblox, elles ne serviraient qu'avec une `SurfaceAppearance` (deux images de plus à téléverser) : à décider après validation. Sans elle, la texture peinte suffit à séparer les matières |
| **4. Cape** | **Étroite aux épaules, évasée vers le bas**, légèrement emportée vers l'arrière. **9 plis** qui se creusent en descendant. **Ourlet souple à trois pointes** au lieu de dents régulières. La lueur de braise suit l'ourlet colonne par colonne : en v1, seules les pointes longues s'allumaient. 13 × 8 points au lieu de 11 × 7 |
| **5. Taille réelle** | Nouveau rendu `combat_view_render.py`, avec la **vraie caméra de combat** : position (0, 32, 34), cible (0, 0, −1), champ vertical de 42°. Kael allié est vu de dos et en plongée, l'Écho de face, au centre de la ligne avant, sur PC 1920 × 1080 et sur mobile 844 × 390, à la taille réelle en pixels. Voir le tableau ci-dessous |

### Lisibilité à la taille réelle de combat (`sheets/compare_combat.png`)

Hauteur du personnage à l'écran, boîte englobante (épée et cheveux compris) :

| | PC 1080p | Mobile 844 × 390 |
|---|---|---|
| Allié (de dos) | ≈ 239 px | ≈ 86 px |
| Écho (de face) | ≈ 215 px | ≈ 78 px |

**Ce qui reste lisible** :

- **Sur PC** :
  - de dos : cape et ourlet lumineux, pointes dorées des épaulières, mèches, épée ;
  - de face : visage (yeux et sourcils), cœur de braise du plastron, filets dorés, pan avant, lame bicolore.
- **Sur mobile** (environ 80 px) : il reste la silhouette, c'est-à-dire mèches en pointes, épaulières à pointes, cape, épée, avec la couleur rouge et or et les points lumineux (cœur, boucle, ourlet).
  - Le détail du visage n'est plus lisible à cette taille, ni pour la production ni pour la v2. C'est une limite de taille, pas de modèle.
  - En jeu, les braises et la lumière de lame (`FighterEmberFx`) renforcent l'identification de l'épée.

**La v1 lisait mieux sur un point** : vue de dos, son ourlet de cape s'allumait sur toute la largeur. La v2 a été corrigée pour retrouver cet indice, avec une lueur qui suit l'ourlet.

**Réserve** : l'éclairage est celui du look-dev Blender, pas celui de l'arène Roblox. Ces vues sont une estimation, à confirmer dans Studio après import.

### Budget avant / après

| Mesure | Production (en jeu) | Premium v1 | Premium v2 | Budget |
|---|---|---|---|---|
| Triangles | 2 892 | 5 858 | **5 914** | ≤ 6 000 |
| Sommets | 1 560 | 3 145 | 3 185 | — |
| Os | 17 | 17 | **17** (rig identique) | ≤ 20 |
| Influences max par sommet | 2 | 3 | 3 | ≤ 4 |
| Maillages / matériaux | 1 / 1 | 1 / 1 | **1 / 1** | 1 / 1 |
| Texture de couleur (Roblox) | 64 × 64, 15 cases (536 o) | 128 × 128, 22 cases (1,4 ko) | **128 × 128, 23 cases (1,6 ko)** | — |
| Textures Blender seulement | — | émission 128 × 128 | émission, métal, rugosité (128 × 128 chacune) | — |
| Option Roblox `SurfaceAppearance` | — | — | + 2 images 128 × 128 (métal, rugosité), non décidé | — |
| FBX | 105 ko | 179 ko | 183 ko | — |
| Effets en jeu (`FighterEmberFx`) | aucun | 2 PointLight + 1 émetteur | inchangé | coupés en « Effets réduits » |

Triangles par pièce en v2 : cheveux 916, armure 720, épée 594 (402 en v1), épaulières 584, bras 576, visage 568 (468), cape 412 (304), bottes 368, tête 340, braises 292, torse 168, jambes 160, ceinture 156, pan 60.

Les triangles ajoutés à l'épée, au visage et à la cape ont été repris sur des pièces peu visibles en combat : rivets d'épaulières retirés, anneaux, plastron, dossière, torse et masse arrière des cheveux un peu moins subdivisés.

### Rig et animations (v2)

- **Rig** : 17 os, identiques à la production (`sameRigAsProduction = true`).
- **Animations** : exportées du `.blend` v2, elles sont **identiques** aux 7 animations de production (comparaison octet par octet). Les animations publiées restent valables.
- **Déformation** : toutes les images-clés ont été rendues (`sheets/poses_after.png`), sans nouvelle interpénétration. La cape plus évasée suit l'accroupi de l'Ultime et la chute de la Défaite.

### Planches comparatives (mêmes angles, même éclairage)

| Fichier | Contenu |
|---|---|
| `sheets/compare_lookdev.png` | **Production / v1 / v2**, scène Eevee identique : face, trois quarts, profil, dos |
| `sheets/compare_combat.png` | **Production / v1 / v2** par la caméra de combat, taille réelle sur PC et mobile (agrandie × 3 sans lissage) |
| `sheets/compare_workbench.png` | Production / v2, contrôle Workbench |
| `sheets/compare_distance.png` | Production / v2, vignettes 96 × 120 |
| `sheets/poses_after.png` | Toutes les images-clés, v2 |

La v1 est rendue à partir de `build/archive/F001_Kael_Premium_v1.blend`, textures intégrées, avec les mêmes scripts :

```bash
blender -b art/kael/premium/build/archive/F001_Kael_Premium_v1.blend --python art/kael/premium/lookdev_render.py -- --out art/kael/premium/build/lookdev --tag v1
blender -b <fichier.blend> --python art/kael/premium/combat_view_render.py -- --out art/kael/premium/build/lookdev --tag <before|v1|after>
python art/kael/premium/compare_sheet.py
```

### CardTile

L'illustration est **conservée telle quelle comme proposition** (`card/F001_Kael_card_proposal.png`, rendue avec la v1). Elle n'est pas refaite ni téléversée : `card_render.py` rendrait aujourd'hui la v2.

Le composant du jeu `src/client/UI/CardTile.luau` a été retouché (présentation seulement) :

| Demande | Retouche |
|---|---|
| **Rareté Commune ≠ finition Holo** | Avant : un seul libellé « COMMUNE · HOLO » en bas de carte, dans la couleur de la rareté. En Compact, ce libellé était masqué, si bien que la finition disparaissait. Maintenant, la **rareté** se lit par le cadre, les gemmes et le libellé « COMMUNE » seul en bas de carte. La **finition** a sa propre **pastille irisée « HOLO »** dans le coin haut gauche de l'illustration, plus le reflet. La pastille est visible à toutes les tailles, Compact compris (attribut `Finish` sur la carte) |
| **Lisibilité du Compact** | Mise en page propre (`CardStyle.CompactLayout`) : illustration plus haute (0,60 au lieu de 0,55), nom plus haut (0,15 au lieu de 0,10, texte jusqu'à 15 px), **élément seul** en sous-titre (« Feu » au lieu de « Feu · Guerrier », illisible à 100 px). La classe de taille est déduite de la **largeur réellement affichée** (`AbsoluteSize`, hors agrandissement du survol), et non plus de la taille déclarée. Les vignettes de la liste de l'écran Équipe, rétrécies par leur grille, restaient en Standard avec un texte minuscule ; elles passent maintenant en Compact |
| **Recadrage** | Règle écrite dans `CardStyle` : illustration source au format **portrait 4:5**, sujet dans la **bande centrale de 70 %**. Part de la hauteur visible : Standard et Large 72 %, Compact 77 % (tests). `card/card_crop_guides.png` montre les deux fenêtres et la bande de sécurité sur la proposition : tête, lame et buste y tiennent |
| **Aucun chevauchement** | Tests sur chaque classe de taille : les gemmes sont centrées sur le bas de l'illustration et entièrement au-dessus du nom ; nom, sous-titre et pied se suivent sans se recouvrir, dans la carte ; la pastille HOLO reste dans l'illustration, loin du badge de quantité |

**Vérifié dans Studio (Play)** :

- **Collection** (grille Standard et grande carte) : « HOLO » sur l'illustration, « COMMUNE » en bas, le badge « x5 » sans chevauchement.
- **Équipe** : ligne d'équipe et liste en Compact (nom lisible, « Feu »).

Kael n'ayant pas encore d'illustration téléversée, Studio montre le visuel de repli (initiale). L'illustration réelle n'est visible que dans la maquette `card/card_mockup.png`.

### Tests (v2)

| Suite | Résultat |
|---|---|
| Lune | **128/128** (+ 3 : mise en page sans chevauchement sur chaque taille, Compact plus lisible, recadrage 4:5 ; plus la finition distincte de la rareté) |
| Studio (Play) | **153/153** |
| Selene, StyLua, `tools/static_check.py` | 0 erreur |
| Modèle v2 (`kael_premium_report.json`) | `valid = true` |

### En attente de votre validation

1. **Valider la v2** : `sheets/compare_lookdev.png`, `sheets/compare_combat.png`, `card/card_mockup.png`.
2. **Ensuite seulement**, avec votre autorisation :
   - import de la v2 dans Studio (téléversement du maillage et de la texture) et vérifications du § 7 ;
   - choix de la `SurfaceAppearance` (2 images de plus) ;
   - illustration finale et son téléversement.
3. Les cinq autres combattants, sur la base de la v2 validée.
