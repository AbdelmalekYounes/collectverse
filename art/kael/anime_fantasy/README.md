# Kael Anime Fantasy (V0.2.5) : production du nouveau modèle

Dossier de production indépendant. Rien ici n'est chargé par le jeu : le modèle en jeu reste `assets/Fighters/F001_Kael.rbxm`. Le détail (choix, mesures, limites) est dans `docs/KAEL_ANIME_FANTASY_PRODUCTION.md`.

## Fichiers

| Fichier | Rôle |
|---|---|
| `kael_af_build.py` | Production complète : squelette, corps, tête, assemblage, poids, atlas, cuisson, animations, recalage au sol, validation, exports |
| `kael_af_parts.py` | Armure (coques épaissies), tassettes, épaulières asymétriques, bras, jambes, épée, cape |
| `kael_af_head.py` | Cheveux : calotte et 29 mèches à section contrôlée |
| `kael_af_materials.py` | Matières procédurales (Cycles), visage peint par projection, dépliage de l'atlas, cuisson, matériau final |
| `af_lib.py` | Outils de modélisation (Skin, coques, tubes, mèches, poids) |
| `paint_textures.py` | Textures peintes sources (Pillow) : yeux, sourcils, bouche, cape, lame |
| `af_render.py` | Rendus : vues studio, neutre et fil de fer, gros plans, vitrine, poses, caméra de combat |
| `af_sheets.py` | Planches : A/B/C, combat, effets, neutre, présentation, poses |
| `fbx_check.py` | Réimporte un FBX dans un Blender vierge et vérifie ce que Roblox recevra |
| `af_validate.py` | Rapport d'animation : poids éloignés, étirements, intersections cape/épée, transitions (`build/animation_report.json`) |
| `plate_check.py` | Chevauchement des plaques de combat (10 combattants, PC et mobile) |
| `flat_render.py` | Rendu à plat de la texture cuite (contrôle de l'atlas) |
| `export_pass1.py` | Exporte la passe 1 archivée en FBX (comparaison dans Studio) |
| `studio_sheets.py` | Planches des captures Studio (`build/studio/` → `build/sheets/studio_*.png`) |

## Produits (`build/`)

| Fichier | Contenu |
|---|---|
| `F001_Kael_AF.blend` | Scène éditable : rig, maillage, 7 actions, matériau final (textures intégrées) |
| `F001_Kael_AF.fbx` | Modèle principal pour Roblox : 13 540 triangles, 17 os, 1 matériau, texture couleur intégrée |
| `F001_Kael_AF_LOD.fbx` | Variante optimisée : 5 199 triangles, même rig, mêmes UV |
| `F001_Kael_AF.glb` | Même modèle en glTF binaire |
| `F001_Kael_AF_Color.png` | **Texture Roblox** (1024 × 1024) : couleur cuite, occlusion et braises intégrées |
| `F001_Kael_AF_{BaseColor,Emission,Roughness,Metalness,Normal,AO}.png` | Cartes séparées (SurfaceAppearance possible, rendus Blender) |
| `animations/*.json` | 7 animations pour `KeyframeBuilder` (format V0.2.3), pour le nouveau squelette |
| `kael_af_report.json` | Rapport de validation (géométrie, rig, poids, sol, contrôles) |
| `plate_check.json` | Contrôle des plaques de combat |
| `animation_report.json` | Compatibilité des 7 animations (passe 2) |
| `F001_Kael_AF_candidate.rbxm` | Candidat de la passe 3 préparé dans Studio (contrat OK, maillage et texture téléversés en privé). **Pas la production** |
| `studio/` | Captures réelles de Roblox Studio (validation) |
| `archive/` | Passes 1 et 2 (`.blend` aux textures intégrées, FBX, couleur, textures sources, rapports, candidat de la passe 2) |
| `renders/`, `sheets/`, `stages/` | Rendus, planches, étapes intermédiaires A et B |

## Tout reproduire (Blender 4.2 LTS, GPU conseillé pour la cuisson)

```bash
python art/kael/anime_fantasy/paint_textures.py art/kael/anime_fantasy/build/textures
blender -b --factory-startup --python art/kael/anime_fantasy/kael_af_build.py -- --out art/kael/anime_fantasy/build
blender -b art/kael/anime_fantasy/build/F001_Kael_AF.blend --python art/kael/kael_anim_export.py -- --out art/kael/anime_fantasy/build/animations --step 2
blender -b art/kael/anime_fantasy/build/F001_Kael_AF.blend --python art/kael/anime_fantasy/af_render.py -- --out art/kael/anime_fantasy/build/renders --tag af --mode views
python art/kael/anime_fantasy/af_sheets.py
```

Modes de rendu : `views`, `neutral`, `closeups`, `showcase`, `poses`, `combat` (avec masque pour le contour façon Highlight), `lineup` (arène 5 contre 5). La passe 1 est archivée dans `build/archive/F001_Kael_AF_pass1.blend` (rendus `--tag p1`). Pour comparer les anciennes versions, rendre aussi `art/kael/build/F001_Kael.blend` (`--tag v022`) et `art/kael/premium/build/F001_Kael_Premium.blend` (`--tag v2`) en `views` et `combat`. La production complète prend environ 2 min 15 s (cuisson OptiX).

Étapes intermédiaires, utiles pour retoucher les volumes sans cuire : `--stage A` (corps), `--stage B` (toutes les pièces, rendus Workbench rapides).

## Import dans Roblox (place de test, après autorisation)

> **Fait le 28/10/2026** dans la place de test : voir `docs/KAEL_ANIME_FANTASY_STUDIO_VALIDATION.md`. Le banc `Dev/ArenaBench` remplace les étapes 2 et 5 ci-dessous. Relancer Studio avant de préparer un modèle (cache des modules).

L'import téléverse un maillage et une texture : **à faire seulement avec votre accord**, et d'abord dans une place de test.

1. **Studio, importateur 3D** : importer `build/F001_Kael_AF.fbx`, avec « Rig » / « Skinned mesh » activés. La texture couleur est intégrée au FBX.
2. **Préparer le modèle, sans toucher à la production** (barre de commande, hors Play) :

   ```lua
   local Dev = game.ServerScriptService.Server.Dev
   local folder = Instance.new("Folder"); folder.Name = "KaelAFTest"; folder.Parent = game.ServerStorage
   print(require(Dev.FighterAssetPrep).prepare(workspace.F001_Kael_AF, "F001_Kael", folder))
   print(require(Dev.FighterEmberFx).apply(folder.F001_Kael, "F001"))
   ```

   Attendu : contrat valide, rig « Skinned », animable, avant vers −Z, aucun conflit de noms, 2 lumières et 1 émetteur.
3. **Vérifier** : `lune run tools/lune/check-fighter-asset -- <place> F001_Kael` sur une place enregistrée avec ce dossier.
4. **Animations** :
   1. copier `build/animations/*.json` dans `src/server/Dev/AnimationData/F001_Kael_AF/` ;
   2. lancer `KeyframeBuilder.verify` sur le modèle importé (repos ≈ 0, dérive ≈ 0) ;
   3. lancer `KeyframeBuilder.build`.

   La **publication** des 7 nouvelles KeyframeSequences demande votre autorisation : les animations publiées en V0.2.3 sont calculées pour l'ancien squelette (positions de repos différentes).
5. **Combat de test** : `ModelFactory.build("F001", { assetsFolder = folder })` ou `SummonController` avec `assetsFolder`, puis un combat avec effets complets et réduits, et le MicroProfiler.
6. **Remplacer la production** (`assets/Fighters/F001_Kael.rbxm` et `VisualAssets.F001.animations`) seulement après validation. Le repli actuel (modèle provisoire) reste en place.

## Ce qui demande encore une intervention

Voir `docs/KAEL_ANIME_FANTASY_PRODUCTION.md`, section « Limites et travail restant ».
