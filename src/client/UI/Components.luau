-- Briques d'interface réutilisables, construites en code et stylées par Theme.
-- Toutes les tailles sont exprimées dans l'espace logique du canevas (voir UIController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Text = require(ReplicatedStorage.Shared.Util.Text)
local Motion = require(script.Parent.Motion)

local Components = {}

-- Crée une instance, applique ses propriétés puis ses enfants.
-- Parent est appliqué en dernier pour éviter des rendus intermédiaires.
function Components.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local new = Components.new

local function merge(defaults: { [string]: any }, overrides: { [string]: any }?): { [string]: any }
	local result = table.clone(defaults)
	if overrides then
		for key, value in overrides do
			result[key] = value
		end
	end
	return result
end

function Components.corner(radius: UDim?): UICorner
	return new("UICorner", { CornerRadius = radius or Theme.Radius.Medium })
end

function Components.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return new("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Components.padding(vertical: number, horizontal: number?): UIPadding
	local h = UDim.new(0, horizontal or vertical)
	local v = UDim.new(0, vertical)
	return new("UIPadding", { PaddingTop = v, PaddingBottom = v, PaddingLeft = h, PaddingRight = h })
end

function Components.list(
	direction: Enum.FillDirection?,
	spacing: number?,
	horizontalAlignment: Enum.HorizontalAlignment?
): UIListLayout
	return new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, spacing or 8),
		HorizontalAlignment = horizontalAlignment or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

-- Le dégradé multiplie BackgroundColor3 : on utilise donc un fond blanc
-- et les couleurs réelles dans le dégradé.
function Components.gradient(top: Color3, bottom: Color3, rotation: number?): UIGradient
	return new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	})
end

function Components.label(props: { [string]: any }?): TextLabel
	return new(
		"TextLabel",
		merge({
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.Body,
			TextColor3 = Theme.Colors.Text,
			TextSize = Theme.TextSize.Body,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 20),
		}, props)
	)
end

-- Paragraphe dont la hauteur suit le texte.
function Components.paragraph(text: string, props: { [string]: any }?): TextLabel
	return Components.label(merge({
		Text = text,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Theme.Colors.TextMuted,
	}, props))
end

function Components.heading(text: string, props: { [string]: any }?): TextLabel
	return Components.label(merge({
		Text = Text.upper(text),
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Caption,
		TextColor3 = Theme.Colors.TextMuted,
		Size = UDim2.new(1, 0, 0, 18),
	}, props))
end

-- Pastille d'information (rareté, élément, rôle…).
function Components.chip(text: string, color: Color3, layoutOrder: number?): Frame
	return new("Frame", {
		Name = "Chip",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.82,
		LayoutOrder = layoutOrder or 0,
	}, {
		Components.corner(Theme.Radius.Pill),
		Components.stroke(color, 1, 0.35),
		Components.padding(0, 10),
		Components.label({
			Text = text,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			TextSize = Theme.TextSize.Caption,
			FontFace = Theme.Fonts.Bold,
			TextColor3 = color,
			TextWrapped = false,
		}),
	})
end

local BUTTON_VARIANTS = {
	primary = { background = Theme.Colors.Violet, text = Theme.Colors.Text, stroke = Theme.Colors.Cyan },
	secondary = { background = Theme.Colors.SurfaceHigh, text = Theme.Colors.Text, stroke = Theme.Colors.Stroke },
	gold = { background = Theme.Colors.Gold, text = Theme.Colors.Background, stroke = Theme.Colors.Gold },
	danger = { background = Theme.Colors.Coral, text = Theme.Colors.Background, stroke = Theme.Colors.Coral },
}

export type ButtonOptions = {
	text: string,
	variant: string?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	textSize: number?,
	name: string?,
	onClick: (() -> ())?,
}

function Components.button(options: ButtonOptions): TextButton
	local variant = BUTTON_VARIANTS[options.variant or "secondary"] or BUTTON_VARIANTS.secondary
	local scale = new("UIScale")
	local stroke = Components.stroke(variant.stroke, 1, 0.4)

	local button = new("TextButton", {
		Name = options.name or "Button",
		AutoButtonColor = false,
		Text = options.text,
		FontFace = Theme.Fonts.Bold,
		TextSize = options.textSize or Theme.TextSize.Label,
		TextColor3 = variant.text,
		BackgroundColor3 = variant.background,
		Size = options.size or UDim2.fromOffset(160, 44),
		Position = options.position or UDim2.new(),
		AnchorPoint = options.anchorPoint or Vector2.zero,
		LayoutOrder = options.layoutOrder or 0,
	}, {
		Components.corner(),
		stroke,
		scale,
		Components.gradient(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 220)),
	})

	local function isDisabled(): boolean
		return button:GetAttribute("Disabled") == true
	end

	button.MouseEnter:Connect(function()
		if not isDisabled() then
			Motion.tween(stroke, Theme.Motion.Fast, { Transparency = 0 })
			Motion.tween(scale, Theme.Motion.Fast, { Scale = 1.03 })
		end
	end)
	button.MouseLeave:Connect(function()
		Motion.tween(stroke, Theme.Motion.Fast, { Transparency = 0.4 })
		Motion.tween(scale, Theme.Motion.Fast, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		if not isDisabled() then
			Motion.tween(scale, Theme.Motion.Fast, { Scale = 0.96 })
		end
	end)
	button.MouseButton1Up:Connect(function()
		Motion.tween(scale, Theme.Motion.Fast, { Scale = 1 })
	end)
	button.Activated:Connect(function()
		if not isDisabled() and options.onClick then
			options.onClick()
		end
	end)

	return button
end

function Components.setButtonEnabled(button: TextButton, enabled: boolean)
	button:SetAttribute("Disabled", not enabled)
	button.BackgroundTransparency = if enabled then 0 else 0.6
	button.TextTransparency = if enabled then 0 else 0.45
end

-- Carte d'interface standard (fond dégradé, coins arrondis, bordure fine).
function Components.panel(props: { [string]: any }?, children: { Instance }?): Frame
	local frame = new(
		"Frame",
		merge({
			BackgroundColor3 = Theme.Colors.White,
			Size = UDim2.fromScale(1, 1),
		}, props),
		children
	)
	Components.corner(Theme.Radius.Medium).Parent = frame
	Components.stroke(Theme.Colors.Stroke, 1, 0.3).Parent = frame
	Components.gradient(Theme.Colors.SurfaceRaised, Theme.Colors.Surface).Parent = frame
	return frame
end

-- Barre de progression horizontale (0 à 1).
function Components.bar(ratio: number, color: Color3, props: { [string]: any }?): Frame
	local track = new(
		"Frame",
		merge({
			Name = "Bar",
			BackgroundColor3 = Theme.Colors.SurfaceHigh,
			Size = UDim2.new(1, 0, 0, 6),
		}, props),
		{ Components.corner(Theme.Radius.Pill) }
	)
	new("Frame", {
		Name = "Fill",
		BackgroundColor3 = color,
		Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1),
		Parent = track,
	}, { Components.corner(Theme.Radius.Pill) })
	return track
end

export type ToggleOptions = {
	label: string,
	description: string?,
	value: boolean,
	layoutOrder: number?,
	onChanged: (value: boolean) -> (),
}

-- Interrupteur avec libellé. Renvoie la ligne et une fonction pour forcer la valeur.
function Components.toggle(options: ToggleOptions): (Frame, (boolean) -> ())
	local value = options.value
	local row = Components.panel({
		Name = "Toggle",
		Size = UDim2.new(1, 0, 0, 64),
		LayoutOrder = options.layoutOrder or 0,
	}, { Components.padding(10, 14) })

	Components.label({
		Text = options.label,
		FontFace = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Label,
		Size = UDim2.new(1, -80, 0, 22),
		Parent = row,
	})
	if options.description then
		Components.label({
			Text = options.description,
			TextColor3 = Theme.Colors.TextMuted,
			TextSize = Theme.TextSize.Caption,
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, -80, 0, 20),
			Parent = row,
		})
	end

	local switch = new("TextButton", {
		Name = "Switch",
		AutoButtonColor = false,
		Text = "",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(52, 28),
		Parent = row,
	}, { Components.corner(Theme.Radius.Pill) })
	local knob = new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = Theme.Colors.Text,
		Parent = switch,
	}, { Components.corner(Theme.Radius.Pill) })

	local function render()
		local goalColor = if value then Theme.Colors.Cyan else Theme.Colors.SurfaceHigh
		local goalPosition = if value then UDim2.new(1, -25, 0.5, 0) else UDim2.new(0, 3, 0.5, 0)
		Motion.tween(switch, Theme.Motion.Fast, { BackgroundColor3 = goalColor })
		Motion.tween(knob, Theme.Motion.Fast, { Position = goalPosition })
	end

	switch.Activated:Connect(function()
		value = not value
		render()
		options.onChanged(value)
	end)

	-- État initial sans animation
	switch.BackgroundColor3 = if value then Theme.Colors.Cyan else Theme.Colors.SurfaceHigh
	knob.Position = if value then UDim2.new(1, -25, 0.5, 0) else UDim2.new(0, 3, 0.5, 0)

	return row, function(newValue: boolean)
		value = newValue
		render()
	end
end

return Components
