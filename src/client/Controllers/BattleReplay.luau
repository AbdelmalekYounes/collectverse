-- Rejoue les événements d'un tour sur un état d'affichage, action par action,
-- pour que les PV évoluent au rythme des animations. Logique pure, testée avec Lune.
-- L'état final est toujours remplacé par le snapshot du serveur, qui fait foi.

local BattleReplay = {}

function BattleReplay.copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[key] = BattleReplay.copy(child)
	end
	return result
end

function BattleReplay.apply(state, event)
	local kind = event.type
	local unit = event.target and state.units[event.target]
	if kind == "Damage" then
		unit.hp = event.hp
		unit.shield = event.shield
	elseif kind == "Heal" then
		unit.hp = event.hp
	elseif kind == "Shield" then
		unit.shield = event.shield
	elseif kind == "Status" then
		unit.statuses[event.status] = { duration = event.duration }
	elseif kind == "StatusExpired" then
		unit.statuses[event.status] = nil
	elseif kind == "Defeated" then
		unit.alive = false
		unit.hp = 0
		unit.shield = 0
		unit.charge = 0
		table.clear(unit.statuses)
	elseif kind == "Action" then
		local actor = state.units[event.actor]
		state.energy[actor.side] -= event.cost
	elseif kind == "Skip" and event.reason == "Stun" then
		-- Même règle que le moteur : l'étourdissement se consomme en faisant perdre l'action.
		local actor = state.units[event.actor]
		local stun = actor.statuses.Stun
		if stun then
			stun.duration -= 1
			if stun.duration <= 0 then
				actor.statuses.Stun = nil
			end
		end
	elseif kind == "Energy" then
		state.energy[event.side] = event.energy
	elseif kind == "TurnEnd" then
		state.energy.Ally = event.energy.Ally
		state.energy.Enemy = event.energy.Enemy
		state.turn = event.turn + 1
	elseif kind == "BattleEnd" then
		state.status = "Finished"
		state.winner = event.winner
	end
end

local function isTick(event): boolean
	return (event.type == "Damage" and event.kind == "Burn") or (event.type == "Heal" and event.kind == "Regen")
end

-- Découpe les événements en « temps forts » animés l'un après l'autre :
-- chaque action ou tour perdu, les effets de fin de tour, la fin du combat.
-- Les événements qui en découlent (dégâts, statuts…) rejoignent le temps fort courant.
function BattleReplay.group(events)
	local beats = {}
	local current = nil
	for _, event in events do
		local startsBeat = event.type == "Action"
			or event.type == "Skip"
			or event.type == "TurnStart"
			or event.type == "BattleEnd"
			or (isTick(event) and (current == nil or current.kind ~= "Ticks"))
		if startsBeat or current == nil then
			current = { kind = if isTick(event) then "Ticks" else event.type, events = {} }
			table.insert(beats, current)
		end
		table.insert(current.events, event)
	end
	return beats
end

return BattleReplay
