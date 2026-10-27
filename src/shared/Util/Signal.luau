-- Signal minimal en Luau pur (sans BindableEvent) : utilisable hors de Roblox,
-- donc dans les tests Lune. Les gestionnaires sont appelés immédiatement, dans l'ordre.

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (self: Connection) -> () }

function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end

function Signal.Connect(self, handler: (...any) -> ()): Connection
	local entry = { handler = handler, connected = true }
	table.insert(self.handlers, entry)
	local handlers = self.handlers
	return {
		Disconnect = function()
			entry.connected = false
			local index = table.find(handlers, entry)
			if index then
				table.remove(handlers, index)
			end
		end,
	}
end

function Signal.Fire(self, ...)
	-- Copie : un gestionnaire peut se déconnecter pendant l'appel.
	for _, entry in table.clone(self.handlers) do
		if entry.connected then
			entry.handler(...)
		end
	end
end

return Signal
