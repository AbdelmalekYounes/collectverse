# Suivi des jalons

Parcours cible : **Lancement → Hub → Collection → Équipe → Combat → Victoire → Booster → Ouverture → Mise à jour de collection.**

| Jalon | Contenu | État |
|---|---|---|
| 1 | Structure Rojo, catalogue, premiers modèles, scène, navigation UI | ✅ Tests Studio OK, rendu visuel à confirmer |
| 2 | Team Builder, moteur de combat, IA | À faire |
| 3 | Invocations carte → personnage 3D, interface de combat | À faire |
| 4 | Boosters, collection, sauvegarde, récompenses | À faire |
| 5 | Tests, corrections, performances, documentation | À faire |

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
