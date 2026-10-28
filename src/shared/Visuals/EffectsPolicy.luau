-- Niveau d'effets graphiques et budget associé (logique pure, testée avec Lune).
-- Le client (GraphicsQuality) fournit les entrées et applique le budget.
--
-- "Reduced" si le joueur a activé « Effets réduits », ou si la qualité graphique
-- Roblox est réglée manuellement bas (appareils peu puissants). En qualité
-- automatique, Roblox n'expose pas le niveau réel : on garde "Full".

local Freeze = require(script.Parent.Parent.Util.Freeze)

local EffectsPolicy = {}

-- Qualité graphique Roblox (1 à 10) à partir de laquelle les effets sont complets.
EffectsPolicy.LowQualityMax = 3

EffectsPolicy.Budgets = Freeze.deep({
	Full = {
		summonParticles = 30, -- particules de l'anneau d'invocation
		dynamicLights = true, -- PointLight des cartes et des modèles
		-- Lumière d'ambiance de l'arène (une seule PointLight, sans ombre) : gardée même
		-- en effets réduits, sinon les combattants texturés deviennent presque noirs de
		-- dos et les braises de la cape de Kael disparaissent (validé dans Studio, V0.2.5).
		arenaLight = true,
		modelParticles = true, -- particules permanentes portées par un modèle (braises de Kael)
		rarityBurst = true, -- éclat derrière les cartes rares à l'ouverture
	},
	Reduced = {
		summonParticles = 8,
		dynamicLights = false,
		arenaLight = true,
		modelParticles = false,
		rarityBurst = false,
	},
})

-- qualityLevel : niveau Roblox 1 à 10, ou nil en qualité automatique.
function EffectsPolicy.level(lowEffects: boolean?, qualityLevel: number?): string
	if lowEffects == true then
		return "Reduced"
	end
	if type(qualityLevel) == "number" and qualityLevel >= 1 and qualityLevel <= EffectsPolicy.LowQualityMax then
		return "Reduced"
	end
	return "Full"
end

function EffectsPolicy.budget(level: string)
	return EffectsPolicy.Budgets[level] or EffectsPolicy.Budgets.Full
end

return EffectsPolicy
