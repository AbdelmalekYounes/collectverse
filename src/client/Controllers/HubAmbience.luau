-- Animations décoratives du Hub, calculées localement (aucun coût réseau).
-- Les pièces portant AmbientSpin (degrés/s) et/ou AmbientBob (studs) tournent
-- et flottent autour de leur position d'origine. Désactivé si « animations réduites ».

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ClientSettings = require(script.Parent.Parent.State.ClientSettings)

local HubAmbience = {}

type Animated = {
	part: BasePart,
	base: CFrame,
	spin: number,
	bob: number,
	phase: number,
}

local animated: { Animated } = {}

local function register(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local spin = instance:GetAttribute("AmbientSpin")
	local bob = instance:GetAttribute("AmbientBob")
	if spin == nil and bob == nil then
		return
	end
	table.insert(animated, {
		part = instance,
		base = instance.CFrame,
		spin = if type(spin) == "number" then spin else 0,
		bob = if type(bob) == "number" then bob else 0,
		phase = #animated * 0.7,
	})
end

local function step()
	if ClientSettings.get("reducedMotion") then
		return
	end
	local now = os.clock()
	-- Parcours à rebours pour retirer les pièces détruites (ex. streaming).
	for index = #animated, 1, -1 do
		local entry = animated[index]
		if entry.part.Parent == nil then
			table.remove(animated, index)
		else
			local offset = math.sin(now * 1.6 + entry.phase) * entry.bob
			entry.part.CFrame = entry.base * CFrame.new(0, offset, 0) * CFrame.Angles(0, math.rad(entry.spin * now), 0)
		end
	end
end

function HubAmbience.init()
	task.spawn(function()
		local hub = Workspace:WaitForChild("CollectverseHub", 30)
		if not hub then
			warn("[HubAmbience] Hub introuvable : animations décoratives désactivées")
			return
		end
		for _, descendant in hub:GetDescendants() do
			register(descendant)
		end
		hub.DescendantAdded:Connect(register)
		RunService.RenderStepped:Connect(step)
	end)
end

return HubAmbience
