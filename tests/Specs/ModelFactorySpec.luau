local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local CardCatalog = require(Shared.Catalog.CardCatalog)
local ModelFactory = require(Shared.Visuals.ModelFactory)
local VisualAssets = require(Shared.Visuals.VisualAssets)
local Client = StarterPlayer.StarterPlayerScripts.Client
local SummonController = require(Client.Battle.SummonController)
local FighterAnimator = require(Client.Battle.FighterAnimator)

-- Personnage riggé minimal, monté comme un rig Roblox : racine ancrée,
-- membre relié par un Motor6D, AnimationController + Animator.
local function motorRig(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Anchored = true
	root.Transparency = 1
	root.Size = Vector3.new(2, 0.2, 1)
	root.Parent = model
	model.PrimaryPart = root
	local torso = Instance.new("Part")
	torso.Name = "UpperTorso"
	torso.Anchored = false
	torso.CanCollide = false
	torso.Size = Vector3.new(2, 2, 1)
	torso.CFrame = root.CFrame * CFrame.new(0, 3, 0)
	torso.Parent = model
	local motor = Instance.new("Motor6D")
	motor.Name = "Root"
	motor.Part0 = root
	motor.Part1 = torso
	motor.C0 = CFrame.new(0, 3, 0)
	motor.Parent = root
	local controller = Instance.new("AnimationController")
	controller.Parent = model
	Instance.new("Animator").Parent = controller
	return model
end

return function(test, expect)
	test("chaque combattant possède une apparence", function()
		for _, fighter in CardCatalog.getFighters() do
			expect.truthy(ModelFactory.hasVisual(fighter.id), fighter.id)
		end
	end)

	test("les modèles provisoires sont bien assemblés", function()
		for _, fighter in CardCatalog.getFighters() do
			local model = ModelFactory.buildPlaceholder(fighter.id)
			local root = model.PrimaryPart
			expect.truthy(root, fighter.id .. " PrimaryPart")
			expect.truthy(root.Anchored, fighter.id .. " Root ancrée")
			expect.equal(model:GetAttribute("FighterId"), fighter.id, "attribut FighterId")

			local parts = 0
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") and descendant ~= root then
					parts += 1
					expect.falsy(descendant.Anchored, descendant.Name .. " non ancrée")
					expect.falsy(descendant.CanCollide, descendant.Name .. " sans collision")
					local weld = descendant:FindFirstChildOfClass("WeldConstraint")
					expect.truthy(weld and weld.Part0 == root, descendant.Name .. " soudée à Root")
				end
			end
			expect.truthy(parts >= 10, fighter.id .. " nombre de pièces")
			expect.truthy(model:FindFirstChildWhichIsA("PointLight", true), fighter.id .. " lumière")
			model:Destroy()
		end
	end)

	test("déplacer Root déplace tout le modèle", function()
		local model = ModelFactory.buildPlaceholder("F001")
		model.Parent = workspace
		local head = model:FindFirstChild("Head") :: BasePart
		local before = head.Position
		model:PivotTo(CFrame.new(0, 500, 0))
		local moved = head.Position - before
		model:Destroy()
		expect.near(moved.Y, 500, 1e-3, "déplacement vertical de la tête")
	end)

	test("un id sans apparence lève une erreur explicite", function()
		expect.fails(function()
			ModelFactory.buildPlaceholder("F404")
		end)
	end)

	test("le modèle provisoire respecte le contrat des assets finaux", function()
		local model = ModelFactory.buildPlaceholder("F001")
		local valid, reason = ModelFactory.validateAsset(model)
		expect.truthy(valid, reason)
		model:Destroy()
	end)

	-- Dossier de modèles isolé, jamais parenté dans le jeu : les tests tournent
	-- pendant que le jeu démarre (Hub, statues) et ne doivent pas toucher au vrai
	-- ReplicatedStorage.Assets.Fighters.
	local function withAsset(asset: Model, callback: (folder: Folder) -> ())
		local folder = Instance.new("Folder")
		folder.Name = "Fighters"
		asset.Parent = folder
		local ok, err = pcall(callback, folder)
		folder:Destroy()
		if not ok then
			error(err, 0)
		end
	end

	test("un asset final conforme remplace le modèle provisoire", function()
		local asset = Instance.new("Model")
		-- Terra (F002) : aucune animation déclarée, donc pas d'avertissement de rig
		-- pour ce modèle minimal (une pièce, sans Animator).
		asset.Name = VisualAssets.modelName("F002")
		local root = Instance.new("Part")
		root.Name = "AssetRoot"
		root.Anchored = true
		root.Parent = asset
		asset.PrimaryPart = root
		withAsset(asset, function(fighters)
			local built = ModelFactory.build("F002", { assetsFolder = fighters })
			expect.truthy(built:FindFirstChild("AssetRoot"), "asset cloné")
			expect.equal(built:GetAttribute("FighterId"), "F002")
			built:Destroy()
		end)
	end)

	test("variante allégée : choisie en détail bas, modèle principal sinon ou en son absence", function()
		local fighters = Instance.new("Folder")
		local main = motorRig(VisualAssets.modelName("F001"))
		main.Parent = fighters
		local function built(detail)
			local model = ModelFactory.build("F001", { assetsFolder = fighters, detail = detail })
			local name = model:GetAttribute("Source")
			model:Destroy()
			return name
		end
		main:SetAttribute("Source", "main")
		expect.equal(built("Low"), "main", "pas de variante allégée : modèle principal")
		local lod = motorRig(VisualAssets.lodModelName("F001"))
		lod:SetAttribute("Source", "lod")
		lod.Parent = fighters
		expect.equal(built("Low"), "lod", "détail bas : variante allégée")
		expect.equal(built("High"), "main", "détail haut : modèle principal")
		expect.equal(built(nil), "main", "par défaut : modèle principal")
		lod.PrimaryPart = nil
		expect.equal(built("Low"), "main", "variante allégée non conforme : modèle principal")
		fighters:Destroy()
	end)

	test("modèle provisoire : pièces soudées, jamais présenté comme riggé", function()
		local model = ModelFactory.buildPlaceholder("F001")
		local rig = ModelFactory.describeRig(model)
		expect.equal(rig.kind, "Welded")
		expect.falsy(rig.animatable, "non animable")
		model:Destroy()
	end)

	test("rig Motor6D et rig à os : reconnus comme animables avec un Animator", function()
		local motor = motorRig("F001")
		local report = ModelFactory.describeRig(motor)
		expect.equal(report.kind, "Motor6D")
		expect.truthy(report.animator and report.animatable, "animable")
		local valid, reason = ModelFactory.validateAsset(motor)
		expect.truthy(valid, reason)

		local skinned = motorRig("F001")
		local bone = Instance.new("Bone")
		bone.Parent = skinned.PrimaryPart
		expect.equal(ModelFactory.describeRig(skinned).kind, "Skinned")

		local noAnimator = motorRig("F001")
		noAnimator:FindFirstChildOfClass("AnimationController"):Destroy()
		expect.falsy(ModelFactory.describeRig(noAnimator).animatable, "sans Animator : non animable")
		for _, model in { motor, skinned, noAnimator } do
			model:Destroy()
		end
	end)

	test("Kael : un modèle riggé conforme est utilisé et invoqué comme le provisoire", function()
		withAsset(motorRig(VisualAssets.modelName("F001")), function(fighters)
			local folder = Instance.new("Folder")
			folder.Parent = Workspace
			local unit = { uid = "A1", fighterId = "F001", name = "Kael", element = "Fire", side = "Ally", slot = 1 }
			local target = CFrame.new(0, 500, 0)
			local ok, err = pcall(function()
				for _, mode in { "instant", "reduced" } do
					local model =
						SummonController.summon(unit, target, folder, { mode = mode, assetsFolder = fighters })
					expect.truthy(model:FindFirstChild("UpperTorso"), mode .. " : modèle riggé utilisé")
					expect.equal(model:GetAttribute("FighterId"), "F001")
					expect.near((model:GetPivot().Position - target.Position).Magnitude, 0, 1e-2, mode .. " : position")
					expect.equal(model.UpperTorso.Transparency, 0, mode .. " : membre visible après l'invocation")
				end
			end)
			folder:Destroy()
			if not ok then
				error(err, 0)
			end
		end)
	end)

	test("combattant sans animation déclarée : mouvements génériques (fallback)", function()
		-- Terra (F002) n'a aucune animation dans VisualAssets, même avec un rig animable.
		local rig = motorRig("F002")
		rig:SetAttribute("FighterId", "F002")
		expect.falsy(FighterAnimator.play(rig, "Attack", 1), "aucune animation spécifique")
		rig:Destroy()
	end)

	test("un asset non conforme est ignoré : modèle provisoire (fallback)", function()
		local asset = Instance.new("Model")
		asset.Name = "F002"
		local loose = Instance.new("Part")
		loose.Name = "AssetBody"
		loose.Parent = asset -- pas de PrimaryPart
		withAsset(asset, function(fighters)
			local valid = ModelFactory.validateAsset(asset)
			expect.falsy(valid, "contrat non respecté")
			local built = ModelFactory.build("F002", { assetsFolder = fighters })
			expect.falsy(built:FindFirstChild("AssetBody"), "asset non utilisé")
			expect.truthy(built.PrimaryPart, "modèle provisoire complet")
			built:Destroy()
		end)
	end)
end
