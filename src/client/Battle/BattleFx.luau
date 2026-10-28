-- Effets visuels de combat : élan d'attaque, éclat d'impact, chiffres flottants,
-- chute d'un combattant. Purement décoratifs : l'état réel vient du serveur.
-- `speed` (> 0) accélère les effets ; avec « animations réduites », ils sont
-- appliqués sans transition.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local BattleFx = {}

local container: Instance? = nil

-- Les BillboardGui doivent vivre dans le PlayerGui pour s'afficher côté client.
function BattleFx.setContainer(folder: Instance)
	container = folder
end

local function tween(
	instance: Instance,
	seconds: number,
	goal,
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local created = TweenService:Create(instance, info, goal)
	created:Play()
	return created
end

local function modelHeight(model: Model): number
	return model:GetExtentsSize().Y
end

-- Chiffre ou mot flottant au-dessus d'un combattant.
function BattleFx.floatText(model: Model, text: string, color: Color3, speed: number)
	if not container or not model.PrimaryPart then
		return
	end
	local height = modelHeight(model) * 0.75
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "FloatText"
	billboard.Adornee = model.PrimaryPart
	billboard.Size = UDim2.fromScale(6, 1.4)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = container

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.FontFace = Theme.Fonts.Bold
	label.TextColor3 = color
	label.TextStrokeColor3 = Theme.Colors.Background
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard

	local duration = 0.9 / speed
	tween(billboard, duration, { StudsOffsetWorldSpace = Vector3.new(0, height + 2.2, 0) })
	task.delay(duration * 0.5, function()
		tween(label, duration * 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	task.delay(duration, function()
		billboard:Destroy()
	end)
end

-- Éclat bref sur le Highlight du modèle, puis retour à son état de base.
function BattleFx.flash(model: Model, color: Color3, speed: number)
	local highlight = model:FindFirstChild("FxHighlight") :: Highlight?
	if not highlight then
		return
	end
	local baseFill = highlight:GetAttribute("BaseFillTransparency") or 1
	local baseOutline = highlight:GetAttribute("BaseOutlineTransparency") or 1
	local baseColor = highlight:GetAttribute("BaseColor") or color
	-- Le contour peut avoir sa propre couleur (contour chaud des alliés).
	local baseOutlineColor = highlight:GetAttribute("BaseOutlineColor") or baseColor
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = 0.25
	highlight.OutlineTransparency = 0
	local fade = tween(highlight, 0.35 / speed, { FillTransparency = baseFill, OutlineTransparency = baseOutline })
	fade.Completed:Once(function()
		highlight.FillColor = baseColor
		highlight.OutlineColor = baseOutlineColor
	end)
end

-- Élan vers une position puis retour à l'emplacement.
function BattleFx.lunge(model: Model, toward: Vector3, speed: number)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local home = root.CFrame
	local offset = toward - home.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude < 0.01 then
		return
	end
	local step = flat.Unit * math.min(2.5, flat.Magnitude * 0.4)
	local forward = tween(root, 0.16 / speed, { CFrame = home + step }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	forward.Completed:Once(function()
		tween(root, 0.2 / speed, { CFrame = home }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	end)
end

-- Léger bond sur place (actions de soutien et défense).
function BattleFx.hop(model: Model, speed: number)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local home = root.CFrame
	local up = tween(root, 0.14 / speed, { CFrame = home + Vector3.new(0, 0.8, 0) })
	up.Completed:Once(function()
		tween(root, 0.18 / speed, { CFrame = home }, Enum.EasingStyle.Bounce)
	end)
end

-- Le combattant s'efface et s'enfonce.
function BattleFx.defeat(model: Model, speed: number)
	local root = model.PrimaryPart
	if not root or model:GetAttribute("Defeated") then
		return
	end
	model:SetAttribute("Defeated", true)
	local duration = 0.5 / speed
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= root then
			tween(descendant, duration, { Transparency = 1 })
		elseif descendant:IsA("Light") then
			tween(descendant, duration, { Brightness = 0 })
		elseif descendant:IsA("Highlight") then
			descendant.Enabled = false
		end
	end
	tween(root, duration, { CFrame = root.CFrame - Vector3.new(0, 1.2, 0) })
end

return BattleFx
