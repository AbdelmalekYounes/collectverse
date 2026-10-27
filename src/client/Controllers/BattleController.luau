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
-- (snapshot, events?, rewards?, previous?) — previous : état avant le tour, pour rejouer les événements.
BattleController.Updated = updated.Event

-- Au-delà, une requête sans réponse ne bloque plus les suivantes.
local REQUEST_TIMEOUT = 15

local busySince = 0
local requestToken = 0

local function invoke(name: string, ...): any
	local remote = Remotes.getFunction(name)
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if not ok or type(result) ~= "table" then
		warn(string.format("[Combat] %s : réponse invalide du serveur (%s)", name, tostring(result)))
		return { ok = false, reason = "Connexion au serveur impossible" }
	end
	return result
end

function BattleController.getSnapshot()
	return snapshot
end

function BattleController.isBusy(): boolean
	return busy and os.clock() - busySince < REQUEST_TIMEOUT
end

-- Toutes les requêtes passent par ici : une seule à la fois.
local function request(name: string, ...): any
	if BattleController.isBusy() then
		return { ok = false, reason = "Requête déjà en cours" }
	end
	if busy then
		warn(string.format("[Combat] Requête précédente sans réponse après %d s, ignorée", REQUEST_TIMEOUT))
	end
	busy = true
	busySince = os.clock()
	requestToken += 1
	local token = requestToken
	local result = invoke(name, ...)
	if token ~= requestToken then
		-- Réponse tardive d'une requête abandonnée : l'état plus récent fait foi.
		return { ok = false, reason = "Réponse expirée" }
	end
	busy = false
	if result.ok and result.snapshot then
		local previous = snapshot
		snapshot = result.snapshot
		updated:Fire(snapshot, result.events, result.rewards, previous)
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
