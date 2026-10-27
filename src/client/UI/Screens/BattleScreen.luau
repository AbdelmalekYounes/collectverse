-- Écran Combat (salle d'attente PvE).
-- Jalon 1 : présentation de la rencontre. Le combat 5 contre 5 arrive aux jalons 2 et 3.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local GameConfig = require(Shared.Config.GameConfig)

local UI = script.Parent.Parent
local Components = require(UI.Components)

local new = Components.new

local BattleScreen = {
	id = "Battle",
	title = "Combat PvE",
	accent = Theme.Colors.Coral,
}

function BattleScreen.build(container: Frame, controller)
	local column = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = container,
	}, { Components.list(Enum.FillDirection.Vertical, 12) })

	local encounter = Components.panel({
		Name = "Encounter",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = column,
	}, { Components.padding(14, 16), Components.list(Enum.FillDirection.Vertical, 6) })
	Components.heading("Rencontre 1", { LayoutOrder = 1, TextColor3 = Theme.Colors.Coral, Parent = encounter })
	Components.label({
		Text = "Faille instable",
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Heading,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = 2,
		Parent = encounter,
	})
	Components.paragraph(
		"Des Échos s'échappent de la faille centrale. Composez une équipe de "
			.. GameConfig.Team.Size
			.. " combattants, planifiez leurs actions puis laissez la vitesse décider de l'ordre de résolution. "
			.. "Une victoire rapporte un booster First Rift.",
		{ LayoutOrder = 3, Parent = encounter }
	)

	local actions = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 2,
		Parent = column,
	}, { Components.list(Enum.FillDirection.Horizontal, 10) })

	Components.button({
		text = "Préparer l'équipe",
		size = UDim2.fromOffset(190, 44),
		layoutOrder = 1,
		onClick = function()
			controller.open("Team")
		end,
	}).Parent =
		actions

	local launch = Components.button({
		text = "Lancer le combat",
		variant = "danger",
		size = UDim2.fromOffset(190, 44),
		layoutOrder = 2,
	})
	Components.setButtonEnabled(launch, false)
	launch.Parent = actions

	Components.paragraph("Combat disponible au jalon 2 (moteur et IA) et au jalon 3 (invocations 3D).", {
		TextColor3 = Theme.Colors.TextDim,
		TextSize = Theme.TextSize.Caption,
		LayoutOrder = 3,
		Parent = column,
	})
	return {}
end

return BattleScreen
