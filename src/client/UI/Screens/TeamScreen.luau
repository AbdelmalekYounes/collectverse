-- Team Builder : composer une équipe de combattants uniques parmi ceux débloqués.
--
-- Interaction (souris et tactile) : choisir un emplacement, puis un combattant
-- dans la liste. Un combattant déjà placé échange sa place. Toucher deux fois un
-- emplacement occupé le vide. Le client vérifie l'équipe pour guider le joueur,
-- mais c'est la réponse du serveur (TeamService) qui fait foi.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local GameConfig = require(Shared.Config.GameConfig)
local CardCatalog = require(Shared.Catalog.CardCatalog)
local TeamRules = require(Shared.Battle.TeamRules)

local Client = script.Parent.Parent.Parent
local DataController = require(Client.Controllers.DataController)
local Components = require(Client.UI.Components)
local CardTile = require(Client.UI.CardTile)

local new = Components.new

local TeamScreen = {
	id = "Team",
	title = "Équipe",
	accent = Theme.Colors.Violet,
}

local TEAM_SIZE = GameConfig.Team.Size

local function clearChildren(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function slotOf(draft, fighterId: string): number?
	for slot = 1, TEAM_SIZE do
		if draft[slot] == fighterId then
			return slot
		end
	end
	return nil
end

local function sameTeam(a, b): boolean
	for slot = 1, TEAM_SIZE do
		if a[slot] ~= b[slot] then
			return false
		end
	end
	return true
end

local function emptySlot(selected: boolean, onClick: () -> ()): TextButton
	local button = new("TextButton", {
		Name = "EmptySlot",
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.fromOffset(100, 140),
		BackgroundColor3 = Theme.Colors.Surface,
		BackgroundTransparency = 0.3,
	}, {
		Components.corner(Theme.Radius.Medium),
		Components.stroke(
			if selected then Theme.Colors.Cyan else Theme.Colors.Stroke,
			if selected then 2.5 else 1.5,
			0.1
		),
		Components.label({
			Text = if selected then "Choisir →" else "Vide",
			TextColor3 = if selected then Theme.Colors.Cyan else Theme.Colors.TextDim,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
		}),
	})
	button.Activated:Connect(onClick)
	return button
end

function TeamScreen.build(container: Frame, _controller)
	local state = {
		draft = {} :: { [number]: string },
		selectedSlot = 1,
		message = nil :: string?,
		messageIsError = false,
		saving = false,
		loaded = false,
	}

	-- Colonne gauche : emplacements
	local left = new("ScrollingFrame", {
		Name = "Slots",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0.58, -8, 1, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		Parent = container,
	}, { Components.list(Enum.FillDirection.Vertical, 4) })

	local function rowFrame(title: string, order: number): Frame
		Components.heading(title, { LayoutOrder = order, Parent = left })
		return new("Frame", {
			Name = title,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 140),
			LayoutOrder = order + 1,
			Parent = left,
		}, { Components.list(Enum.FillDirection.Horizontal, 8) })
	end
	local frontRow = rowFrame("Ligne avant — protège la ligne arrière", 1)
	local backRow = rowFrame("Ligne arrière", 3)

	local statusLabel = Components.label({
		Name = "Status",
		TextSize = Theme.TextSize.Caption,
		FontFace = Theme.Fonts.Bold,
		LayoutOrder = 5,
		Parent = left,
	})
	local buttons = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 6,
		Parent = left,
	}, { Components.list(Enum.FillDirection.Horizontal, 8) })

	-- Colonne droite : combattants
	local right = new("ScrollingFrame", {
		Name = "Roster",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0.58, 8, 0, 0),
		Size = UDim2.new(0.42, -8, 1, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.Violet,
		Parent = container,
	}, {
		Components.padding(4),
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(100, 140),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local render

	local function loadFromProfile()
		local profile = DataController.getProfile()
		if not profile then
			return
		end
		state.draft = {}
		for slot = 1, TEAM_SIZE do
			state.draft[slot] = profile.team[slot]
		end
		state.selectedSlot = 1
		state.loaded = true
	end

	local function nextEmptySlot(after: number): number
		for offset = 1, TEAM_SIZE do
			local slot = (after + offset - 1) % TEAM_SIZE + 1
			if state.draft[slot] == nil then
				return slot
			end
		end
		return after
	end

	local function onSlotClicked(slot: number)
		if state.selectedSlot == slot and state.draft[slot] then
			state.draft[slot] = nil
		end
		state.selectedSlot = slot
		state.message = nil
		render()
	end

	local function onFighterClicked(fighterId: string)
		local target = state.selectedSlot
		local current = slotOf(state.draft, fighterId)
		if current == target then
			return
		end
		if current then
			-- Échange : l'occupant de l'emplacement visé prend l'ancienne place.
			state.draft[current] = state.draft[target]
		end
		state.draft[target] = fighterId
		state.selectedSlot = nextEmptySlot(target)
		state.message = nil
		render()
	end

	local saveButton
	saveButton = Components.button({
		text = "Enregistrer",
		variant = "primary",
		size = UDim2.fromOffset(150, 40),
		layoutOrder = 1,
		onClick = function()
			if state.saving then
				return
			end
			state.saving = true
			render()
			local team = {}
			for slot = 1, TEAM_SIZE do
				team[slot] = state.draft[slot]
			end
			local result = DataController.requestSetTeam(team)
			state.saving = false
			state.message = if result.ok then "Équipe enregistrée" else result.reason
			state.messageIsError = not result.ok
			render()
		end,
	})
	saveButton.Parent = buttons

	Components.button({
		text = "Suggestion",
		size = UDim2.fromOffset(130, 40),
		layoutOrder = 2,
		onClick = function()
			local profile = DataController.getProfile()
			if not profile then
				return
			end
			local unlocked = {}
			for id in profile.unlockedFighters do
				table.insert(unlocked, id)
			end
			local suggestion = TeamRules.suggest(unlocked)
			state.draft = {}
			for slot = 1, TEAM_SIZE do
				state.draft[slot] = suggestion[slot]
			end
			state.selectedSlot = nextEmptySlot(TEAM_SIZE)
			state.message = nil
			render()
		end,
	}).Parent =
		buttons

	render = function()
		clearChildren(frontRow)
		clearChildren(backRow)
		clearChildren(right)

		local profile = DataController.getProfile()
		if not profile then
			statusLabel.Text = "Chargement du profil…"
			statusLabel.TextColor3 = Theme.Colors.TextMuted
			Components.setButtonEnabled(saveButton, false)
			return
		end
		if not state.loaded then
			loadFromProfile()
		end

		for slot = 1, TEAM_SIZE do
			local row = if TeamRules.rowOfSlot(slot) == "Front" then frontRow else backRow
			local fighter = state.draft[slot] and CardCatalog.getFighter(state.draft[slot])
			local onClick = function()
				onSlotClicked(slot)
			end
			local element
			if fighter then
				element = CardTile.create(fighter, { onClick = onClick })
				element.Size = UDim2.fromOffset(100, 140)
				CardTile.setSelected(element, fighter, slot == state.selectedSlot)
			else
				element = emptySlot(slot == state.selectedSlot, onClick)
			end
			element.LayoutOrder = slot
			element.Parent = row
		end

		for index, fighter in CardCatalog.getFighters() do
			local unlocked = profile.unlockedFighters[fighter.id] == true
			local tile = CardTile.create(fighter, {
				layoutOrder = index,
				owned = unlocked,
				onClick = if unlocked
					then function()
						onFighterClicked(fighter.id)
					end
					else nil,
			})
			if unlocked and slotOf(state.draft, fighter.id) then
				CardTile.setSelected(tile, fighter, true)
			end
			tile.Parent = right
		end

		local valid, reason = TeamRules.validate(state.draft, profile.unlockedFighters)
		local unchanged = sameTeam(state.draft, profile.team)
		if state.message then
			statusLabel.Text = state.message
			statusLabel.TextColor3 = if state.messageIsError then Theme.Colors.Coral else Theme.Colors.Success
		elseif not valid then
			statusLabel.Text = reason or "Équipe incomplète"
			statusLabel.TextColor3 = Theme.Colors.Coral
		else
			statusLabel.Text = if unchanged then "Équipe enregistrée" else "Équipe valide, pensez à l'enregistrer"
			statusLabel.TextColor3 = Theme.Colors.Success
		end
		Components.setButtonEnabled(saveButton, valid and not unchanged and not state.saving)
	end

	DataController.Changed:Connect(function()
		render()
	end)

	state.reload = function()
		state.loaded = false
		state.message = nil
		render()
	end
	render()
	return state
end

function TeamScreen.onOpen(state)
	state.reload()
end

return TeamScreen
