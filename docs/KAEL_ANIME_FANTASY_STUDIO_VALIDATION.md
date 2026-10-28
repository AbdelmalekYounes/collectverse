# Kael Anime Fantasy : validation dans Roblox Studio (Art Pass 2, puis passe 3 de texture)

Test du modèle candidat (Art Pass 2) dans la place de test « Test de Collectverse », dans l'arène réelle, avec la caméra, les plaques, l'éclairage et la politique d'effets du jeu.

Toutes les images citées sont des **captures de Roblox Studio**, pas des rendus Blender.

## Conclusion

**Corrections mineures nécessaires avant intégration.**

- **Côté technique, le candidat est prêt :**
  - import et dimensions conformes ;
  - rig skinné de 17 os, contrat validé ;
  - les 7 animations converties se jouent sans écart ni dérive sur le maillage importé ;
  - aucune plaque ne se chevauche.
- **Côté visuel, il est nettement au-dessus de la V0.2.2 en effets complets sur PC.**
- **Quatre points sont à corriger avant de remplacer la production :**
  1. **Effets réduits.** La lumière de l'arène est coupée et Kael devient presque noir de dos. Les braises de la cape disparaissent.
  2. **Lame.** Elle se lit lilas-gris, pas incandescente.
  3. **Cuir et sous-armure.** Ils virent au bleu marine sous l'ambiance violette.
  4. **Bras dans la cape.** Ils traversent brièvement la cape pendant la Compétence.

Aucun de ces points ne demande une refonte artistique. Les trois premiers se corrigent par la texture et un réglage de présentation (§ 4 et 5).

**Mise à jour après la passe 3 (retouche de texture, § 11)** :

- **Lame : corrigée.** Elle se lit orange-bronze au lieu de lilas.
- **Sous-armure et cuir : corrigés.** Ils se lisent noir chaud et brun-bordeaux au lieu de bleu marine.
- **Effets réduits : seulement améliorés.** Les flammes de l'ourlet restent visibles en gros plan, mais à la distance de combat Kael reste sombre. La texture seule ne suffit pas : il faut aussi le contour C et la lumière d'arène (§ 4).
- **Bras dans la cape : inchangé** (animation, pas texture).

**Mise à jour : contour C et lumière d'arène appliqués au jeu (§ 12)**, validés en vrai combat dans Studio.

Il reste avant l'intégration du candidat :

- le bras qui traverse la cape pendant la Compétence ;
- la mesure sur un vrai téléphone ;
- avec votre accord : la publication des 7 animations et le remplacement du modèle de production.

**Lisibilité retenue : C, un contour fin et peu opaque sur les alliés**, et la lumière de l'arène gardée en effets réduits. Le choix est expliqué au § 4.

## 1. Préservation de l'existant

| Élément | État |
|---|---|
| `assets/Fighters/F001_Kael.rbxm` (production V0.2.2) | **Inchangé** (27/10 20:43). Contrat vérifié OK après la session |
| `ReplicatedStorage.Assets.Fighters` de la place de test | Toujours un seul modèle, le V0.2.2 (maillage `138475817837268`). Un incident, corrigé, est décrit au § 7 |
| `VisualAssets`, animations publiées V0.2.3, sauvegardes, boosters, combat | Non modifiés |
| Candidats dans la place de test | `ServerStorage.KaelBench.P1`, `.P2` et `.P3` : hors de portée du jeu (`ModelFactory` ne lit que `ReplicatedStorage`) |
| Fichier candidat | `art/kael/anime_fantasy/build/F001_Kael_AF_candidate.rbxm` (passe 3) : contrat **OK** (`check-fighter-asset`). La passe 2 est archivée dans `build/archive/F001_Kael_AF_candidate_pass2.rbxm` |

### Téléversements effectués par l'importateur 3D

L'importateur a téléversé ces assets **privés** sur votre compte, nécessaires pour tester en jeu :

| Version | Maillage | Texture |
|---|---|---|
| Passe 3 | `rbxassetid://132517036744752` | `rbxassetid://110697693974825` |
| Passe 2 | `rbxassetid://137098653700179` | `rbxassetid://70672778242914` |
| Passe 1 | `rbxassetid://103916033883372` | `rbxassetid://102011508989155` |

Aucune animation n'a été publiée. Les animations du candidat sont enregistrées localement par `KeyframeSequenceProvider:RegisterKeyframeSequence`. Ces identifiants sont temporaires et valables seulement dans la session Studio.

## 2. Intégration 3D

### Import

| Contrôle (importateur, puis Studio) | Passe 2 | Passe 1 | V0.2.2 |
|---|---|---|---|
| Unité / facteur | Stud / 1 | Stud / 1 | Stud / 1 |
| Dimensions du fichier | 3,47 × **7,27** × 3,75 | 3,54 × 7,24 × 3,74 | 3,21 × 6,60 × 2,47 |
| Polygones (triangles) | **13 266** | 13 540 | 2 892 |
| Hauteur du modèle préparé (`GetExtentsSize`, pivot compris) | 7,38 | 7,38 | 6,70 |
| Contrat (`FighterAssetPrep`) | OK : Skinned, 17 os, Animator, avant vers −Z | OK | OK |
| Braises (`FighterEmberFx`) | 2 lumières, 1 émetteur, 17 os (inchangé) | idem | aucune |
| Matériau | `TextureID` couleur seule, pas de `SurfaceAppearance` | idem | idem |

**Plaques à la hauteur réelle de 7,38** (`plate_check.py`) : aucun chevauchement sur PC ni sur mobile. Toutes les plaques sont à l'écran, la plus haute à 39,6 px du haut sur mobile.

### Animations

Les JSON d'animation livrés avec la passe 2 dataient en réalité de la passe 1. En particulier, la Défense ne relâchait pas sa garde : 11 images au lieu de 16. Je les ai réexportés depuis `F001_Kael_AF.blend` et copiés dans `src/server/Dev/AnimationData/F001_Kael_AF/`.

`KeyframeBuilder.verify`, sur le modèle importé :

| Animation | Images | Os manquants | Écart au repos | Écart max | Dérive |
|---|---|---|---|---|---|
| Idle | 31 | 0 | 0,0000 | 0,0000 | 0,0000 |
| Attack | 13 | 0 | 0,0000 | 0,0000 | 0,0000 |
| Skill | 19 | 0 | 0,0000 | 0,0000 | 0,0000 |
| Ultimate | 31 | 0 | 0,0000 | 0,0000 | 0,0000 |
| Defend | 16 | 0 | 0,0000 | 0,0000 | 0,0000 |
| Hit | 8 | 0 | 0,0000 | 0,0000 | 0,0000 |
| Defeat | 21 | 0 | 0,0000 | 0,0000 | 0,0000 |

**Lecture par l'Animator** (`studio_animations.png`) : les 7 animations ont été jouées sur les deux Kael de l'arène, figées à l'instant clé puis en lecture continue (Ultime, Compétence, Attaque).

**Constats visuels** :

- **Attack** : épée levée au-dessus de la tête, puis frappe. Rien à signaler.
- **Skill** : rotation bras tendus. Vers 0,67 s, un bras traverse le bord de la cape, de façon visible mais brève. Défaut connu en Blender (23 points), confirmé.
- **Ultimate** : saut d'environ 1,5 stud, épée haute. Le personnage reste sous sa plaque.
- **Defend** : la lame verticale passe devant le visage. C'est la garde voulue.
- **Hit** : recul. Rien à signaler.
- **Defeat** : Kael finit à genoux, buste penché. La pointe de l'épée touche le sol.
- **Idle** : en boucle, sans saut visible.
- **Intersections** : aucune intersection épée/corps constatée. L'armure ne se déforme pas visiblement à la distance de combat.

**Les animations publiées en V0.2.3 restent incompatibles** avec ce squelette. Il faudra publier les 7 nouvelles séquences au moment de l'intégration, avec votre accord.

## 3. Lisibilité dans l'arène réelle

### Méthode

- **Banc d'essai** : `src/server/Dev/ArenaBench.luau`, à lancer en mode Run (F8). Il utilise la vraie arène (`Arena.build`), la caméra et le champ de vision du jeu (`BattleLayout`), les vraies plaques (`UnitPlate`), le Highlight du jeu et l'éclairage du serveur (`LightingSetup`).
- **Composition** : 5 contre 5, avec Kael au centre de chaque ligne avant. Les autres combattants sont les modèles provisoires actuels du jeu.
- **PC 1080p** : la fenêtre de Studio ne peut pas afficher 1920 × 1080 à l'échelle 1 (écran de 1920 × 1080 avec les panneaux). La vue « combat1080 » garde la caméra du jeu et resserre le champ (27,3°) pour obtenir exactement la densité de pixels d'un écran 1080p. Les captures sont donc un **recadrage central de la vraie vue de combat, à taille réelle**.
  - J'ai aussi testé l'émulateur « Android TV 1080p » de Studio (zone sûre de 1726 × 972, rapport 16:9), mais il s'affiche réduit à 64 %.
- **Mobile** : émulateur de Studio, iPhone 13 en paysage, 844 × 390 (zone sûre de 749 × 389, champ de 42°). Les captures sont agrandies × 1,37 par l'affichage.

### Résultats (`studio_combat_pc.png`, `studio_combat_mobile.png`)

| | PC 1080p, effets complets | PC, effets réduits | Mobile, complets | Mobile, réduits |
|---|---|---|---|---|
| **V0.2.2** | Petit, lisible par les bras clairs | Sombre mais lisible | Tache rouge et blanche | — |
| **Passe 1 / 2, A** | Kael allié de dos très lisible : cheveux, épaulières, cape aux flammes. L'ennemi est lisible de face mais **caché à mi-corps par la plaque du Kael allié** | **Dos presque noir, flammes de l'ourlet éteintes** | Silhouette rouge lisible, environ 70 px de haut | **L'allié se fond dans le sol** |
| **Passe 2, B** (contre-jour) | À 2,2 : invisible. À 5 : épaulières et cheveux à peine plus clairs. À 10 : effet de projecteur | **Identique à A** : lumières coupées | Pas de différence visible | Identique à A |
| **Passe 2, C** (contour) | Liseré chaud fin autour des alliés, qui détache la cape du sol sans « effet d'autocollant » | **Silhouette conservée** | Liseré d'environ 1 px, discret | **Silhouette conservée** |
| **Passe 2, C + lumière d'arène gardée en réduit** | — | **Retrouve presque le rendu complet, flammes de l'ourlet comprises** | — | — |

Les passes 1 et 2 sont indiscernables à la distance de combat. Les gains de la passe 2 (gravures, sous-mèches, fermoirs) ne se voient qu'en gros plan (`studio_versions.png`).

### Constats hors Kael (mise en page actuelle)

- **Plaque contre modèle** : la plaque du combattant allié central recouvre le bas du corps de l'ennemi central. C'était déjà le cas avec la V0.2.2. Ce n'est pas un chevauchement de plaques : `plate_check` ne le mesure pas.
- **Plaques sur mobile** : le texte des noms et des PV est minuscule.

## 4. Choix de l'éclairage : C

| Critère | A (actuel) | B (contre-jour) | C (contour fin) |
|---|---|---|---|
| Rendu | Bon en effets complets | Gain faible ; fort, il paraît artificiel | Liseré discret, chaud, à 60 % de transparence |
| Lisibilité en effets réduits | **Mauvaise** | Nulle (lumière dynamique coupée par `EffectsPolicy`) | **Bonne** |
| Mobile | Moyenne ; mauvaise en effets réduits | Nulle | Bonne |
| Coût mesuré | Référence | +10 SpotLight, +20 instances | +17 appels de dessin, +13 266 triangles par Kael |
| Mise en œuvre | — | Une lumière par combattant | Le Highlight existe déjà sur chaque modèle (`SummonController.addHighlight`) : seules la couleur et la transparence du contour allié changent |

**Recommandation, appliquée depuis (§ 12) :**

1. **Highlight des alliés** : `OutlineColor` = `#FFE3B8`, `OutlineTransparency` = 0,6, `FillTransparency` = 1.
   - Le contour corail des ennemis reste tel quel.
   - Pas de contour blanc épais.
   - La limite moteur de 31 Highlight laisse de la marge pour 10 modèles.
2. **`EffectsPolicy.Reduced`** : garder la lumière de l'arène, une seule `PointLight` sans ombre. C'est la seule mesure qui conserve les braises de la cape en effets réduits (`pc_P2_C_reduced_arenalight`).

Ces deux changements touchent la présentation de tous les combattants. Ils ont été appliqués après votre accord (§ 12).

## 5. Matériaux vus dans Roblox (`studio_closeups.png`, `studio_versions.png`)

Roblox n'applique ici que la texture couleur (`TextureID`). Les cartes de métal, de rugosité et de normales ne sont pas utilisées, et la texture n'a pas d'émission.

| Matière | Dans Studio | Ajustement de texture qui aide réellement à distance |
|---|---|---|
| **Métal de l'armure** | Rouge et or bien séparés par la teinte et les filets. Aucun reflet : à distance, il se lit comme de la peinture | Accentuer le contraste clair/sombre des arêtes dans la couleur cuite. Ou tester une `SurfaceAppearance` (métal, rugosité, normales), qui demande de téléverser 3 images de plus |
| **Tissu de la cape** | Rouge profond. Les flammes de l'ourlet sont très lisibles en effets complets et éteintes en effets réduits | Éclaircir et saturer les flammes dans la couleur (+15 à 20 % de valeur). Cela n'aide qu'avec la lumière d'arène gardée |
| **Cuir et sous-armure** | Lus **bleu marine** sous l'ambiance violette (Ambient 38, 34, 70) | Réchauffer la teinte vers un brun-bordeaux et remonter un peu la valeur |
| **Cheveux** | Le meilleur rendu : rouge-orange vif, mèches et arêtes lisibles | Aucun |
| **Lame incandescente** | **Lilas-gris.** La `PointLight` de la lame éclaire les voisins, pas la lame | Cuire l'émission de la lame à pleine intensité (au lieu de ×0,5) pour une âme orange-or franche. Un maillage séparé en matériau `Neon` est l'autre option, mais il change le modèle |
| **Visage** | Lisible en gros plan (yeux ambrés, sourcils, nez). Rose chez l'ennemi : le remplissage corail du Highlight teinte la peau | Foncer légèrement les traits des yeux et des sourcils, et désaturer un peu la peau |

## 6. Performances

| Mesure (Studio, RTX 4080, vue de combat, 10 combattants) | Sans Kael | V0.2.2 | Passe 2 (A) | Passe 2 (C) |
|---|---|---|---|---|
| Triangles opaques | 15 246 | 21 054 (+2 × 2 892) | 41 802 (+2 × 13 266) | 46 692 |
| Appels de dessin opaques | 36 | 38 | 39 | 56 |
| Passe Highlight (triangles) | 0 | 2 892 (ennemi) | 13 266 (ennemi) | 26 532 (2 Kael) |
| Temps d'image moyen / p95 | — | 16,67 / 17,94 ms | 16,67 / 17,83 ms | 16,67 / 17,93 ms |
| Mémoire maillages / textures | 7,6 / 36,5 Mo pour toutes les variantes : les trois modèles sont chargés dans la place | | | |

**Ce que ces chiffres ne montrent pas** :

- Studio plafonne à 60 images/s, donc le temps d'image ne départage rien sur cette machine.
- Les temps CPU et GPU de rendu ne sont pas lisibles par script (0 renvoyé).
- **Aucune mesure sur un vrai téléphone.**
- La variante allégée LOD (5 199 triangles) n'a pas été importée.
- Avec `RenderFidelity` réglé sur `Automatic`, les deux Kael restent rendus à 13 266 triangles à la distance de combat.

Avec 10 combattants de ce niveau, on atteindrait environ 130 000 triangles, plus environ 65 000 pour les Highlight ennemis. Il faudra donc mesurer sur téléphone et prévoir le LOD avant de généraliser.

## 7. Bugs et incidents constatés

1. **Cache de modules dans Studio**, corrigé.
   - Studio a exécuté une ancienne version de `FighterAssetPrep`, chargée plus tôt dans la session : elle ignorait le dossier de destination et nommait le pivot `Root`.
   - Le candidat a donc été rangé une minute à côté de la production dans `ReplicatedStorage`. Je l'ai déplacé aussitôt et la production a été vérifiée intacte.
   - J'ai repréparé le modèle avec une copie fraîche du module : pivot `AssetPivot`, contrat OK.
   - La mise en garde est maintenant dans `ArenaBench.prepare`.
2. **JSON d'animation de la passe 1** livrés comme ceux de la passe 2 : réexportés (§ 2).
3. **Bras dans la cape** (Compétence) et **pointe de l'épée au sol** (Défaite) : toujours présents.
4. **Plaque allié/ennemi central** : la plaque cache l'ennemi central (§ 3). Ce défaut existait déjà avant le candidat.
5. **Place de test collaborative** : un message de Studio signale l'échec d'un enregistrement collaboratif (HTTP 500), passager.

## 8. Tests exécutés

| Exécution | Résultat |
|---|---|
| Lune (`tools/lune/run-tests`) | 128 réussis, 0 échec |
| Studio, au lancement de la simulation (place de test, banc et données AF présents) | 153 réussis, 0 échec |
| `KeyframeBuilder.verify`, 7 animations, modèle importé | Écart et dérive à 0,0000 |
| `check-fighter-asset` : candidat / production | OK / OK |
| `plate_check.py` (hauteur 7,38) | Aucun chevauchement |
| selene, StyLua, `rojo build` | Conformes |

## 9. Reproduire

1. Exporter la passe 1 (comparaison seulement) :
   ```
   blender -b art/kael/anime_fantasy/build/archive/F001_Kael_AF_pass1.blend --python art/kael/anime_fantasy/export_pass1.py
   ```
2. Studio, **relancé au préalable** à cause du cache des modules : importer `build/F001_Kael_AF.fbx` (Stud, facteur 1), puis dans la barre de commande :
   ```lua
   require(game.ServerScriptService.Server.Dev.ArenaBench).prepare(workspace.F001_Kael_AF, "P2")
   ```
3. Lancer la simulation avec **F8**, puis dans la barre de commande :
   ```lua
   _G.B = require(game.ServerScriptService.Server.Dev.ArenaBench)
   _G.B.stage({ variant = "P2", look = "C", effects = "Reduced" })
   _G.B.camera("combat1080")
   ```
   Ensuite `B.play`, `B.pose`, `B.measure`, `B.versions` et `B.versionsCamera` donnent les animations, les mesures et la comparaison des versions. Pour le mobile, activer l'émulateur depuis l'engrenage de la vue (*GUI → Émulateur*).
4. Planches : `python art/kael/anime_fantasy/studio_sheets.py`. Les captures brutes sont dans `build/studio/`.

## 10. Prochaines étapes proposées (sur accord)

1. ~~**Retouche de texture**~~ : faite, voir § 11.
2. **Présentation** :
   - contour C sur les alliés ;
   - lumière d'arène gardée en effets réduits.
3. **Mesure sur un vrai téléphone**, et import du LOD pour comparer.
4. **Puis l'intégration** :
   - publier les 7 animations ;
   - remplacer `assets/Fighters/F001_Kael.rbxm` et `VisualAssets.F001.animations` ;
   - garder le repli actuel.

## 11. Passe 3 : retouche de texture

Géométrie, rig, poids et animations sont inchangés. Seules les textures et la couleur cuite pour Roblox changent. La passe 2 est archivée dans `build/archive/` (`.blend`, FBX, couleur, textures, rapports, candidat).

### Modifications

| Cible | Passe 2 | Passe 3 | Fichier |
|---|---|---|---|
| **Lame** | Acier bleuté ; âme orange sur 6 % de la largeur | Acier chaud ; dégradé de chaleur sur environ 70 % de la largeur ; âme incandescente sur environ 30 %, plus vive vers la garde | `paint_textures.blade` |
| **Sous-armure** | Rampe bleu-noir (`#07070E` à `#343C58`), contre-jour bleuté | Noir chaud (`#0E0807` à `#583631`), contre-jour brun | `kael_af_materials.RAMPS["Under"]` |
| **Cuir** | `#140A06` à `#764830` | Plus clair et plus chaud, `#1E0E07` à `#A06838` | idem |
| **Peau** | Rampe rosée | Moins saturée (`#946050` à `#F2D4BC`) | idem |
| **Ourlet de la cape** | Flammes `(196, 64, 18)` / `(255, 150, 50)` ; émission de l'ourlet à 0,6 | `(236, 96, 24)` / `(255, 190, 80)` ; émission à 0,85 | `paint_textures.cape`, matériau « Cape » |
| **Visage** | Paupière de 6 à 23 px, cil inférieur à 82 % d'opacité | Paupière de 9 à 29 px, plus sombre, cil inférieur opaque ; sourcils et bouche plus foncés | `paint_textures.eye`, `.brow`, `.mouth` |
| **Lueur cuite dans la couleur Roblox** | Addition à 0,5 | Superposition (screen) à 0,9 (`EMIT_WEIGHT`) | `kael_af_materials.bake` |

### Contrôles

| Contrôle | Résultat |
|---|---|
| Production Blender (`kael_af_report.json`) | `valide = True`, 13 266 triangles, LOD 5 199, hauteur 7,266, 17 os, mêmes noms |
| Réimport du FBX (`fbx_check.py`) | 17 os, 1 maillage skinné, 4 influences au plus, 1 matériau, `AtlasUV`, texture intégrée |
| Animations réexportées | Identiques octet pour octet à celles testées en Studio |
| Import dans Studio | Stud ×1, 3,47 × 7,27 × 3,75, 13 266 polygones |
| Préparation (copie fraîche de `FighterAssetPrep`) | Contrat OK, `AssetPivot`, Skinned, 17 os, avant vers −Z ; braises 2/1 |
| `KeyframeBuilder.verify`, 7 animations | 17 os, aucun manquant, écart et dérive à 0,0000 |
| Tests Studio au lancement de la simulation | 153 réussis, 0 échec |
| `check-fighter-asset` (candidat passe 3 / production) | OK / OK |

### Résultat dans Studio (`sheets/studio_pass3.png`)

| Point | Passe 2 | Passe 3 | Verdict |
|---|---|---|---|
| **Lame**, gros plan et combat | Lilas-gris | **Orange-bronze**, âme chaude visible, fils clairs gardés | Corrigé. Elle se lit comme du métal chauffé plutôt que comme une lame qui brille : Roblox n'a pas d'émission par texel |
| **Sous-armure**, face ennemie | Bleu marine | **Noir chaud, brun-bordeaux** | Corrigé : la palette rouge, noir et or tient sous l'ambiance violette |
| **Ourlet, effets complets** | Flammes orange vif | Flammes plus claires, bande jaune pâle à l'ourlet | Légèrement plus délavé ; acceptable |
| **Ourlet, effets réduits, gros plan** | Presque éteint | **Flammes visibles** | Amélioré |
| **Dos, effets réduits, caméra de combat** | Silhouette sombre | Silhouette sombre, ourlet à peine plus clair | **Pas assez** : il faut C et la lumière d'arène |
| **Visage** | Rose (remplissage corail de l'ennemi) | Quasi identique ; paupières un peu plus marquées | Peu de gain : la teinte vient du Highlight ennemi et de l'ambiance, pas de la texture |

Conclusion de la passe : les deux défauts de matière (lame, sous-armure) sont réglés par la texture seule. Le mode « effets réduits » relève de la présentation du combat (§ 4), pas du modèle.

### Téléversement

L'import a ajouté deux assets privés : le maillage `132517036744752` et la texture `110697693974825`. Aucune animation n'a été publiée.

## 12. Contour des alliés et lumière d'arène : appliqués au jeu

Les changements touchent seulement la présentation : aucune règle de combat, aucune sauvegarde, aucun asset.

### Code modifié

| Fichier | Changement |
|---|---|
| `src/client/Battle/SummonController.luau` | `SummonController.AllyOutline` : couleur `#FFE3B8`, transparence 0,6. Le Highlight d'un allié (sans teinte) prend ce contour, sans remplissage. Les Échos ennemis sont inchangés (corail, remplissage à 85 % et contour à 35 % de transparence). Nouvel attribut `BaseOutlineColor` |
| `src/client/Battle/BattleFx.luau` | `flash` rend au contour sa couleur propre (`BaseOutlineColor`) après un éclat d'impact. Avant, il reprenait la couleur de remplissage, ce qui aurait remis le contour allié en blanc |
| `src/shared/Visuals/EffectsPolicy.luau` | Nouvelle entrée `arenaLight` dans le budget, vraie en effets complets **et réduits**. `dynamicLights` ne concerne plus que les cartes et les modèles |
| `src/client/Battle/Arena.luau` | La lumière d'ambiance de l'arène suit `arenaLight` au lieu de `dynamicLights` |
| `src/server/Dev/ArenaBench.luau` | Le banc d'essai suit la nouvelle politique ; le look A y décrit l'état d'avant la V0.2.5 |

### Tests

| Exécution | Résultat |
|---|---|
| Lune | 128 réussis, 0 échec (budget : `arenaLight` vrai en effets complets et réduits) |
| Studio, lancement du jeu | **154 réussis, 0 échec** (153 avant). Nouveau test `SummonSpec` : contour d'un allié, transparence d'au moins 0,5, pas de remplissage, couleur restaurée, `DepthMode` Occluded |
| selene, StyLua | Conformes |

### Validation en vrai combat (`sheets/studio_game_outline.png`)

Le jeu a été lancé en Play dans la place de test : rencontre 1 « Faille instable », équipe du profil de test avec le Kael V0.2.2 de production.

| Contrôle | Résultat |
|---|---|
| Highlight des 5 alliés | `#FFE3B8`, contour à 0,6, remplissage à 1, actif : **5 sur 5** |
| Highlight des 5 Échos | Inchangés (corail) |
| Après un tour avec dégâts sur un allié (éclat d'impact) | Contour allié revenu à `#FFE3B8` et 0,6 |
| Option « Effets réduits » activée dans l'écran Options | Lumières des combattants : 0 allumée sur 8. **Lumière d'arène : allumée** |
| Mobile, iPhone 13, effets réduits | Silhouettes des alliés détachées par le contour, arène éclairée |

**Sauvegarde de test** : pour ce contrôle, j'ai activé l'option « Effets réduits » dans le profil de la place de test, puis je l'ai **remise à désactivée**. Les combats ont été arrêtés avant la fin : aucune récompense ni progression n'a été enregistrée.

**Coût** : le contour allié ajoute une passe Highlight par allié visible. Mesuré au § 6 : +17 appels de dessin, et la géométrie des alliés redessinée, soit +13 266 triangles par Kael AF. Un modèle provisoire ne coûte que quelques centaines de triangles. Il reste à mesurer sur un vrai téléphone.
