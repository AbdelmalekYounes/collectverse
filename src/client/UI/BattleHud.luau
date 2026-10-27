-- Interface plein écran du mode combat, superposée à l'arène 3D.
--   Haut : tour, jauge d'énergie (disponible / réservée), Passer, Abandonner.
--   Bas : barre d'ordres (allié sélectionné, 4 actions, Valider le tour).
--   Droite : journal repliable. Centre : annonces d'actions et écran de résultat.
-- Le centre de l'écran reste libre pour l'arène et les plaques des combattants.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local AbilityText = require(Shared.Catalog.AbilityText)
local Boosters = require(Shared.Catalog.Boosters)
local CardCatalog = require(Shared.Catalog.CardCatalog)
local Roles = require(Shared.Catalog.Roles)
local BattleEngine = require(Shared.Battle.BattleEngine)
local Text = require(Shared.Util.Text)

local Components = require(script.Parent.Components)
local Motion = require(script.Parent.Motion)
local BattleLog = require(script.Parent.BattleLog)

local new = Components.new

local BattleHud = {}

local MAX_LOG_LINES = 200
local COMMAND_HEIGHT = 96

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

local PHASE_TEXT = {
	Summoning = "Invocation des combattants…",
	Resolving = "Résolution du tour…",
}

local SLOT_COLORS = {
	basic = Theme.Colors.TextMuted,
	skill = Theme.Colors.Cyan,
	ultimate = Theme.Colors.Gold,
	defend = Theme.Colors.Success,
}

export type Handlers = {
	onAction: (slot: string) -> (),
	onValidate: () -> (),
	onForfeit: () -> (),
	onSkip: () -> (),
	onReplay: () -> (),
	onHub: () -> (),
}

local function clearGui(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function darkPanel(props)
	local frame = new("Frame", props)
	frame.BackgroundColor3 = Theme.Colors.Background
	frame.BackgroundTransparency = 0.15
	Components.corner(Theme.Radius.Medium).Parent = frame
	Components.stroke(Theme.Colors.Stroke, 1, 0.3).Parent = frame
	return frame
end

function BattleHud.create(canvas: Frame, handlers: Handlers)
	local root = new("Frame", {
		Name = "BattleHud",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 20,
		Parent = canvas,
	})

	-- Haut ----------------------------------------------------------------
	local topLeft = darkPanel({
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(240, 82),
		Parent = root,
	})
	Components.padding(6, 12).Parent = topLeft
	local turnLabel = Components.label({
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Label,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = topLeft,
	})
	local subtitleLabel = Components.label({
		TextSize = Theme.TextSize.Caption,
		TextColor3 = Theme.Colors.Coral,
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = topLeft,
	})

	-- L'énergie partage le panneau du tour : le haut-centre de l'écran reste libre
	-- pour les plaques des Échos de la ligne arrière (et la bande réservée par Roblox).
	local energyLabel = Components.label({
		FontFace = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Caption,
		TextColor3 = Theme.Colors.Cyan,
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = topLeft,
	})
	local pipRow = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 12),
		Parent = topLeft,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local pips = {}

	local topRight = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(320, 40),
		Parent = root,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local logToggle = Components.button({
		text = "Journal",
		textSize = Theme.TextSize.Caption,
		size = UDim2.fromOffset(90, 36),
		layoutOrder = 1,
	})
	logToggle.Parent = topRight
	local skipButton = Components.button({
		text = "Passer ▶▶",
		variant = "gold",
		textSize = Theme.TextSize.Caption,
		size = UDim2.fromOffset(100, 36),
		layoutOrder = 2,
		onClick = handlers.onSkip,
	})
	skipButton.Visible = false
	skipButton.Parent = topRight
	local forfeitButton = Components.button({
		text = "Abandonner",
		textSize = Theme.TextSize.Caption,
		size = UDim2.fromOffset(100, 36),
		layoutOrder = 3,
		onClick = handlers.onForfeit,
	})
	forfeitButton.Parent = topRight

	-- Annonces et phase : en bas, à la place de la barre d'ordres (masquée hors planification).
	local phaseLabel = Components.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(360, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Bold,
		TextColor3 = Theme.Colors.TextMuted,
		TextStrokeTransparency = 0.5,
		Visible = false,
		Parent = root,
	})
	local toast = new("Frame", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -44),
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 1,
		Parent = root,
	}, { Components.corner(Theme.Radius.Pill), Components.padding(0, 18) })
	local toastLabel = Components.label({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		FontFace = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Label,
		TextWrapped = false,
		TextTransparency = 1,
		Parent = toast,
	})
	local toastToken = 0

	-- Barre d'ordres ------------------------------------------------------
	local hintLabel = Components.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(COMMAND_HEIGHT + 18)),
		Size = UDim2.new(0.9, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = Theme.TextSize.Caption,
		TextStrokeTransparency = 0.4,
		Parent = root,
	})
	local command = darkPanel({
		Name = "Command",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(0.96, 0, 0, COMMAND_HEIGHT),
		Parent = root,
	})
	new("UISizeConstraint", { MaxSize = Vector2.new(900, COMMAND_HEIGHT) }).Parent = command
	Components.padding(10, 12).Parent = command

	local actorName = Components.label({
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Body,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(0, 130, 0, 22),
		Parent = command,
	})
	local actorRole = Components.label({
		TextSize = Theme.TextSize.Caption,
		TextColor3 = Theme.Colors.TextMuted,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(0, 130, 0, 40),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = command,
	})
	local actionRow = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(140, 0),
		Size = UDim2.new(1, -140 - 150, 1, 0),
		Parent = command,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local validateButton = Components.button({
		text = "Valider le tour",
		variant = "primary",
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.fromScale(1, 0),
		size = UDim2.new(0, 140, 1, 0),
		onClick = handlers.onValidate,
	})
	validateButton.Parent = command

	-- Journal --------------------------------------------------------------
	local log = new("ScrollingFrame", {
		Name = "Log",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 58),
		Size = UDim2.fromOffset(280, 220),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		Visible = false,
		Parent = root,
	}, {
		Components.corner(Theme.Radius.Medium),
		Components.padding(6, 8),
		Components.list(Enum.FillDirection.Vertical, 1),
	})
	local logCount = 0
	logToggle.Activated:Connect(function()
		log.Visible = not log.Visible
	end)

	-- Résultat ---------------------------------------------------------------
	local resultOverlay = new("Frame", {
		Name = "Result",
		BackgroundColor3 = Theme.Colors.Overlay,
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 30,
		Parent = root,
	})
	local resultPanel = Components.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 200),
		Parent = resultOverlay,
	}, { Components.padding(18), Components.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Center) })
	local resultScale = new("UIScale", { Parent = resultPanel })
	local resultTitle = Components.label({
		FontFace = Theme.Fonts.Title,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 1,
		Parent = resultPanel,
	})
	local resultDetail = Components.label({
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Colors.TextMuted,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 2,
		Parent = resultPanel,
	})
	local resultButtons = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 3,
		Parent = resultPanel,
	}, { Components.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center) })
	Components.button({
		text = "Rejouer",
		variant = "danger",
		size = UDim2.fromOffset(160, 44),
		layoutOrder = 1,
		onClick = handlers.onReplay,
	}).Parent =
		resultButtons
	Components.button({
		text = "Retour au Hub",
		size = UDim2.fromOffset(160, 44),
		layoutOrder = 2,
		onClick = handlers.onHub,
	}).Parent =
		resultButtons

	-- API --------------------------------------------------------------------
	local api = {}

	function api.setVisible(visible: boolean)
		root.Visible = visible
		if not visible then
			resultOverlay.Visible = false
		end
	end

	function api.setPhase(phase: string)
		local planning = phase == "Planning"
		command.Visible = planning
		hintLabel.Visible = planning
		skipButton.Visible = phase == "Summoning" or phase == "Resolving"
		forfeitButton.Visible = phase ~= "Finished"
		phaseLabel.Visible = PHASE_TEXT[phase] ~= nil
		phaseLabel.Text = PHASE_TEXT[phase] or ""
	end

	function api.setSubtitle(text: string)
		subtitleLabel.Text = text
	end

	-- state : état affiché (snapshot ou rejeu en cours) ; reserved : énergie réservée par le plan.
	function api.renderStatus(state, reserved: number)
		turnLabel.Text = string.format("TOUR %d / %d", state.turn, state.maxTurns)
		local energy = state.energy.Ally
		energyLabel.Text = if reserved > 0
			then string.format("Énergie %d / %d  ·  %d réservée(s)", energy, state.maxEnergy, reserved)
			else string.format("Énergie %d / %d", energy, state.maxEnergy)
		for index = 1, state.maxEnergy do
			local pip = pips[index]
			if not pip then
				pip = new("Frame", {
					Size = UDim2.fromOffset(18, 12),
					LayoutOrder = index,
					Parent = pipRow,
				}, { Components.corner(Theme.Radius.Small) })
				pips[index] = pip
			end
			local available = index <= energy - reserved
			local isReserved = not available and index <= energy
			pip.BackgroundColor3 = if available
				then Theme.Colors.Cyan
				elseif isReserved then Theme.Colors.Gold
				else Theme.Colors.SurfaceHigh
		end
	end

	function api.renderCommands(snapshot, planner, message: string?)
		clearGui(actionRow)
		local actor = planner.selectedUid and snapshot.units[planner.selectedUid]
		if not actor then
			actorName.Text = "—"
			actorRole.Text = ""
			hintLabel.Text = message or "Aucun combattant à commander : validez le tour."
			hintLabel.TextColor3 = if message then Theme.Colors.Coral else Theme.Colors.TextMuted
			return
		end
		actorName.Text = actor.name
		actorRole.Text = Roles.Info[actor.role].name .. " · " .. Roles.Rows[actor.row].name

		local fighter = CardCatalog.getFighter(actor.fighterId)
		local planned = planner.plan[actor.uid]
		for index, slot in CardCatalog.ActionSlots do
			local action = fighter.actions[slot]
			local usable = planner:isUsable(actor.uid, slot)
			local selected = (planned and planned.slot == slot) or planner.pendingSlot == slot
			local button = Components.button({
				text = "",
				variant = if selected then "primary" else "secondary",
				size = UDim2.new(0.25, -5, 1, 0),
				layoutOrder = index,
				onClick = function()
					handlers.onAction(slot)
				end,
			})
			Components.padding(6, 8).Parent = button
			Components.label({
				Text = Text.upper(AbilityText.slotLabel(slot)),
				FontFace = Theme.Fonts.Bold,
				TextSize = 11,
				TextColor3 = SLOT_COLORS[slot],
				Size = UDim2.new(1, -24, 0, 14),
				Parent = button,
			})
			Components.label({
				Text = if action.cost > 0 then tostring(action.cost) else "",
				FontFace = Theme.Fonts.Bold,
				TextSize = 12,
				TextColor3 = Theme.Colors.Cyan,
				TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, 24, 0, 14),
				Parent = button,
			})
			Components.label({
				Text = action.name,
				FontFace = Theme.Fonts.Bold,
				TextSize = Theme.TextSize.Body,
				TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.fromOffset(0, 16),
				Size = UDim2.new(1, 0, 1, -16),
				Parent = button,
			})
			Components.setButtonEnabled(button, usable)
			button.Parent = actionRow
		end

		if message then
			hintLabel.Text = message
			hintLabel.TextColor3 = Theme.Colors.Coral
		elseif planner.pendingSlot then
			local action = BattleEngine.getAction(actor, planner.pendingSlot)
			hintLabel.Text = "Touchez une cible encadrée en blanc pour « " .. action.name .. " »."
			hintLabel.TextColor3 = Theme.Colors.Text
		else
			local slot = if planned then planned.slot else "basic"
			hintLabel.Text = AbilityText.describe(fighter.actions[slot])
			hintLabel.TextColor3 = Theme.Colors.TextMuted
		end
	end

	function api.setBusy(busy: boolean)
		Components.setButtonEnabled(validateButton, not busy)
		validateButton.Text = if busy then "Envoi…" else "Valider le tour"
	end

	function api.toast(text: string, color: Color3, seconds: number)
		toastToken += 1
		local token = toastToken
		toastLabel.Text = text
		toastLabel.TextColor3 = color
		toast.BackgroundTransparency = 0.2
		toastLabel.TextTransparency = 0
		task.delay(seconds, function()
			if token == toastToken then
				Motion.tween(toast, Theme.Motion.Normal, { BackgroundTransparency = 1 })
				Motion.tween(toastLabel, Theme.Motion.Normal, { TextTransparency = 1 })
			end
		end)
	end

	function api.clearLog()
		for _, child in log:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
	end

	function api.appendLog(snapshot, events)
		for _, event in events do
			local text, category = BattleLog.format(snapshot, event)
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

	function api.showResult(winner: string?, rewards)
		local result = RESULT_TEXT[winner or "Draw"] or RESULT_TEXT.Draw
		resultTitle.Text = result.title
		resultTitle.TextColor3 = result.color
		local lines = {}
		if rewards and rewards.boosters then
			for boosterId, quantity in rewards.boosters do
				local booster = Boosters[boosterId]
				table.insert(
					lines,
					string.format("+%d booster %s", quantity, if booster then booster.name else boosterId)
				)
			end
		end
		resultDetail.Text = if #lines > 0 then table.concat(lines, "\n") else "Aucune récompense cette fois."
		resultOverlay.Visible = true
		resultScale.Scale = 0.85
		Motion.tween(resultScale, Theme.Motion.Slow, { Scale = 1 })
	end

	function api.hideResult()
		resultOverlay.Visible = false
	end

	return api
end

return BattleHud
