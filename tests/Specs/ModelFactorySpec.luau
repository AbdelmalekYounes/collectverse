local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CardCatalog = require(Shared.Catalog.CardCatalog)
local ModelFactory = require(Shared.Visuals.ModelFactory)

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

	-- Place un asset de test dans ReplicatedStorage.Assets.Fighters le temps d'un appel.
	local function withAsset(asset: Model, callback: () -> ())
		local createdAssets = ReplicatedStorage:FindFirstChild("Assets") == nil
		local assets = ReplicatedStorage:FindFirstChild("Assets") or Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ReplicatedStorage
		local createdFighters = assets:FindFirstChild("Fighters") == nil
		local fighters = assets:FindFirstChild("Fighters") or Instance.new("Folder")
		fighters.Name = "Fighters"
		fighters.Parent = assets
		asset.Parent = fighters
		local ok, err = pcall(callback)
		asset:Destroy()
		if createdFighters then
			fighters:Destroy()
		end
		if createdAssets then
			assets:Destroy()
		end
		if not ok then
			error(err, 0)
		end
	end

	test("un asset final conforme remplace le modèle provisoire", function()
		local asset = Instance.new("Model")
		asset.Name = "F001"
		local root = Instance.new("Part")
		root.Name = "AssetRoot"
		root.Anchored = true
		root.Parent = asset
		asset.PrimaryPart = root
		withAsset(asset, function()
			local built = ModelFactory.build("F001")
			expect.truthy(built:FindFirstChild("AssetRoot"), "asset cloné")
			expect.equal(built:GetAttribute("FighterId"), "F001")
			built:Destroy()
		end)
	end)

	test("un asset non conforme est ignoré : modèle provisoire (fallback)", function()
		local asset = Instance.new("Model")
		asset.Name = "F002"
		local loose = Instance.new("Part")
		loose.Name = "AssetBody"
		loose.Parent = asset -- pas de PrimaryPart
		withAsset(asset, function()
			local valid = ModelFactory.validateAsset(asset)
			expect.falsy(valid, "contrat non respecté")
			local built = ModelFactory.build("F002")
			expect.falsy(built:FindFirstChild("AssetBody"), "asset non utilisé")
			expect.truthy(built.PrimaryPart, "modèle provisoire complet")
			built:Destroy()
		end)
	end)
end
