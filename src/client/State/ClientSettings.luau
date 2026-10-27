-- Préférences locales du joueur (présentation uniquement, jamais de gameplay).
-- Enregistrées dans le profil du joueur par SettingsSync (jalon 4).

local GuiService = game:GetService("GuiService")

local ClientSettings = {}

local values = {
	reducedMotion = false, -- animations d'interface instantanées
	skipSummons = false, -- invocations de combat raccourcies (jalon 3)
	lowEffects = false, -- effets graphiques réduits (appareils peu puissants)
}

-- Respecte le réglage d'accessibilité Roblox « Réduire les animations » s'il existe.
local ok, systemReducedMotion = pcall(function()
	return (GuiService :: any).ReducedMotionEnabled
end)
if ok and systemReducedMotion == true then
	values.reducedMotion = true
end

local changed = Instance.new("BindableEvent")
ClientSettings.Changed = changed.Event

function ClientSettings.get(key: string): any
	return values[key]
end

function ClientSettings.set(key: string, value: any)
	if values[key] == nil then
		error("ClientSettings : réglage inconnu " .. tostring(key))
	end
	if values[key] ~= value then
		values[key] = value
		changed:Fire(key, value)
	end
end

return ClientSettings
