-- Animations décoratives du Hub, calculées localement (aucun coût réseau).
-- Les pièces portant AmbientSpin (degrés/s) et/ou AmbientBob (studs) tournent
-- et flottent autour de leur position d'origine. Désactivé si « animations réduites »
-- et suspendu pendant un combat (le Hub n'est alors plus à l'écran).

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ClientSettings = require(script.Parent.Parent.State.ClientSettings)
local BattleDirector = require(script.Parent.BattleDirector)

local HubAmbience = {}

type Animated = {
	part: BasePart,
	base: CFrame,
	spin: number,
	bob: number,
	phase: number,
}

local animated: { Animated } = {}
local inBattle = false
-- Tampons réutilisés à chaque image pour BulkMoveTo (évite d'allouer deux tables par image).
local bulkParts: { BasePart } = {}
local bulkCFrames: { CFrame } = {}

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
	if inBattle or ClientSettings.get("reducedMotion") then
		return
	end
	local now = os.clock()
	local count = 0
	-- Parcours à rebours pour retirer les pièces détruites (ex. streaming).
	for index = #animated, 1, -1 do
		local entry = animated[index]
		if entry.part.Parent == nil then
			table.remove(animated, index)
		else
			local offset = math.sin(now * 1.6 + entry.phase) * entry.bob
			count += 1
			bulkParts[count] = entry.part
			bulkCFrames[count] = entry.base * CFrame.new(0, offset, 0) * CFrame.Angles(0, math.rad(entry.spin * now), 0)
		end
	end
	for index = #bulkParts, count + 1, -1 do
		bulkParts[index] = nil
		bulkCFrames[index] = nil
	end
	if count > 0 then
		-- Un seul appel moteur pour toutes les pièces. FireCFrameChanged est le mode
		-- le plus léger : seul l'événement CFrame est émis, pas Position/Orientation.
		Workspace:BulkMoveTo(bulkParts, bulkCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function HubAmbience.init()
	BattleDirector.ModeChanged:Connect(function(active: boolean)
		inBattle = active
	end)
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
