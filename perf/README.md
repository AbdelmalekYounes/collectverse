# Test privé de performance de Kael (branche `test/kael-af-perf`)

Branche de test, à ne jamais fusionner dans `main`. Procédure complète : [docs/KAEL_ANIME_FANTASY_TEST_PRIVE.md](../docs/KAEL_ANIME_FANTASY_TEST_PRIVE.md).

| Scénario | Place construite | Kael |
|---|---|---|
| A | `rojo build perf/A.project.json -o perf/build/collectverse_perf_A.rbxlx` | V0.2.2 (production actuelle) |
| B | `rojo build perf/B.project.json -o perf/build/collectverse_perf_B.rbxlx` | Anime Fantasy, modèle principal |
| C | `rojo build perf/C.project.json -o perf/build/collectverse_perf_C.rbxlx` | Anime Fantasy, LOD |

À remplir avant les essais sur téléphone : `test_place.json` (PlaceId de la place de test privée) et `af_animation_ids.json` (identifiants publiés, avec l'accord du propriétaire).
