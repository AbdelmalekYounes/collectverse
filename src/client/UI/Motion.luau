-- Enveloppe de TweenService qui respecte le réglage « animations réduites » :
-- dans ce cas, l'état final est appliqué immédiatement et aucun Tween n'est renvoyé.

local TweenService = game:GetService("TweenService")

local ClientSettings = require(script.Parent.Parent.State.ClientSettings)

local Motion = {}

function Motion.tween(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween?
	if ClientSettings.get("reducedMotion") then
		for key, value in goal do
			(instance :: any)[key] = value
		end
		return nil
	end
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

-- Exécute `callback` à la fin du tween, ou immédiatement s'il n'y en a pas.
function Motion.after(tween: Tween?, callback: () -> ())
	if tween then
		tween.Completed:Once(callback)
	else
		callback()
	end
end

return Motion
