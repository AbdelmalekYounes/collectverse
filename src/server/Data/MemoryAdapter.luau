-- Stockage en mémoire, même interface que DataStoreAdapter.
-- Sert au mode test local (DataStore indisponible : rien n'est persisté, et le
-- joueur en est averti) et aux tests, qui peuvent simuler des pannes.

local MemoryAdapter = {}
MemoryAdapter.__index = MemoryAdapter

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

function MemoryAdapter.new()
	return setmetatable({
		persistent = false,
		records = {},
		writes = 0, -- nombre d'écritures effectives (pour vérifier l'absence d'écritures inutiles)
		failReads = 0, -- nombre de prochaines lectures à faire échouer
		failWrites = 0, -- nombre de prochaines écritures à faire échouer
	}, MemoryAdapter)
end

function MemoryAdapter.read(self, key: string): (boolean, any)
	if self.failReads > 0 then
		self.failReads -= 1
		return false, "échec de lecture simulé"
	end
	return true, deepCopy(self.records[key])
end

function MemoryAdapter.update(self, key: string, transform: (old: any) -> any): (boolean, any)
	if self.failWrites > 0 then
		self.failWrites -= 1
		return false, "échec d'écriture simulé"
	end
	local new = transform(deepCopy(self.records[key]))
	if new == nil then
		return true, nil
	end
	self.records[key] = deepCopy(new)
	self.writes += 1
	return true, deepCopy(new)
end

return MemoryAdapter
