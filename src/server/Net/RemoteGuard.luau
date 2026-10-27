-- Branche un gestionnaire serveur sur une RemoteFunction avec les protections communes :
--  - limitation de fréquence par joueur ;
--  - aucune erreur Lua renvoyée au client (message générique, détail dans la sortie serveur) ;
--  - réponse toujours au format { ok, reason? }.
-- La validation des arguments reste à la charge de chaque gestionnaire.

local Players = game:GetService("Players")

local RateLimiter = require(script.Parent.RateLimiter)

local RemoteGuard = {}

local limiters: { RateLimiter.RateLimiter } = {}

export type Options = {
	maxRequests: number,
	windowSeconds: number,
}

function RemoteGuard.bindFunction(remote: RemoteFunction, options: Options, handler: (Player, ...any) -> any)
	local limiter = RateLimiter.new(options.maxRequests, options.windowSeconds)
	table.insert(limiters, limiter)

	remote.OnServerInvoke = function(player: Player, ...)
		if not limiter:allow(player) then
			return { ok = false, reason = "Trop de requêtes, patientez un instant" }
		end
		local success, result = pcall(handler, player, ...)
		if not success then
			warn(string.format("[RemoteGuard] %s (%s) : %s", remote.Name, player.Name, tostring(result)))
			return { ok = false, reason = "Erreur serveur" }
		end
		if type(result) ~= "table" then
			return { ok = false, reason = "Erreur serveur" }
		end
		return result
	end
end

Players.PlayerRemoving:Connect(function(player)
	for _, limiter in limiters do
		limiter:forget(player)
	end
end)

return RemoteGuard
