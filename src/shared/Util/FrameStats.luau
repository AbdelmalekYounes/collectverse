-- Statistiques de temps d'image (logique pure, testée avec Lune) : utilisées par la
-- sonde de performance du client (Controllers/PerfProbe) pendant les combats.

local FrameStats = {}

export type Summary = {
	frames: number,
	seconds: number,
	meanMs: number,
	fps: number,
	p50Ms: number,
	p95Ms: number,
	p99Ms: number,
	maxMs: number,
	slowShare: number, -- part des images de plus de 33,3 ms (sous 30 images/s)
}

local SLOW_MS = 1000 / 30

local function percentile(sorted: { number }, p: number): number
	if #sorted == 0 then
		return 0
	end
	local index = math.clamp(math.ceil(#sorted * p), 1, #sorted)
	return sorted[index]
end

-- samples : durées d'image en millisecondes (dans l'ordre d'arrivée).
function FrameStats.summarize(samples: { number }): Summary
	local sorted = table.clone(samples)
	table.sort(sorted)
	local total, slow = 0, 0
	for _, ms in sorted do
		total += ms
		if ms > SLOW_MS then
			slow += 1
		end
	end
	local count = #sorted
	local mean = if count > 0 then total / count else 0
	return {
		frames = count,
		seconds = total / 1000,
		meanMs = mean,
		fps = if mean > 0 then 1000 / mean else 0,
		p50Ms = percentile(sorted, 0.5),
		p95Ms = percentile(sorted, 0.95),
		p99Ms = percentile(sorted, 0.99),
		maxMs = sorted[count] or 0,
		slowShare = if count > 0 then slow / count else 0,
	}
end

function FrameStats.describe(summary: Summary): string
	return string.format(
		"%d images en %.1f s | moy %.1f ms (%.0f i/s) | p50 %.1f | p95 %.1f | p99 %.1f | max %.1f ms | < 30 i/s : %.1f %%",
		summary.frames,
		summary.seconds,
		summary.meanMs,
		summary.fps,
		summary.p50Ms,
		summary.p95Ms,
		summary.p99Ms,
		summary.maxMs,
		summary.slowShare * 100
	)
end

return FrameStats
