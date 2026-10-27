# Audit et stabilisation V0.1

Audit de **COLLECTVERSE: Echoes of the Rift**, version de départ `0.5.0-jalon5`, version livrée `0.5.1-audit`. Il fait suite à la spécification « PROMPT 002 ».

Le gameplay n'a pas changé : mêmes règles, mêmes taux, même équilibrage. Les modifications portent sur trois points :

- la fiabilité des sauvegardes ;
- l'adaptation des combats à l'écran ;
- la préparation de l'architecture visuelle V0.2.

## 1. Résumé

| Domaine | Avant | Après |
|---|---|---|
| Sauvegardes | Pas de verrou de session. Un changement rapide de serveur pouvait faire perdre toute la progression de la nouvelle session. | Verrou de session dans l'enregistrement DataStore, attente puis reprise contrôlée, libération au départ, sauvegarde rapide après un booster ou une récompense. |
| Profil en lecture seule | Les modifications étaient acceptées en mémoire, puis jamais enregistrées. | Elles sont refusées, avec un message, avant tout tirage ou combat. |
| Gameplay | Logique des sessions de combat dans un service Roblox, non testable hors Studio. | Extraite dans `BattleSessions` (logique pure) et couverte par des tests Lune. |
| Mobile | Champ de vision fixe et plaques calculées une seule fois. | Caméra et plaques recalculées à chaque changement de résolution ou d'orientation. |
| Visuels V0.2 | Remplacement des modèles possible, rien d'autre. | Registre central des illustrations, modèles et animations ; contrat de modèle ; animations spécifiques avec repli ; niveau d'effets graphiques. |
| Tests | Lune 87, Studio 94 | **Lune 115, Studio 125**, tous réussis |

## 2. Méthode

- **Lecture du code** : `README.md`, `LIVRABLES.md`, `JALONS.md`, puis les modules serveur (données, services, logique, réseau) et client (contrôleurs, combat, interfaces), en suivant les chemins de données de bout en bout.
- **Tests exécutés avant toute modification** :
  - Lune : 87 réussis, 0 échec ;
  - selene : 0 erreur, 0 avertissement ;
  - vérification statique : 88 fichiers, aucune erreur.
- **Contrôle des tests ajoutés** : on y injecte volontairement des défauts (mutations), on vérifie qu'ils échouent, puis on restaure le code.
- **Vérification dans Studio** : place privée publiée « Collectverse Test », DataStore actif, code synchronisé par Rojo, Device Simulator pour le mobile.

## 3. Constats

| # | Gravité | Constat | Statut |
|---|---|---|---|
| A1 | **Critique** | **Pas de verrou de session.** Un joueur rejoint un serveur B pendant que A termine sa sauvegarde de départ. B charge la révision *n*, puis A écrit *n + 1*. À sa première sauvegarde, B détecte le conflit et passe en lecture seule. Toute la progression faite sur B est perdue, sans possibilité de la récupérer. | Corrigé |
| A2 | Élevée | `PlayerDataService.update` acceptait des modifications sur une session en lecture seule. Un booster ouvert s'affichait alors avec ses cartes, mais n'était jamais enregistré, et le joueur les perdait à la reconnexion. | Corrigé |
| A3 | Élevée | Même problème sur un seul serveur : un joueur qui quitte puis revient aussitôt pouvait être rechargé avant la fin de sa sauvegarde de départ. | Corrigé |
| A4 | Moyenne | Une modification survenant pendant la sauvegarde de départ (par exemple la fin d'un combat au même moment) était perdue en silence. | Corrigé |
| A5 | Moyenne | Un booster ouvert n'était enregistré qu'à la sauvegarde périodique. Un arrêt brutal du serveur pouvait annuler jusqu'à 120 s de progression, sans jamais rien dupliquer. | Corrigé : sauvegarde rapide, au plus une toutes les 7 s |
| A6 | Moyenne | Joueur parti pendant le chargement de son profil : avec un verrou, celui-ci serait resté posé. | Corrigé : libération immédiate |
| A7 | Faible | Un combat pouvait être lancé sur un profil en lecture seule ; la victoire n'aurait alors rien rapporté. | Corrigé : lancement refusé |
| A8 | Moyenne | Mobile et tablettes : champ de vision fixe (42°) prévu pour 16:9. Sur un format plus étroit (4:3), les combattants des bords sortent de l'écran. Les plaques n'étaient pas recalculées si la résolution changeait en cours de combat. | Corrigé |
| A9 | Faible | L'outil `tools/static_check.py` prenait `local x = a and b` pour un alias de `a` (faux positif). | Corrigé |
| A10 | Testabilité | Démarrage, tours, abandon, reprise et récompense des combats n'étaient testables que dans Studio. | Extrait dans `server/Logic/BattleSessions` |

Points vérifiés, sans défaut trouvé :

- **Remotes** : arguments validés, fréquence limitée (`RemoteGuard`), réponses uniformes, aucune erreur Lua renvoyée au client.
- **Combats** : plans nettoyés par `PlanSanitizer`, protection anti-rejeu par numéro de tour, récompense attribuée une seule fois (drapeau `rewarded`).
- **Boosters** : `BoosterLogic.open` valide toutes les cartes avant tout crédit. Booster consommé et cartes ajoutées forment une seule modification du profil, enregistrée d'un bloc.
- **Équipe** : verrouillée pendant un combat et validée côté serveur.
- **Profils** : migration refusée pour un format plus récent, réparation sans perte des cartes valides.

## 4. Fiabilisation des sauvegardes

### Stratégie retenue : verrou dans l'enregistrement, via `UpdateAsync`

Les serveurs Roblox ne partagent pas de mémoire. Le seul point de synchronisation fiable est l'écriture atomique `UpdateAsync` sur la clé du joueur. Le verrou est donc stocké dans l'enregistrement lui-même :

```
{ revision = n, data = profil, savedAt = t, lock = { jobId = serveur, at = t } }
```

**Chargement.** L'acquisition se fait dans la même transaction que la lecture.

- **Pas de verrou, ou verrou à nous** : on le prend, la révision passe à *n + 1*.
- **Verrou actif d'un autre serveur** : on ne touche à rien et on réessaie, 5 tentatives espacées de 4 s. C'est le cas normal : l'ancien serveur finit sa sauvegarde de départ et libère le verrou, puis le nouveau charge les données finales.
- **Dernière tentative** : le verrou est repris de force (serveur arrêté brutalement). Le journal le signale.
- **Verrou non renouvelé depuis plus de 600 s** : il est repris sans attendre.
- **Enregistrement illisible ou d'un format plus récent** : on n'écrit rien, pas même le verrou, et la session passe en lecture seule.

**Sauvegarde.** L'écriture n'aboutit que si la révision *et* le verrou sont toujours les nôtres. Sinon, la session passe en lecture seule et n'écrase jamais des données plus récentes. Si l'ancien serveur se réveille après une reprise forcée, son écriture est refusée.

**Renouvellement.** Chaque sauvegarde renouvelle le verrou. La boucle périodique écrit aussi un profil inchangé dont le verrou a plus de 200 s.

**Libération.** Elle a lieu au départ du joueur et à l'arrêt du serveur (`BindToClose`). La session est alors fermée : plus aucune modification ni écriture.

### Sécuriser les écritures

| Situation | Comportement |
|---|---|
| Départ du joueur | Toute modification est refusée à partir de cet instant, puis une sauvegarde finale libère le verrou. |
| Retour immédiat sur le même serveur | Le chargement attend la fin de la sauvegarde de départ (30 s au plus). |
| Retour sur un autre serveur | Le nouveau serveur attend que l'ancien libère le verrou (environ 16 s), puis le reprend de force si besoin. |
| Arrêt brutal du serveur | Le dernier état enregistré fait foi. Le verrou abandonné est repris au plus tard après les tentatives. |
| Échec d'écriture DataStore | Trois essais avec attente croissante. Le profil reste à sauvegarder, la session reste utilisable. |
| Panne DataStore au chargement | La session passe en lecture seule (« Sauvegarde indisponible ») : boosters, combats, équipe et options sont refusés avec un message. |
| Booster ou récompense | Sauvegarde rapide, regroupée, au plus une toutes les 7 s : Roblox limite les écritures à environ une toutes les 6 s par clé. |

### Boosters : ni duplication ni perte

Le tirage, le crédit des cartes et la consommation du booster forment une seule modification du profil, écrite d'un bloc. Après un arrêt brutal, on retrouve donc soit l'état d'avant (booster non consommé, aucune carte), soit l'état d'après (booster consommé, cinq cartes). Un serveur qui a perdu le verrou ne peut rien enregistrer. Ces cas sont testés.

### Données existantes

Le format V0.1 (sans champ `lock`) se charge tel quel : le verrou est simplement ajouté. Les données stockées ne sont réécrites qu'à la première sauvegarde. Le schéma reste en version 1, aucune migration n'est nécessaire.

Vérifié sur le vrai DataStore : le profil créé au jalon 4 s'est chargé sans réparation.

### Coût DataStore

Par joueur :

- une écriture au chargement (verrou) ;
- une écriture rapide au plus toutes les 7 s, uniquement après un booster ou une récompense ;
- une écriture périodique si le profil a changé, ou au moins toutes les 4 min environ pour renouveler le verrou ;
- une écriture au départ.

C'est très en dessous du budget Roblox, de l'ordre de 60 + 10 × joueurs requêtes par minute.

## 5. Gameplay vérifié

| Cas demandé | Test automatisé (Lune) | Studio |
|---|---|---|
| Défaite et abandon | `RewardsSpec` : défaite comptée, aucun booster, second abandon refusé | Abandon joué : « Défaite — Aucune récompense cette fois. » |
| Réouverture de l'interface pendant un combat | `RewardsSpec` : reprise au même tour, même combat côté serveur, aucune issue appliquée | Non jouable par l'interface (les écrans sont bloqués pendant un combat) ; chemin serveur testé |
| Ouvertures successives | `RewardsSpec` : 5 ouvertures, 25 cartes, 6e refusée sans rien créditer | 3 boosters ouverts à la suite (« Ouvrir un autre ») |
| Déblocage d'un légendaire | `RewardsSpec` : Oris via une fixture déterministe, débloqué, doublon conservé ensuite | Oris imposé par `StudioDebug` : badge « DÉBLOQUÉ », message « Nouveau combattant débloqué : Oris ! » |
| Nouveau personnage dans le Team Builder | `RewardsSpec` : équipe avec Oris acceptée par la validation serveur | Oris passé de grisé à disponible sans recharger, placé dans l'équipe et enregistré, conservé après redémarrage |
| Récompense distribuée une seule fois | `RewardsSpec` : tour ou abandon après la fin refusés, double envoi d'un tour refusé | — |

**Fixture déterministe** (`tests/Fixtures/BoosterFixtures`). Elle fait sortir des cartes précises en passant par le vrai `BoosterLogic.roll` et les vrais poids de production. Un tirage impossible en production, par exemple une Commune dans l'emplacement garanti, lève une erreur, et ce refus est lui-même testé. Les taux n'ont pas été modifiés.

**Outil Studio** (`server/Dev/StudioDebug`). Il n'est actif que si `RunService:IsStudio()`, donc jamais sur un serveur publié. Depuis la barre de commande, en contexte Serveur :

```lua
game.Players:GetPlayers()[1]:SetAttribute("DebugGrantBoosters", 3)
game.Players:GetPlayers()[1]:SetAttribute("DebugNextBooster", "F001,F002,F003,I001,F006")
```

## 6. Compatibilité mobile

Bilan de l'audit de l'interface 2D :

- le canevas est mis à l'échelle à chaque changement de taille (référence 960 × 540) ;
- `ScreenInsets = CoreUISafeInsets` respecte l'encoche et la barre Roblox ;
- `ResetOnSpawn = false` conserve l'interface ;
- les panneaux ont une taille maximale ;
- aucun débordement constaté dans le simulateur : écrans principaux sur iPhone XR (jalon 5), écran de combat sur iPad Pro 13 pouces (audit). Les autres écrans n'ont pas été revus sur tablette.

Corrections apportées au combat, via `client/Battle/BattleLayout`, un module pur testé :

- **Champ de vision.** Sur un écran plus étroit que 16:9, il est élargi pour conserver la largeur visible prévue. Il reste à 42° en 16:9 et au-delà, ce qui inclut les téléphones en paysage, et il est plafonné à 110°.
- **Plaques.** Leur marge en pixels est proportionnelle à la hauteur de l'écran (introduite au jalon 5).
- **Changement de résolution ou d'orientation en plein combat.** La caméra et toutes les plaques sont recalculées (`ViewportSize`).

Dans le Device Simulator, un passage d'iPhone XR à iPad Pro 13 pouces (4:3) en plein combat a été vérifié. Après la bascule, les dix combattants sont visibles, ceux des bords compris, et les plaques ne se chevauchent pas.

## 7. Préparation des visuels V0.2

| Besoin | Mise en place | Repli si l'asset manque |
|---|---|---|
| Références centralisées des illustrations | `shared/Visuals/VisualAssets` : `art` par id de carte, validé (`rbxassetid://…`), avertissement au démarrage pour une entrée invalide | Dégradé et initiale, toujours dessinés sous l'image (`CardTile`, carte d'invocation) |
| Association combattant → modèle 3D | `VisualAssets.modelName` + contrat `ModelFactory.validateAsset` : PrimaryPart ancrée aux pieds, autres pièces non ancrées et reliées | Modèle en primitives, avec un seul avertissement par combattant |
| Animations spécifiques | `client/Battle/FighterAnimator` : Idle, Attack, Skill, Ultimate, Defend, Hit, Defeat. Chaque action du moteur a son animation (`ActionAnimation`). | Mouvement générique (`BattleFx` : élan, bond, fondu) si aucune animation n'est déclarée, si le modèle n'a pas d'Animator ou si l'animation n'est pas chargée |
| Appareils moins puissants | `shared/Visuals/EffectsPolicy` (pur, testé) + `client/State/GraphicsQuality` : option **« Effets réduits »** (enregistrée dans le profil), ou qualité graphique Roblox réglée à 3 ou moins | Budget réduit : 8 particules au lieu de 30, lumières dynamiques coupées (cartes, modèles, arène), pas d'éclat de rareté |

Pour ajouter un asset, il suffit de remplir l'entrée correspondante dans `VisualAssets.Cards`. Le registre est vérifié par `VisualAssetsSpec` et au démarrage du serveur.

## 8. Tests et résultats

| Exécution | Résultat |
|---|---|
| Lune (`lune run tools/lune/run-tests`) | **115 réussis, 0 échec** |
| Studio (à chaque Play), place publiée, version 0.5.1-audit | **125 réussis, 0 échec** |
| selene | 0 erreur, 0 avertissement |
| StyLua (`stylua --check src tests`) | Conforme |
| Vérification statique | 99 fichiers, 316 `require` résolus, aucune erreur |
| `rojo build` | OK |

Tests ajoutés ou réécrits :

- **`ProfileStoreSpec`** (20, contre 10 auparavant) :
  - verrou : attente de la sauvegarde de départ, verrou abandonné, reprise forcée puis refus de l'ancien serveur, exclusivité, libération, renouvellement ;
  - défense en profondeur ;
  - format plus récent ou illisible jamais modifié, profil V0.1 chargé sans perte ;
  - atomicité des boosters après panne et arrêt brutal, booster sur un serveur qui a perdu le verrou.
- **`RewardsSpec`** (9) : cas de gameplay de la section 5.
- **`BattleLayoutSpec`** (4) : champ de vision selon le format, plaques.
- **`VisualAssetsSpec`** (5) : registre, fallback, validateur, politique d'effets.
- **`ModelFactorySpec`** (+3, Studio) : contrat du modèle provisoire, asset conforme utilisé, asset non conforme ignoré.

Mutations contrôlées :

- **Chargement sans contrôle du verrou** : 4 échecs.
- **Sauvegarde sans contrôle du verrou** : d'abord non détectée, car la révision suffit à bloquer l'ancien serveur. Un test de défense en profondeur a été ajouté ; il échoue désormais.
- Code restauré après chaque mutation.

## 9. Vérifié dans Studio (DataStore réel)

1. Sortie : « Sauvegarde DataStore active », « Outils de test Studio actifs », « Serveur prêt (version 0.5.1-audit) », `[Tests] 125 réussi(s), 0 échec(s)`.
2. Profil V0.1 existant chargé sans attente ni réparation.
3. Abandon d'un combat : Défaite, aucune récompense.
4. Trois boosters crédités, puis ouverts à la suite. Le deuxième, imposé, contient Oris : badge « DÉBLOQUÉ ».
5. Oris disponible aussitôt dans l'Équipe, placé et enregistré.
6. Arrêt puis relance immédiate : profil rechargé sans attente ni « verrou repris », ce qui prouve que le verrou a bien été libéré à l'arrêt. Oris et l'équipe sont conservés, aucune sauvegarde échouée.
7. Combat dans le Device Simulator, passage iPhone XR → iPad Pro 13 pouces en plein combat : caméra et plaques adaptées.

À noter : à chaque Play en Studio, la sortie affiche `[ModelFactory] Asset de F002 ignoré (PrimaryPart manquante)`. Ce message vient du test de fallback de `ModelFactorySpec`, pas d'un asset du jeu.

## 10. Vérifications manuelles restantes

À faire hors de ce que Studio permet ici :

1. **Plusieurs serveurs réels.** Rejoindre un serveur publié, changer rapidement de serveur (ou se faire téléporter) juste après avoir ouvert un booster. La progression doit suivre. Une éventuelle attente d'environ 16 s, puis un message « verrou repris » dans les journaux serveur, sont normaux si l'ancien serveur ne répond plus.
2. **Arrêt brutal.** Fermer un serveur de test depuis le Creator Dashboard pendant une partie, puis vérifier le profil au retour.
3. **Vrai téléphone et vraie tablette** :
   - lisibilité des plaques réduites ;
   - joystick et bouton de saut (non affichés par le Device Simulator) ;
   - rotation réelle de l'appareil. Le jeu reste en paysage (orientation Roblox par défaut) ; le mode portrait n'a pas été testé.
4. **Effets réduits** : comparer visuellement une invocation et une ouverture de booster rare avec et sans l'option, sur un appareil d'entrée de gamme.
5. **Assets V0.2** : premier vrai modèle, première vraie illustration, premières animations, avec le repli quand l'un d'eux manque.

## 11. Risques restants

- **Reprise forcée.** Si un ancien serveur est toujours actif mais ne répond plus pendant environ 16 s (DataStore très lent), le nouveau reprend le verrou. Les modifications que l'ancien n'a pas encore écrites sont alors perdues, au plus une sauvegarde rapide ou périodique. Elles ne sont jamais dupliquées et n'écrasent jamais rien. C'est le compromis habituel (attendre plus longtemps bloquerait le joueur).
- **Horloges des serveurs.** L'âge du verrou utilise `os.time()`. Un écart de quelques minutes entre serveurs reste couvert par le délai de 600 s.
- **Départ en plein combat.** Le combat n'est pas comptabilisé : ni défaite, ni récompense. C'est un choix inchangé depuis le jalon 2.
- **Dossier `tests` publié avec la place.** Il ne s'exécute qu'en Studio. `StudioDebug` y lit la fixture, en Studio uniquement.
- **Qualité graphique automatique.** Roblox n'expose pas le niveau réel. Dans ce cas, les effets restent complets, sauf si le joueur active « Effets réduits ».
- **Toujours valables :** une seule rencontre PvE, objets sans mécanique, visuels provisoires (voir [LIVRABLES.md](LIVRABLES.md)).

## 12. Fichiers modifiés

- **Sauvegarde** : `server/Data/ProfileStore` (réécrit), `server/Services/PlayerDataService` (réécrit), `shared/Config/GameConfig` (réglages du verrou, version).
- **Gameplay** : `server/Logic/BattleSessions` (nouveau), `server/Services/BattleService` (allégé), `BoosterService` et `TeamService` (refus si non modifiable, sauvegarde rapide), `server/Dev/StudioDebug` (nouveau), `server/Main.server`.
- **Mobile** : `client/Battle/BattleLayout` (nouveau), `BattleCamera`, `client/UI/UnitPlate`, `client/Controllers/BattleDirector`.
- **Visuels V0.2** :
  - nouveaux : `shared/Visuals/VisualAssets`, `EffectsPolicy`, `client/Battle/FighterAnimator`, `client/State/GraphicsQuality` ;
  - modifiés : `ModelFactory`, `CardTile`, `SummonController`, `Arena`, `BoosterScreen`, `SettingsScreen`, `ClientSettings`, `ProfileTemplate` (préférence `lowEffects`).
- **Tests** :
  - réécrit : `ProfileStoreSpec` ;
  - nouveaux : `RewardsSpec`, `BattleLayoutSpec`, `VisualAssetsSpec`, `tests/Fixtures/BoosterFixtures` ;
  - complété : `ModelFactorySpec`.
- **Outils** : `tools/static_check.py` (faux positif `and`/`or`).
