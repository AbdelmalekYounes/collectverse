-- Navigation entre les interfaces.
--
-- Mise à l'échelle : toute l'interface vit dans un « canevas » dont la taille
-- logique est l'écran divisé par un facteur d'échelle, puis agrandi par un UIScale.
-- Les écrans sont donc conçus pour environ 540 unités de haut, et restent
-- lisibles du téléphone (≈ 390 px) au grand écran (≈ 1080 px).
--
-- Un seul écran modal est ouvert à la fois. Chaque module d'écran expose :
--   id, title, accent, build(container, controller) -> state, onOpen?(state), onClose?(state)
-- Les écrans sont construits à la première ouverture puis réutilisés.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Text = require(ReplicatedStorage.Shared.Util.Text)

local BattleDirector = require(script.Parent.BattleDirector)
local DataController = require(script.Parent.DataController)

local UI = script.Parent.Parent.UI
local Components = require(UI.Components)
local Motion = require(UI.Motion)
local Hud = require(UI.Hud)

local Screens = UI.Screens
local SCREEN_MODULES = {
	require(Screens.CollectionScreen),
	require(Screens.TeamScreen),
	require(Screens.BoosterScreen),
	require(Screens.BattleScreen),
	require(Screens.SettingsScreen),
}

local REFERENCE_SIZE = Vector2.new(960, 540)
local MIN_SCALE = 0.6
local MAX_SCALE = 2.2
local HEADER_HEIGHT = 56

local new = Components.new

local UIController = {}

local screenDefinitions = {}
local screenEntries = {}
local currentId: string? = nil
local gui: ScreenGui
local canvas: Frame
local overlay: TextButton
local modalHost: Frame
local hud: Hud.HudApi

local changedEvent = Instance.new("BindableEvent")
UIController.ScreenChanged = changedEvent.Event

local function updateScale(uiScale: UIScale)
	local size = gui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local scale = math.clamp(math.min(size.X / REFERENCE_SIZE.X, size.Y / REFERENCE_SIZE.Y), MIN_SCALE, MAX_SCALE)
	uiScale.Scale = scale
	canvas.Size = UDim2.fromOffset(size.X / scale, size.Y / scale)
end

local function setPromptsEnabled(enabled: boolean)
	-- Masque les invites de proximité du Hub pendant qu'un écran est ouvert.
	pcall(function()
		ProximityPromptService.Enabled = enabled
	end)
end

local function buildModal(definition)
	local accent = definition.accent or Theme.Colors.Violet

	local panel = new("Frame", {
		Name = definition.id .. "Screen",
		Active = true, -- bloque les clics vers le voile (qui fermerait l'écran)
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.88),
		BackgroundColor3 = Theme.Colors.White,
		Visible = false,
		Parent = modalHost,
	}, {
		Components.corner(Theme.Radius.Large),
		Components.stroke(accent, 1.5, 0.35),
		Components.gradient(Theme.Colors.SurfaceRaised, Theme.Colors.Background),
		new("UISizeConstraint", { MaxSize = Vector2.new(1120, 640) }),
	})
	local openScale = new("UIScale", { Name = "OpenScale", Parent = panel })

	local header = new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		Parent = panel,
	}, { Components.padding(0, 20) })
	Components.label({
		Text = Text.upper(definition.title),
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Heading,
		TextWrapped = false,
		Size = UDim2.new(1, -130, 1, 0),
		Parent = header,
	})
	Components.button({
		name = "Close",
		text = "Fermer",
		size = UDim2.fromOffset(110, 36),
		textSize = Theme.TextSize.Body,
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.fromScale(1, 0.5),
		onClick = function()
			UIController.close()
		end,
	}).Parent =
		header

	-- Filet lumineux sous l'en-tête, qui s'estompe vers la droite
	new("Frame", {
		Name = "AccentLine",
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(20, HEADER_HEIGHT - 2),
		Size = UDim2.new(1, -40, 0, 2),
		Parent = panel,
	}, {
		new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})

	local body = new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, HEADER_HEIGHT),
		Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT),
		ClipsDescendants = true,
		Parent = panel,
	}, { Components.padding(16, 20) })

	local state = definition.build(body, UIController)
	return { panel = panel, openScale = openScale, state = state }
end

function UIController.open(screenId: string)
	-- Aucun écran modal pendant un combat : l'interface de combat occupe l'écran.
	if currentId == screenId or BattleDirector.isActive() then
		return
	end
	local definition = screenDefinitions[screenId]
	if not definition then
		warn("[UIController] Écran inconnu : " .. tostring(screenId))
		return
	end
	if currentId then
		UIController.close(true)
	end

	local entry = screenEntries[screenId]
	if not entry then
		entry = buildModal(definition)
		screenEntries[screenId] = entry
	end

	currentId = screenId
	overlay.Visible = true
	Motion.tween(overlay, Theme.Motion.Normal, { BackgroundTransparency = 0.35 })
	entry.panel.Visible = true
	entry.openScale.Scale = 0.94
	Motion.tween(entry.openScale, Theme.Motion.Normal, { Scale = 1 })

	if definition.onOpen then
		definition.onOpen(entry.state)
	end
	setPromptsEnabled(false)
	hud.setActive(screenId)
	changedEvent:Fire(screenId)
end

-- keepOverlay : utilisé lors d'un passage direct d'un écran à un autre.
function UIController.close(keepOverlay: boolean?)
	local closingId = currentId
	if not closingId then
		return
	end
	local definition = screenDefinitions[closingId]
	local entry = screenEntries[closingId]
	entry.panel.Visible = false
	if definition.onClose then
		definition.onClose(entry.state)
	end
	currentId = nil

	if keepOverlay then
		return
	end
	local tween = Motion.tween(overlay, Theme.Motion.Normal, { BackgroundTransparency = 1 })
	Motion.after(tween, function()
		if currentId == nil then
			overlay.Visible = false
		end
	end)
	setPromptsEnabled(true)
	hud.setActive(nil)
	changedEvent:Fire(nil)
end

function UIController.toggle(screenId: string)
	if currentId == screenId then
		UIController.close()
	else
		UIController.open(screenId)
	end
end

function UIController.getCurrent(): string?
	return currentId
end

function UIController.init()
	for _, definition in SCREEN_MODULES do
		screenDefinitions[definition.id] = definition
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = new("ScreenGui", {
		Name = "CollectverseUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = 5,
		Parent = playerGui,
	})
	canvas = new("Frame", {
		Name = "Canvas",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	local uiScale = new("UIScale", { Parent = canvas })

	hud = Hud.create(canvas, UIController)
	DataController.Changed:Connect(hud.setProfile)
	if DataController.getProfile() then
		hud.setProfile(DataController.getProfile())
	end

	-- Mode combat : l'interface du Hub et les invites de zone s'effacent.
	BattleDirector.init(canvas)
	BattleDirector.ModeChanged:Connect(function(inBattle: boolean)
		hud.setVisible(not inBattle)
		setPromptsEnabled(not inBattle)
	end)
	BattleDirector.ExitRequested:Connect(function(choice: string)
		if choice == "replay" then
			UIController.open("Battle")
		end
	end)

	overlay = new("TextButton", {
		Name = "Overlay",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Theme.Colors.Overlay,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 10,
		Parent = canvas,
	})
	overlay.Activated:Connect(function()
		UIController.close()
	end)

	modalHost = new("Frame", {
		Name = "Modals",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 11,
		Parent = canvas,
	})

	updateScale(uiScale)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		updateScale(uiScale)
	end)

	-- Manette : B ferme l'écran ouvert.
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonB and currentId then
			UIController.close()
		end
	end)
end

return UIController
