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
end
