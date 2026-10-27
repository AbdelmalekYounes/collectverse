-- Interface permanente du Hub : logo, pastilles d'état et barre de navigation.
-- La navigation est placée à droite, au-dessus du bouton de saut mobile,
-- pour ne pas gêner le joystick virtuel (en bas à gauche).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Components = require(script.Parent.Components)
local Motion = require(script.Parent.Motion)

local new = Components.new

local Hud = {}

local NAV_ITEMS = {
	{ id = "Collection", label = "Collection", color = Theme.Colors.Cyan },
	{ id = "Team", label = "Équipe", color = Theme.Colors.Violet },
	{ id = "Booster", label = "Boosters", color = Theme.Colors.Gold },
	{ id = "Battle", label = "Combat", color = Theme.Colors.Coral },
	{ id = "Settings", label = "Options", color = Theme.Colors.TextMuted },
}

local NAV_WIDTH = 150

export type HudApi = {
	setActive: (screenId: string?) -> (),
	setBoosterCount: (count: number?) -> (),
}

function Hud.create(canvas: Frame, controller): HudApi
	-- Logo
	local brand = new("Frame", {
		Name = "Brand",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.fromOffset(280, 46),
		Parent = canvas,
	})
	Components.label({
		Text = "COLLECTVERSE",
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Heading,
		TextWrapped = false,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = brand,
	})
	Components.label({
		Text = "Echoes of the Rift",
		TextColor3 = Theme.Colors.Cyan,
		TextSize = Theme.TextSize.Caption,
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = brand,
	})

	-- Pastilles d'état (en haut à droite)
	local status = new("Frame", {
		Name = "Status",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(400, 22),
		Parent = canvas,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	Components.chip("Prototype v0.1", Theme.Colors.TextMuted, 1).Parent = status
	local boosterChip = Components.chip("Boosters : —", Theme.Colors.Gold, 2)
	boosterChip.Parent = status
	local boosterLabel = boosterChip:FindFirstChildOfClass("TextLabel") :: TextLabel

	-- Navigation
	local nav = new("Frame", {
		Name = "Nav",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.45, 0),
		Size = UDim2.fromOffset(NAV_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = canvas,
	}, { Components.list(Enum.FillDirection.Vertical, 6) })

	local navButtons = {}
	for index, item in NAV_ITEMS do
		local button = Components.button({
			name = item.id,
			text = item.label,
			size = UDim2.fromOffset(NAV_WIDTH, 44),
			layoutOrder = index,
			onClick = function()
				controller.toggle(item.id)
			end,
		})
		button.TextXAlignment = Enum.TextXAlignment.Left
		Components.padding(0, 18).Parent = button
		new("Frame", {
			Name = "Accent",
			BackgroundColor3 = item.color,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -10, 0.5, 0),
			Size = UDim2.new(0, 3, 0.55, 0),
			Parent = button,
		}, { Components.corner(Theme.Radius.Pill) })
		button.Parent = nav
		navButtons[item.id] = { button = button, color = item.color }
	end

	local api = {}

	-- La navigation se replie pendant qu'un écran est ouvert (le panneau la recouvrirait).
	function api.setActive(screenId: string?)
		local hidden = screenId ~= nil
		Motion.tween(nav, Theme.Motion.Normal, {
			Position = if hidden then UDim2.new(1, NAV_WIDTH + 24, 0.45, 0) else UDim2.new(1, -16, 0.45, 0),
		})
		for id, entry in navButtons do
			local stroke = entry.button:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if id == screenId then entry.color else Theme.Colors.Stroke
			end
		end
	end

	function api.setBoosterCount(count: number?)
		boosterLabel.Text = "Boosters : " .. (if count then tostring(count) else "—")
	end

	return api
end

return Hud
