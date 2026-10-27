-- Conversion des images-clés Blender en KeyframeSequence (Dev/KeyframeBuilder).
-- Studio uniquement (CFrame, Bone, KeyframeSequence).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Dev = ServerScriptService.Server.Dev
local KeyframeBuilder = require(Dev.KeyframeBuilder)

local function quaternion(cf: CFrame): { number }
	local axis, angle = cf:ToAxisAngle()
	local s = math.sin(angle / 2)
	return { math.cos(angle / 2), axis.X * s, axis.Y * s, axis.Z * s }
end

local function position(v: Vector3): { number }
	return { v.X, v.Y, v.Z }
end

-- Rig synthétique : deux os aux orientations quelconques (axes locaux différents
-- de ceux de Blender), sous une pièce qui sert de pivot.
local function syntheticRig()
	local model = Instance.new("Model")
	local part = Instance.new("Part")
	part.Name = "Body"
	part.Anchored = true
	part.CFrame = CFrame.new()
	part.Parent = model
	model.PrimaryPart = part
	local a = Instance.new("Bone")
	a.Name = "A"
	a.CFrame = CFrame.new(0, 1, 0) * CFrame.Angles(0.3, 1.1, -0.4)
	a.Parent = part
	local b = Instance.new("Bone")
	b.Name = "B"
	b.CFrame = CFrame.new(0, 0, -2) * CFrame.Angles(-0.7, 0.2, 0.9)
	b.Parent = a
	return model, a, b
end

-- Données comme les exporterait Blender : A tourne de 90° autour de la verticale
-- (rotation « monde »), B suit son parent.
local function syntheticData(a: Bone, b: Bone)
	local restA = a.CFrame
	local restB = a.CFrame * b.CFrame
	local delta = CFrame.Angles(0, math.rad(90), 0)
	local posedB = restA.Position + delta:VectorToWorldSpace(restB.Position - restA.Position)
	return {
		animation = "Test",
		model = "Synthetic",
		length = 1,
		loop = false,
		priority = "Action",
		bones = { "A", "B" },
		parents = { B = "A" },
		rest = { A = position(restA.Position), B = position(restB.Position) },
		frames = {
			{
				time = 0,
				bones = {
					A = { p = position(restA.Position), q = { 1, 0, 0, 0 } },
					B = { p = position(restB.Position), q = { 1, 0, 0, 0 } },
				},
			},
			{
				time = 1,
				bones = {
					A = { p = position(restA.Position), q = quaternion(delta) },
					B = { p = position(posedB), q = quaternion(delta) },
				},
			},
		},
	}
end

return function(test, expect)
	test("rotation monde convertie quelles que soient les orientations des os", function()
		local model, a, b = syntheticRig()
		local data = syntheticData(a, b)
		local report = KeyframeBuilder.verify(model, data)
		expect.near(report.restError, 0, 1e-4, "repos")
		expect.near(report.maxError, 0, 1e-4, "positions")
		expect.near(report.maxDrift, 0, 1e-4, "aucune translation parasite : rotations justes")
		local transforms = KeyframeBuilder.solve(model, data, data.frames[2])
		local _, angle = transforms.A:ToAxisAngle()
		expect.near(math.deg(angle), 90, 1e-3, "A tourne de 90°")
		local _, childAngle = transforms.B:ToAxisAngle()
		expect.near(childAngle, 0, 1e-4, "B suit son parent sans rotation propre")
		expect.equal(a.Transform, CFrame.identity, "Transform remis à zéro après vérification")
		model:Destroy()
	end)

	test("la KeyframeSequence reprend images, boucle, priorité et hiérarchie des os", function()
		local model, a, b = syntheticRig()
		local data = syntheticData(a, b)
		local sequence = KeyframeBuilder.build(model, data)
		expect.equal(#sequence:GetKeyframes(), 2)
		expect.falsy(sequence.Loop)
		expect.equal(sequence.Priority, Enum.AnimationPriority.Action)
		local last = sequence:GetKeyframes()[2]
		local poseA = last:FindFirstChild("A")
		expect.truthy(poseA and poseA:FindFirstChild("B"), "pose B imbriquée sous A")
		sequence:Destroy()
		model:Destroy()
	end)

	test("Kael : les 7 animations exportées se convertissent sans écart sur le vrai modèle", function()
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local fighters = assets and assets:FindFirstChild("Fighters")
		local kael = fighters and fighters:FindFirstChild("F001_Kael")
		if not kael then
			-- Place construite sans assets (rojo build simple) : rien à vérifier ici.
			return
		end
		local copy = kael:Clone()
		local folder = Dev.AnimationData.F001_Kael
		local count = 0
		for _, module in folder:GetChildren() do
			count += 1
			local report = KeyframeBuilder.verify(copy, require(module) :: any)
			expect.equal(#report.missing, 0, module.Name .. " : os manquants")
			expect.near(report.restError, 0, 1e-3, module.Name .. " : repos")
			expect.near(report.maxDrift, 0, 1e-3, module.Name .. " : dérive")
		end
		expect.equal(count, 7, "sept animations exportées")
		copy:Destroy()
	end)
end
