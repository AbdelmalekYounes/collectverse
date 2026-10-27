-- Issue d'un combat appliquée au profil : statistiques et boosters de victoire.
-- Logique pure, sans service Roblox : testée avec Lune. BattleService garantit
-- qu'elle n'est appelée qu'une fois par combat.

local BattleRewards = {}

export type Rewards = { boosters: { [string]: number } }

-- `winner` vaut "Ally", "Enemy" ou nil (égalité à la limite de tours).
-- `victoryBoosters` : { [boosterId] = quantité }, crédités seulement en cas de victoire.
function BattleRewards.apply(profile, winner: string?, victoryBoosters: { [string]: number }): Rewards
	local rewards: Rewards = { boosters = {} }
	if winner == "Ally" then
		profile.stats.battlesWon += 1
		for boosterId, quantity in victoryBoosters do
			profile.boosters[boosterId] = (profile.boosters[boosterId] or 0) + quantity
			rewards.boosters[boosterId] = quantity
		end
	elseif winner == "Enemy" then
		profile.stats.battlesLost += 1
	else
		profile.stats.battlesDrawn += 1
	end
	return rewards
end

return BattleRewards
