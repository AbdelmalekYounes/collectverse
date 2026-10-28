-- Statistiques de temps d'image (sonde de performance des combats).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FrameStats = require(ReplicatedStorage.Shared.Util.FrameStats)

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
end
