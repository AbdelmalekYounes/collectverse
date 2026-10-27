# V0.2.3 : pipeline d'animation 3D (Kael)

Version `0.6.2-anim`, à partir du commit `8ff11db`.

Objectif : faire jouer à Kael ses animations Blender dans Roblox, jusqu'en combat. Le problème est résolu. Les **7 animations sont converties, validées dans Studio, publiées (avec votre accord) et jouées en combat**. Le modèle de production, le gameplay, les sauvegardes et le réseau ne sont pas modifiés. Les autres combattants ne sont pas traités.

## 1. Compte rendu par animation

| Animation | FBX exporté (V0.2.2) | Converti (données) | Validé dans Studio | Publié | Joué en combat |
|---|---|---|---|---|---|
| Idle | ✅ | ✅ 31 images | ✅ écart 0,0001 stud | ✅ `139388493488767` | ✅ en boucle dès l'invocation |
| Attack | ✅ | ✅ 13 images | ✅ écart 0,0013 stud | ✅ `85859268098888` | ✅ 3 fois, sur de vraies actions de l'IA |
| Skill | ✅ | ✅ 19 images | ✅ écart 0,0052 stud | ✅ `138516128631569` | ⚠️ déclenchée sur le modèle de combat* |
| Ultimate | ✅ | ✅ 31 images | ✅ écart 0,0006 stud | ✅ `128975789100207` | ⚠️ déclenchée sur le modèle de combat* |
| Defend | ✅ | ✅ 11 images | ✅ écart 0,0002 stud | ✅ `108376040520289` | ⚠️ déclenchée sur le modèle de combat* |
| Hit | ✅ | ✅ 8 images | ✅ écart 0,0014 stud | ✅ `90520511069344` | ⚠️ déclenchée sur le modèle de combat* |
| Defeat | ✅ | ✅ 21 images | ✅ écart 0,0002 stud | ✅ `115751158976399` | ⚠️ déclenchée sur le modèle de combat* |

\* Ces cinq animations ont été lancées par `FighterAnimator.play`, la fonction même qu'appelle le combat, sur le modèle de l'Écho de Kael dans l'arène. Chacune a démarré avec sa durée exacte, par-dessus l'Idle. Pendant la partie jouée, l'IA n'a utilisé ni compétence ni ultime, et Kael n'a été ni touché ni vaincu : leur déclenchement **par un vrai événement de combat** reste à observer (§ 8).

**Vérification par l'utilisateur** (27/10/2026) : vous avez ajouté Kael à **votre équipe** et constaté en combat que **ses animations fonctionnent**. C'est le cas que mes propres essais ne couvraient pas : Kael côté allié, piloté par vos ordres. Cette observation n'est pas détaillée animation par animation.

**L'import FBX de l'éditeur d'animation n'est plus utilisé.** Les FBX d'animation restent des exports de référence, et ce ne sont pas eux qui sont joués dans Roblox.

## 2. Diagnostic

### Comparaison des hiérarchies

- **Rig importé (Roblox)** : `F001_Kael (Model) > F001_Kael_Mesh (MeshPart) > Root (os) > HumanoidRootPart > LowerTorso > UpperTorso > Head`, avec les bras et les jambes sous `UpperTorso` et `LowerTorso`. Il y a 17 os, et le pivot de contrat `AssetPivot` est soudé au maillage.
- **FBX d'animation (Blender)** : l'objet armature `F001_Kael`, puis les mêmes 17 os, mêmes noms, même parenté.
- **Noms** : identiques. **Unités et positions** : identiques, écart au repos de 0,0000 stud entre Blender converti et le rig importé. **Pivot** : aux pieds dans les deux cas.
- **Orientations locales des os** : différentes. Blender oriente chaque os selon son axe Y, et l'export FBX puis l'import Roblox réorientent ces repères. Une rotation locale ne peut donc pas être recopiée telle quelle d'un logiciel à l'autre.

### Expérience décisive

J'ai construit à la main une `KeyframeSequence` qui fait tourner `RightUpperArm`, puis je l'ai jouée avec l'Animator de la statue de Kael (en Play, identifiant local `KeyframeSequenceProvider`, rien de publié). J'ai testé quatre préfixes de chemin de poses : aucun, `F001_Kael_Mesh`, `AssetPivot`, `AssetPivot/F001_Kael_Mesh`.

**Dans les quatre cas, l'os tourne** : l'Animator associe les poses aux os **par leur nom**.

**Conclusion** : le rig importé est parfaitement animable, et l'échec de la V0.2.2 venait de l'**import FBX de l'éditeur d'animation** (aucune piste associée), pas du modèle.

**Corrections FBX non tentées.** La spécification prévoyait d'essayer d'abord des corrections ciblées de l'export FBX. Je ne l'ai pas fait. Après l'expérience ci-dessus, la conversion directe en `KeyframeSequence` était plus sûre : elle ne dépend pas des heuristiques de l'importateur, et elle se vérifie par le calcul. Les hypothèses FBX de la V0.2.2 (nœud d'armature en trop, échelle des translations) restent donc non vérifiées.

## 3. Solution : conversion Blender → KeyframeSequence

```
F001_Kael.blend (lecture seule)
  └─ art/kael/kael_anim_export.py ──► src/server/Dev/AnimationData/F001_Kael/<Animation>.json
                                       (Rojo : ModuleScripts de données, serveur uniquement)
  └─ Dev/KeyframeBuilder.verify ──► rapport chiffré sur le vrai rig (copie isolée)
  └─ Dev/KeyframeBuilder.build  ──► ServerStorage.AnimationSources.F001_Kael.F001_Kael_<Animation>
  └─ Publication (Studio)       ──► AnimationId réel ──► VisualAssets.Cards.F001.animations
```

**Données exportées**, une image sur deux (15 images/s), interpolation linéaire. Pour chaque os :
- `p` : position de la tête de l'os animé, dans les axes Roblox, relative aux pieds ;
- `q` : rotation **monde** qui amène l'os de son repos à sa pose animée. Elle ne dépend pas des axes locaux des os.

Conversion d'axes Blender → Roblox (rotation propre) : `X = −X_b`, `Y = Z_b`, `Z = Y_b`.

**Reconstruction dans Studio**, os par os, de la racine vers les extrémités :

```
cible     = CFrame(p) · rotation(q) · orientation de repos (rig importé)
Transform = (pose du parent · Bone.CFrame)⁻¹ · cible
```

Le repos est calculé uniquement à partir des `Bone.CFrame`. Le premier essai lisait `Bone.WorldCFrame`, qui suit les `Transform` des os parents. La mesure de dérive (ci-dessous) a révélé cette erreur, de 1,6 stud au maximum, qui est corrigée.

## 4. Validation

Les critères suivent la spécification.

| Critère | Mesure | Résultat |
|---|---|---|
| Pistes associées aux os | 17 os sur 17 trouvés ; pendant la lecture, chaque os suit sa cible | ✅ 7/7 |
| Pas de déformation anormale | **Dérive** : translation parasite dans le `Transform` d'un os qui ne doit que tourner. Toute rotation mal convertie apparaîtrait ici. | ✅ 0,0000 stud sur les 7 animations |
| Les membres suivent les mouvements attendus | Animator en Play, figé à chaque image-clé : position de chaque os comparée à Blender | ✅ écart max 0,0001 à 0,0052 stud |
| Retour à la pose | 0,5 s après l'arrêt de toutes les pistes : `Transform` résiduel nul. Attack par-dessus l'Idle, puis Idle seule, puis arrêt : résiduel nul | ✅ |
| Rejouable en combat | Idle en boucle et Attack sur de vraies actions (§ 1) ; les cinq autres via `FighterAnimator` sur le modèle de combat | ✅, avec la réserve du § 1 |
| Aucun système cassé | Lune 125/125, Studio 146/146, combat joué sans erreur | ✅ |

**Contrôle visuel** d'Attack au ralenti sur la statue de Kael : épée armée au-dessus de la tête, buste qui pivote, frappe vers l'avant, puis retour à la garde. Le maillage suit les os sans déformation.

**Identifiants publiés** : chacun a été rechargé depuis Roblox (`GetKeyframeSequenceAsync`) et comparé à sa source (nombre d'images, boucle, priorité). Les 7 sont **conformes**, ce qui écarte toute erreur de lecture à l'écran.

## 5. Intégration en jeu

- **`VisualAssets.Cards.F001.animations`** : les 7 identifiants réels et publiés. Tout autre combattant garde les mouvements génériques (fallback inchangé).
- **`FighterAnimator.stopIdle`** : nouvelle fonction, qui arrête la boucle d'attente.
- **`BattleDirector`**, à la défaite : si l'animation Defeat est jouée, l'Idle s'arrête et le fondu démarre après 0,9 s, ajusté à la vitesse. Sans animation, le fondu reste immédiat, comme avant.
- **Comportement inchangé** : une action avec animation spécifique ne déclenche pas l'élan générique, Hit accompagne l'éclat d'impact, et l'Idle tourne dès l'invocation.

## 6. Procédure reproductible

1. **Exporter les animations de Blender**, sans modifier le `.blend` :
   ```bash
   blender -b art/kael/build/F001_Kael.blend --python art/kael/kael_anim_export.py -- --out src/server/Dev/AnimationData/F001_Kael --step 2
   ```
2. **Synchroniser dans Studio** (Rojo), hors Play.
3. **Vérifier** dans la barre de commande, sur une copie isolée du modèle :
   ```lua
   local KB = require(game.ServerScriptService.Server.Dev.KeyframeBuilder:Clone()) -- copie : contourne le cache de require
   local copy = game.ReplicatedStorage.Assets.Fighters.F001_Kael:Clone()
   for _, m in game.ServerScriptService.Server.Dev.AnimationData.F001_Kael:GetChildren() do
       print(KB.describe(KB.verify(copy, require(m))))
   end
   ```
   Attendu : écart au repos et **dérive à 0,0000**, aucun os manquant.
4. **Construire** les séquences dans `ServerStorage.AnimationSources.F001_Kael` avec `KB.build(model, data)`. La commande complète est dans l'en-tête de `KeyframeBuilder`.
5. **Publier**, uniquement avec l'accord du propriétaire : *clic droit sur la séquence → Sauvegarder/Exporter → Sauvegarder sur Roblox*, créateur « Moi ». Gardez « Supprimer les instances locales » désactivé.
6. **Vérifier chaque identifiant** avec `GetKeyframeSequenceAsync` (images, boucle, priorité), puis le déclarer dans `VisualAssets`.
7. **Contrôler en combat** : Idle en boucle et actions jouées, en inspectant l'Animator du modèle dans l'arène.

Pour un autre combattant, la même chaîne s'applique : export depuis son `.blend`, mêmes outils.

## 7. Tests

| Exécution | Résultat |
|---|---|
| Lune | **125 réussis, 0 échec** (124 avant) |
| Studio (place de test, modèle et animations réels) | **146 réussis, 0 échec** (141 avant) |
| selene, StyLua, vérification statique, `rojo build` (avec et sans assets), `check-fighter-asset` | Conformes |

Ajouts :
- **`KeyframeBuilderSpec`** (3, Studio) :
  - rig synthétique dont les os ont des orientations quelconques : rotation de 90° convertie sans dérive, l'enfant suit son parent, `Transform` remis à zéro ;
  - structure de la séquence : images, boucle, priorité, poses imbriquées ;
  - données réelles de Kael sur le vrai modèle : les 7 animations sans os manquant, écart au repos et dérive nuls.
- **`VisualAssetsSpec`** : Kael déclare 7 identifiants Roblox distincts, et les autres combattants aucun.
- **`ModelFactorySpec`** : le repli générique est testé sur Terra, sans animation. Le test du modèle minimal porte désormais sur Terra, ce qui supprime un faux avertissement de rig sur Kael.

## 8. Restes et vérifications manuelles

1. **Skill, Ultimate, Defend, Hit et Defeat déclenchés par de vrais événements de combat** : vous avez confirmé que les animations de Kael fonctionnent quand il est dans votre équipe. Reste éventuellement à vérifier, une à une, celles qui n'apparaissent pas à chaque combat (Ultimate, Defeat).
2. **Propriété des animations** : elles sont publiées sur votre compte et ne se jouent que dans les expériences qui vous appartiennent. Si le jeu passe sous un groupe, il faudra les republier au nom du groupe et mettre à jour les identifiants.
3. **Modération** : vérifier le statut des 7 animations sur le Creator Dashboard.
4. **Dossier `ServerStorage.RBX_ANIMSAVES`** dans la place de test : sauvegarde automatique laissée par l'éditeur d'animation lors de l'essai FBX de la V0.2.2. Il est inutile et vous pouvez le supprimer ; je ne l'ai pas supprimé moi-même.
5. **`ServerStorage.AnimationSources`** : sources des animations publiées, à garder pour les republier. Elles se régénèrent à partir des données JSON versionnées.
6. **Plugin Rojo 7.7.1** : toujours en attente de votre autorisation de modifier les scripts. La synchronisation de cette version s'est faite avec le binaire 7.4.4.
7. **Vrai téléphone** : fluidité des animations dans l'arène.
