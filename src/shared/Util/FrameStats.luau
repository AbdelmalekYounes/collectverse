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

-- Phases du combat mesurées (BattleDirector), dans l'ordre du rapport. « Finished »
-- (écran de résultat) et « Idle » ne sont jamais mesurées : lire le résultat n'est
-- pas une performance du combat.
FrameStats.MeasuredPhases = table.freeze({ "Summoning", "Planning", "Resolving" })
local MEASURED = {}
for _, phase in FrameStats.MeasuredPhases do
	MEASURED[phase] = true
end

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

export type Recorder = {
	phase: string,
	samples: { [string]: { number } },
	maxSamples: number,
	memoryPeakMb: number,
}

-- Enregistreur par phase. maxSamples borne la mémoire par phase (10 min à 60 i/s).
function FrameStats.newRecorder(maxSamples: number?): Recorder
	local samples = {}
	for _, phase in FrameStats.MeasuredPhases do
		samples[phase] = {}
	end
	return { phase = "Idle", samples = samples, maxSamples = maxSamples or 36000, memoryPeakMb = 0 }
end

function FrameStats.setPhase(recorder: Recorder, phase: string)
	recorder.phase = phase
end

-- Image de durée `ms` : comptée dans la phase en cours si elle est mesurée.
function FrameStats.record(recorder: Recorder, ms: number)
	local bucket = MEASURED[recorder.phase] and recorder.samples[recorder.phase]
	if bucket and #bucket < recorder.maxSamples then
		table.insert(bucket, ms)
	end
end

function FrameStats.recordMemory(recorder: Recorder, megabytes: number)
	recorder.memoryPeakMb = math.max(recorder.memoryPeakMb, megabytes)
end

export type Report = {
	phases: { [string]: Summary },
	combat: Summary, -- invocations + planification + résolution (hors écran de résultat)
	memoryPeakMb: number,
}

function FrameStats.report(recorder: Recorder): Report
	local phases, all = {}, {}
	for _, phase in FrameStats.MeasuredPhases do
		local samples = recorder.samples[phase]
		phases[phase] = FrameStats.summarize(samples)
		table.move(samples, 1, #samples, #all + 1, all)
	end
	return { phases = phases, combat = FrameStats.summarize(all), memoryPeakMb = recorder.memoryPeakMb }
end

-- Lignes lisibles du rapport (console et capture d'écran).
function FrameStats.describeReport(report: Report): { string }
	local lines = { "combat (hors résultat) : " .. FrameStats.describe(report.combat) }
	for _, phase in FrameStats.MeasuredPhases do
		local summary = report.phases[phase]
		if summary.frames > 0 then
			table.insert(lines, phase .. " : " .. FrameStats.describe(summary))
		end
	end
	table.insert(lines, string.format("mémoire max %.0f Mo", report.memoryPeakMb))
	return lines
end

return FrameStats
