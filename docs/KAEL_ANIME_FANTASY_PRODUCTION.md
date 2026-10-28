# Kael Anime Fantasy (V0.2.5) : production du nouveau modèle 3D

Nouvelle direction artistique pour Kael (F001) : héros de fantasy japonaise, adulte, élancé, en armure. C'est le prototype de référence pour les six combattants.

## État en une phrase

Un vrai modèle 3D, riggé, texturé et exporté (FBX, GLB, `.blend`), avec 7 animations reconstruites. Il passe tous les contrôles automatiques et se réimporte proprement. Il n'est **ni importé dans Roblox ni intégré au jeu** : le téléversement attend votre accord.

Il marque un changement net de proportions et d'esthétique par rapport aux versions précédentes. Il reste en revanche **en dessous de la richesse de détail de la référence** : la section 9 détaille les écarts.

| Étape | Résultat |
|---|---|
| A. Silhouette | Corps continu de 7,3 têtes, nouveau squelette (17 os, mêmes noms et hiérarchie) |
| B. Modélisation | Visage, 29 mèches, armure en coques, épaulières asymétriques, épée des braises, cape à plis |
| C. Matières | Atlas 1024 cuit sur GPU : couleur, émission, rugosité, métal, normales, occlusion |
| D. Rig et animations | Poids automatiques, 7 animations reconstruites et recalées au sol, données KeyframeSequence exportées |
| E. Roblox | FBX vérifié par réimport, LOD, plaques de combat vérifiées, guide d'import ; **import non fait** (autorisation) |
| **Art Pass 2** | Visage, mèches, gravures, matières, épée, attaches de cape, lisibilité de dos, contour testé, rapport d'animation — voir **§ 11** |

Le modèle en jeu (`assets/Fighters/F001_Kael.rbxm`), les animations publiées, le combat, les sauvegardes et les autres combattants ne sont pas touchés. Les fichiers V0.2.4 (premium V1/V2), non commités, sont conservés tels quels.

## 1. Audit de départ

- **Fichiers lus** : spécification, scripts de production et d'export, pipelines V0.2.2 et V0.2.3, `ModelFactory`, `VisualAssets`, `FighterAssetPrep`, `KeyframeBuilder`, `FighterAnimator`, `SummonController`, `build.project.json`.
- **État Git** : dernier commit `062107b` (V0.2.3) ; travail V0.2.4 présent mais non commité, laissé intact.
- **Arène** (`Arena.luau`, `BattleLayout.luau`, `UnitPlate.luau`) :
  - caméra en (0, 32, 34), champ vertical de 42° ;
  - rangées espacées de 5,5 studs ;
  - plaque de vie posée à `GetExtentsSize().Y + 2,4` au-dessus du modèle.

  Un personnage plus grand remonte donc sa plaque. Hauteur retenue : **7,24 studs** au total, cheveux compris (6,9 au sommet du crâne). Le calcul du § 7 montre qu'aucune plaque ne se chevauche.

## 2. Ancien et nouveau modèle

| | V0.2.2 (en jeu) | Premium V2 (V0.2.4) | **Anime Fantasy (V0.2.5)** |
|---|---|---|---|
| Style | chibi | chibi enrichi | **héros anime adulte** |
| Têtes de haut | ≈ 4,4 | ≈ 4,5 | **≈ 7,3** |
| Hauteur | 6,6 | 6,75 | **7,24** |
| Corps | tubes séparés | tubes séparés | **corps continu** (modificateur Skin + subdivision), taille marquée, jambes longues |
| Armure | sphères, boîtes | ellipsoïdes et filets | **coques épaissies** qui suivent le corps, filets dorés le long des bords, lames articulées |
| Visage | yeux ronds en géométrie | yeux anime en géométrie | **traits peints** (yeux en amande, iris ambre, paupière épaisse, sourcils anguleux), mâchoire marquée, nez défini |
| Cheveux | 8 cônes | 16 mèches tubulaires | **calotte + 29 mèches plates à section contrôlée**, en couches |
| Texture | 64² aplats | 128² dégradés | **atlas 1024² cuit** : volume peint, reflets d'arête, occlusion, fissures de braise |
| Triangles | 2 892 | 5 914 | **13 540** (variante optimisée : **5 199**) |

Planche : `art/kael/anime_fantasy/build/sheets/compare_ABC.png`. Même éclairage (Eevee « studio »), même caméra, même échelle pour les trois versions.

## 3. Proportions retenues

- Sommet du crâne à 6,9, tête de 0,95, soit **≈ 7,3 têtes**. Avec les cheveux : 7,24 studs.
- Hanches à 3,55 (jambes ≈ 49 % de la hauteur), épaules à 5,42 et largeur aux épaulières ≈ 2,3. Torse en V (poitrine 0,86 de large, taille 0,6).
- Bras le long du corps, légèrement écartés (pose A, environ 15°), comme le rig de production : les intentions d'animation s'appliquent sans adaptation.
- Tête moins volumineuse, cou visible, col haut.

## 4. Détails créés

- **Visage** :
  - tête en ovale adulte : mâchoire resserrée vers un menton net, face aplatie, pommettes ;
  - nez en arête, oreilles en grande partie sous les cheveux ;
  - yeux, sourcils et bouche **peints dans la texture** par projection frontale (`kael_af_materials.paint_face`), à partir de dessins vectoriels (`paint_textures.py`) : œil en amande, paupière épaisse qui finit en aile, iris ambre et orange avec anneau, pupille, deux reflets ; sourcils anguleux ; bouche discrète, expression sérieuse ;
  - le visage a sa propre zone dans l'atlas, avec 12 fois plus de surface relative.
- **Cheveux** :
  - calotte qui suit le crâne, ligne de cheveux basse sur la nuque ;
  - 29 mèches (frange, mèches latérales, couronne balayée vers l'arrière et le haut, pointes arrière, nuque) ;
  - chaque mèche a une section lenticulaire orientée par rapport au crâne (large et plate, pas un cône), se couche sur le crâne puis s'en détache ;
  - dégradé rouge sombre → rouge vif → orange → doré, avec un anneau de reflet anime.
- **Armure** :
  - plastron rouge sombre avec encolure en V, pointe basse et filets dorés en haut et en bas ;
  - dossière ; deux lames abdominales articulées ; gorgerin ; ceinture de cuir et boucle à gemme ;
  - **cristal incandescent** taillé (bipyramide), serti d'or au centre du torse ;
  - tassettes sur trois rangs de chaque côté, évasées, à bas en pointe ; pan avant en tissu bordé d'or ;
  - **épaulières asymétriques** : gauche à trois étages avec deux cornes dorées, droite à deux étages avec une corne ; canons d'arrière-bras ;
  - canons d'avant-bras, cubitières à pointe, gantelets en lames ; cuissards, genouillères à pointe, grèves galbées à arête dorée, solerets pointus à coque dorée ;
  - **fissures de braise** (Voronoi) sur une partie de l'armure.
- **Épée des braises** :
  - lame longue en **langues de flamme** (dents irrégulières sur les deux fils) ;
  - acier sombre au centre, fils clairs, **âme incandescente** qui s'éteint vers la pointe, gravures de flammes près de la garde ;
  - garde dorée à ailes et pointes recourbées, cristaux sertis, poignée sombre filetée, pommeau doré à pointe de braise ;
  - **tenue basse en diagonale** (pointe vers le sol, à l'extérieur) : elle ne masque plus le visage au repos.
- **Cape** :
  - double face, étroite aux épaules, évasée et emportée vers l'arrière ;
  - plis qui se creusent en descendant, ourlet irrégulier à trois pointes souples ;
  - extérieur rouge profond à trame de tissu, liserés dorés, **motif de flammes** et lueur le long de l'ourlet ; intérieur sombre.

## 5. Matières et textures

Chaque matière source est un shader procédural Cycles, puis tout est **cuit dans un atlas unique de 1024 × 1024** (GPU OptiX) :

- **Métal rouge et sombre** : volume peint (lumière haute et avant), reflets d'arête par la courbure, fissures de braise, métal 0,55–0,6 et rugosité 0,32–0,4.
- **Or** : rampe chaude, arêtes claires, métal 0,9, rugosité 0,22.
- **Sous-armure** : noir bleuté, trame textile, mat (rugosité 0,8).
- **Cuir** : brun chaud, grain, rugosité 0,62.
- **Cape** : texture peinte, rouge profond, flammes et lueur d'ourlet (émission), mate.
- **Cheveux** : dégradé le long de la mèche et reflet anime.
- **Lame** : texture peinte (acier bicolore, âme et gravures), émission de l'âme.
- **Peau et visage** : rampe chaude et traits peints.

Cartes cuites :

| Carte | Usage |
|---|---|
| `F001_Kael_AF_Color.png` | **Texture Roblox** (MeshPart.TextureID) : couleur, avec occlusion de contact (0,35 stud) et braises intégrées. Lisible sous l'éclairage de Roblox, qui n'a pas d'émission sur une texture simple |
| `Emission`, `Roughness`, `Metalness`, `Normal` | Rendus Blender ; dans Roblox, seulement avec une **SurfaceAppearance** (images à téléverser, non décidé) |
| `BaseColor`, `AO` | Couleur brute et occlusion, pour retouche |

Le FBX ne porte que la couleur : les autres cartes sont débranchées à l'export.

## 6. Rig et compatibilité des animations

- **Squelette** : 17 os, **mêmes noms et même hiérarchie** que la production (vérifié : `sameBoneNamesAndHierarchy`). Les **positions de repos changent** (nouvelles proportions). Root et HumanoidRootPart ne déforment rien, comme en production.
- **Poids** :
  - corps par poids automatiques (chaleur des os) : 0 sommet oublié ;
  - pièces d'armure rigides sur leur os ;
  - tassettes et pan avant fondus entre bassin et cuisses ; cape fondue entre torse et bassin ; cou entre torse et tête ;
  - au plus 4 influences par sommet, normalisées.
- **Animations** : les animations publiées en V0.2.3 **ne sont pas réutilisables telles quelles**, car leurs poses sont calculées pour l'ancien repos. Elles ont été **reconstruites** à partir des mêmes intentions (`kael_build.ANIMATIONS`, rotations dans les axes du personnage), avec les déplacements du bassin mis à l'échelle des jambes (× 1,25).
  - **Recalage au sol automatique** : à chaque image-clé, si le corps passe sous le sol, le bassin est relevé (Idle +0,02 ; Ultimate +0,40 / +0,31 ; Defend +0,31 ; Defeat +0,69 / +0,88 stud). Le sol n'est plus traversé par le corps dans aucune animation.
  - Données exportées par la chaîne V0.2.3 (`kael_anim_export.py`), dans `build/animations/`, prêtes pour `KeyframeBuilder`. **Non converties ni publiées dans Roblox** : la publication demande votre autorisation.
- **Contrôle visuel** (`sheets/poses.png`, toutes les images-clés) : déformation correcte des articulations, cape et tassettes qui suivent.
  - Avec l'épée basse : armée en haut à l'attaque, estocade vers l'avant, garde verticale en défense.
  - **Défaut connu** : à la défaite (image 15), la pointe de l'épée descend sous le sol (−0,33).

## 7. Validation à taille réelle (caméra de combat du jeu)

Rendu par la vraie caméra (`af_render.py --mode combat`), Kael au centre de la ligne avant :

| Hauteur à l'écran (boîte englobante) | V0.2.2 | Premium V2 | **Anime Fantasy** |
|---|---|---|---|
| Allié de dos, PC 1080p | 220 px | 239 px | **269 px** |
| Ennemi de face, PC | 201 px | 215 px | **239 px** |
| Allié, mobile 844 × 390 | 80 px | 86 px | **97 px** |
| Ennemi, mobile | 73 px | 78 px | **86 px** |

- **Lisibilité** (`sheets/combat_ABC.png`, `sheets/combat_effects.png`) :
  - silhouette élancée immédiatement différente ;
  - cheveux reconnaissables, de dos comme de face ;
  - cape à ourlet de flammes très lisible de dos ;
  - épée en diagonale visible ;
  - séparation armure rouge, sous-armure noire et or.
  - Sur mobile, le détail du visage ne se lit pas (≈ 10 px) : silhouette, couleurs et animations priment, comme demandé.
- **Effets complets / réduits** : complets = émission + lumières de lame et de cœur (`FighterEmberFx` en jeu) ; réduits = couleur seule. La texture porte déjà les braises, donc le personnage reste identifiable en mode réduit.
- **Plaques** (`plate_check.py`, `build/plate_check.json`) : 10 plaques, 5 contre 5, sur PC et mobile : **aucun chevauchement**, toutes à l'écran, pour 6,6 et pour 7,24 studs. La plaque la plus haute passe à 41 px du haut sur mobile (47 px en production).
- **Réserve** : l'éclairage est celui de Blender (Eevee), pas celui de l'arène Roblox. À confirmer dans Studio après import.

## 8. Coûts de rendu et rapport

| Mesure | Valeur | Cible |
|---|---|---|
| Triangles (principal) | **13 540** | 8 000–12 000 : **dépassement de 13 %** |
| Triangles (variante optimisée, réduction automatique) | **5 199** | 4 000–6 000 ✓ |
| Sommets | 7 113 | — |
| Os / influences max | 17 / 4 | ≤ 20 / ≤ 4 ✓ |
| Maillages / matériaux | 1 / 1 | ✓ |
| Texture Roblox | 1 × 1024² (1,4 Mo PNG) | « jusqu'à 1024 si justifié » |
| Effets en jeu | 2 PointLight + 1 émetteur (≈ 8 particules), coupés en « Effets réduits » | ✓ |
| Fichiers | FBX 1,9 Mo (texture intégrée), LOD 1,7 Mo, GLB 2,3 Mo, `.blend` 6,2 Mo | — |
| Production complète | ≈ 2 min 15 s (cuisson GPU OptiX, RTX 4080 SUPER) | — |

Triangles par pièce : mèches 1 560, épaulières 892, cape 596, tassettes 576, plastron 540, grèves 424, filets d'épaulières 400, cuissards 352, canons d'avant-bras 344, solerets 300, canons d'arrière-bras 280, corps 1 656, tête 520, et le reste en dessous de 260.

Optimisations déjà faites :

- biseaux géométriques remplacés par des reflets d'arête peints ;
- grilles allégées ;
- 122 faces du corps cachées sous l'armure supprimées ;
- traits du visage peints, sans géométrie.

Pour descendre sous 12 000, les pistes sont : moins de mèches (environ −300), filets en ruban plat au lieu de tubes (environ −600), cape 13 × 9. À arbitrer après le test en jeu. Le coût réel (images par seconde sur mobile, mémoire) n'est **pas mesuré** : il faut le MicroProfiler dans Studio, après import.

Rapport machine : `build/kael_af_report.json` (`valid = true`, contrôles listés).

FBX vérifié par réimport dans un Blender vierge (`fbx_check.py`) : 1 armature de 17 os aux noms attendus, 1 maillage skinné (15 groupes), 4 influences au plus, 13 540 triangles, 1 matériau, une seule couche UV `AtlasUV`, texture couleur intégrée, hauteur 7,236 ; même résultat pour le LOD (5 197 triangles).

## 9. Limites et travail restant (honnêtement)

**Écart avec la référence.** La référence est une illustration 2D très détaillée. Le modèle est entièrement construit par script, sans sculpture ni peinture manuelle. Ce qui est atteint : proportions, silhouette, palette, organisation de l'armure, cape, épée en flammes, visage anime lisible. Ce qui manque :

- **Armure** : pas de filigranes ni de gravures dorées, plaques assez lisses, épaulières moins sculptées (pas de rebords travaillés ni de lames en éventail) ;
- **Cheveux** : 29 mèches lisibles, mais moins de sous-mèches fines et de chevauchements que la référence ;
- **Mains** : gantelets simplifiés (poing et deux lames), sans doigts articulés ;
- **Visage** : lisible et mature, mais l'ombrage du nez et de la bouche reste simple ; pas d'expressions changeantes (le rig n'a pas d'os de visage) ;
- **Cape** : rigide par morceaux (torse et bassin), **sans simulation**, signalé comme demandé ; dans les grands mouvements (rotation de la Compétence), elle tourne avec le corps sans flotter ;
- **Effets** : pas d'effet de chaleur ni de flammes animées autour de l'épée dans le modèle ; en jeu, seulement les braises et la lumière de `FighterEmberFx` ;
- **Animations** : mêmes intentions que la production, recalées au sol : **fonctionnelles, pas encore spectaculaires** (pas de traînées, d'anticipation marquée ni d'effets) ; la pointe de l'épée traverse le sol à la défaite ;
- **Pieds** : 4 cm au-dessus du sol au repos (corrigé en passe 2, voir § 11).

**Interventions nécessaires** (dans l'ordre) :

1. **Votre validation** de la direction (planches `presentation.png`, `compare_ABC.png`, `combat_ABC.png`).
2. **Autorisation de téléverser** le maillage et la texture, puis import en place de test (guide dans `art/kael/anime_fantasy/README.md`).
3. Conversion des 7 animations dans Studio (`KeyframeBuilder.verify` puis `build`) et **autorisation de les publier** : elles remplaceront les identifiants de `VisualAssets` seulement après validation.
4. Test de combat en place de test (effets complets et réduits, MicroProfiler, éclairage réel), retouche des couleurs de l'atlas si l'éclairage Roblox les écrase.
5. Décision SurfaceAppearance (normales, métal, rugosité : trois images de plus).
6. Passe artiste manuelle pour combler l'écart avec la référence (filigranes, épaulières, mèches fines, mains), puis passe d'animation dédiée (chorégraphies, VFX).
7. Nouvelle illustration de carte à partir de ce modèle (l'actuelle montre l'ancien).

## 10. Tests

- **Contrôles du modèle** (`kael_af_report.json`) : 9/9 :
  - triangles ≤ 15 000 (contrôle de sécurité ; la cible 12 000 est dépassée, voir § 8) ;
  - 17 os, mêmes noms et hiérarchie, influences ≤ 4, tous les sommets pondérés ;
  - 1 matériau, pieds au sol à 5 cm près, hauteur ≈ 7, aucune pénétration du sol par le corps.
- **Réimport FBX** du modèle principal et du LOD : conforme.
- **Plaques de combat** : aucun chevauchement (PC, mobile).
- **Jeu** : aucun fichier de `src/` ni de `tests/` modifié pour cette étape, donc aucun test Luau à relancer. Les suites restent celles de la V0.2.4 (Lune 128/128, Studio 153/153).
- **Non testé** : le modèle dans Roblox (import non autorisé à ce stade).

## 11. Art Pass 2 (passe 2)

Point de départ : le modèle des § 1 à 10 (passe 1), validé comme nouvelle direction. Il est archivé dans `build/archive/F001_Kael_AF_pass1.blend`, avec ses textures intégrées, et rendu avec les mêmes scripts pour l'avant/après. **Pas de retour aux proportions cartoon** : proportions, squelette, silhouette et palette sont inchangés. Rien n'a été publié ni intégré.

### Ce qui a changé, priorité par priorité

| Priorité | Fait dans Blender | Effet mesuré ou visible |
|---|---|---|
| **1. Visage** | **Yeux redessinés** : iris strié à lueur de braise en bas, pupille étroite, trois reflets, paupière épaisse avec cils en aile, pli de paupière, cil inférieur. **Sourcils** en faisceau de traits effilés. **Nez** : ombre latérale et narines peintes ; le nez porte maintenant la même projection que le visage. **Mâchoire** plus anguleuse (joues droites, angle marqué, menton net). Expression sérieuse conservée | Gros plan : `closeups_before_after.png`. À taille réelle, les yeux se lisent sur PC (face ≈ 30 px) ; sur mobile, le visage reste une tache claire (≈ 11 px), comme attendu |
| **1. Cheveux** | Chaque mèche porte sa position en travers : **bords assombris** (séparation) et **arête éclairée** (relief) ; **5 sous-mèches** (couches intermédiaires) | Mèches mieux détachées les unes des autres |
| **2. Armure** | **Gravures** : motif doré répétable (volutes, flammes) projeté en boîte, **limité au plastron autour du cristal et aux dômes d'épaulières**. Un premier essai réparti partout lisait comme des rayures : abandonné. Fissures de braise plus rares. **Cubitières rigides** : elles n'étaient plus étirées par le coude | Armure non étirée à la pose neutre (1,0 contre 1,29) |
| **2. Matières** | Moins « plastique » : rugosité armure 0,42 / 0,48, or 0,30, lame 0,26 (contre 0,32 / 0,40 / 0,22 / 0,20). Reflets d'arête atténués (0,28). Cuir grainé et tissu tramé conservés. Palette rouge, noir et or inchangée | Reflets moins brillants, sans surexposition dans le même éclairage |
| **3. Épée** | Silhouette inchangée. **Carte d'émission peinte** : âme incandescente, plus vive près de la garde, et **fissures de braise qui partent des fils**. Intensité contrôlée (2,5) | `closeups_before_after.png` |
| **3. Cape** | **Plis irréguliers** (grands plis et plis secondaires à phase variable), **col roulé** le long du bord supérieur, **fermoirs dorés à gemme** sur le haut du torse, reliés à la cape par des **cordons** | Attaches lisibles de face ; intersections mesurées (§ suivant) |
| **4. Lisibilité** | **Contre-jour peint** : les surfaces tournées vers l'arrière et le haut sont légèrement éclaircies, **dans leur propre teinte**. Un premier essai en blanc rendait la cape sarcelle sous le contre-jour cyan : corrigé. Il ne dépend pas de l'éclairage du jeu et ne coûte rien sur mobile | Dos un peu plus détaché : col doré, épaulières |
| **4. Contour** | **Test d'un contour de silhouette** façon `Highlight` Roblox (contour seul, remplissage transparent), simulé en post-traitement à partir d'un masque du personnage (2 px sur PC, 1 px sur mobile, 55 %) | `combat_pass2.png`, `lineup_10.png` : nette amélioration de la lecture de dos et sur mobile |
| **5. Technique** | Pieds remis au sol (solerets abaissés : point bas à 0,01 au lieu de 0,04). Corps (en grande partie caché) réduit à 65 %. Filets dorés à 3 côtés | 13 266 triangles (passe 1 : 13 540) |

### Contour en jeu : recommandation (non intégrée)

Le test le plus efficace pour la lisibilité est le contour. Dans Roblox, l'équivalent est un `Highlight` sur le modèle, avec `FillTransparency = 1`, `OutlineTransparency` d'environ 0,5, une couleur chaude claire et `DepthMode = Occluded`.

- **Limite moteur** : 31 `Highlight` actifs à la fois ; 10 combattants passent.
- **Mobile** : d'après la documentation Roblox, il est disponible sur toutes les plateformes, mais son coût sur mobile n'est **pas mesuré**. À tester en place de test.
- **Repli sans coût** : le contre-jour peint, déjà dans la texture.

Je ne l'ai pas ajouté au jeu : c'est un changement de présentation à valider d'abord.

### Lisibilité parmi dix combattants (`sheets/lineup_10.png`)

Arène 5 contre 5 rendue par la caméra du jeu, sur PC 1920 × 1080 et mobile 844 × 390. Kael Anime Fantasy occupe le centre des deux lignes avant. L'ancien Kael (V0.2.2) sert de figurant aux 8 autres places, faute de modèles 3D pour les autres combattants. Les 10 plaques de vie sont dessinées à leur position calculée.

- **Silhouette** : Kael AF se distingue immédiatement (plus grand de 0,67 stud, cape à flammes de dos, épée en diagonale de face), sans écraser la composition.
- **Taille** : non agrandie artificiellement. 7,27 studs, comme prévu ; mêmes cadrage et caméra.
- **Plaques** (`plate_check.json`, recalculé à 7,27) : **aucun chevauchement** sur PC ni sur mobile, toutes à l'écran ; la plus haute est à 40,7 px du haut sur mobile (47,4 px en production).

### Rapport de compatibilité des animations (`build/animation_report.json`)

Mesuré sur le maillage réellement déformé, à chaque image-clé des 7 animations reconstruites (`af_validate.py`). Les animations publiées en V0.2.3 **ne sont pas compatibles** avec le nouveau squelette : positions de repos différentes. Ce sont les animations reconstruites qui sont testées ici.

| Animation | Images-clés | Début / fin vs Idle | Étirement corps (min / max) | Armure | Cape dans le corps (pts sur 300) | Épée dans le corps |
|---|---|---|---|---|---|---|
| Idle | 1, 31, 61 | 0° / 0° | 0,60 / 1,17 | 0,97 / 1,00 | 7 | 0 |
| Attack | 1, 8, 13, 25 | 0° / 0° | **0,17** / 2,08 (bras levé) | 0,87 / 1,14 | 5–7 | 0 |
| Skill | 1, 9, 21, 31, 37 | 0° / 0° | 0,55 / 2,14 (bras à l'horizontale) | 1,00 | **23** (image 21, rotation) | 0 |
| Ultimate | 1, 13, 27, 39, 61 | 0° / 0° | **0,20** / 2,22 (bras au-dessus de la tête) | 0,57 / 1,19 (tassettes accroupi) | 2–7 | 0 |
| Defend | 1, 9, 21, **31** | 0° / **0°** (passe 1 : fin à 97°) | 0,37 / 1,52 | 0,84 / 1,11 | 4–7 | 0 |
| Hit | 1, 5, 15 | 0° / 0° | 0,66 / 1,38 | 0,98 / 1,23 | 5–7 | 0 |
| Defeat | 1, 15, 41 | 0° / 93° (reste au sol, voulu) | 0,33 / 1,69 | 0,45 / 1,24 | 7–8 | 0 |

**Lecture du tableau** :

- **Transitions** : toutes les actions partent exactement de la pose d'attente.
  - **Défense** : elle tenait sa garde jusqu'au bout et sautait à l'attente quand Roblox coupe la piste. Elle relâche maintenant sa garde vers la pose neutre (30 images au lieu de 20).
  - **Défaite** : elle se termine au sol, voulu (l'attente est arrêtée par `FighterAnimator.stopIdle`).
- **Épée** : aucune intersection avec le corps ou l'armure, dans aucune pose. À la défaite, la pointe descend sous le sol (−0,33) : défaut connu.
- **Cape** : 7 points sur environ 300 (échantillonnés) touchent déjà la dossière et le gorgerin au repos. C'est le col roulé, posé contre l'armure : invisible. Le pic de 23 points dans la Compétence (image 21) vient des bras tendus pendant la rotation, qui traversent les bords de la cape rigide : visible brièvement.
- **Corps** : quand un bras monte au-dessus de la tête (Attack, Ultimate), la peau sous l'aisselle s'écrase (rapport 0,17–0,20) et s'étire (2,2). En grande partie caché par l'épaulière et le gorgerin.
  - Un **lissage des poids** a été essayé : il aggrave le problème (étirement × 6), donc il a été abandonné.
  - La vraie correction demanderait des morphs correctifs, que Roblox ne gère pas sur un maillage skinné, ou des os d'épaule supplémentaires, ce qui changerait le rig.
- **Tassettes** : elles s'écrasent (0,45–0,57) quand les cuisses montent (accroupi de l'Ultime, défaite). Effet de plaques articulées, acceptable.
- **Poids éloignés** : 173 sommets, tous voulus : bas de cape sur le bassin (151), longues mèches sur la tête (15), pointes et cornes rigides (7).
- **Testé depuis dans Studio** (`docs/KAEL_ANIME_FANTASY_STUDIO_VALIDATION.md`) : conversion conforme, lecture par l'Animator. Les JSON de `build/animations` dataient encore de la passe 1 ; ils ont été réexportés depuis le `.blend` de la passe 2. Publication toujours en attente de votre autorisation.

### Budget de performance (passe 2)

| Mesure | Passe 1 | **Passe 2** | Cible |
|---|---|---|---|
| Triangles (principal) | 13 540 | **13 266** | 8 000–12 000 : **dépassement de 10,6 %** |
| Triangles (LOD) | 5 199 | **5 199** | 4 000–6 000 ✓ |
| Sommets | 7 113 | 6 982 | — |
| Os / influences max | 17 / 4 | 17 / 4 | ✓ |
| Maillages / matériaux | 1 / 1 | 1 / 1 | ✓ |
| Texture Roblox | 1 × 1024² | 1 × 1024² (1,5 Mo PNG) | ✓ |
| Cartes optionnelles (SurfaceAppearance) | normales, métal, rugosité | idem | non décidé |
| Hauteur | 7,236 | 7,266 | ≈ 7 |
| FBX / LOD / GLB / `.blend` | 1,9 / 1,7 / 2,3 / 6,2 Mo | 2,0 / 1,8 / 2,4 / 6,9 Mo | — |

Ajouts de la passe (sous-mèches, col, fermoirs, cordons : ≈ +340 triangles nets, filets à 3 côtés compris) compensés par la réduction du corps caché (−459) et des épaulières un peu allégées. Réimport FBX (`fbx_check.py`) : conforme pour le modèle et le LOD (17 os, 1 maillage skinné, 4 influences au plus, 1 matériau, `AtlasUV` seule, texture intégrée).

### Limitations restantes (après la passe 2)

- **Écart avec la référence** : pas de filigranes en relief (seulement peints, et seulement sur le plastron et les épaulières), pas de mèches fines secondaires, gantelets simplifiés, ombrage du visage simple, aucune expression changeante.
- **Gravures et yeux** limités par l'atlas 1024 : légèrement pixelisés en gros plan. Un atlas 2048, ou une texture de visage séparée (deuxième maillage), améliorerait les gros plans, sans rien changer en combat.
- **Aisselles** : écrasement bras levé (voir ci-dessus).
- **Cape** : rigide par morceaux (sans simulation) ; bords traversés par les bras dans la rotation de la Compétence.
- **Défaite** : la pointe de l'épée traverse le sol.
- **Animations** : fonctionnelles, pas spectaculaires (même chorégraphie que la production, sans traînées ni effets).
- **Éclairage** : tous les rendus sont faits dans Blender. L'ourlet orange paraît verdâtre sous le contre-jour cyan du studio quand l'émission est coupée (effets réduits) : à vérifier sous l'éclairage réel de l'arène.
- **Non fait, en attente d'autorisation** : import en place de test (téléversement), conversion et publication des 7 animations, mesure MicroProfiler, test du `Highlight` en jeu.
- **Autres personnages** : pas commencés.
