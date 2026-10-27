-- État client du combat en cours : dernier snapshot reçu du serveur et
-- envoi des intentions. Aucune règle n'est calculée ici ; l'interface lit
-- le snapshot et utilise les modules partagés (Targeting, BattleEngine.checkAction)
-- uniquement pour griser les choix impossibles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local BattleController = {}

local snapshot = nil
local busy = false

local updated = Instance.new("BindableEvent")
-- (snapshot, events?, rewards?)
BattleController.Updated = updated.Event

local function invoke(name: string, ...): any
	local remote = Remotes.getFunction(name)
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if not ok or type(result) ~= "table" then
		return { ok = false, reason = "Connexion au serveur impossible" }
	end
	return result
end

function BattleController.getSnapshot()
	return snapshot
end

function BattleController.isBusy(): boolean
	return busy
end

-- Toutes les requêtes passent par ici : une seule à la fois.
local function request(name: string, ...): any
	if busy then
		return { ok = false, reason = "Requête déjà en cours" }
	end
	busy = true
	local result = invoke(name, ...)
	busy = false
	if result.ok and result.snapshot then
		snapshot = result.snapshot
		updated:Fire(snapshot, result.events, result.rewards)
	end
	return result
end

function BattleController.start(encounterId: string)
	return request("StartBattle", encounterId)
end

-- plan : { [uid] = { slot, target? } }
function BattleController.submit(plan)
	if not snapshot then
		return { ok = false, reason = "Aucun combat en cours" }
	end
	return request("SubmitTurn", plan, snapshot.turn)
end

function BattleController.forfeit()
	return request("ForfeitBattle")
end

function BattleController.clear()
	snapshot = nil
end

return BattleController
