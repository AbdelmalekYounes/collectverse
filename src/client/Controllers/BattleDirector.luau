-- Mise en scène du combat : arène 3D, invocations, plaques, interface et
-- lecture des tours. Aucune règle n'est calculée ici : le serveur résout le tour,
-- BattleReplay rejoue ses événements pour animer l'affichage, puis l'état final
-- est remplacé par le snapshot du serveur, qui fait foi.
--
-- Phases : Idle → Summoning → Planning ⇄ Resolving → Finished → Idle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local CardCatalog = require(Shared.Catalog.CardCatalog)
local Statuses = require(Shared.Catalog.Statuses)
local Signal = require(Shared.Util.Signal)
local VisualAssets = require(Shared.Visuals.VisualAssets)

local Client = script.Parent.Parent
local BattleController = require(script.Parent.BattleController)
local BattlePlanner = require(script.Parent.BattlePlanner)
local BattleReplay = require(script.Parent.BattleReplay)
local ClientSettings = require(Client.State.ClientSettings)
local Arena = require(Client.Battle.Arena)
local BattleCamera = require(Client.Battle.BattleCamera)
local BattleFx = require(Client.Battle.BattleFx)
local FighterAnimator = require(Client.Battle.FighterAnimator)
local SummonController = require(Client.Battle.SummonController)
local BattleHud = require(Client.UI.BattleHud)
local UnitPlate = require(Client.UI.UnitPlate)

local BattleDirector = {}

-- (active: boolean) : entrée et sortie du mode combat
BattleDirector.ModeChanged = Signal.new()
-- (choice: "replay" | "hub") : choix du joueur sur l'écran de résultat
BattleDirector.ExitRequested = Signal.new()

-- Durée d'affichage de chaque temps fort, en secondes (vitesse normale).
local BEAT_SECONDS = {
	TurnStart = 0.5,
	Action = 0.75,
	Skip = 0.55,
	Ticks = 0.6,
	BattleEnd = 0.3,
}
local REDUCED_SPEED = 2.5

local hud
local planner
local plateFolder: Folder
local active = false
local phase = "Idle"
local busy = false
local message: string? = nil
local skipRequested = false
local display = nil -- état affiché (snapshot ou rejeu en cours)
local models: { [string]: Model } = {}
local homes: { [string]: CFrame } = {}
local plates = {}
local viewportConnection: RBXScriptConnection? = nil

local function speed(): number
	return if ClientSettings.get("reducedMotion") then REDUCED_SPEED else 1
end

-- Attend `seconds` sauf si le joueur passe l'animation ou quitte le combat.
local function pause(seconds: number)
	local elapsed = 0
	while elapsed < seconds and not skipRequested and active do
		elapsed += task.wait()
	end
end

local function setPhase(newPhase: string)
	phase = newPhase
	hud.setPhase(newPhase)
end

local function refresh()
	if not active or not display then
		return
	end
	local planning = phase == "Planning"
	hud.renderStatus(display, if planning then planner:plannedCost() else 0)
	local targetable = if planning then planner:targetable() else {}
	for uid, plate in plates do
		local unit = display.units[uid]
		plate.update(unit, {
			selected = planning and planner.selectedUid == uid,
			targetable = targetable[uid] == true,
			plannedText = if planning then planner:plannedText(unit) else nil,
			chargeMax = display.chargeMax,
		})
	end
	if planning then
		hud.renderCommands(BattleController.getSnapshot(), planner, message)
	end
end

local function actionName(unit, slot: string): string
	local fighter = CardCatalog.getFighter(unit.fighterId)
	local action = fighter and fighter.actions[slot]
	return if action then action.name else slot
end

-- Effet visuel associé à un événement (l'état est mis à jour par BattleReplay).
local function playEventFx(event, rate: number)
	local model = event.target and models[event.target]
	if event.type == "Damage" and model then
		local color = if event.kind == "Burn" then Theme.Element.Fire else Theme.Colors.Coral
		BattleFx.flash(model, color, rate)
		local text = "-" .. event.amount
		if event.absorbed > 0 then
			text ..= string.format(" (%d bouclier)", event.absorbed)
		end
		BattleFx.floatText(model, text, color, rate)
		FighterAnimator.play(model, "Hit", rate) -- facultatif : l'éclat suffit sans asset
	elseif event.type == "Heal" and model and event.amount > 0 then
		BattleFx.flash(model, Theme.Colors.Success, rate)
		BattleFx.floatText(model, "+" .. event.amount, Theme.Colors.Success, rate)
	elseif event.type == "Shield" and model then
		BattleFx.floatText(model, "+" .. event.amount .. " bouclier", Theme.Colors.Cyan, rate)
	elseif event.type == "Status" and model then
		local info = Statuses.Info[event.status]
		local color = if info and info.kind == "Debuff" then Theme.Colors.Violet else Theme.Colors.Gold
		BattleFx.floatText(model, if info then info.name else event.status, color, rate)
	elseif event.type == "Defeated" and model then
		FighterAnimator.play(model, "Defeat", rate)
		BattleFx.defeat(model, rate) -- le fondu s'applique dans tous les cas
	elseif event.type == "Skip" and models[event.actor] then
		BattleFx.floatText(models[event.actor], "Étourdi", Theme.Colors.Violet, rate)
	end
end

local function playBeat(beat)
	local rate = speed()
	local first = beat.events[1]
	if first.type == "TurnStart" then
		hud.toast("Tour " .. first.turn, Theme.Colors.Gold, 0.7 / rate)
	elseif first.type == "Action" then
		local actor = display.units[first.actor]
		local color = if actor.side == "Ally" then Theme.Colors.Cyan else Theme.Colors.Coral
		hud.toast(actor.name .. " · " .. actionName(actor, first.slot), color, 0.9 / rate)
		local actorModel = models[first.actor]
		local animationKind = VisualAssets.ActionAnimation[first.slot]
		if actorModel and animationKind and FighterAnimator.play(actorModel, animationKind, rate) then
			-- Animation spécifique jouée : pas de mouvement générique.
			actorModel = nil
		end
		if actorModel then
			-- Élan vers les adversaires visés, simple bond pour une action de soutien.
			local sum, count = Vector3.zero, 0
			for _, uid in first.targets do
				local target = display.units[uid]
				if target and target.side ~= actor.side and models[uid] then
					sum += models[uid]:GetPivot().Position
					count += 1
				end
			end
			if count > 0 then
				BattleFx.lunge(actorModel, sum / count, rate)
			else
				BattleFx.hop(actorModel, rate)
			end
		end
		pause(0.16 / rate)
	end

	for _, event in beat.events do
		BattleReplay.apply(display, event)
		playEventFx(event, rate)
	end
	refresh()
	pause((BEAT_SECONDS[beat.kind] or 0.3) / rate)
end

-- Remet chaque modèle à sa place et applique les défaites (après un passage rapide).
local function settleModels()
	for uid, model in models do
		local unit = display.units[uid]
		if unit and unit.alive then
			if model.PrimaryPart then
				model.PrimaryPart.CFrame = homes[uid]
			end
		else
			BattleFx.defeat(model, 10)
		end
	end
end

local function finish(snapshot, rewards)
	setPhase("Finished")
	refresh()
	hud.showResult(snapshot.winner, rewards)
end

local function playTurn(snapshot, events, rewards, previous)
	if not events then
		-- Abandon ou reprise : pas d'événements à rejouer.
		display = BattleReplay.copy(snapshot)
		if snapshot.status == "Finished" then
			settleModels()
			finish(snapshot, rewards)
		else
			refresh()
		end
		return
	end

	setPhase("Resolving")
	skipRequested = false
	display = BattleReplay.copy(previous or snapshot)
	hud.appendLog(snapshot, events)
	refresh()
	for _, beat in BattleReplay.group(events) do
		if not active then
			return
		end
		if skipRequested then
			for _, event in beat.events do
				BattleReplay.apply(display, event)
			end
		else
			playBeat(beat)
		end
	end
	if not active then
		return
	end

	display = BattleReplay.copy(snapshot)
	skipRequested = false
	settleModels()
	if snapshot.status == "Finished" then
		finish(snapshot, rewards)
	else
		message = nil
		setPhase("Planning")
		planner:reset()
		refresh()
	end
end

local function onUnitClicked(uid: string)
	if phase == "Planning" then
		message = nil
		planner:click(uid)
	end
end

function BattleDirector.isActive(): boolean
	return active
end

-- Entre en mode combat avec le snapshot courant de BattleController.
-- withSummon : jouer les invocations (faux pour une reprise).
function BattleDirector.enter(withSummon: boolean, subtitle: string?)
	local snapshot = BattleController.getSnapshot()
	if active or not snapshot then
		return
	end
	active = true
	busy = false
	message = nil
	skipRequested = false
	display = BattleReplay.copy(snapshot)
	BattleDirector.ModeChanged:Fire(true)

	hud.clearLog()
	hud.hideResult()
	hud.setSubtitle(subtitle or "")
	hud.setVisible(true)
	setPhase("Summoning")
	refresh()

	local arena = Arena.build()
	local actors = Instance.new("Folder")
	actors.Name = "Combatants"
	actors.Parent = arena
	BattleCamera.enter()
	-- Résolution ou orientation modifiée en plein combat : caméra et plaques suivent.
	local camera = Workspace.CurrentCamera
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			BattleCamera.refresh()
			for _, plate in plates do
				plate.resize()
			end
		end)
	end

	local entries = {}
	for _, uid in snapshot.unitOrder do
		local unit = snapshot.units[uid]
		if unit.alive then
			table.insert(entries, { unit = unit, cframe = Arena.slotCFrame(unit.side, unit.slot) })
		end
	end
	local mode = "full"
	if not withSummon then
		mode = "instant"
	elseif ClientSettings.get("skipSummons") or ClientSettings.get("reducedMotion") then
		mode = "reduced"
	end
	local summoned = SummonController.summonAll(entries, actors, mode, function(unit)
		return if unit.side == "Enemy" then Theme.Colors.Coral else nil
	end)
	if not active then
		return
	end

	models = summoned
	for _, model in models do
		FighterAnimator.preload(model)
		FighterAnimator.startIdle(model)
	end
	for uid, model in models do
		homes[uid] = (model.PrimaryPart :: BasePart).CFrame
		plates[uid] = UnitPlate.create(model, display.units[uid], plateFolder, onUnitClicked)
	end

	-- L'état a pu changer pendant les invocations (abandon) : on relit le snapshot.
	local current = BattleController.getSnapshot() or snapshot
	display = BattleReplay.copy(current)
	if current.status == "Finished" then
		finish(current, nil)
	else
		setPhase("Planning")
		planner:reset()
		refresh()
	end
end

function BattleDirector.exit(choice: string)
	if not active then
		return
	end
	active = false
	phase = "Idle"
	SummonController.requestSkip()
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end
	for _, plate in plates do
		plate.billboard:Destroy()
	end
	plateFolder:ClearAllChildren()
	plates = {}
	models = {}
	homes = {}
	display = nil
	hud.setVisible(false)
	BattleCamera.exit()
	Arena.destroy()
	BattleController.clear()
	BattleDirector.ModeChanged:Fire(false)
	BattleDirector.ExitRequested:Fire(choice)
end

function BattleDirector.init(canvas: Frame)
	plateFolder = Instance.new("Folder")
	plateFolder.Name = "CollectverseBattleWorld"
	plateFolder.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	BattleFx.setContainer(plateFolder)

	planner = BattlePlanner.new(BattleController.getSnapshot)
	planner.Changed:Connect(function()
		if phase == "Planning" then
			refresh()
		end
	end)

	hud = BattleHud.create(canvas, {
		onAction = function(slot)
			if phase ~= "Planning" then
				return
			end
			message = nil
			if planner:chooseAction(slot) == "unavailable" then
				local _, reason = planner:isUsable(planner.selectedUid or "", slot)
				message = reason
				refresh()
			end
		end,
		onValidate = function()
			if phase ~= "Planning" or busy then
				return
			end
			busy = true
			hud.setBusy(true)
			local result = BattleController.submit(planner:getPlan())
			busy = false
			hud.setBusy(false)
			if not result.ok then
				message = result.reason
				refresh()
			end
		end,
		onForfeit = function()
			if phase == "Planning" and not busy then
				BattleController.forfeit()
			end
		end,
		onSkip = function()
			skipRequested = true
			SummonController.requestSkip()
		end,
		onReplay = function()
			BattleDirector.exit("replay")
		end,
		onHub = function()
			BattleDirector.exit("hub")
		end,
	})

	BattleController.Updated:Connect(function(snapshot, events, rewards, previous)
		if active and phase ~= "Summoning" then
			task.spawn(playTurn, snapshot, events, rewards, previous)
		end
	end)
end

return BattleDirector
