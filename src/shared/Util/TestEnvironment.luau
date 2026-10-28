-- Environnement de test : Studio, ou une place de test déclarée par son PlaceId
-- (GameConfig.Debug.TestPlaceIds). Les outils de mesure et les réglages forcés
-- (PerfProbe, ForceModelDetail) ne s'activent que là, même si leur option est
-- restée activée par erreur dans GameConfig. Logique pure testée avec Lune.

local TestEnvironment = {}

function TestEnvironment.matches(isStudio: boolean, placeId: number, testPlaceIds: { number }?): boolean
	if isStudio then
		return true
	end
	if placeId == 0 then
		return false -- place non publiée hors de Studio : jamais considérée comme test
	end
	for _, id in testPlaceIds or {} do
		if id == placeId then
			return true
		end
	end
	return false
end

-- Environnement courant (Roblox).
function TestEnvironment.isActive(debugConfig: { TestPlaceIds: { number }? }): boolean
	local ok, isStudio = pcall(function()
		return game:GetService("RunService"):IsStudio()
	end)
	return TestEnvironment.matches(ok and isStudio == true, game.PlaceId, debugConfig.TestPlaceIds)
end

return TestEnvironment
