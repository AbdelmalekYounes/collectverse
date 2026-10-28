-- Effets de braise posés sur les os (Dev/FighterEmberFx). Studio uniquement :
-- crée des Instances. Le vrai asset n'est jamais modifié (copie).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local FighterEmberFx = require(ServerScriptService.Server.Dev.FighterEmberFx)
local ModelFactory = require(ReplicatedStorage.Shared.Visuals.ModelFactory)

-- Rig minimal au contrat : pivot ancré, maillage soudé qui porte les os.
local function riggedModel(): Model
	local model = Instance.new("Model")
	local pivot = Instance.new("Part")
	pivot.Name = "AssetPivot"
	pivot.Anchored = true
	pivot.Parent = model
	model.PrimaryPart = pivot
	local mesh = Instance.new("Part")
	mesh.Name = "Mesh"
	mesh.Parent = model
	local torso = Instance.new("Bone")
	torso.Name = "UpperTorso"
	torso.Parent = mesh
	local hand = Instance.new("Bone")
	hand.Name = "RightHand"
	hand.Parent = torso
	return model
end

local function countFx(model: Instance): (number, number)
	local lights, emitters = 0, 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("PointLight") then
			lights += 1
		elseif descendant:IsA("ParticleEmitter") then
			emitters += 1
		end
	end
	return lights, emitters
end

return function(test, expect)
	test("Kael : lumières et braises sur les os, sans os ni pièce ajoutés", function()
		local model = riggedModel()
		local parts = #model:GetChildren()
		local report = FighterEmberFx.apply(model, "F001")
		expect.equal(#report.missingBones, 0)
		expect.equal(report.lights, 2, "lame et plastron")
		expect.equal(report.emitters, 1, "braises de la lame")
		expect.equal(report.bones, 2, "aucun os ajouté")
		expect.equal(#model:GetChildren(), parts, "aucune pièce ajoutée")
		local hand = model.Mesh.UpperTorso.RightHand
		expect.truthy(hand:FindFirstChildOfClass("PointLight"), "lumière portée par l'os de la main")
		expect.truthy(hand:FindFirstChildOfClass("ParticleEmitter"), "braises portées par l'os de la main")
		local ok, reason = ModelFactory.validateAsset(model)
		expect.truthy(ok, reason)
		model:Destroy()
	end)

	test("relancer l'outil remplace les effets (idempotent)", function()
		local model = riggedModel()
		FighterEmberFx.apply(model, "F001")
		FighterEmberFx.apply(model, "F001")
		local lights, emitters = countFx(model)
		expect.equal(lights, 2)
		expect.equal(emitters, 1)
		FighterEmberFx.remove(model)
		lights, emitters = countFx(model)
		expect.equal(lights + emitters, 0, "effets retirés")
		model:Destroy()
	end)

	test("os absent : signalé, rien d'autre n'échoue", function()
		local model = riggedModel()
		model.Mesh.UpperTorso.RightHand:Destroy()
		local report = FighterEmberFx.apply(model, "F001")
		expect.equal(#report.missingBones, 1)
		expect.equal(report.missingBones[1], "RightHand")
		expect.equal(report.lights, 1, "le plastron garde sa lumière")
		model:Destroy()
	end)

	test("sur une copie du vrai Kael : 17 os conservés, contrat validé", function()
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local fighters = assets and assets:FindFirstChild("Fighters")
		local kael = fighters and fighters:FindFirstChild("F001_Kael")
		if not kael then
			return -- place construite sans assets
		end
		local copy = kael:Clone()
		local report = FighterEmberFx.apply(copy, "F001")
		expect.equal(#report.missingBones, 0)
		expect.equal(report.bones, 17)
		local ok, reason = ModelFactory.validateAsset(copy)
		expect.truthy(ok, reason)
		expect.truthy(ModelFactory.describeRig(copy).animatable, "toujours animable")
		copy:Destroy()
	end)
end
