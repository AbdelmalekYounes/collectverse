# Kael Anime Fantasy : finalisation avant intégration (V0.2.5)

Ce document fait suite à [KAEL_ANIME_FANTASY_STUDIO_VALIDATION.md](KAEL_ANIME_FANTASY_STUDIO_VALIDATION.md), à partir du commit `79110bf`.

Les captures citées viennent de Roblox Studio, dans la place de test : `art/kael/anime_fantasy/build/sheets/studio_finalisation.png`, avec les captures brutes dans `build/studio/`.

## État

**Prêt pour l'intégration, sous réserve de deux points :**

- la mesure sur un vrai téléphone (§ 4), que je ne peux pas faire ;
- votre autorisation pour publier les 7 animations et remplacer le modèle de production (§ 6).

| Point | Résultat |
|---|---|
| Intersection cape/bras de Skill | **Corrigée** : trajectoire des bras ; les 6 autres animations sont identiques octet pour octet |
| LOD | **Testé** dans Studio : rig, contrat et 7 animations conformes ; −61 % de triangles pour Kael, rendu quasi identique à distance de combat |
| Stratégie de LOD | **Préparée dans le code** : `ModelFactory` choisit `F001_Kael_LOD` en effets réduits, sinon le modèle principal |
| Plaque centrale | **Corrigée** dans le jeu : aucun ennemi n'est plus masqué. Vérifié en vrai combat, sur PC et mobile, avec la sélection au toucher |
| Performances mobiles | **Non mesurées sur téléphone** (pas d'appareil accessible). Sonde de mesure ajoutée et protocole prêt (§ 4) |
| Production (`assets/Fighters/F001_Kael.rbxm`) | **Inchangée**. Répétition à blanc du remplacement réussie (§ 6) |
| Animations publiées | **Aucune nouvelle publication** |

## 1. Correction de Skill

### Diagnostic

Nouvel outil `art/kael/anime_fantasy/af_cape_check.py`. À **chaque image** des 7 animations, sur le maillage réellement déformé par le rig, il compte les paires de triangles bras/cape qui se coupent (`BVHTree.overlap`), séparément pour chaque bras.

Les contacts déjà présents au repos (col, fermoirs, épaulières posées contre la cape : 41 paires, invisibles) sont exclus. Seules les traversées nouvelles comptent.

| Skill, avant | Images | Paires (gauche / droite) |
|---|---|---|
| Montée des bras | 2 à 7 | 1 à 17 |
| Bras tendus pendant la rotation | **8 à 29** | **17 / 28 à 29** |
| Retour | 30 à 36 | 1 à 19 |

**Localisation** (`cape_where`, au repos) :

- **Côté bras** : le haut des brassards (armure, os `UpperArm`), à la hauteur 5,6 à 5,7 et à ±0,6 stud de l'axe.
- **Côté cape** : le tombé sur l'épaule, entièrement pesé sur `UpperTorso`, à la hauteur 5,2 à 5,5, à ±0,4 et 0,3 stud derrière.

**Cause : la trajectoire du bras.** En écartement pur à 80–85° (roulis seul), le bord supérieur du brassard pivote vers le haut et l'arrière, à travers le tombé de cape. La cape est rigide sur l'épaule, ce qui est voulu : elle a le même placement dans toutes les animations.

Ni les poids ni la cape ne sont en cause. Les modifier aurait changé les 7 animations et imposé un nouvel import du maillage.

### Correction

Elle est locale, dans `kael_af_build.SKILL_ARMS`, sous forme de surcharge propre à cette version, comme celle de la Défense. Seules les images-clés 8, 20 et 30 de Skill changent :

| Image-clé | Bras droit (avant → après) | Bras gauche (avant → après) |
|---|---|---|
| 8 | (0, 80, 0) → (−40, 62, 0) | (0, −60, 0) → (−40, −45, 0) |
| 20 | (0, 85, 0) → (−40, 66, 0) | (0, −60, 0) → (−40, −45, 0) |
| 30 | (0, 60, 0) → (−30, 45, 0) | (0, −40, 0) → (−30, −28, 0) |

Les angles sont dans les axes du personnage (tangage, roulis, lacet). Les bras se lèvent un peu vers l'avant et s'écartent un peu moins : même rotation et même lecture, mais la cape reste derrière les bras.

Trois variantes ont été mesurées :

| Variante | Pire image (paires) | Somme sur la piste |
|---|---|---|
| Avant | 46 | — |
| Tangage −30° | 17 | — |
| **Tangage −40° (retenue)** | **16** | **232** |
| Tangage −45° | 17 | 243 |

`af_rebuild_actions.py` reconstruit les 7 actions dans le `.blend` sans toucher au maillage, aux poids, aux textures ni aux exports du modèle. Le recalage au sol donne les mêmes valeurs qu'avant.

### Résultats

| Animation | Pire avant | Pire après | Commentaire |
|---|---|---|---|
| **Skill** | **46** (image 8) | **16** (image 4) | Pendant la rotation : 3/3, contre 17/29. Le reste est la peau de l'épaule au ras du col de cape, sous l'épaulière, et au passage seulement (images 3–5 et 33–35) |
| Attack | 54 | 54 | Inchangé (voir les limites) |
| Ultimate | 26 | 26 | Inchangé |
| Defend | 26 | 26 | Inchangé |
| Hit | 18 | 18 | Inchangé |
| Defeat | 10 | 10 | Inchangé |
| Idle | 0 | 0 | — |

Rapport `build/animation_report.json`, pour Skill :

- **Cape dans le corps** : 9 points au plus, contre 23.
- **Étirement maximal** : 1,92, contre 2,14.
- **Épée** : 0 point dans le corps.
- **Début et fin par rapport à Idle** : 0°.

**Autres animations** : `Attack.json`, `Ultimate.json`, `Defend.json`, `Hit.json`, `Defeat.json` et `Idle.json` sont **identiques octet pour octet** à la version testée en Studio.

**Studio** :

- `KeyframeBuilder.verify` sur les modèles importés (principal et LOD) : 7 animations, 17 os, aucun manquant, écart et dérive à 0,0000.
- Poses de Skill à 0,27 s, 0,67 s et 1,0 s : bras devant la cape, aucune traversée visible (`studio_finalisation.png`, ligne 1).

**Limite connue** : dans Attack, la main gauche croise le flanc de la cape à hauteur de hanche (images 12 à 22, 54 paires). Le buste pivote de 25° et la cape, pesée sur le bassin, ne suit pas. C'est un défaut distinct, non signalé en jeu, que je n'ai pas modifié. La même méthode s'appliquerait : bras gauche avancé aux images 7 et 12.

## 2. LOD

### Import et contrôles

Le LOD a été importé dans la place de test (dossier isolé `ServerStorage.KaelBench.P3`) et préparé sous le nom `F001_Kael_LOD`, à côté du modèle principal.

| Contrôle | Principal | LOD |
|---|---|---|
| Polygones (importateur) | 13 266 | **5 199** |
| Dimensions | 3,47 × 7,27 × 3,75 | 3,42 × 7,27 × 3,66 |
| Contrat, rig | OK, Skinned, 17 os, Animator | OK, Skinned, 17 os, Animator |
| `KeyframeBuilder.verify`, 7 animations | 0,0000 | 0,0000 |
| Maillage | `rbxassetid://132517036744752` | `rbxassetid://134747344742606` |
| Texture | `rbxassetid://110697693974825` | **la même** (Roblox l'a dédoublonnée : aucune mémoire de texture en plus) |
| Fichier candidat | `build/F001_Kael_AF_candidate.rbxm`, contrat OK | `build/F001_Kael_AF_LOD_candidate.rbxm`, contrat OK |

### Comparaison visuelle (`studio_finalisation.png`, ligne 2)

- **Gros plan** : le LOD simplifie les dentelures de la lame et quelques pointes de cheveux. Le visage, l'armure et la cape sont équivalents.
- **Caméra de combat à densité 1080p et mobile** : différence à peine perceptible. Seule la lame paraît plus lisse.

### Mesures de rendu (Studio, vue de combat, 10 combattants, contour C)

| | Triangles opaques | Passe de contour (Highlight) | Appels de dessin |
|---|---|---|---|
| Sans Kael | 20 136 | 0 | 53 |
| 2 Kael, modèle principal | 46 692 (+26 556) | 26 532 | 56 + 2 |
| 2 Kael, LOD | 30 558 (+10 422) | 10 398 | 56 + 2 |

La part de Kael passe de 53 088 à 20 820 triangles, soit **−61 %**, sans appel de dessin en plus.

**Mémoire** : les modèles chargés dans la place (production, P1, P2, P3, LOD) se partagent les compteurs de Studio. La différence de mémoire entre principal et LOD n'est donc pas isolable ici ; elle fait partie du protocole téléphone (§ 4). **Temps d'image** : plafonné à 60 i/s dans Studio, il ne départage rien (§ 4).

### Stratégie de sélection (préparée dans le code)

**Roblox ne choisira pas ce LOD.** `RenderFidelity = Automatic` ne simplifie que le maillage d'une même MeshPart, selon des niveaux générés par Roblox. Mesuré : à la distance de combat, les deux Kael restent rendus à 13 266 triangles chacun.

Le choix doit donc être explicite :

- **Convention** (`VisualAssets.lodModelName`) : la variante allégée de `F001_Kael` s'appelle `F001_Kael_LOD`, dans le même dossier d'assets. Rien à déclarer.
- **Budget** (`EffectsPolicy.modelDetail`) : `"High"` en effets complets, `"Low"` en effets réduits, c'est-à-dire l'option du joueur ou une qualité Roblox réglée à 3 ou moins.
- **`ModelFactory.build(id, { detail })`** : en `"Low"`, il prend `<modèle>_LOD` s'il existe **et** respecte le contrat. Sinon il prend le modèle principal, sinon le modèle provisoire.
- **`SummonController`** transmet le budget au moment de l'invocation. La statue du Hub garde toujours le modèle principal.
- **Tant que `F001_Kael_LOD` n'est pas dans `assets/Fighters`**, rien ne change en jeu.

**Limite** : en qualité automatique, Roblox n'expose pas le niveau réel de l'appareil. Un téléphone faible en automatique reste en `"High"`, sauf si le joueur active « Effets réduits ». À réévaluer avec les mesures sur téléphone : par exemple, prendre le LOD dès qu'un appareil tactile a un petit écran. Ce n'est pas fait, faute de mesure.

## 3. Plaque centrale

### Reproduction et analyse

Nouvel outil `art/kael/anime_fantasy/plate_layout.py`. Il reprend les calculs d'`Arena`, `BattleLayout` et `UnitPlate`, projette la silhouette de chaque combattant et chaque plaque sur PC 1920 × 1080 et mobile 844 × 390, et mesure :

- la part de chaque modèle masquée par une plaque d'un autre combattant ;
- les chevauchements de plaques ;
- les conflits avec l'interface de combat (panneau du tour, boutons, barre d'ordres).

**Problème 1 (signalé)** : la caméra est derrière les alliés. La plaque d'un allié de la ligne avant, posée au-dessus de sa tête, se projette sur l'Écho qui lui fait face. Elle masque **41 %** de l'ennemi central et 33 % des ennemis latéraux.

**Problème 2 (trouvé à l'occasion)** : chaque plaque suivait la hauteur de son propre modèle. Avec des modèles de tailles différentes (Kael AF à 7,38, modèles provisoires vers 6), la plaque de l'ennemi central, plus haute, **chevauchait les deux plaques de la ligne arrière ennemie**. L'ancien `plate_check` supposait une hauteur unique et ne pouvait pas le voir.

| Placement (Kael AF au centre, modèles provisoires ailleurs) | Masquage maximal PC / mobile | Plaques qui se chevauchent | Conflit avec l'interface |
|---|---|---|---|
| Actuel : au-dessus de tous, selon la hauteur du modèle | 0,41 / 0,42 | 2 | — |
| Alliés avant sous les pieds | 0,16 / 0,19 | 2 | — |
| Tous les alliés sous les pieds | 0,10 / 0,12 | 2 | **barre d'ordres sur mobile** |
| Alliés avant abaissés (tête + 0,9) | 0,39 / 0,40 | 2 | — |
| Hauteur fixe pour tous | 0,41 / 0,42 | 0 | — |
| **Retenu : alliés avant au sol, autres à hauteur fixe** | **0,19 / 0,22** | **0** | **—** |

Avec le placement retenu, **aucun ennemi n'est masqué**. Les 19–22 % restants sont des alliés entre eux : plaques de la ligne arrière au-dessus des têtes de la ligne avant, et plaques au sol sur le haut des alliés arrière. C'était déjà le cas avant. Avec dix combattants de 7,4 studs (futurs modèles 3D) : 0,15 / 0,17, aucun chevauchement.

### Correction (appliquée)

- **`BattleLayout.plateOffset(side, row, modelHeight)`** (logique pure) :
  - allié de la ligne avant : −1,3 stud, la plaque au sol devant ses pieds ;
  - autres : `max(hauteur, 7,4) + 2,4`, une hauteur commune par ligne. Un modèle plus grand que 7,4 garde sa plaque au-dessus de sa tête.
- **`UnitPlate`** utilise cette position. Taille, clic et toucher sont inchangés : toute la plaque reste un bouton.

### Vérification dans Studio (`studio_finalisation.png`, lignes 3 et 4)

- **Vrai combat (Play), PC** : les plaques de Kael, Terra et Nox sont au sol, les ennemis entièrement visibles, aucun chevauchement avec la barre d'ordres.
- **Sélection** : un clic sur la plaque au sol de Terra la sélectionne (contour doré, panneau d'ordres de Terra).
- **Mobile 844 × 390 (émulateur)** : les plaques au sol restent au-dessus de la barre d'ordres et de la ligne d'aide.
- **Banc, 10 combattants avec Kael AF des deux côtés** : PC et mobile, effets complets et réduits avec le LOD.

## 4. Performances mobiles

**Aucune mesure sur téléphone physique** : je n'ai accès à aucun appareil. Le simulateur d'appareil de Studio ne sert ici qu'au cadrage et à la lisibilité. **Il ne mesure pas les performances d'un téléphone** : le rendu est fait par le PC (RTX 4080), et Studio plafonne à 60 i/s.

### Ce qui est prêt

**Sonde `Controllers/PerfProbe`** :

- elle est **désactivée par défaut** (`GameConfig.Debug.PerfProbe = false`) ;
- pendant chaque combat, elle enregistre la durée de chaque image côté appareil (`RenderStepped`) et affiche les i/s en direct ;
- **à la fin du combat**, elle écrit un résumé : nombre d'images, durée, moyenne, i/s, médiane, p95, p99, maximum, part des images sous 30 i/s, mémoire totale, maillages, textures, niveau d'effets, taille d'écran et type d'entrée ;
- le résumé s'affiche à l'écran (pour une capture) et dans la console développeur ;
- les calculs sont dans `Util/FrameStats`, testés sous Lune.

**Vérifiée dans Studio** :

- l'affichage en direct fonctionne ;
- le résumé de fin n'a pas été déclenché, pour ne pas finir un combat dans la sauvegarde de test ;
- la sonde a été remise à `false` ensuite.

### Protocole à suivre (par vous)

1. **Préparer une copie de test de l'expérience**, jamais l'expérience publique :
   - `GameConfig.Debug.PerfProbe = true` ;
   - pour mesurer le candidat : les fichiers `F001_Kael.rbxm` et `F001_Kael_LOD.rbxm` du § 6 dans `assets/Fighters`, et les animations du candidat déclarées (identifiants de test) ;
   - publier cette copie en privé.
2. **Appareils** : au moins un Android d'entrée de gamme (3 Go de RAM ou moins) et un iPhone récent. Batterie au-dessus de 50 %, hors charge, autres applications fermées, appareil froid.
3. **Scénarios**, rencontre 1 « Faille instable », équipe identique :

   | | Modèle | Effets |
   |---|---|---|
   | S1 | Kael V0.2.2 (production actuelle) | complets |
   | S2 | Kael AF principal | complets |
   | S3 | Kael AF, LOD | réduits (option « Effets réduits ») |
   | S4 | Kael AF principal | réduits avec LOD retiré du dossier, pour isoler l'effet du LOD |

4. **Déroulé** : jouer **3 tours** puis finir le combat. À la fin, capturer la ligne `[PerfProbe] combat : …` à l'écran. Faire **3 essais par scénario** et garder la médiane.
5. **Compléments** :
   - console développeur : touche F9, ou `/console` dans le chat. Onglet *Memory* : *PlaceMemory*, *GraphicsMeshParts*, *GraphicsTexture* ;
   - MicroProfiler : *Paramètres → MicroProfiler* sur le téléphone, puis, depuis un PC du même réseau, `http://<IP du téléphone>:1338` pour enregistrer une capture pendant la résolution d'un tour.
6. **Seuils proposés** :
   - entrée de gamme en S3 : moyenne ≥ 30 i/s et p95 ≤ 50 ms ;
   - iPhone en S2 : moyenne ≥ 55 i/s ;
   - écart de mémoire S2 − S1 inférieur à 30 Mo.
7. **Me transmettre les lignes `[PerfProbe]`**. Je les ajouterai à ce document et j'ajusterai si besoin la règle de choix du LOD (§ 2).

## 5. Vérifications avant intégration

| Élément | État |
|---|---|
| Modèle principal (passe 3) | Contrat OK (Studio et `check-fighter-asset`), 13 266 triangles, 17 os |
| LOD | Contrat OK, 5 199 triangles, 17 os, même texture |
| 7 animations | Données `AnimationData/F001_Kael_AF` (Skill corrigé). `verify` à 0 sur les deux modèles. Lues par l'Animator avec des identifiants locaux, **non publiées** |
| Effets réduits | Lumières des combattants coupées, lumière d'arène gardée, contour allié actif, LOD choisi en `"Low"` (banc) |
| Assets privés importés (place de test) | Voir le tableau ci-dessous |
| Pipeline Rojo | `rojo build build.project.json` (avec assets) et `default.project.json` : OK. Place construite : contrat de `F001_Kael` OK |
| Répétition du remplacement (§ 6) | Place construite avec le candidat en `F001_Kael` et le LOD en `F001_Kael_LOD` (copie temporaire) : contrats OK. Le dépôt n'est pas touché |
| Non-régression | Lune **132 / 132** ; Studio **159 / 159** au lancement du jeu ; selene et StyLua conformes |

### Assets privés importés

| Version | Maillage | Texture |
|---|---|---|
| V0.2.2 (production) | `138475817837268` | `80682674897701` |
| AF passe 1 | `103916033883372` | `102011508989155` |
| AF passe 2 | `137098653700179` | `70672778242914` |
| **AF passe 3 (candidat)** | `132517036744752` | `110697693974825` |
| **AF passe 3, LOD (candidat)** | `134747344742606` | `110697693974825` |

**Animations publiées** : seulement les 7 de la V0.2.3, pour l'ancien squelette, déclarées dans `VisualAssets`.

Les passes 1 et 2 ne serviront plus : vous pouvez les archiver depuis le Creator Dashboard. Je ne l'ai pas fait.

## 6. Remplacement de la production : procédure prête, non exécutée

À faire **seulement après votre autorisation explicite**, dans cet ordre :

1. **Publier les 7 animations** (Studio, place de test) :
   - `KeyframeBuilder.build` sur `ServerStorage.KaelBench.P3.F001_Kael`, avec les données `AnimationData.F001_Kael_AF` ;
   - *clic droit → Sauvegarder sur Roblox*, créateur « Moi » ;
   - vérifier chaque identifiant avec `GetKeyframeSequenceAsync` (images, boucle, priorité), comme en V0.2.3.
2. **Remplacer les fichiers du modèle** :
   - copier `art/kael/anime_fantasy/build/F001_Kael_AF_candidate.rbxm` vers `assets/Fighters/F001_Kael.rbxm` ;
   - copier `F001_Kael_AF_LOD_candidate.rbxm` vers `assets/Fighters/F001_Kael_LOD.rbxm` ;
   - l'ancien modèle reste dans l'historique Git : le retour arrière se fait par `git revert`.
3. **Mettre à jour le code** :
   - `VisualAssets.Cards.F001.animations` : les 7 nouveaux identifiants ;
   - `KeyframeBuilderSpec`, test « Kael… sur le vrai modèle » : utiliser `AnimationData.F001_Kael_AF`, puisque les données `F001_Kael` correspondent à l'ancien squelette ;
   - `VisualAssetsSpec` vérifie déjà 7 identifiants distincts.
4. **Mettre à jour la place** : remplacer `ReplicatedStorage.Assets.Fighters.F001_Kael` par le candidat et y ajouter `F001_Kael_LOD`. `default.project.json` ne synchronise pas les assets, volontairement.
5. **Vérifier** :
   - `lune run tools/lune/check-fighter-asset -- assets/Fighters/F001_Kael.rbxm` puis `F001_Kael_LOD` ;
   - tests Lune et Studio ;
   - un combat avec Kael allié et ennemi, effets complets et réduits ;
   - la statue du Hub.
6. **Repli conservé** : si un modèle manque ou n'est pas conforme, `ModelFactory` prend le modèle principal, puis le modèle provisoire. Si une animation est indisponible, `FighterAnimator` joue les mouvements génériques.

## 7. Limites restantes

- **Mesure sur téléphone** à faire (§ 4).
- **Attack** : la main gauche croise le flanc de la cape (§ 1), non corrigé.
- **Choix du LOD** limité à l'option « Effets réduits » et aux qualités 1 à 3. La qualité automatique n'est pas lisible par script (§ 2).
- **Plaques au sol** : elles recouvrent un peu le haut des alliés de la ligne arrière (10 à 12 %). Le placement des alliés diffère selon la ligne, ce qui reste lisible dans les captures.
- **Sonde de performance** : le résumé de fin de combat n'a pas été vu en conditions réelles ; seul l'affichage en direct a été vérifié.

## 8. Fichiers

| Fichier | Rôle |
|---|---|
| `art/kael/anime_fantasy/af_cape_check.py` | Intersections bras/cape image par image (`build/cape_check.json` ; avant correction : `build/cape_check_before.json`) |
| `art/kael/anime_fantasy/af_rebuild_actions.py` | Reconstruit seulement les actions du `.blend` (essais `--skill`, `--save`) |
| `art/kael/anime_fantasy/kael_af_build.py` | `SKILL_ARMS` : bras de la Compétence |
| `art/kael/anime_fantasy/plate_layout.py` | Analyse des plaques (`build/plate_layout.json`) |
| `src/client/Battle/BattleLayout.luau`, `src/client/UI/UnitPlate.luau` | Position des plaques |
| `src/shared/Visuals/VisualAssets.luau`, `ModelFactory.luau`, `EffectsPolicy.luau`, `src/client/Battle/SummonController.luau` | Choix du LOD |
| `src/client/Controllers/PerfProbe.luau`, `src/shared/Util/FrameStats.luau` | Sonde de performance (désactivée) |
| `tests/Specs/BattleLayoutSpec.luau`, `ModelFactorySpec.luau`, `VisualAssetsSpec.luau`, `FrameStatsSpec.luau` | Nouveaux tests |
| `build/F001_Kael_AF_candidate.rbxm`, `build/F001_Kael_AF_LOD_candidate.rbxm` | Candidats prêts pour le § 6 |
