-- Gel récursif des tables de données : empêche toute modification accidentelle
-- du catalogue ou de la configuration pendant l'exécution.

local Freeze = {}

function Freeze.deep<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	if table.isfrozen(value :: any) then
		return value
	end
	for _, child in value :: any do
		Freeze.deep(child)
	end
	table.freeze(value :: any)
	return value
end

return Freeze
