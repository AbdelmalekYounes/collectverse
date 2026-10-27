-- Mise au contrat d'un combattant importé avec l'importateur 3D de Studio.
-- Outil de production (barre de commande de Studio, hors Play), jamais appelé par le jeu.
--
--   local Prep = require(game.ServerScriptService.Server.Dev.FighterAssetPrep)
--   print(Prep.prepare(workspace.F001_Kael, "F001_Kael"))
--
-- Étapes (voir VisualAssets et ModelFactory.validateAsset) :
--  1. pièce « AssetPivot » ancrée, invisible, sans collision, placée au pivot du
--     modèle (les pieds : origine de la scène Blender), droite et tournée vers −Z.
--     Elle ne s'appelle pas « Root » : c'est le nom de l'os racine de l'armature,
--     et l'éditeur d'animation refuse une pièce et un os de même nom ;
--  2. AssetPivot devient la PrimaryPart ; toutes les autres pièces sont désancrées
--     et soudées à elle (WeldConstraint), les os restent dans leur maillage ;
--  3. AnimationController + Animator (créés s'ils manquent) ;
--  4. modèle renommé et rangé dans ReplicatedStorage.Assets.Fighters ;
--  5. rapport : contrat (validateAsset), nature du rig (describeRig), facing.
-- Idempotent : relancer l'outil sur un modèle déjà préparé ne change rien.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelFactory = require(ReplicatedStorage.Shared.Visuals.ModelFactory)

local FighterAssetPrep = {}

FighterAssetPrep.PivotName = "AssetPivot"

export type Report = {
	valid: boolean,
	reason: string?,
	rig: ModelFactory.RigReport,
	parts: number,
	height: number,
	facingMinusZ: boolean?, -- le côté gauche du personnage est en −X (avant vers −Z)
	nameConflicts: { string }, -- noms portés à la fois par une pièce et un os
}

-- Noms partagés entre une pièce et un os : l'éditeur d'animation refuse ce rig.
function FighterAssetPrep.nameConflicts(model: Instance): { string }
	local parts, bones = {}, {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			parts[descendant.Name] = true
		elseif descendant:IsA("Bone") then
			bones[descendant.Name] = true
		end
	end
	local conflicts = {}
	for name in parts do
		if bones[name] then
			table.insert(conflicts, name)
		end
	end
	table.sort(conflicts)
	return conflicts
end

local function ensureFolder(parent: Instance, name: string): Instance
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

-- Vérifie l'orientation à partir des os R15 : avec l'avant vers −Z, le bras
-- gauche est du côté −X du pivot (repère du pivot).
local function facesMinusZ(model: Model, root: BasePart): boolean?
	local left, right
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Bone") then
			if descendant.Name == "LeftUpperArm" then
				left = descendant.WorldPosition
			elseif descendant.Name == "RightUpperArm" then
				right = descendant.WorldPosition
			end
		end
	end
	if not left or not right then
		return nil
	end
	return root.CFrame:PointToObjectSpace(left).X < root.CFrame:PointToObjectSpace(right).X
end

-- destination : dossier où ranger le modèle (par défaut ReplicatedStorage.Assets.Fighters ;
-- les tests passent un dossier isolé).
function FighterAssetPrep.prepare(model: Model, assetName: string, destination: Instance?): Report
	assert(model:IsA("Model"), "FighterAssetPrep : un Model est attendu")

	-- 1. Pivot aux pieds, droit, tourné vers −Z (une ancienne pièce « Root » créée
	-- par une version précédente de l'outil est renommée)
	local legacy = model:FindFirstChild("Root")
	if legacy and legacy:IsA("BasePart") and not model:FindFirstChild(FighterAssetPrep.PivotName) then
		legacy.Name = FighterAssetPrep.PivotName
	end
	local root = model:FindFirstChild(FighterAssetPrep.PivotName)
	if not (root and root:IsA("BasePart")) then
		local pivot = model:GetPivot().Position
		root = Instance.new("Part")
		root.Name = FighterAssetPrep.PivotName
		root.Size = Vector3.new(2, 0.2, 1)
		root.Transparency = 1
		root.CanCollide = false
		root.CanQuery = false
		root.CanTouch = false
		root.CFrame = CFrame.new(pivot)
		root.Parent = model
	end
	local rootPart = root :: BasePart
	rootPart.Anchored = true

	-- 2. PrimaryPart, pièces désancrées et soudées à Root
	model.PrimaryPart = rootPart
	local parts = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= rootPart then
			parts += 1
			descendant.Anchored = false
			descendant.CanCollide = false
			local weld = descendant:FindFirstChild("RootWeld")
			if not weld then
				weld = Instance.new("WeldConstraint")
				weld.Name = "RootWeld"
				weld.Part0 = rootPart
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end
	end

	-- 3. AnimationController + Animator
	local controller = model:FindFirstChildOfClass("AnimationController") or model:FindFirstChildOfClass("Humanoid")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Parent = model
	end
	if not controller:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = controller
	end

	-- 4. Rangement
	model.Name = assetName
	model.Parent = destination or ensureFolder(ensureFolder(ReplicatedStorage, "Assets"), "Fighters")

	-- 5. Rapport
	local valid, reason = ModelFactory.validateAsset(model)
	local conflicts = FighterAssetPrep.nameConflicts(model)
	if valid and #conflicts > 0 then
		valid, reason = false, "pièce et os de même nom : " .. table.concat(conflicts, ", ")
	end
	local _, size = model:GetBoundingBox()
	return {
		valid = valid,
		reason = reason,
		nameConflicts = conflicts,
		rig = ModelFactory.describeRig(model),
		parts = parts,
		height = size.Y,
		facingMinusZ = facesMinusZ(model, rootPart),
	}
end

-- Rapport lisible dans la sortie de Studio.
function FighterAssetPrep.describe(report: Report): string
	return string.format(
		"contrat %s%s | rig %s (os %d, Motor6D %d, Animator %s, animable %s) | pièces %d | hauteur %.2f | avant vers −Z %s",
		if report.valid then "OK" else "REFUSÉ",
		if report.reason then " (" .. report.reason .. ")" else "",
		report.rig.kind,
		report.rig.bones,
		report.rig.motors,
		tostring(report.rig.animator),
		tostring(report.rig.animatable),
		report.parts,
		report.height,
		tostring(report.facingMinusZ)
	)
end

return FighterAssetPrep
