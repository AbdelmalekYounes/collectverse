-- Déroulé de l'ouverture d'un booster : suite d'étapes et durées. Logique pure,
-- testée avec Lune ; BoosterScreen joue les étapes.
--
-- Le résultat est tiré par le serveur AVANT l'animation et ne change jamais.
-- Règle d'honnêteté : aucune étape ne révèle ni ne suggère la rareté d'une carte
-- avant son retournement. Les dos sont identiques, la distribution est uniforme,
-- et la mise en lumière d'une carte Épique ou Légendaire vient APRÈS son retournement.
--
-- Étapes : Charge (le paquet s'illumine), Burst (ouverture), Deal (dos distribués),
-- puis Flip (retournement de la carte n), éventuellement suivi de Spotlight (n).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Catalog.Rarities)

local RevealTimeline = {}

export type Step = { kind: string, index: number?, duration: number }

local DURATIONS = {
	full = {
		charge = 0.7,
		burst = 0.35,
		dealPerCard = 0.1,
		beforeFlip = 0.45,
		spotlight = { Epic = 0.55, Legendary = 1.3 },
	},
	reduced = {
		charge = 0,
		burst = 0.1,
		dealPerCard = 0,
		beforeFlip = 0.12,
		spotlight = { Epic = 0, Legendary = 0.45 },
	},
}

-- Rang à partir duquel une carte est mise en lumière après son retournement.
RevealTimeline.SpotlightMinRank = 3

-- rarities : rareté de chaque carte, dans l'ordre de révélation.
function RevealTimeline.build(rarities: { string }, options: { reducedMotion: boolean? }?): { Step }
	local timing = if options and options.reducedMotion then DURATIONS.reduced else DURATIONS.full
	local steps: { Step } = {
		{ kind = "Charge", duration = timing.charge },
		{ kind = "Burst", duration = timing.burst },
		{ kind = "Deal", duration = timing.dealPerCard * #rarities },
	}
	for index, rarity in rarities do
		table.insert(steps, { kind = "Flip", index = index, duration = timing.beforeFlip })
		local info = Rarities.Info[rarity]
		if info and info.rank >= RevealTimeline.SpotlightMinRank then
			local duration = timing.spotlight[rarity] or 0
			table.insert(steps, { kind = "Spotlight", index = index, duration = duration })
		end
	end
	return steps
end

function RevealTimeline.totalDuration(steps: { Step }): number
	local total = 0
	for _, step in steps do
		total += step.duration
	end
	return total
end

return RevealTimeline
