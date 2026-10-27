-- État de planification d'un tour, côté client : allié sélectionné, ordres
-- donnés, action en attente de cible. Logique pure (aucune Instance), testée avec Lune.
--
-- Le planificateur ne fait que guider le joueur (choix grisés, cibles valides) ;
-- le serveur revalide intégralement le plan envoyé.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local AbilityText = require(Shared.Catalog.AbilityText)
local BattleEngine = require(Shared.Battle.BattleEngine)
local Targeting = require(Shared.Battle.Targeting)
local Units = require(Shared.Battle.Units)
local Signal = require(Shared.Util.Signal)

local BattlePlanner = {}
BattlePlanner.__index = BattlePlanner

-- getSnapshot : fonction renvoyant l'état de combat courant (ou nil).
function BattlePlanner.new(getSnapshot: () -> any)
	return setmetatable({
		getSnapshot = getSnapshot,
		plan = {},
		selectedUid = nil :: string?,
		pendingSlot = nil :: string?,
		Changed = Signal.new(),
	}, BattlePlanner)
end

local function planning(self)
	local snapshot = self.getSnapshot()
	if snapshot and snapshot.status == "Planning" then
		return snapshot
	end
	return nil
end

function BattlePlanner.canCommand(_self, unit): boolean
	return unit.side == "Ally" and unit.alive and not Units.hasStatus(unit, "Stun")
end

-- Prochain allié commandable après `afterSlot` sans ordre ; à défaut, le premier commandable.
function BattlePlanner.nextCommandable(self, afterSlot: number?): string?
	local snapshot = self.getSnapshot()
	if not snapshot then
		return nil
	end
	local fallback = nil
	for _, unit in Units.living(snapshot, "Ally") do
		if self:canCommand(unit) then
			fallback = fallback or unit.uid
			if (afterSlot == nil or unit.slot > afterSlot) and self.plan[unit.uid] == nil then
				return unit.uid
			end
		end
	end
	return fallback
end

function BattlePlanner.reset(self)
	self.plan = {}
	self.pendingSlot = nil
	self.selectedUid = self:nextCommandable(nil)
	self.Changed:Fire()
end

function BattlePlanner.plannedCost(self): number
	local snapshot = self.getSnapshot()
	if not snapshot then
		return 0
	end
	local total = 0
	for uid, entry in self.plan do
		total += BattleEngine.getAction(snapshot.units[uid], entry.slot).cost
	end
	return total
end

-- Énergie disponible pour cet allié, son propre ordre actuel étant remboursé.
function BattlePlanner.remainingFor(self, uid: string): number
	local snapshot = self.getSnapshot()
	local entry = self.plan[uid]
	local own = if entry then BattleEngine.getAction(snapshot.units[uid], entry.slot).cost else 0
	return snapshot.energy.Ally - self:plannedCost() + own
end

function BattlePlanner.isUsable(self, uid: string, slot: string): (boolean, string?)
	local snapshot = planning(self)
	if not snapshot then
		return false, "Le combat n'est pas en phase de planification"
	end
	local unit = snapshot.units[uid]
	if not unit or not self:canCommand(unit) then
		return false, "Combattant indisponible"
	end
	local ok, reason = BattleEngine.checkAction(snapshot, unit, slot)
	if not ok then
		return false, reason
	end
	if BattleEngine.getAction(unit, slot).cost > self:remainingFor(uid) then
		return false, "Énergie insuffisante"
	end
	return true, nil
end

function BattlePlanner.select(self, uid: string): boolean
	local snapshot = planning(self)
	local unit = snapshot and snapshot.units[uid]
	if not unit or not self:canCommand(unit) then
		return false
	end
	self.selectedUid = uid
	self.pendingSlot = nil
	self.Changed:Fire()
	return true
end

local function commit(self, uid: string, slot: string, target: string?)
	self.plan[uid] = { slot = slot, target = target }
	self.pendingSlot = nil
	local unit = self.getSnapshot().units[uid]
	self.selectedUid = self:nextCommandable(unit.slot)
	self.Changed:Fire()
end

-- Renvoie "planned", "needsTarget" ou "unavailable".
function BattlePlanner.chooseAction(self, slot: string): string
	local uid = self.selectedUid
	if not uid or not self:isUsable(uid, slot) then
		return "unavailable"
	end
	local snapshot = self.getSnapshot()
	local actor = snapshot.units[uid]
	local action = BattleEngine.getAction(actor, slot)
	if not Targeting.needsChoice(action.target) then
		commit(self, uid, slot, nil)
		return "planned"
	end
	local choices = Targeting.choices(snapshot, actor, action.target)
	if #choices == 1 then
		commit(self, uid, slot, choices[1])
		return "planned"
	end
	self.pendingSlot = slot
	self.Changed:Fire()
	return "needsTarget"
end

function BattlePlanner.targetable(self): { [string]: boolean }
	local result = {}
	local snapshot = planning(self)
	if not snapshot or not self.pendingSlot or not self.selectedUid then
		return result
	end
	local actor = snapshot.units[self.selectedUid]
	local action = BattleEngine.getAction(actor, self.pendingSlot)
	for _, uid in Targeting.choices(snapshot, actor, action.target) do
		result[uid] = true
	end
	return result
end

-- Clic sur un combattant : choisit la cible en attente, sinon sélectionne l'allié.
function BattlePlanner.click(self, uid: string): boolean
	if self.pendingSlot and self:targetable()[uid] then
		commit(self, self.selectedUid :: string, self.pendingSlot, uid)
		return true
	end
	return self:select(uid)
end

function BattlePlanner.cancelTargeting(self)
	if self.pendingSlot then
		self.pendingSlot = nil
		self.Changed:Fire()
	end
end

-- Texte d'ordre affiché sous un allié.
function BattlePlanner.plannedText(self, unit): string?
	if unit.side ~= "Ally" or not unit.alive then
		return nil
	end
	if Units.hasStatus(unit, "Stun") then
		return "Étourdi"
	end
	local entry = self.plan[unit.uid]
	if not entry then
		return "Attaque (auto)"
	end
	local label = AbilityText.slotLabel(entry.slot)
	local snapshot = self.getSnapshot()
	local target = entry.target and snapshot.units[entry.target]
	return if target then label .. " → " .. target.name else label
end

-- Copie du plan à envoyer au serveur.
function BattlePlanner.getPlan(self)
	local copy = {}
	for uid, entry in self.plan do
		copy[uid] = { slot = entry.slot, target = entry.target }
	end
	return copy
end

return BattlePlanner
