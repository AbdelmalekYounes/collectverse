-- Écran Combat : salle d'attente PvE, puis combat 5 contre 5.
--
-- Planification : sélectionner un allié, choisir une action, puis une cible si
-- nécessaire. Un allié sans ordre fait une attaque normale. « Valider le tour »
-- envoie le plan ; le serveur résout le tour et renvoie événements et état.
-- Les modules partagés servent seulement à griser les choix impossibles.
-- Jalon 2 : interface fonctionnelle. Le jalon 3 ajoutera l'arène 3D et les invocations.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local GameConfig = require(Shared.Config.GameConfig)
local AbilityText = require(Shared.Catalog.AbilityText)
local CardCatalog = require(Shared.Catalog.CardCatalog)
local Boosters = require(Shared.Catalog.Boosters)
local Encounters = require(Shared.Catalog.Encounters)
local BattleEngine = require(Shared.Battle.BattleEngine)
local Targeting = require(Shared.Battle.Targeting)
local Units = require(Shared.Battle.Units)

local Client = script.Parent.Parent.Parent
local BattleController = require(Client.Controllers.BattleController)
local Components = require(Client.UI.Components)
local BattleLog = require(Client.UI.BattleLog)
local UnitCard = require(Client.UI.UnitCard)

local new = Components.new

local BattleScreen = {
	id = "Battle",
	title = "Combat PvE",
	accent = Theme.Colors.Coral,
}

local ENCOUNTER_ID = "RiftEcho1"
local MAX_LOG_LINES = 200

local LOG_COLORS = {
	Turn = Theme.Colors.Gold,
	Action = Theme.Colors.Text,
	Damage = Theme.Colors.Coral,
	Heal = Theme.Colors.Success,
	Status = Theme.Colors.Violet,
	Defeated = Theme.Colors.TextDim,
	End = Theme.Colors.Gold,
}

local RESULT_TEXT = {
	Ally = { title = "Victoire", color = Theme.Colors.Gold },
	Enemy = { title = "Défaite", color = Theme.Colors.Coral },
	Draw = { title = "Égalité", color = Theme.Colors.TextMuted },
}

local function clearGui(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function buildLobby(container: Frame, onLaunch: () -> (), onPrepare: () -> ())
	local encounter = Encounters[ENCOUNTER_ID]
	local lobby = new("Frame", {
		Name = "Lobby",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = container,
	}, { Components.list(Enum.FillDirection.Vertical, 12) })

	local panel = Components.panel({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = lobby,
	}, { Components.padding(14, 16), Components.list(Enum.FillDirection.Vertical, 6) })
	Components.heading("Rencontre 1", { LayoutOrder = 1, TextColor3 = Theme.Colors.Coral, Parent = panel })
	Components.label({
		Text = encounter.name,
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Heading,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = 2,
		Parent = panel,
	})
	local enemyNames = {}
	for _, enemy in encounter.enemies do
		table.insert(enemyNames, CardCatalog.getFighter(enemy.fighterId).name)
	end
	Components.paragraph(
		encounter.description
			.. " Échos présents : "
			.. table.concat(enemyNames, ", ")
			.. ". Planifiez les actions de vos "
			.. GameConfig.Team.Size
			.. " combattants ; la vitesse décide de l'ordre. Une victoire rapporte un booster First Rift.",
		{ LayoutOrder = 3, Parent = panel }
	)

	local actions = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 2,
		Parent = lobby,
	}, { Components.list(Enum.FillDirection.Horizontal, 10) })
	Components.button({
		text = "Préparer l'équipe",
		size = UDim2.fromOffset(190, 44),
		layoutOrder = 1,
		onClick = onPrepare,
	}).Parent =
		actions
	local launch = Components.button({
		text = "Lancer le combat",
		variant = "danger",
		size = UDim2.fromOffset(190, 44),
		layoutOrder = 2,
		onClick = onLaunch,
	})
	launch.Parent = actions

	local message = Components.label({
		Name = "Message",
		Text = "",
		TextColor3 = Theme.Colors.Coral,
		TextSize = Theme.TextSize.Caption,
		LayoutOrder = 3,
		Parent = lobby,
	})
	return lobby, launch, message
end

function BattleScreen.build(container: Frame, controller)
	local state = {
		mode = "Lobby",
		plan = {} :: { [string]: { slot: string, target: string? } },
		selectedUid = nil :: string?,
		pendingSlot = nil :: string?,
		message = nil :: string?,
		submitting = false,
		rewards = nil,
	}
	-- Déclarées d'avance : utilisées par des rappels créés avant leur définition.
	local render
	local clearLog

	local function snapshot()
		return BattleController.getSnapshot()
	end

	local function canPlan(unit): boolean
		return unit.side == "Ally" and unit.alive and not Units.hasStatus(unit, "Stun")
	end

	local function plannedCost(): number
		local current = snapshot()
		local total = 0
		for uid, entry in state.plan do
			local action = BattleEngine.getAction(current.units[uid], entry.slot)
			total += action.cost
		end
		return total
	end

	local function firstPlannable(afterSlot: number?): string?
		local current = snapshot()
		if not current then
			return nil
		end
		local fallback = nil
		for _, unit in Units.living(current, "Ally") do
			if canPlan(unit) then
				fallback = fallback or unit.uid
				if (afterSlot == nil or unit.slot > afterSlot) and state.plan[unit.uid] == nil then
					return unit.uid
				end
			end
		end
		return fallback
	end

	local function resetPlanning()
		state.plan = {}
		state.pendingSlot = nil
		state.selectedUid = firstPlannable(nil)
	end

	-- Coût encore disponible pour l'allié sélectionné (son action actuelle est remboursée).
	local function remainingFor(uid: string): number
		local current = snapshot()
		local own = 0
		local entry = state.plan[uid]
		if entry then
			own = BattleEngine.getAction(current.units[uid], entry.slot).cost
		end
		return current.energy.Ally - plannedCost() + own
	end

	local function setPlan(uid: string, slot: string, target: string?)
		state.plan[uid] = { slot = slot, target = target }
		state.pendingSlot = nil
		state.message = nil
		local unit = snapshot().units[uid]
		state.selectedUid = firstPlannable(unit.slot)
	end

	-- Lobby
	local lobby, launchButton, lobbyMessage
	lobby, launchButton, lobbyMessage = buildLobby(container, function()
		if BattleController.isBusy() then
			return
		end
		Components.setButtonEnabled(launchButton, false)
		local result = BattleController.start(ENCOUNTER_ID)
		Components.setButtonEnabled(launchButton, true)
		if not result.ok then
			lobbyMessage.Text = result.reason or "Impossible de lancer le combat"
			return
		end
		lobbyMessage.Text = ""
		state.mode = "Arena"
		state.rewards = nil
		clearLog()
		resetPlanning()
		render()
	end, function()
		controller.open("Team")
	end)

	-- Arène
	local arena = new("Frame", {
		Name = "Arena",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = container,
	})

	local topBar = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = arena,
	})
	local turnLabel = Components.label({
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Label,
		Size = UDim2.new(0.3, 0, 1, 0),
		Parent = topBar,
	})
	local energyLabel = Components.label({
		FontFace = Theme.Fonts.Bold,
		TextColor3 = Theme.Colors.Cyan,
		Position = UDim2.fromScale(0.3, 0),
		Size = UDim2.new(0.45, 0, 1, 0),
		Parent = topBar,
	})
	Components.button({
		text = "Abandonner",
		textSize = Theme.TextSize.Caption,
		size = UDim2.fromOffset(110, 30),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.fromScale(1, 0),
		onClick = function()
			local current = snapshot()
			if current and current.status == "Planning" then
				BattleController.forfeit()
			end
		end,
	}).Parent =
		topBar

	local field = new("Frame", {
		Name = "Field",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(0.66, -8, 1, -36),
		Parent = arena,
	}, { Components.list(Enum.FillDirection.Vertical, 4) })
	Components.heading("Échos", { LayoutOrder = 1, TextColor3 = Theme.Colors.Coral, Parent = field })
	local function unitRow(order: number): Frame
		return new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, UnitCard.Size.Y.Offset),
			LayoutOrder = order,
			Parent = field,
		}, { Components.list(Enum.FillDirection.Horizontal, 6) })
	end
	local enemyRow = unitRow(2)
	Components.heading("Votre équipe", { LayoutOrder = 3, TextColor3 = Theme.Colors.Cyan, Parent = field })
	local allyRow = unitRow(4)
	local hintLabel = Components.label({
		Name = "Hint",
		TextSize = Theme.TextSize.Caption,
		TextColor3 = Theme.Colors.TextMuted,
		LayoutOrder = 5,
		Parent = field,
	})

	local side = new("Frame", {
		Name = "Command",
		BackgroundTransparency = 1,
		Position = UDim2.new(0.66, 8, 0, 36),
		Size = UDim2.new(0.34, -8, 1, -36),
		Parent = arena,
	})
	local actorLabel = Components.label({
		FontFace = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Body,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = side,
	})
	local actionList = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 4 * 34 + 3 * 4),
		Parent = side,
	}, { Components.list(Enum.FillDirection.Vertical, 4) })

	local validateButton = Components.button({
		text = "Valider le tour",
		variant = "primary",
		position = UDim2.fromOffset(0, 22 + 4 * 34 + 3 * 4 + 6),
		size = UDim2.new(1, 0, 0, 38),
		onClick = function()
			local current = snapshot()
			if state.submitting or not current or current.status ~= "Planning" then
				return
			end
			state.submitting = true
			render()
			local result = BattleController.submit(state.plan)
			state.submitting = false
			if result.ok then
				resetPlanning()
				state.message = nil
			else
				state.message = result.reason
			end
			render()
		end,
	})
	validateButton.Parent = side

	local logTop = 22 + 4 * 34 + 3 * 4 + 6 + 38 + 8
	local log = new("ScrollingFrame", {
		Name = "Log",
		BackgroundColor3 = Theme.Colors.Surface,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, logTop),
		Size = UDim2.new(1, 0, 1, -logTop),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		Parent = side,
	}, {
		Components.corner(Theme.Radius.Small),
		Components.padding(6, 8),
		Components.list(Enum.FillDirection.Vertical, 1),
	})
	local logCount = 0

	clearLog = function()
		for _, child in log:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
	end

	local function appendLog(current, events)
		for _, event in events do
			local text, category = BattleLog.format(current, event)
			if text then
				logCount += 1
				Components.paragraph(text, {
					TextSize = 11,
					TextColor3 = LOG_COLORS[category] or Theme.Colors.TextMuted,
					LayoutOrder = logCount,
					Parent = log,
				})
			end
		end
		-- Limite la taille du journal
		local lines = {}
		for _, child in log:GetChildren() do
			if child:IsA("TextLabel") then
				table.insert(lines, child)
			end
		end
		table.sort(lines, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for index = 1, #lines - MAX_LOG_LINES do
			lines[index]:Destroy()
		end
		task.defer(function()
			log.CanvasPosition = Vector2.new(0, math.max(0, log.AbsoluteCanvasSize.Y - log.AbsoluteWindowSize.Y))
		end)
	end

	-- Bandeau de fin de combat
	local resultOverlay = new("Frame", {
		Name = "Result",
		BackgroundColor3 = Theme.Colors.Overlay,
		BackgroundTransparency = 0.25,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 5,
		Parent = arena,
	}, { Components.corner(Theme.Radius.Medium) })
	local resultPanel = Components.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(360, 190),
		ZIndex = 6,
		Parent = resultOverlay,
	}, { Components.padding(16), Components.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center) })
	local resultTitle = Components.label({
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Title,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 34),
		ZIndex = 6,
		LayoutOrder = 1,
		Parent = resultPanel,
	})
	local resultDetail = Components.label({
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Colors.TextMuted,
		Size = UDim2.new(1, 0, 0, 40),
		ZIndex = 6,
		LayoutOrder = 2,
		Parent = resultPanel,
	})
	local resultButtons = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 3,
		ZIndex = 6,
		Parent = resultPanel,
	}, { Components.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center) })
	local function leaveArena()
		BattleController.clear()
		state.mode = "Lobby"
		render()
	end
	for index, definition in
		{
			{ text = "Rejouer", variant = "danger", action = leaveArena },
			{
				text = "Retour au Hub",
				variant = "secondary",
				action = function()
					leaveArena()
					controller.close()
				end,
			},
		}
	do
		local button = Components.button({
			text = definition.text,
			variant = definition.variant,
			size = UDim2.fromOffset(150, 40),
			layoutOrder = index,
			onClick = definition.action,
		})
		button.ZIndex = 6
		button.Parent = resultButtons
	end

	local function onUnitClicked(uid: string)
		local current = snapshot()
		if not current or current.status ~= "Planning" then
			return
		end
		local unit = current.units[uid]
		if state.pendingSlot and state.selectedUid then
			local actor = current.units[state.selectedUid]
			local action = BattleEngine.getAction(actor, state.pendingSlot)
			if table.find(Targeting.choices(current, actor, action.target), uid) then
				setPlan(actor.uid, state.pendingSlot, uid)
				render()
				return
			end
		end
		if canPlan(unit) then
			state.selectedUid = uid
			state.pendingSlot = nil
			render()
		end
	end

	local function onActionClicked(slot: string)
		local current = snapshot()
		local actor = state.selectedUid and current.units[state.selectedUid]
		if not actor then
			return
		end
		local action = BattleEngine.getAction(actor, slot)
		if Targeting.needsChoice(action.target) then
			local choices = Targeting.choices(current, actor, action.target)
			if #choices == 1 then
				setPlan(actor.uid, slot, choices[1])
			else
				state.pendingSlot = slot
				state.message = nil
			end
		else
			setPlan(actor.uid, slot, nil)
		end
		render()
	end

	local function plannedText(unit): string?
		if unit.side ~= "Ally" or not unit.alive then
			return nil
		end
		if Units.hasStatus(unit, "Stun") then
			return "Étourdi"
		end
		local entry = state.plan[unit.uid]
		if not entry then
			return "Attaque (auto)"
		end
		local label = AbilityText.slotLabel(entry.slot)
		if entry.target then
			return label .. " → " .. snapshot().units[entry.target].name
		end
		return label
	end

	local function renderActions(current)
		clearGui(actionList)
		local actor = state.selectedUid and current.units[state.selectedUid]
		if not actor or current.status ~= "Planning" then
			actorLabel.Text = if current.status == "Planning" then "Aucun combattant à commander" else ""
			return
		end
		actorLabel.Text = "Ordres : " .. actor.name
		local remaining = remainingFor(actor.uid)
		for index, slot in CardCatalog.ActionSlots do
			local action = BattleEngine.getAction(actor, slot)
			local usable = BattleEngine.checkAction(current, actor, slot) and action.cost <= remaining
			local selected = (state.plan[actor.uid] and state.plan[actor.uid].slot == slot) or state.pendingSlot == slot
			local button = Components.button({
				text = string.format("%s — %s", AbilityText.slotLabel(slot), action.name),
				variant = if selected then "primary" else "secondary",
				textSize = 12,
				size = UDim2.new(1, 0, 0, 34),
				layoutOrder = index,
				onClick = function()
					onActionClicked(slot)
				end,
			})
			button.TextXAlignment = Enum.TextXAlignment.Left
			button.TextTruncate = Enum.TextTruncate.AtEnd
			Components.padding(0, 10).Parent = button
			Components.label({
				Text = if action.cost > 0 then tostring(action.cost) else "",
				FontFace = Theme.Fonts.Bold,
				TextColor3 = Theme.Colors.Cyan,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextSize = 12,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, 24, 1, 0),
				Parent = button,
			})
			Components.setButtonEnabled(button, usable)
			button.Parent = actionList
		end
	end

	render = function()
		local current = snapshot()
		if state.mode == "Arena" and not current then
			state.mode = "Lobby"
		end
		lobby.Visible = state.mode == "Lobby"
		arena.Visible = state.mode == "Arena"
		if state.mode ~= "Arena" then
			return
		end

		turnLabel.Text = string.format("Tour %d / %d", current.turn, current.maxTurns)
		energyLabel.Text =
			string.format("Énergie %d / %d  ·  réservée %d", current.energy.Ally, current.maxEnergy, plannedCost())

		local targetable = {}
		if state.pendingSlot and state.selectedUid then
			local actor = current.units[state.selectedUid]
			local action = BattleEngine.getAction(actor, state.pendingSlot)
			for _, uid in Targeting.choices(current, actor, action.target) do
				targetable[uid] = true
			end
		end

		clearGui(enemyRow)
		clearGui(allyRow)
		for _, uid in current.unitOrder do
			local unit = current.units[uid]
			local card = UnitCard.create(unit, current.chargeMax, {
				selected = uid == state.selectedUid,
				targetable = targetable[uid] == true,
				plannedText = plannedText(unit),
				onClick = function()
					onUnitClicked(uid)
				end,
			})
			card.Parent = if unit.side == "Ally" then allyRow else enemyRow
		end

		if state.message then
			hintLabel.Text = state.message
			hintLabel.TextColor3 = Theme.Colors.Coral
		elseif state.pendingSlot then
			hintLabel.Text = "Choisissez une cible (encadrée en blanc)."
			hintLabel.TextColor3 = Theme.Colors.Text
		else
			hintLabel.Text = "Touchez un allié, puis une action. Les alliés sans ordre attaquent."
			hintLabel.TextColor3 = Theme.Colors.TextMuted
		end

		renderActions(current)
		Components.setButtonEnabled(validateButton, current.status == "Planning" and not state.submitting)
		validateButton.Text = if state.submitting then "Résolution…" else "Valider le tour"

		local finished = current.status == "Finished"
		resultOverlay.Visible = finished
		if finished then
			local result = RESULT_TEXT[current.winner] or RESULT_TEXT.Draw
			resultTitle.Text = result.title
			resultTitle.TextColor3 = result.color
			local rewardLines = {}
			if state.rewards and state.rewards.boosters then
				for boosterId, quantity in state.rewards.boosters do
					table.insert(
						rewardLines,
						string.format(
							"+%d booster %s",
							quantity,
							Boosters[boosterId] and Boosters[boosterId].name or boosterId
						)
					)
				end
			end
			resultDetail.Text = if #rewardLines > 0
				then table.concat(rewardLines, "\n")
				else "Aucune récompense cette fois."
		end
	end

	BattleController.Updated:Connect(function(current, events, rewards)
		if events then
			appendLog(current, events)
		end
		if rewards then
			state.rewards = rewards
		end
		render()
	end)

	state.refresh = function()
		local current = snapshot()
		if current and state.mode == "Lobby" then
			state.mode = "Arena"
			resetPlanning()
		end
		render()
	end
	render()
	return state
end

function BattleScreen.onOpen(state)
	state.refresh()
end

return BattleScreen
