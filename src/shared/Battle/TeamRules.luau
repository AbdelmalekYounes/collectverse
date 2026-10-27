-- Règles de composition d'équipe, partagées par le serveur (autorité) et le
-- client (retour immédiat dans le Team Builder).
-- Une équipe est un tableau de GameConfig.Team.Size ids : l'index est l'emplacement,
-- les FrontSlots premiers forment la ligne avant.

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local CardCatalog = require(Shared.Catalog.CardCatalog)

local TeamRules = {}

function TeamRules.rowOfSlot(slot: number): string
	return if slot <= GameConfig.Team.FrontSlots then "Front" else "Back"
end

-- owned : ensemble { [fighterId] = true } des combattants débloqués (nil = pas de contrôle).
function TeamRules.validate(team: any, owned: { [string]: boolean }?): (boolean, string?)
	if type(team) ~= "table" then
		return false, "Équipe invalide"
	end
	local size = GameConfig.Team.Size

	-- Refuse toute clé hors des emplacements 1..Size (tables envoyées par le client).
	local count = 0
	for key in team do
		if type(key) ~= "number" or key < 1 or key > size or math.floor(key) ~= key then
			return false, "Format d'équipe invalide"
		end
		count += 1
	end
	if count ~= size then
		return false, string.format("L'équipe doit compter %d combattants", size)
	end

	local seen = {}
	for slot = 1, size do
		local id = team[slot]
		if type(id) ~= "string" then
			return false, string.format("Emplacement %d invalide", slot)
		end
		local fighter = CardCatalog.getFighter(id)
		if not fighter then
			return false, "Combattant inconnu"
		end
		if seen[id] then
			return false, fighter.name .. " est déjà dans l'équipe"
		end
		if owned and not owned[id] then
			return false, fighter.name .. " n'est pas débloqué"
		end
		seen[id] = true
	end
	return true, nil
end

-- Propose une équipe en respectant si possible la ligne préférée de chacun.
-- Renvoie moins de Size ids si le joueur n'a pas assez de combattants.
function TeamRules.suggest(fighterIds: { string }): { string }
	-- Copie explicite : la liste reçue peut être gelée (configuration).
	local sorted = {}
	for _, id in fighterIds do
		table.insert(sorted, id)
	end
	table.sort(sorted)

	local frontSlots = GameConfig.Team.FrontSlots
	local backSlots = GameConfig.Team.BackSlots
	local front, back, rest = {}, {}, {}
	for _, id in sorted do
		local fighter = CardCatalog.getFighter(id)
		if fighter then
			if fighter.preferredRow == "Front" and #front < frontSlots then
				table.insert(front, id)
			elseif fighter.preferredRow == "Back" and #back < backSlots then
				table.insert(back, id)
			else
				table.insert(rest, id)
			end
		end
	end
	for _, id in rest do
		if #front < frontSlots then
			table.insert(front, id)
		elseif #back < backSlots then
			table.insert(back, id)
		end
	end

	-- L'index est l'emplacement : la ligne arrière ne commence qu'après une ligne
	-- avant complète. Avec trop peu de combattants, la ligne avant est donc
	-- complétée par ceux de la ligne arrière plutôt que de les perdre.
	while #front < frontSlots and #back > 0 do
		table.insert(front, table.remove(back, 1))
	end
	local team = front
	for _, id in back do
		table.insert(team, id)
	end
	return team
end

return TeamRules
