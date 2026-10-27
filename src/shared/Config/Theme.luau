-- Jetons visuels centralisés (couleurs, polices, rayons, animations).
-- Aucune logique de jeu ici : la présentation lit ce module, jamais l'inverse.

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

local Theme = {}

Theme.Colors = {
	-- Palette de la direction artistique
	Background = hex("#101426"),
	Violet = hex("#7858EB"),
	Cyan = hex("#39CBE7"),
	Gold = hex("#F0BF61"),
	Coral = hex("#F36D79"),

	-- Dérivés pour les surfaces et le texte
	Surface = hex("#171C34"),
	SurfaceRaised = hex("#1F2546"),
	SurfaceHigh = hex("#2A3160"),
	Stroke = hex("#343C70"),
	Text = hex("#EEF0FF"),
	TextMuted = hex("#9AA2CC"),
	TextDim = hex("#646C99"),
	Success = hex("#5ED6A0"),
	Overlay = hex("#05060D"),
	White = Color3.new(1, 1, 1),
}

Theme.Rarity = {
	Common = hex("#AEB6D9"),
	Rare = Theme.Colors.Cyan,
	Epic = Theme.Colors.Violet,
	Legendary = Theme.Colors.Gold,
}

Theme.Element = {
	Fire = hex("#FF7A3D"),
	Earth = hex("#C29A5B"),
	Water = hex("#3FA9F5"),
	Shadow = hex("#8A5CD6"),
	Lightning = hex("#F2E25C"),
	Light = hex("#FFF1C1"),
}

Theme.Fonts = {
	Title = Font.new("rbxasset://fonts/families/Michroma.json", Enum.FontWeight.Regular),
	Body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
	Bold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
}

Theme.TextSize = {
	Caption = 12,
	Body = 14,
	Label = 16,
	Heading = 20,
	Title = 24,
}

Theme.Radius = {
	Small = UDim.new(0, 6),
	Medium = UDim.new(0, 10),
	Large = UDim.new(0, 16),
	Pill = UDim.new(1, 0),
}

Theme.Motion = {
	Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Normal = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
}

return Theme
