-- Adaptateur DataStoreService (persistance réelle).
-- Les appels Roblox sont protégés : une erreur devient (false, message).
-- UpdateAsync applique la transformation de manière atomique ; renvoyer nil
-- depuis la transformation annule l'écriture.

local DataStoreService = game:GetService("DataStoreService")

local DataStoreAdapter = {}
DataStoreAdapter.__index = DataStoreAdapter

local PROBE_KEY = "__collectverse_probe"

-- Vérifie que les DataStores sont réellement utilisables. Renvoie (adaptateur) ou (nil, raison).
-- En Studio, il faut une place publiée et « Enable Studio Access to API Services ».
function DataStoreAdapter.probe(storeName: string)
	if game.GameId == 0 then
		return nil, "place non publiée sur Roblox"
	end
	local okStore, store = pcall(function()
		return DataStoreService:GetDataStore(storeName)
	end)
	if not okStore then
		return nil, tostring(store)
	end
	local okRead, err = pcall(function()
		return store:GetAsync(PROBE_KEY)
	end)
	if not okRead then
		return nil, tostring(err)
	end
	return setmetatable({ persistent = true, store = store }, DataStoreAdapter)
end

function DataStoreAdapter.read(self, key: string): (boolean, any)
	return pcall(function()
		return self.store:GetAsync(key)
	end)
end

function DataStoreAdapter.update(self, key: string, transform: (old: any) -> any): (boolean, any)
	return pcall(function()
		return self.store:UpdateAsync(key, function(old)
			return transform(old)
		end)
	end)
end

return DataStoreAdapter
