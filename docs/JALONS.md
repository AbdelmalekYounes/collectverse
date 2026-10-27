# Suivi des jalons

Parcours cible : **Lancement → Hub → Collection → Équipe → Combat → Victoire → Booster → Ouverture → Mise à jour de collection.**

| Jalon | Contenu | État |
|---|---|---|
| 1 | Structure Rojo, catalogue, premiers modèles, scène, navigation UI | ✅ Tests Studio OK, rendu visuel à confirmer |
| 2 | Team Builder, moteur de combat, IA | ✅ Tests de logique OK (Lune), rendu à confirmer dans Studio |
| 3 | Invocations carte → personnage 3D, interface de combat | À faire |
| 4 | Boosters, collection, sauvegarde, récompenses | À faire |
| 5 | Tests, corrections, performances, documentation | À faire |

Parcours jouable après le jalon 2 : Lancement → Hub → Collection → **Équipe → Combat → Victoire** (+1 booster crédité). L'ouverture du booster arrive au jalon 4.

## Jalon 2

### Implémenté

**Logique de combat partagée** (`Shared/Battle`), pure et déterministe, sans hasard :

- `TeamRules` : équipe de 5 combattants uniques et débloqués ; emplacements 1 à 3 en ligne avant, 4 et 5 en ligne arrière ; suggestion automatique.
- `Targeting` : la ligne avant protège la ligne arrière, les assassins contournent, la Provocation redirige, une cible tombée entre-temps est remplacée.
- `AbilitySystem` : interprète génériquement les effets Damage, Heal, Shield et Status.
- `BattleEngine` : il gère les points suivants.
  - Planification et validation des plans.
  - Ordre d'exécution : vitesse décroissante ; à égalité, le camp allié puis le plus petit emplacement.
  - Énergie commune, dépensée à l'exécution ; jauge d'ultime personnelle.
  - Statuts : Brûlure, Régénération, Garde, Provocation, Attaque renforcée, Armure brisée, Étourdissement.
  - Victoire, défaite, égalité après 30 tours.
- `CombatAI` : il agit du plus rapide au plus lent, dans la limite de l'énergie.
  - Priorité : ultime, puis compétence utile, puis défense sous 30 % de PV, sinon attaque.
  - Il ne soigne pas une équipe en bonne santé.
- `PlanSanitizer` : copie défensive des plans reçus du client.
- Rencontre `RiftEcho1` : les 5 Échos de départ, à 85 % des statistiques.

**Serveur autoritaire** :

- `Remotes` : liste centralisée. Le serveur n'invoque jamais le client.
- `RemoteGuard` + `RateLimiter` : quota par joueur et par remote, erreurs internes masquées, réponse `{ ok, reason }`.
- `PlayerDataService` : profils en mémoire, versionnés. Le client en reçoit une copie, et le HUD affiche **« Sauvegarde inactive »**.
- `TeamService` : validation serveur de l'équipe ; modification refusée pendant un combat.
- `BattleService` : il gère les points suivants.
  - Démarrage et reprise d'un combat.
  - Contrôle du numéro de tour (anti-rejeu).
  - Nettoyage et validation du plan, puis plan de l'IA vérifié.
  - Résolution du tour et récompense unique : 1 booster First Rift par victoire.
  - Abandon.

**Client** :

- `DataController` : profil en lecture seule.
- `BattleController` : une requête à la fois.
- **Team Builder** : il propose les fonctions suivantes.
  - Choix d'un emplacement, puis d'un combattant ; échange automatique de place.
  - Double appui pour vider un emplacement.
  - Oris est affiché verrouillé.
  - Retour immédiat sur la validité de l'équipe, et bouton « Suggestion ».
- **Écran de combat** : il affiche les éléments suivants.
  - Cartes des 10 combattants : PV, bouclier, jauge d'ultime, statuts, ordre planifié.
  - Sélection de l'action, puis de la cible : seules les cibles valides sont encadrées, et les actions inabordables sont grisées.
  - Énergie réservée, journal coloré, abandon, écran de résultat avec la récompense.

### Réellement testé

- **Studio, 1re exécution** : 57 réussis, 2 échecs. Les deux étaient de vrais défauts, corrigés depuis :
  - `TeamRules.suggest` perdait les combattants de la ligne arrière quand la ligne avant n'était pas pleine ;
  - l'IA ne lançait jamais d'ultime (le plus rapide dépensait toute l'énergie), d'où une égalité au tour 31. Un ultime prêt est désormais servi en premier, et l'équipe économise s'il n'est pas encore abordable.
- **Lune** (`lune run tools/lune/run-tests`) : **55 réussis, 0 échec**. Ce sont les 59 tests, moins les 4 de `ModelFactorySpec`, réservés à Studio.
  - Le harnais a été vérifié par injection de défauts : une constante de Garde modifiée et une attente inversée sont toutes deux détectées, avec un code de sortie 1.
  - Équilibrage observé : l'équipe de départ, jouée par l'IA, bat la rencontre 1 au tour 20 sans perte (6 ultimes contre 3).
- `selene src tests` : 0 erreur, 0 avertissement. `stylua --check` : conforme.
- `python tools/static_check.py` : 62 fichiers, 178 `require` résolus.
- `rojo build` : place générée sans erreur.

### Contenu des tests

Total dans Studio : **59 tests** (23 du jalon 1 + 36).

- `TeamRulesSpec` :
  - compositions valides et 11 cas invalides ;
  - suggestion ;
  - profil par défaut.
- `BattleEngineSpec` :
  - dégâts calculés à la main (70, 35, 80, 81), boucliers, soins plafonnés ;
  - énergie, défense ;
  - ligne avant et assassins, 9 actions invalides ;
  - ultime, ordre de vitesse, égalité de vitesse ;
  - étourdissement, brûlure, provocation ;
  - victoire, égalité, indépendance du snapshot.
- `CombatAISpec` :
  - plans toujours valides sur un combat complet, déterminisme ;
  - **rencontre 1 gagnable par l'équipe de départ jouée par l'IA** (test d'équilibrage : un échec signale un réglage à revoir, pas forcément un bug) ;
  - budget d'énergie, soins utiles, étourdissement.
- `SecuritySpec` : plans malformés, champs parasites ignorés, limiteur de fréquence.

### À vérifier dans Studio

1. La sortie affiche `[Tests] 59 réussi(s), 0 échec(s)`, puis l'avertissement « Sauvegarde non active ».
2. Le HUD affiche « Sauvegarde inactive » et « Boosters : 1 ».
3. Équipe :
   - l'équipe de départ est chargée ;
   - placer Kael dans un autre emplacement échange bien les places ;
   - vider un emplacement désactive « Enregistrer » ;
   - Oris est grisé et non cliquable.
4. Combat :
   - lancer, donner des ordres, puis valider le tour ;
   - Kael ne peut pas cibler Lyra (ligne arrière) tant que la ligne avant adverse vit ; Nox (Pas de l'ombre) le peut ;
   - l'ultime n'est disponible qu'avec « ULTIME PRÊT ».
5. Gagner un combat : l'écran de résultat indique « +1 booster First Rift » et le HUD passe à « Boosters : 2 ».
6. Fermer l'écran pendant un combat, puis le rouvrir : le combat reprend au même tour.
7. Émulateur mobile : les 5 cartes par ligne tiennent, et le panneau d'ordres et le journal restent lisibles.

### Limitations connues

- L'interface de combat est en 2D (cartes) : l'arène 3D et les invocations arrivent au jalon 3.
- Profils non persistés : tout est réinitialisé à la déconnexion (jalon 4).
- Une seule rencontre PvE. L'IA est simple (pas d'anticipation, pas de réserve d'énergie).
- Les combats ne comportent aucun hasard (choix de conception) : pas de coups critiques ni d'esquive.

## Jalon 1

### Implémenté

- **Projet Rojo** : `default.project.json`, outils (`rokit.toml`), selene et StyLua.
- **Catalogue déclaratif** : 6 combattants (statistiques et 4 actions chacun) et 4 objets. Données gelées, accès par `CardCatalog`.
- **Éléments, rôles, raretés, statuts et règles de ciblage** : définis comme données.
- **CatalogValidator** : vérifie ids, types, coûts, ciblage, cohérence des effets, boosters, équipe de départ. Le serveur refuse de démarrer si une règle échoue.
- **AbilityText** : descriptions d'actions générées depuis les effets.
- **Booster First Rift** : poids exacts définis (non encore tirés). `BoosterOdds` calcule les taux affichés.
- **ModelFactory** : 6 personnages provisoires reconnaissables, chacun avec une silhouette propre (épée, bouclier, bâton, dagues, orbes, halo) et des couleurs liées à son élément. L'apparence est séparée des données de gameplay, et le remplacement par un asset final est automatique.
- **Hub 3D** : plateforme, faille centrale animée, zones Boosters, Collection (statues des 6 combattants) et Combat (portail), avec ambiance lumineuse.
- **Interface** :
  - canevas mis à l'échelle (≈ 540 unités de haut), zones sûres respectées, navigation à droite pour ne pas gêner les contrôles tactiles ;
  - écrans Collection (grille filtrable et fiche détaillée), Équipe (aperçu 3 avant / 2 arrière), Boosters (taux exacts), Combat (salle d'attente), Options (animations réduites, invocations rapides) ;
  - ouverture et fermeture animées, bouton Fermer, clic sur le voile, bouton B à la manette.

### Réellement testé

- **Roblox Studio (Play)** : `[Tests] 23 réussi(s), 0 échec(s)`, puis `[Collectverse] Serveur prêt`.
  - Avertissement attendu : la `SpawnLocation` du modèle Baseplate est désactivée pour la session.
  - Avertissement `ContentId rbxassetid://203785492` émis par Studio, pas par le projet (aucun asset référencé dans `src`).
- `rojo build` (Rojo 7.4.4) : la place `Collectverse.rbxlx` est générée sans erreur.
- `selene src tests` (0.27.1, std roblox) : 0 erreur, 0 avertissement, 0 erreur d'analyse.
- `stylua --check src tests` : code conforme au format du projet.
- `python tools/static_check.py` : 39 fichiers, 97 `require` résolus dans l'arbre Rojo, aucune erreur de bloc ni de parenthèse.
- Le vérificateur lui-même a été validé sur des défauts injectés (`end` manquant ou en trop, `!=`, crochet orphelin, `require` introuvable) : il les détecte tous et accepte les if-expressions Luau.

### Non testé (exécution Roblox indisponible hors Studio)

- Aucune analyse de types Luau stricte (luau-lsp non installé).
- Rendu visuel et ergonomie mobile : à confirmer avec la liste ci-dessous.

### À vérifier dans Studio

1. La sortie affiche `[Collectverse] Serveur prêt` et `[Tests] … 0 échec(s)`.
2. Le Hub apparaît, le joueur naît face à la faille et les trois zones sont visibles depuis le point d'apparition.
3. Les 6 statues sont lisibles et distinctes, debout sur leurs socles et tournées vers le centre.
4. La faille, les éclats et le booster tournent et flottent. Avec « Animations réduites », ils s'arrêtent.
5. L'invite **E** de chaque zone ouvre le bon écran. Les invites sont masquées tant qu'un écran est ouvert.
6. Collection : les filtres fonctionnent, la fiche se met à jour et le défilement marche.
7. Les polices Michroma et BuilderSans s'affichent (sinon, remplacer les familles dans `Theme.Fonts`).
8. **Émulateur mobile** (téléphone en paysage) : textes lisibles, aucun chevauchement entre la navigation et le bouton de saut, panneaux entièrement visibles.
9. Le rendu est meilleur avec `Lighting.Technology = Future`. Vérifier que le bloom reste mesuré.

### Limitations connues

- Le combat, l'ouverture de boosters et la sauvegarde ne sont pas encore implémentés : les boutons correspondants sont désactivés et l'indiquent.
- La collection affiche le catalogue complet, pas l'inventaire du joueur.
- Les préférences (Options) ne sont pas persistées.
- Les objets n'ont aucune mécanique.
- Les cartes utilisent des visuels provisoires (initiale sur un dégradé élémentaire).
