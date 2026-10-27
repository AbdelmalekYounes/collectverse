-- Liste centralisée des remotes. Le serveur les crée au démarrage ; le client les attend.
-- Convention de réponse des RemoteFunctions : { ok = true, ... } ou { ok = false, reason = "..." }.
-- Le serveur n'invoque jamais le client (pas d'InvokeClient) : seuls des RemoteEvents descendent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "Remotes"

local Remotes = {
	Functions = {
		GetProfile = "GetProfile",
		SetTeam = "SetTeam",
		StartBattle = "StartBattle",
		SubmitTurn = "SubmitTurn",
		ForfeitBattle = "ForfeitBattle",
	},
	Events = {
		ProfileUpdated = "ProfileUpdated",
	},
}

-- Serveur : crée le dossier et toutes les remotes (idempotent).
function Remotes.createServer(): Folder
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for name in Remotes.Functions do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for name in Remotes.Events do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	return folder
end

function Remotes.getFunction(name: string): RemoteFunction
	assert(Remotes.Functions[name], "Remotes : fonction inconnue " .. tostring(name))
	return ReplicatedStorage:WaitForChild(FOLDER_NAME):WaitForChild(name) :: RemoteFunction
end

function Remotes.getEvent(name: string): RemoteEvent
	assert(Remotes.Events[name], "Remotes : événement inconnu " .. tostring(name))
	return ReplicatedStorage:WaitForChild(FOLDER_NAME):WaitForChild(name) :: RemoteEvent
end

return Remotes
