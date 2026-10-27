# Kael (F001) : spécifications artistiques et techniques

Ce document fixe ce que doit respecter tout modèle de Kael : le modèle pilote généré par `kael_build.py`, comme une future version faite par un artiste. Les valeurs chiffrées sont reprises du script (constantes `PALETTE`, `BONES`, `BUDGET`) et vérifiées à chaque production dans `build/kael_report.json`.

## Identité

| | |
|---|---|
| Rôle et élément | Guerrier, Feu. Ligne avant. |
| Titre | « Lame des Braises » : un forgeron devenu guerrier, dont la lame garde la chaleur d'une nuit d'incendie. |
| Direction artistique | Stylized Premium Fantasy / Anime : lecture immédiate à petite taille, silhouette nette, aplats de couleur, peu de détails fins. |

## Proportions et silhouette

- **Hauteur** : 6,6 studs, pieds au sol (Z = 0 dans Blender). C'est la même hauteur que le modèle provisoire : l'arène et les plaques de combat restent calées.
- **Environ 5 têtes de haut** : la tête est volontairement grande (style anime), environ 1,5 stud.
- **Silhouette identifiable à distance** :
  - cheveux en mèches pointues, vers le haut et l'arrière (8 mèches à pointe orangée) ;
  - épaulières rondes ;
  - épée tenue main droite, lame vers l'avant et le haut ;
  - tassettes sur les hanches et tabard avant.
- **Orientation** : face vers −Y dans Blender, donc vers −Z dans Roblox, l'avant attendu par `ModelFactory`. La gauche du personnage est en +X dans Blender.

## Équipement

| Élément | Forme | Couleur |
|---|---|---|
| Plastron | coque bombée sur le torse | armure `#7A2418` |
| Épaulières | demi-sphères, rivet doré | armure, or `#F0BF61` |
| Ceinture et boucle | anneau, braise centrale | finitions `#2B1C1A`, braise `#FF7A3D` |
| Tassettes et tabard | plaques sur les hanches, pan de tissu | armure, tissu `#3A1C17` |
| Gantelets, genouillères | manchons et plaques | acier `#8C93A8`, armure |
| Bottes | tige et pied | cuir `#4A2A1E`, finitions |
| Bandeau | anneau autour de la tête | or |
| Épée de braises | lame, garde, poignée, pommeau, âme incandescente | acier clair `#DDE3F0`, or, finitions, braise |

## Palette et textures

- **Une seule texture « palette »** de 64 × 64 px (`F001_Kael_Palette.png`), 4 × 4 cases de couleur unie. Chaque zone du maillage a ses UV regroupés au centre d'une case : aucune bavure, et un poids minimal pour le mobile.
- 15 couleurs : armure, finitions, peau, braise, cheveux, pointes de cheveux, acier, or, yeux, reflet des yeux, tissu, cuir, `blade`, bouche, acier de lame. La case `blade` n'est plus utilisée, mais elle est conservée : la retirer décalerait les cases suivantes et désynchroniserait la texture déjà importée dans Roblox.
- Pas de texture normale ni d'émission dans le pilote. L'émission (lame, boucle) est une piste pour la version artiste, avec une pièce en Neon ou une `SurfaceAppearance`.

## Budget de performance mobile

| Critère | Budget | Pilote mesuré |
|---|---|---|
| Triangles | ≤ 6 000 | **2 892** |
| Os | ≤ 20 | **17** |
| Influences par sommet | ≤ 4 | **2** |
| Sommets sans poids | 0 | **0** |
| Matériaux | 1 | **1** |
| Texture | 64 × 64 (palette) | **64 × 64** |
| Maillages (MeshPart) | 1 | **1** |

## Rig

C'est un vrai rig : le maillage est déformé par une armature, il n'est pas fait de pièces soudées.

```
Root (aux pieds)
└─ HumanoidRootPart
   └─ LowerTorso
      ├─ UpperTorso
      │  ├─ Head
      │  ├─ LeftUpperArm → LeftLowerArm → LeftHand
      │  └─ RightUpperArm → RightLowerArm → RightHand
      ├─ LeftUpperLeg → LeftLowerLeg → LeftFoot
      └─ RightUpperLeg → RightLowerLeg → RightFoot
```

- **Noms R15** : ils facilitent l'éditeur d'animation et les conventions Roblox.
- **Poids de skinning** calculés par le script :
  - armure, épée et tête rigides sur leur os ;
  - membres et torse en fondu autour des articulations, au plus 2 os par sommet.
- **Contrat Roblox** (après import et `FighterAssetPrep`) :
  - pièce `AssetPivot` ancrée aux pieds, PrimaryPart ;
  - maillage non ancré, soudé au pivot ;
  - `AnimationController` avec un `Animator` ;
  - aucun nom partagé entre une pièce et un os.

## Animations (30 images/s)

| Animation | Durée | Boucle | Intention |
|---|---|---|---|
| Idle | 60 images (2 s) | oui | respiration, léger balancement des bras |
| Attack | 24 images | non | armé au-dessus de l'épaule, frappe vers l'avant avec un pas |
| Skill | 36 images | non | tour complet sur soi, bras tendus (« Taille ardente ») |
| Ultimate | 60 images | non | accroupi, saut de 2 studs, frappe au sol (« Nova des braises ») |
| Defend | 20 images | non | garde basse, bras devant, genoux fléchis |
| Hit | 14 images | non | recul du buste et de la tête, bras écartés |
| Defeat | 40 images | non | chute à genoux puis buste effondré |

État réel, au moment de la V0.2.2 :
- créées dans Blender (images-clés) ;
- vérifiées sur les rendus de poses ;
- exportées en FBX ;
- **pas encore importées dans Roblox avec succès**, et **non publiées** (voir `docs/V022_KAEL_PIPELINE.md`).
