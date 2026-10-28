# Kael premium (V0.2.4) : copie de travail

Rien ici n'est chargé par le jeu. Le modèle de production reste `assets/Fighters/F001_Kael.rbxm`, produit par `../kael_build.py`. Le détail (choix, mesures, validations, suite) est dans `docs/V024_KAEL_ART_PASS.md`.

| Fichier | Rôle |
|---|---|
| `kael_premium_build.py` | Modèle premium : reprend l'armature et les animations de `kael_build.py`, refait tout l'habillage (texture 128 × 128 en dégradés). Produit FBX, GLB, `.blend`, textures, rendus de contrôle, `kael_premium_report.json`. |
| `lookdev_render.py` | Rendus Eevee identiques pour n'importe quel `.blend` de Kael (`--tag before` / `after`), vignettes à distance, `--poses` pour toutes les images-clés. |
| `combat_view_render.py` | Kael vu par la vraie caméra de combat, à sa taille réelle sur PC et mobile. |
| `compare_sheet.py` | Planches comparatives production / v1 / v2 (`build/sheets/`). |
| `build/archive/` | Premium v1 (direction validée), `.blend` aux textures intégrées, pour les comparaisons. |
| `card_render.py` | Proposition d'illustration de carte (rendu Eevee, portrait 1024 × 1280). L'image conservée a été rendue avec la v1. |
| `card_mockup.py` | Zone de recadrage CardTile et maquette de la carte aux trois tailles du jeu. |

## Tout reproduire (Blender 4.2 LTS)

```bash
blender -b --factory-startup --python art/kael/premium/kael_premium_build.py -- --out art/kael/premium/build
python art/kael/contact_sheet.py art/kael/premium/build
blender -b art/kael/build/F001_Kael.blend --python art/kael/premium/lookdev_render.py -- --out art/kael/premium/build/lookdev --tag before
blender -b art/kael/premium/build/F001_Kael_Premium.blend --python art/kael/premium/lookdev_render.py -- --out art/kael/premium/build/lookdev --tag after --poses
blender -b art/kael/premium/build/archive/F001_Kael_Premium_v1.blend --python art/kael/premium/lookdev_render.py -- --out art/kael/premium/build/lookdev --tag v1
blender -b <fichier .blend> --python art/kael/premium/combat_view_render.py -- --out art/kael/premium/build/lookdev --tag <before|v1|after>
python art/kael/premium/compare_sheet.py
blender -b art/kael/premium/build/F001_Kael_Premium.blend --python art/kael/premium/card_render.py -- --out art/kael/premium/build/card
python art/kael/premium/card_mockup.py
```

## Vérifier que les animations publiées restent valables

```bash
blender -b art/kael/premium/build/F001_Kael_Premium.blend --python art/kael/kael_anim_export.py -- --out <dossier temporaire> --step 2
```

Puis comparer les 7 JSON avec `src/server/Dev/AnimationData/F001_Kael/` : ils doivent être identiques (vérifié en V0.2.4).

Les rendus de chaque image-clé (`build/lookdev/*_poses/`) ne sont pas versionnés : ils sont résumés dans `build/sheets/poses_after.png`.
