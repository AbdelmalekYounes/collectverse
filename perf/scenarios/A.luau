-- Scénario A du test privé de performance (branche test/kael-af-perf) : modèle V0.2.2 et ses animations publiées (V0.2.3).
-- Lu par Util/PerfScenario, seulement dans les places construites par perf/A.project.json.
return {
	name = "A",
	label = "Kael V0.2.2 (production actuelle)",
	forceModelDetail = "High",
	-- true : animations de Kael lues dans perf/af_animation_ids.json (Anime Fantasy) ;
	-- identifiants absents : mouvements génériques, jamais les animations V0.2.3.
	afAnimations = false,
}
