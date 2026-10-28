-- Scénario C du test privé de performance (branche test/kael-af-perf) : modèle Anime Fantasy et sa variante allégée (5 199 triangles), détail imposé Low.
-- Lu par Util/PerfScenario, seulement dans les places construites par perf/C.project.json.
return {
	name = "C",
	label = "Kael Anime Fantasy, LOD",
	forceModelDetail = "Low",
	-- true : animations de Kael lues dans perf/af_animation_ids.json (Anime Fantasy) ;
	-- identifiants absents : mouvements génériques, jamais les animations V0.2.3.
	afAnimations = true,
}
