# Pipeline visuel V0.2

Étape **V0.2.1, « Visual Foundation & Premium Card System »**, version `0.6.0-visual`.

Cette première étape pose les fondations visuelles :
- un système de cartes premium ;
- un écran de booster retravaillé ;
- les points d'intégration des vrais assets ;
- un personnage pilote, Kael.

Elle ne modifie ni le gameplay, ni les données des cartes, ni les sauvegardes, ni le réseau, ni le tirage.

## 1. Architecture

| Module | Rôle | Testé |
|---|---|---|
| `shared/Visuals/CardStyle` | **Données** : cadres par rareté, variantes, classes de taille, mise en page proportionnelle, contraste WCAG | Lune (`CardStyleSpec`) |
| `shared/Visuals/VisualAssets` | **Registre central** : illustration, variante, modèle et animations par id de carte, avec validation | Lune (`VisualAssetsSpec`, `CardStyleSpec`) |
| `client/UI/CardTile` | **Rendu** de la carte premium (API inchangée : `create`, `setSelected`) | Studio (visuel) |
| `client/UI/RevealTimeline` | **Déroulé** de l'ouverture d'un booster (étapes et durées) | Lune (`CardStyleSpec`) |
| `client/UI/Screens/BoosterScreen` | Mise en scène de l'ouverture | Studio (visuel) |
| `shared/Visuals/ModelFactory` | Modèle final ou provisoire, contrat (`validateAsset`), nature du rig (`describeRig`) | Studio (`ModelFactorySpec`) |
| `client/Battle/FighterAnimator` | Animations spécifiques, repli sur les mouvements génériques | Studio (`ModelFactorySpec`) |
| `shared/Visuals/EffectsPolicy` + `client/State/GraphicsQuality` | Niveau d'effets (option « Effets réduits », qualité graphique) | Lune (`VisualAssetsSpec`) |

La séparation reste stricte. Les données de combat (`Catalog/*`) ne contiennent aucune information visuelle, et le visuel ne lit que l'id, la rareté, l'élément, le rôle et le nom d'une carte.

## 2. Système de cartes premium

### Cadres par rareté

La rareté se lit de trois façons redondantes : le cadre, les gemmes et le libellé écrit. Elle reste ainsi lisible pour les daltoniens et sur petit écran.

| Rareté | Contour (dégradé) | Épaisseur | Gemmes | Ornements d'angle | Liseré lumineux | Reflet holo |
|---|---|---|---|---|---|---|
| Commune | argent `#C9CFEA` → `#7E87B5` | 1,5 | 1 | — | — | — |
| Rare | cyan `#A8F1FF` → `#39CBE7` → `#1C7187` | 2 | 2 | — | cyan | — |
| Épique | violet `#D2C4FF` → `#7858EB` → `#3A2690` | 2,5 | 3 | oui | violet | — |
| Légendaire | or `#FFF4D1` → `#F0BF61` → `#A8711C` | 3 | 4 | oui | or | **oui** |

### Structure d'une carte

Les proportions sont identiques à toutes les tailles :

1. **Fenêtre d'illustration** (86 % × 55 %). Elle affiche l'image du registre si elle existe. Sinon, on garde le repli amélioré : dégradé de l'élément, emblème circulaire, grande initiale et vignettage.
2. **Gemmes de rareté**, à cheval sur le bas de l'illustration.
3. **Nom** (gras). Il se réduit pour tenir sur une ligne.
4. **Élément · rôle**, l'élément dans sa couleur. Pour un objet : « Objet ».
5. **Libellé de rareté** dans la couleur de la rareté, suivi de « · HOLO » pour la variante holographique.

### Variantes

Une **variante** change l'apparence sans toucher à l'id ni aux données. La variante `Holo` ajoute le reflet holographique, mais le cadre, les gemmes et le libellé restent ceux de la vraie rareté. Une variante ne peut donc jamais faire passer une carte pour plus rare qu'elle ne l'est.

Pour ajouter une variante future (illustration alternative, édition signée…) : déclarez-la dans `CardStyle.Variants`, puis attribuez-la à une carte via `VisualAssets.Cards[id].variant`.

### Tailles

| Classe | Largeur | Usage | Particularités |
|---|---|---|---|
| Compact | ≤ 105 | équipe (100 × 140) | sans libellé de rareté (cadre et gemmes suffisent), textes plus petits |
| Standard | ≤ 150 | grilles (112 × 158), révélation (116 × 164) | complète |
| Large | > 150 | grande carte de la fiche Collection (180 × 254) | textes plus grands |

La classe est déduite de la largeur de la carte, ou imposée (`sizeClass`). Les textes suivent la taille de la carte, plafonnés selon la classe.

### Effets et accessibilité

- **Reflet holographique** : bande irisée (cyan, violet, or) qui balaie la carte. Elle est figée si « Animations réduites » est actif, et absente si « Effets réduits » l'est (le liseré lumineux aussi).
- **Contraste**, vérifié par test selon les critères WCAG (au moins 4,5:1) pour :
  - le nom et le libellé de rareté sur le bandeau ;
  - l'élément et le rôle sur le fond.

### Kael, prototype de carte premium

L'entrée `F001 = { variant = "Holo" }` de `VisualAssets` fait de Kael le pilote des cartes spéciales.

Sa carte montre tout le système : cadre de sa rareté réelle (Commune), reflet, gemme, « COMMUNE · HOLO ». Elle apparaît en taille Standard dans la grille et en taille Large dans la fiche.

Aucun Asset ID n'a été inventé : l'illustration reste le repli tant qu'une vraie image n'est pas importée.

## 3. Ouverture des boosters

Le serveur tire les cartes **avant** l'animation, et rien côté client ne peut changer le résultat. Le client joue les étapes calculées par `RevealTimeline` :

| Étape | Complet | Animations réduites | Effets réduits |
|---|---|---|---|
| Charge : le paquet tremble, son contour s'intensifie | 0,7 s | supprimée | identique |
| Ouverture : éclair, le paquet grandit et s'efface | 0,35 s | 0,1 s, sans mouvement | sans éclair |
| Distribution : dos identiques, un par un | 0,1 s par carte | instantanée | identique |
| Retournement : pliage, puis face, avec un éclat de la couleur de la rareté à partir de Rare | 0,45 s avant chaque carte | 0,12 s, sans pliage | sans éclat |
| Mise en lumière (Épique, Légendaire) : bannière « ÉPIQUE » / « LÉGENDAIRE ! », rebond de la carte, rayons tournants | 0,55 s / 1,3 s | Légendaire seule, 0,45 s | sans rayons |

**Règle d'honnêteté**, vérifiée par test :
- aucune étape ne vise ni ne suggère une carte avant son retournement ;
- les dos sont tous identiques ;
- la mise en lumière vient toujours après le retournement.

Il n'y a aucune fausse anticipation, aucune rareté qui « monte » pendant l'animation.

**« Tout révéler »** termine tout instantanément, à n'importe quelle étape. Fermer l'écran a le même effet.

**Mobile** : même mise en page dans le canevas mis à l'échelle (cinq cartes de 116 × 164). Elle a été vérifiée dans le Device Simulator pour la Collection, mais l'ouverture elle-même n'a pas été jouée dans le simulateur (voir § 8).

## 4. Points d'intégration des vrais assets

| Asset | Où le déclarer | Présent et valide | Absent ou invalide |
|---|---|---|---|
| Illustration de carte | `VisualAssets.Cards[id].art = "rbxassetid://<id>"` | Affichée dans `CardTile` et sur la carte d'invocation | Repli : dégradé, emblème, initiale |
| Variante | `VisualAssets.Cards[id].variant = "Holo"` | Reflet holographique | `Standard` |
| Modèle 3D | `ReplicatedStorage.Assets.Fighters.<nom>` ; nom via `VisualAssets.Cards[id].model` (par défaut l'id) | Cloné à la place du modèle provisoire | Modèle provisoire, un avertissement si non conforme |
| Animations | `VisualAssets.Cards[id].animations = { Idle, Attack, Skill, Ultimate, Defend, Hit, Defeat }` | Jouées par `FighterAnimator` | Mouvements génériques (élan, bond, fondu) |

Validation automatique :
- `VisualAssets.validate` au démarrage du serveur et dans les tests (format `rbxassetid://<nombre>`, animations et variantes connues) ;
- `ModelFactory.validateAsset` au chargement d'un modèle.

Un avertissement est aussi émis si des animations sont déclarées pour un modèle qui ne peut pas les jouer.

## 5. Modèle 3D de Kael : état et contrat

**Blender n'est pas installé sur la machine de développement.** Je l'ai vérifié : pas de commande `blender`, rien dans Program Files, ni dans la liste des logiciels installés. Aucun modèle n'a donc été généré, et Kael garde son **modèle provisoire**.

Ce modèle provisoire est fait de pièces **soudées** : `ModelFactory.describeRig` le classe `Welded`, non animable. Ce n'est pas un personnage riggé, et il n'est jamais présenté comme tel.

Ce qui est prêt et testé dans Studio (`ModelFactorySpec`) :
- un modèle **riggé** conforme est accepté : rig `Motor6D` ou à os (`Skinned`), avec un `AnimationController` contenant un `Animator` ;
- `describeRig` le reconnaît comme animable ;
- `SummonController` l'invoque en mode instantané comme en mode réduit (position correcte, membres visibles) ;
- sans animation déclarée, `FighterAnimator` renvoie vers les mouvements génériques.

### Contrat du modèle final

1. Un `Model` dont la **PrimaryPart est ancrée, placée aux pieds**, avec l'avant tourné vers −Z.
2. Toutes les autres pièces **non ancrées**, reliées à la PrimaryPart, directement ou via le rig (Motor6D, soudure de la pièce du maillage).
3. Pour les animations : un `AnimationController` (ou `Humanoid`) contenant un `Animator`, et un vrai rig (os dans un maillage riggé, ou Motor6D).

Le `HumanoidRootPart` d'un rig de type R15 est à hauteur de hanches, pas aux pieds. Il faut donc ajouter une pièce **`Root`** aux pieds, comme PrimaryPart ancrée, et y relier le rig (étape 4 ci-dessous).

## 6. Importation Blender → Roblox (Kael)

> **Mis à jour par la V0.2.2** : la procédure a été réellement exécutée et corrigée. Elle est décrite dans [V022_KAEL_PIPELINE.md](V022_KAEL_PIPELINE.md). Changements :
> - la pièce de pivot s'appelle **`AssetPivot`** et non `Root`, nom de l'os racine (l'éditeur d'animation refuse une pièce et un os de même nom) ;
> - la mise au contrat est faite par l'outil `Dev/FighterAssetPrep` ;
> - le modèle est versionné via `build.project.json` ;
> - Rojo passe en 7.7.1.
>
> La suite de cette section décrit le plan initial, conservé pour l'historique.

Ces instructions suivent la procédure documentée par Roblox pour les personnages riggés. **Elles n'ont pas été exécutées ici**, faute de Blender. Les réglages marqués ⚠ dépendent des versions de Blender et de Studio : vérifiez-les lors du premier import.

### Étape 1 : modélisation et rig dans Blender

- **Dossier de travail séparé** : `art/kael/` (hors de `src/`). Il contient `kael.blend` et les exports, sans jamais rien intégrer automatiquement à la place principale.
- **Style** : Stylized Premium Fantasy / Anime, palette de Kael (corps `#7A2418`, finitions `#2B1C1A`, peau `#E8B48A`, lueur `#FF7A3D`), environ 10 000 triangles au maximum pour le mobile.
- **Orientation et origine** : personnage debout, origine de l'objet aux pieds, face vers −Y dans Blender (soit −Z dans Roblox à l'export).
- **Échelle** : hauteur cible d'environ 6,5 studs, comme le modèle provisoire. ⚠ Dans *Scene Properties → Units*, la documentation Roblox recommande `Unit Scale = 0.01` et des longueurs en centimètres pour un import à la bonne taille. Vérifiez la taille en studs après l'import.
- **Armature** : un seul objet Armature. Pour réutiliser l'éditeur d'animation et les conventions R15, nommez les os comme R15 :
  - racine `HumanoidRootPart`, puis `LowerTorso` et `UpperTorso` ;
  - `Head` ;
  - bras `LeftUpperArm`, `LeftLowerArm`, `LeftHand` et leurs équivalents `Right…` ;
  - jambes `LeftUpperLeg`, `LeftLowerLeg`, `LeftFoot` et leurs équivalents `Right…`.
- **Skinning** : *Armature Deform with Automatic Weights*, puis correction des poids. Au plus 4 os par sommet.
- **Avant l'export** : appliquez transformations, rotation et échelle (*Ctrl + A → All Transforms*) au maillage et à l'armature.

### Étape 2 : export FBX

*File → Export → FBX*, avec ces réglages :
- **Sélection** : *Limit to Selected Objects*, armature et maillage sélectionnés.
- **Object Types** : Armature et Mesh.
- **Transformations** : ⚠ *Apply Scalings : FBX Units Scale* ; *Forward : -Z Forward* ; *Up : Y Up*.
- **Armature** : décochez *Add Leaf Bones*.
- **Animation** : décochez *Bake Animation* pour le modèle. Les animations s'exportent séparément ou se créent dans l'éditeur Roblox.
- **Textures** : *Path Mode : Copy* et *Embed Textures*, ou importez les textures à part dans Studio.

Le fichier exporté s'appelle `art/kael/F001_Kael.fbx`.

### Étape 3 : import dans Studio

1. Ouvrez la place de test (pas la place publique).
2. *Accueil → Importer → Importer en 3D*, puis choisissez `F001_Kael.fbx`.
3. Dans l'aperçu, vérifiez que le squelette est détecté (os visibles), que l'échelle et l'orientation sont correctes et qu'aucune erreur n'apparaît. ⚠ Selon la version de Studio, choisissez le type de rig proposé (R15 si les os sont nommés comme ci-dessus, sinon personnalisé).
4. Importez.

### Étape 4 : mise au contrat

Dans l'Explorer :

1. Renommez le Model en **`F001_Kael`**.
2. Ajoutez une `Part` nommée **`Root`** : `Anchored = true`, `Transparency = 1`, `CanCollide = false`, placée **aux pieds** et tournée vers −Z. Définissez-la comme `PrimaryPart` du Model.
3. Rendez toutes les autres pièces **non ancrées** (`Anchored = false`).
4. Reliez le rig à `Root` : une `WeldConstraint` entre `Root` et la pièce racine du rig (`HumanoidRootPart` ou la pièce du maillage).
5. Si l'importateur ne l'a pas créé : ajoutez un `AnimationController` au Model, puis un `Animator` dans cet `AnimationController`.
6. Déplacez le Model dans **`ReplicatedStorage.Assets.Fighters`** (créez les dossiers `Assets` et `Fighters` s'ils n'existent pas).

### Étape 5 : déclaration et vérification

1. Dans `src/shared/Visuals/VisualAssets.luau` :
   ```lua
   F001 = { variant = "Holo", model = "F001_Kael" },
   ```
2. **Vérification du contrat**. Dans la barre de commande (hors Play) :
   ```lua
   local MF = require(game.ReplicatedStorage.Shared.Visuals.ModelFactory)
   local m = game.ReplicatedStorage.Assets.Fighters.F001_Kael
   print(MF.validateAsset(m)) ; print(MF.describeRig(m))
   ```
   Le résultat attendu est `true`, puis un rapport avec `kind = "Skinned"` (ou `"Motor6D"`) et `animatable = true`.
3. **Play** : lancez un combat avec Kael dans l'équipe. Le modèle final apparaît après la carte d'invocation, à la place du provisoire, sans aucun avertissement `[ModelFactory]`.

### Étape 6 : animations

1. Ouvrez l'**éditeur d'animation** de Studio sur `F001_Kael`. Créez Idle (en boucle), Attack, Skill, Ultimate, Defend, Hit et Defeat.
2. Publiez chaque animation sur Roblox, sous le compte ou le groupe propriétaire de l'expérience, et notez son **AnimationId** réel.
3. Déclarez les identifiants :
   ```lua
   F001 = { variant = "Holo", model = "F001_Kael", animations = { Idle = "rbxassetid://<id réel>", Attack = "rbxassetid://<id réel>", … } },
   ```
4. Vérifiez en combat que chaque action joue son animation. Une animation absente ou non chargée garde le mouvement générique.

### Versionner le modèle

`rojo serve` ignore les instances qu'il ne gère pas sous `ReplicatedStorage` : un modèle placé à la main dans la place publiée est conservé. En revanche, **`rojo build` génère une place sans ce modèle**.

Pour le versionner :
1. faites un clic droit sur le Model, puis *Enregistrer dans un fichier*, vers `assets/Fighters/F001_Kael.rbxm` ;
2. ajoutez `"Assets": { "$path": "assets" }` sous `ReplicatedStorage` dans `default.project.json`.

Cette étape n'a pas été faite, puisqu'aucun modèle n'existe encore.

## 7. Tests exécutés

| Exécution | Résultat |
|---|---|
| Lune (`lune run tools/lune/run-tests`) | **124 réussis, 0 échec** (115 avant cette étape) |
| Studio (à chaque Play), version 0.6.0-visual | **137 réussis, 0 échec** (125 avant) |
| selene, StyLua, vérification statique, `rojo build` | Conformes, aucune erreur |

Tests ajoutés :
- **`CardStyleSpec`** (9) :
  - cadres complets et couleurs valides ;
  - richesse croissante avec la rareté ;
  - contraste WCAG ;
  - variante sans changement de rareté ;
  - classes de taille, mise en page sans chevauchement ;
  - Kael pilote sans Asset ID ;
  - honnêteté de la révélation, mise en valeur de la Légendaire et version réduite.
- **`ModelFactorySpec`** (+3, Studio) : provisoire classé `Welded`, rigs Motor6D et à os reconnus, Kael riggé invoqué et repli des animations.

Gameplay inchangé : aucun fichier serveur, aucune donnée de catalogue, de sauvegarde ou de réseau n'a été modifié. Les tests de sauvegarde, de boosters, d'équipes et de combats passent tous.

### Vérifications visuelles réalisées dans Studio

Elles ont été faites sur la place de test, code synchronisé par Rojo, avec des captures prises pendant la vérification :

- **Collection** :
  - les 10 cartes ont leur cadre de rareté, leurs gemmes (1 à 4), « élément · rôle » et le libellé de rareté ;
  - Kael affiche « COMMUNE · HOLO » ;
  - la grande carte de la fiche s'affiche en taille Large ;
  - la carte non obtenue est voilée.
- **Équipe** : vignettes Compact sans libellé de rareté, contour de sélection cyan, reflet sur Oris.
- **Ouverture complète**, avec un tirage imposé par `StudioDebug` contenant une Épique et une Légendaire :
  - éclair et disparition du paquet ;
  - distribution des dos identiques ;
  - retournements successifs avec pliage ;
  - bannière « LÉGENDAIRE ! » et rayons dorés après le retournement d'Oris ;
  - récapitulatif final ; « Ouvrir un autre » grisé sans booster restant.
- **Animations réduites** : déroulé court (environ 1 s), bannière « LÉGENDAIRE ! » conservée.
- **iPhone 13** (Device Simulator) : la Collection et la grande carte tiennent dans l'écran et restent lisibles.

**Défauts trouvés et corrigés pendant cette vérification :**
- gemmes écrasées par la taille automatique ;
- « LéGENDAIRE » mal mis en majuscules ;
- initiale trop petite. `TextScaled` était annulé selon l'ordre d'application des propriétés, corrigé dans `Components.label` ;
- éclair d'ouverture trop opaque.

## 8. Assets manquants et validations restantes

**Assets à produire**, aucun n'existe encore :
1. Les illustrations des 10 cartes (format portrait, environ 512 × 640, sujet centré, recadrées par la fenêtre d'illustration).
2. Le modèle 3D riggé de Kael (§ 5 et 6), puis ceux des autres combattants.
3. Les animations Idle, Attack, Skill, Ultimate, Defend, Hit et Defeat de Kael.
4. Éventuellement, une image du paquet et du dos de carte (aujourd'hui construits en interface).

**Validations visuelles restantes :**
1. La bannière « ÉPIQUE » : son code est le même que celui de la Légendaire, qui a été vue, mais elle est tombée entre deux captures.
2. Le rendu de l'option « Effets réduits » (sans reflet, rayons, éclair ni liseré). Il a été vérifié dans le code et les tests, pas visuellement.
3. **Vrai téléphone** :
   - lisibilité des noms d'objets longs, très réduits pour tenir sur une ligne ;
   - fluidité du reflet et de l'ouverture ;
   - ouverture de booster jouée au toucher.
4. La première vraie illustration : cadrage dans la fenêtre, contraste avec le vignettage.
5. Le premier vrai modèle et les premières animations de Kael (§ 6, étapes 5 et 6), en combat et pendant l'invocation.
6. L'import FBX lui-même (réglages ⚠), à confirmer sur les versions de Blender et de Studio utilisées.
