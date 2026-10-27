-- Écran Options : préférences de présentation locales.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local GameConfig = require(Shared.Config.GameConfig)

local Client = script.Parent.Parent.Parent
local ClientSettings = require(Client.State.ClientSettings)
local Components = require(Client.UI.Components)

local new = Components.new

local SettingsScreen = {
	id = "Settings",
	title = "Options",
	accent = Theme.Colors.TextMuted,
}

local TOGGLES = {
	{
		key = "reducedMotion",
		label = "Animations réduites",
		description = "Transitions d'interface instantanées.",
	},
	{
		key = "skipSummons",
		label = "Invocations rapides",
		description = "Raccourcit l'animation carte → personnage en combat.",
	},
	{
		key = "lowEffects",
		label = "Effets réduits",
		description = "Moins de particules et de lumières : pour les appareils peu puissants.",
	},
}

function SettingsScreen.build(container: Frame, _controller)
	local column = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = container,
	}, { Components.list(Enum.FillDirection.Vertical, 10) })

	local setters = {}
	for index, toggle in TOGGLES do
		local row, setValue = Components.toggle({
			label = toggle.label,
			description = toggle.description,
			value = ClientSettings.get(toggle.key),
			layoutOrder = index,
			onChanged = function(value)
				ClientSettings.set(toggle.key, value)
			end,
		})
		row.Parent = column
		setters[toggle.key] = setValue
	end

	-- Garde les interrupteurs synchronisés si un réglage change ailleurs.
	ClientSettings.Changed:Connect(function(key, value)
		local setValue = setters[key]
		if setValue then
			setValue(value)
		end
	end)

	Components.paragraph(
		string.format(
			"Version %s. Ces préférences sont enregistrées dans votre profil (si la sauvegarde est active).",
			GameConfig.Version
		),
		{ TextColor3 = Theme.Colors.TextDim, TextSize = Theme.TextSize.Caption, LayoutOrder = 10, Parent = column }
	)
	return {}
end

return SettingsScreen
