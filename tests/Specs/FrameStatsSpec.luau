-- Statistiques de temps d'image et environnement de test (sonde de performance).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FrameStats = require(ReplicatedStorage.Shared.Util.FrameStats)
local TestEnvironment = require(ReplicatedStorage.Shared.Util.TestEnvironment)

return function(test, expect)
	test("60 i/s réguliers", function()
		local samples = table.create(120, 1000 / 60)
		local summary = FrameStats.summarize(samples)
		expect.equal(summary.frames, 120)
		expect.near(summary.fps, 60, 1e-6, "i/s")
		expect.near(summary.seconds, 2, 1e-6, "durée")
		expect.equal(summary.slowShare, 0, "aucune image lente")
	end)

	test("percentiles et images lentes", function()
		local samples = {}
		for i = 1, 100 do
			samples[i] = if i <= 90 then 16 else 50
		end
		local summary = FrameStats.summarize(samples)
		expect.equal(summary.p50Ms, 16, "médiane")
		expect.equal(summary.p95Ms, 50, "p95 sur les images lentes")
		expect.equal(summary.maxMs, 50, "max")
		expect.near(summary.slowShare, 0.1, 1e-9, "10 % sous 30 i/s")
		expect.contains(FrameStats.describe(summary), "p95 50.0", "résumé lisible")
	end)

	test("aucune image : pas d'erreur", function()
		local summary = FrameStats.summarize({})
		expect.equal(summary.frames, 0)
		expect.equal(summary.fps, 0)
	end)

	test("par phase : l'écran de résultat et la sortie ne sont jamais mesurés", function()
		local recorder = FrameStats.newRecorder()
		FrameStats.record(recorder, 99) -- avant le combat (Idle)
		FrameStats.setPhase(recorder, "Summoning")
		FrameStats.record(recorder, 20)
		FrameStats.setPhase(recorder, "Planning")
		FrameStats.record(recorder, 16)
		FrameStats.record(recorder, 16)
		FrameStats.setPhase(recorder, "Resolving")
		FrameStats.record(recorder, 40)
		FrameStats.setPhase(recorder, "Planning")
		FrameStats.record(recorder, 16)
		FrameStats.setPhase(recorder, "Finished")
		FrameStats.record(recorder, 500) -- lecture du résultat
		FrameStats.setPhase(recorder, "Idle")
		FrameStats.record(recorder, 500)
		FrameStats.recordMemory(recorder, 300)
		FrameStats.recordMemory(recorder, 280)
		local report = FrameStats.report(recorder)
		expect.equal(report.phases.Summoning.frames, 1, "invocations")
		expect.equal(report.phases.Planning.frames, 3, "planification, plusieurs tours")
		expect.equal(report.phases.Resolving.frames, 1, "résolution")
		expect.equal(report.combat.frames, 5, "combat sans résultat ni hors combat")
		expect.equal(report.combat.maxMs, 40, "les 500 ms du résultat sont exclues")
		expect.equal(report.memoryPeakMb, 300, "pic de mémoire")
		local lines = FrameStats.describeReport(report)
		expect.contains(lines[1], "combat (hors résultat)")
		expect.equal(#lines, 5, "combat, 3 phases, mémoire")
	end)

	test("enregistreur borné", function()
		local recorder = FrameStats.newRecorder(3)
		FrameStats.setPhase(recorder, "Resolving")
		for _ = 1, 10 do
			FrameStats.record(recorder, 16)
		end
		expect.equal(FrameStats.report(recorder).phases.Resolving.frames, 3)
	end)

	test("environnement de test : Studio ou PlaceId déclaré, jamais ailleurs", function()
		expect.truthy(TestEnvironment.matches(true, 0, nil), "Studio")
		expect.truthy(TestEnvironment.matches(true, 123, {}), "Studio, place publiée")
		expect.truthy(TestEnvironment.matches(false, 456, { 456 }), "place de test déclarée")
		expect.falsy(TestEnvironment.matches(false, 789, { 456 }), "autre place : production")
		expect.falsy(TestEnvironment.matches(false, 789, nil), "aucune place déclarée")
		expect.falsy(TestEnvironment.matches(false, 0, { 0 }), "place non publiée hors Studio")
	end)
end
