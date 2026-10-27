-- Mise au contrat d'un combattant importé (Dev/FighterAssetPrep). Studio uniquement :
-- crée des Instances. Le modèle simule un import skinné (maillage + os R15), rangé
-- dans un dossier isolé, jamais dans le vrai ReplicatedStorage.Assets.

local ServerScriptService = game:GetService("ServerScriptService")

local FighterAssetPrep = require(ServerScriptService.Server.Dev.FighterAssetPrep)

-- Modèle tel que livré par l'importateur 3D : un maillage non ancré qui porte les
-- os, un AnimationController sans Animator, pivot aux pieds, avant vers −Z.
local function importedModel(): Model
	local model = Instance.new("Model")
	model.Name = "F001_Kael"
	local mesh = Instance.new("Part")
	mesh.Name = "F001_Kael_Mesh"
	mesh.Anchored = true -- l'outil doit le désancrer
	mesh.Size = Vector3.new(3, 6.6, 2)
	mesh.CFrame = CFrame.new(0, 3.3, 0)
	mesh.Parent = model
	model.PrimaryPart = mesh
	local root = Instance.new("Bone")
	root.Name = "Root"
	root.Parent = mesh
	-- Avant vers −Z : bras gauche du personnage en −X.
	for name, x in { LeftUpperArm = -0.8, RightUpperArm = 0.8 } do
		local bone = Instance.new("Bone")
		bone.Name = name
		bone.Position = Vector3.new(x, 1.1, 0)
		bone.Parent = root
	end
	Instance.new("AnimationController").Parent = model
	-- Pivot aux pieds, comme l'importateur (origine de la scène Blender). Avec une
	-- PrimaryPart, c'est son PivotOffset qui le définit (WorldPivot serait ignoré).
	mesh.PivotOffset = CFrame.new(0, -3.3, 0)
	return model
end

local function withDestination(callback: (Folder) -> ())
	local folder = Instance.new("Folder")
	local ok, err = pcall(callback, folder)
	folder:Destroy()
	if not ok then
		error(err, 0)
	end
end

return function(test, expect)
	test("modèle importé : pivot aux pieds, soudures, Animator, contrat validé", function()
		withDestination(function(destination)
			local model = importedModel()
			local report = FighterAssetPrep.prepare(model, "F001_Kael", destination)
			expect.truthy(report.valid, report.reason)
			local pivot = model.PrimaryPart
			expect.equal(pivot.Name, FighterAssetPrep.PivotName, "pivot dédié")
			expect.truthy(pivot.Anchored, "pivot ancré")
			expect.near(pivot.Position.Y, 0, 1e-3, "pivot aux pieds")
			local mesh = model.F001_Kael_Mesh
			expect.falsy(mesh.Anchored, "maillage désancré")
			expect.truthy(mesh:FindFirstChild("RootWeld"), "maillage soudé au pivot")
			expect.truthy(
				model:FindFirstChildOfClass("AnimationController"):FindFirstChildOfClass("Animator"),
				"Animator"
			)
			expect.equal(report.rig.kind, "Skinned")
			expect.truthy(report.rig.animatable, "animable")
			expect.truthy(report.facingMinusZ, "avant vers −Z")
			expect.equal(model.Parent, destination, "rangé dans le dossier demandé")
		end)
	end)

	test("relancer l'outil ne change rien (idempotent)", function()
		withDestination(function(destination)
			local model = importedModel()
			FighterAssetPrep.prepare(model, "F001_Kael", destination)
			local count = #model:GetDescendants()
			local report = FighterAssetPrep.prepare(model, "F001_Kael", destination)
			expect.truthy(report.valid, report.reason)
			expect.equal(#model:GetDescendants(), count, "aucune instance ajoutée")
		end)
	end)

	test("une pièce et un os de même nom sont refusés (éditeur d'animation)", function()
		withDestination(function(destination)
			local model = importedModel()
			-- (Une pièce « Root » serait renommée par l'outil : le conflit porte sur
			-- un autre os.)
			local clash = Instance.new("Part")
			clash.Name = "LeftUpperArm"
			clash.Parent = model
			local report = FighterAssetPrep.prepare(model, "F001_Kael", destination)
			expect.falsy(report.valid, "contrat refusé")
			expect.contains(tostring(report.reason), "LeftUpperArm")
		end)
	end)

	test("une ancienne pièce de pivot « Root » est renommée, plus de conflit", function()
		withDestination(function(destination)
			local model = importedModel()
			local legacy = Instance.new("Part")
			legacy.Name = "Root"
			legacy.Anchored = true
			legacy.Parent = model
			local report = FighterAssetPrep.prepare(model, "F001_Kael", destination)
			expect.truthy(report.valid, report.reason)
			expect.equal(model.PrimaryPart, legacy, "pièce existante réutilisée")
			expect.equal(legacy.Name, FighterAssetPrep.PivotName)
			expect.equal(#report.nameConflicts, 0)
		end)
	end)
end
