# Kael Anime Fantasy : test privé de performance (branche `test/kael-af-perf`)

Ce document part de `dd4c14c` (version `0.6.4-af`) et applique la procédure de [KAEL_ANIME_FANTASY_PREVALIDATION.md](KAEL_ANIME_FANTASY_PREVALIDATION.md), § 3.

**Tout est sur la branche `test/kael-af-perf`**. La branche `main` n'est pas modifiée et cette branche ne doit **jamais être fusionnée**.

- Aucune animation, place ni asset n'a été publié.
- Le modèle de production n'est pas remplacé.
- Le gameplay n'est pas modifié.

Les essais faits dans Studio valident le fonctionnement du dispositif. **Ce ne sont pas des mesures de performance mobile** : le rendu y est fait par le PC et la cadence est plafonnée à 60 i/s.

## 1. Ce que contient la branche

| Élément | Rôle |
|---|---|
| `perf/A.project.json`, `B.project.json`, `C.project.json` | Une place Rojo par scénario |
| `perf/assets/A/Fighters/F001_Kael.rbxm` | A : Kael V0.2.2, copie du modèle de production |
| `perf/assets/B/Fighters/F001_Kael.rbxm` | B : Kael Anime Fantasy (candidat), sans LOD |
| `perf/assets/C/Fighters/F001_Kael.rbxm` et `F001_Kael_LOD.rbxm` | C : Kael Anime Fantasy et son LOD |
| `perf/scenarios/A.luau`, `B.luau`, `C.luau` | Nom, libellé, détail imposé (`High`, `High`, `Low`), animations à utiliser |
| `perf/af_animation_ids.json` | Les 7 identifiants Anime Fantasy, **vides tant qu'ils ne sont pas publiés** |
| `perf/test_place.json` | PlaceId de la place de test privée, **vide** : à remplir (§ 4) |
| `src/shared/Util/PerfScenario.luau` | Lit le scénario dans `ReplicatedStorage.PerfTest`, présent seulement dans ces places. Ailleurs, rien ne change |
| `VisualAssets` | B et C : animations Anime Fantasy si les 7 identifiants sont valides, **sinon aucune** (mouvements génériques), jamais celles de l'ancien squelette |
| `GraphicsQuality.modelDetail` | Détail imposé par le scénario |
| `TestEnvironment` | Ajoute le PlaceId de `perf/test_place.json` aux places de test |
| `PerfProbe` | Activée (`GameConfig.Debug.PerfProbe = true`), mais seulement en environnement de test. Le rapport indique le scénario et l'état des animations |
| `GameConfig.Save.DataStoreName = "CollectverseProfiles_PerfTest"` | **Les profils existants ne sont jamais lus ni modifiés** par ces places |
| Éclairage des trois places | `GlobalShadows = false`, `LightingStyle = Soft`, `PrioritizeLightingQuality = false`, comme dans la place de test actuelle |
| `Dev/AnimationPublishing.inspect` | Contrôle des sources avant publication |
| `tools/lune/apply-animation-ids.luau` | Applique les 7 identifiants publiés à `VisualAssets`, avec aperçu par défaut |
| Tests | `PerfScenarioSpec` (nouveau) ; `VisualAssetsSpec` et `KeyframeBuilderSpec` tiennent compte du scénario |

## 2. Vérifications faites

| Vérification | Résultat |
|---|---|
| Lune (branche) | **137 / 137** |
| Construction des places A, B, C (`rojo build`) | OK |
| `check-fighter-asset` sur les places | A : `138475817837268` (V0.2.2) ; B : `132517036744752` (AF) ; C : AF et LOD `134747344742606`. Contrats **OK** |
| Studio, places ouvertes en **fichier local** | Sauvegarde : « MODE TEST LOCAL » (rien n'est enregistré) |
| Tests Studio au lancement, places A et B | **164 / 164**, 0 échec (avant correction des trois tests, la place C en avait 3, attendus) |
| PerfProbe, place A / B / C | Annonce « actif (environnement de test), scénario A (Kael V0.2.2, animations V0.2.3) », puis B (modèle principal) et C (LOD) ; pour B et C, « sans animation AF (mouvements génériques) » |
| PerfProbe, combat complet (place C, un tour puis abandon, en mémoire) | **Rapport de fin obtenu**, avec la mesure combat hors résultat et Summoning, Planning et Resolving séparés, la mémoire, et « détail Low ». Capture : `art/kael/anime_fantasy/build/studio/perf_probe_report_C_studio.jpg` |
| `AnimationPublishing.prepare` (place C) | 7/7 conformes (17 os, aucun manquant, écart et dérive à 0,0000) |
| `AnimationPublishing.inspect` (sources préparées) | 7/7 conformes : images, instants, 17 poses par image, boucle, priorité |
| `apply-animation-ids` (sur une copie de `VisualAssets`) | Fichier vide, doublon ou format invalide : refusés. Identifiants valides : 7 lignes remplacées, rien d'autre |

**Incident pendant les essais** : dans la place locale C, en jeu, un clic a ouvert le script `TestRunner` et une commande y a été tapée. J'ai annulé aussitôt, puis répondu « Non » à la conservation des changements faits en jeu. Le fichier du dépôt n'a jamais été touché.

**Place de test « Test de Collectverse »** : le serveur Rojo, lancé depuis le dossier du dépôt, a synchronisé le code de la branche dans cette place collaborative. Effet : elle utilise maintenant le DataStore `CollectverseProfiles_PerfTest`. Le retour arrière est au § 7.

## 3. Animations Anime Fantasy : préparation et publication

**Faites** : sources préparées et contrôlées dans la place C (§ 2).

**À faire après votre autorisation explicite**, dans Studio, de préférence fraîchement lancé :

1. Ouvrir `perf/build/collectverse_perf_C.rbxlx` (*Fichier → Ouvrir depuis un fichier*), puis dans la barre de commande :
   ```lua
   local Dev = game.ServerScriptService.Server.Dev
   local AP = require(Dev.AnimationPublishing)
   print(AP.describe(AP.prepare(game.ReplicatedStorage.Assets.Fighters.F001_Kael, Dev.AnimationData.F001_Kael_AF, "F001_Kael_AF")))
   print(AP.describe(AP.inspect("F001_Kael_AF", Dev.AnimationData.F001_Kael_AF)))
   ```
   Attendu : deux fois `=> tout est conforme`.
2. Dans l'Explorateur, `ServerStorage › AnimationSources › F001_Kael_AF`. Pour **chacune des 7** séquences :
   - *clic droit → Sauvegarder/Exporter → Sauvegarder sur Roblox* ;
   - créateur « Moi », « Supprimer les instances locales » désactivé ;
   - noter l'identifiant.
3. Vérifier les identifiants :
   ```lua
   print(AP.describe(AP.check({ Idle = "rbxassetid://…", Attack = "…", Skill = "…", Ultimate = "…", Defend = "…", Hit = "…", Defeat = "…" }, Dev.AnimationData.F001_Kael_AF)))
   ```
4. Écrire les 7 identifiants dans `perf/af_animation_ids.json`, puis vérifier sans rien modifier :
   ```bash
   lune run tools/lune/apply-animation-ids -- perf/af_animation_ids.json --target src/shared/Visuals/VisualAssets.luau
   ```
   Si l'aperçu est accepté, les identifiants sont valides.
5. Reconstruire B et C (§ 4, étape 2). Leur rapport PerfProbe indique alors « animations AF ».

**Plus tard, sur `main`**, pour l'intégration et sur autorisation séparée : la même commande avec `--write` met à jour `VisualAssets`. Ensuite, suivre la prévalidation, § 5 B.

## 4. Lancer chaque scénario sur smartphone

### Une fois

1. **Créer la place de test privée.** C'est votre action : je ne publie rien.
   - Dans Studio, ouvrir `perf/build/collectverse_perf_A.rbxlx`.
   - *Fichier → Publier sur Roblox sous… → Nouvelle expérience*, nom par exemple « Collectverse Perf Test ».
   - Vérifier dans le Creator Hub qu'elle est **privée**.
   - Elle doit appartenir **au même compte** que les animations (Akroniik), sinon les animations privées ne se chargent pas.
   - Relever son **PlaceId** : Creator Hub, ou `print(game.PlaceId)` dans la barre de commande de la place publiée.
2. **Déclarer le PlaceId** dans `perf/test_place.json`, sur la branche :
   ```json
   { "placeIds": [123456789] }
   ```
   **Sans ce PlaceId, la sonde ne s'active pas sur le téléphone** : c'est voulu, l'expérience publique ne doit jamais l'activer.
3. **Reconstruire les trois places** :
   ```bash
   rojo build perf/A.project.json -o perf/build/collectverse_perf_A.rbxlx
   ```
   ```bash
   rojo build perf/B.project.json -o perf/build/collectverse_perf_B.rbxlx
   ```
   ```bash
   rojo build perf/C.project.json -o perf/build/collectverse_perf_C.rbxlx
   ```
4. **Sur le téléphone** :
   - application Roblox connectée au même compte ;
   - *Paramètres Roblox → Qualité graphique : Automatique* ;
   - batterie au-dessus de 50 %, hors charge, autres applications fermées.

### Pour chaque scénario X, dans l'ordre A, B, C

1. Studio : ouvrir `perf/build/collectverse_perf_X.rbxlx`, puis *Fichier → Publier sur Roblox sous… →* la place « Collectverse Perf Test ». Elle est remplacée par le scénario X.
2. Téléphone : fermer complètement l'application, la relancer, rejoindre « Collectverse Perf Test », par exemple depuis vos créations ou par le lien de l'expérience.
3. Vérifier en haut de l'écran le texte `[PerfProbe] X · …`. S'il manque, la sonde est inactive : PlaceId mal déclaré (étape 2 de « Une fois »).
4. *Options* : « Effets réduits » **désactivé**, « Invocations rapides » **désactivé**.
5. *Combat → Lancer le combat* (rencontre 1). Équipe : la même pour les trois scénarios. Elle est sauvegardée dans le DataStore de test, donc identique d'un scénario à l'autre.
6. Jouer **3 tours** en validant les ordres proposés (*Valider le tour*), puis **Abandonner**. Le résultat compte comme une défaite, uniquement dans le DataStore de test.
7. À l'écran de résultat, **capturer l'écran** : le rapport `[PerfProbe] combat terminé | scénario X …` est affiché en haut.
8. Recommencer les étapes 2 à 7 **trois fois** pour ce scénario.

Le rapport donne pour chaque essai :

- **combat hors résultat** : i/s moyens, p95 et part des images sous 30 i/s ;
- **Summoning, Planning et Resolving** séparément ;
- **mémoire maximale**, maillages et textures ;
- **écran, type d'entrée, niveau d'effets et détail des modèles**.

**Facultatif** : console développeur (`/console` dans le chat, onglet *Log*) pour recopier le texte. MicroProfiler du téléphone (*Paramètres → MicroProfiler*, puis depuis un PC du même réseau `http://<IP du téléphone>:1338`).

**Série optionnelle** : refaire A, B et C avec « Effets réduits » activé. Dans B, le détail reste imposé à High, et le rapport indique « effets Reduced ».

## 5. Ce que vous devrez me transmettre

1. **Le PlaceId** de la place de test privée, si vous voulez que je le déclare et reconstruise les places.
2. **Les 7 identifiants** des animations Anime Fantasy, une fois publiées avec votre autorisation, ou `perf/af_animation_ids.json` rempli.
3. **Pour chaque téléphone** : modèle, version du système, mémoire vive si connue.
4. **Pour chaque scénario (A, B, C) et chaque essai (3)** : la capture du rapport `[PerfProbe]`, ou son texte.
5. **Tout comportement anormal** : Kael absent ou provisoire, animations figées, textures manquantes, chute de cadence visible, échauffement.

Avec ces données, je remplirai le tableau de la prévalidation (§ 3) et j'appliquerai la règle de choix du LOD (§ 2), ou je proposerai les ajustements.

## 6. Actions qui demandent votre intervention

| Action | Pourquoi vous |
|---|---|
| Publier les 7 animations (§ 3, étapes 2 à 4) | Publication d'assets sur votre compte : votre autorisation explicite |
| Créer et publier la place de test privée, puis la remplacer par A, B et C | Publication de place : vous seul |
| Lancer les essais sur téléphone | Je n'ai accès à aucun appareil |
| Décider de pousser la branche `test/kael-af-perf` | Elle est seulement locale pour l'instant |

## 7. Retour arrière sûr

| Élément | Retour arrière |
|---|---|
| Dépôt | `main` n'a pas été modifiée. `git switch main` revient à `dd4c14c`. Pour abandonner le test : `git branch -D test/kael-af-perf`, et `git push origin --delete test/kael-af-perf` si la branche a été poussée |
| Place « Test de Collectverse » | Après `git switch main`, la reconnecter à Rojo depuis `main` : le code de `main` y revient, avec `DataStoreName = "CollectverseProfiles"`. Les essais faits avec le code de la branche n'ont écrit que dans `CollectverseProfiles_PerfTest` |
| Place « Collectverse Perf Test » | Expérience privée et indépendante. La rendre inactive ou l'archiver dans le Creator Hub. Aucun effet sur l'expérience publique ni sur ses sauvegardes |
| Animations Anime Fantasy publiées | Restent dans votre inventaire sans être utilisées par la production, qui garde les identifiants V0.2.3. Archivables depuis le Creator Hub |
| Modèle de production | Inchangé : `assets/Fighters/F001_Kael.rbxm` et l'identifiant de maillage `138475817837268` |
| Fichiers construits | `perf/build/` est ignoré par Git, à supprimer librement |

## 8. Limites

- **Mesures Studio non représentatives du mobile** : 60 i/s plafonnés, rendu du PC.
- **Éclairage** : les places construites n'ont pas de réglage `Technology` (Studio les convertit en « Voxel » à l'ouverture), mais les trois scénarios sont identiques. Si la place publique utilise un autre réglage d'éclairage, me l'indiquer : je l'ajouterai aux trois projets pour mesurer dans ses conditions.
- **Sans animations publiées**, B et C mesurent le rendu avec des mouvements génériques et sous-estiment le coût d'animation : le rapport le signale.
