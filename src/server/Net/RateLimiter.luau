-- Limiteur de fréquence à fenêtre glissante : au plus `maxRequests` appels
-- par clé (un joueur) sur `windowSeconds` secondes.
-- L'horloge est injectable pour les tests.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		maxRequests: number,
		windowSeconds: number,
		clock: () -> number,
		history: { [any]: { number } },
	},
	RateLimiter
))

function RateLimiter.new(maxRequests: number, windowSeconds: number, clock: (() -> number)?): RateLimiter
	return setmetatable({
		maxRequests = maxRequests,
		windowSeconds = windowSeconds,
		clock = clock or os.clock,
		history = {},
	}, RateLimiter)
end

function RateLimiter.allow(self: RateLimiter, key: any): boolean
	local now = self.clock()
	local stamps = self.history[key]
	if not stamps then
		stamps = {}
		self.history[key] = stamps
	end
	-- Retire les appels sortis de la fenêtre (les plus anciens sont en tête).
	while stamps[1] and now - stamps[1] >= self.windowSeconds do
		table.remove(stamps, 1)
	end
	if #stamps >= self.maxRequests then
		return false
	end
	table.insert(stamps, now)
	return true
end

function RateLimiter.forget(self: RateLimiter, key: any)
	self.history[key] = nil
end

return RateLimiter
