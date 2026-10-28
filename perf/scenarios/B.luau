-- Scénario B du test privé de performance (branche test/kael-af-perf) : modèle Anime Fantasy (13 266 triangles), détail imposé High.
-- Lu par Util/PerfScenario, seulement dans les places construites par perf/B.project.json.
return {
	name = "B",
	label = "Kael Anime Fantasy, modèle principal",
	forceModelDetail = "High",
	-- true : animations de Kael lues dans perf/af_animation_ids.json (Anime Fantasy) ;
	-- identifiants absents : mouvements génériques, jamais les animations V0.2.3.
	afAnimations = true,
}
