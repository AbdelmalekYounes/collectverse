# Production 3D de Kael (F001)

Dossier de travail distinct du code du jeu (`src/`). Rien ici n'est chargé par le jeu : seul le modèle validé et enregistré dans `assets/Fighters/F001_Kael.rbxm` l'est (via `build.project.json`).

| Fichier | Rôle |
|---|---|
| `KAEL_SPEC.md` | Spécifications artistiques et techniques (proportions, palette, équipement, budget, rig, animations). |
| `kael_build.py` | Script Blender reproductible : maillage, texture, armature, poids, animations, exports, rendus, rapport. |
| `contact_sheet.py` | Planche de contrôle (vues et poses) à partir des rendus. |
| `kael_anim_export.py` | Export des animations en images-clés pour Roblox (V0.2.3), à partir du `.blend`, sans le modifier. Voir `docs/V023_ANIMATION_PIPELINE.md`. |
| `build/` | Résultats de la dernière production, versionnés pour pouvoir être relus sans Blender. |

## Produire

Testé avec **Blender 4.2.23 LTS**, version portable officielle de download.blender.org (empreinte SHA-256 vérifiée).

```bash
blender -b --factory-startup --python art/kael/kael_build.py -- --out art/kael/build
python art/kael/contact_sheet.py art/kael/build
```

La commande s'exécute sans interface, en environ 30 s, et produit :

- `build/F001_Kael.fbx` : modèle (maillage skinné + armature, texture intégrée), pour l'import Roblox ;
- `build/F001_Kael.glb` : même modèle en glTF binaire (format alternatif accepté par Studio) ;
- `build/F001_Kael_Palette.png` : texture palette 64 × 64 ;
- `build/animations/F001_Kael_<Animation>.fbx` : une animation par fichier ;
- `build/F001_Kael.blend` : scène Blender complète, pour retouche manuelle ;
- `build/renders/*.png` : rendus de contrôle (face, trois quarts, profil, dos, une pose par animation) et `kael_contact_sheet.png` ;
- `build/kael_report.json` : rapport de validation (budget, os, influences, sommets sans poids, pieds au sol, hauteur).

La production s'arrête en signalant `valide = False` si un critère du budget n'est pas respecté.

## Animations pour Roblox

Les FBX d'animation ne sont pas importés dans Roblox : l'éditeur d'animation n'y associait aucune piste. Les animations sont exportées en données, puis converties en `KeyframeSequence` dans Studio :

```bash
blender -b art/kael/build/F001_Kael.blend --python art/kael/kael_anim_export.py -- --out src/server/Dev/AnimationData/F001_Kael --step 2
```

La suite (vérification, construction, publication) est décrite dans `docs/V023_ANIMATION_PIPELINE.md`.

## Importer dans Roblox

Voir `docs/V022_KAEL_PIPELINE.md`, section « Import Roblox Studio » : importateur 3D, `FighterAssetPrep`, vérification, enregistrement du `.rbxm`.

## Réutiliser pour un autre combattant

Le script est paramétré par ses constantes : `PALETTE`, `BONES`, `ANIMATIONS` et les fonctions de construction (`build_character`). Pour un nouveau combattant :

1. copiez `kael_build.py` ;
2. changez la palette et la silhouette ;
3. gardez la même armature R15 et les mêmes vérifications.

Les outils côté Roblox (`FighterAssetPrep`, `check-fighter-asset`) sont génériques.
