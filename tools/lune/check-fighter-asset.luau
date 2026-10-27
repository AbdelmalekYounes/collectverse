--[[
	Vérifie hors de Studio qu'un modèle de combattant respecte le contrat de
	ModelFactory.validateAsset, et décrit son rig (mêmes règles que describeRig).

		lune run tools/lune/check-fighter-asset -- assets/Fighters/F001_Kael.rbxm
		lune run tools/lune/check-fighter-asset -- Collectverse.rbxlx F001_Kael

	Avec un fichier de place (.rbxl/.rbxlx), le modèle est cherché dans
	ReplicatedStorage.Assets.Fighters (nom donné en second argument).
	Code de sortie 1 si le contrat n'est pas respecté.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

-- Lune transmet le séparateur « -- » tel quel : on l'ignore.
local args = {}
for _, value in process.args do
	if value ~= "--" then
		table.insert(args, value)
	end
end
local path = args[1]
local wanted = args[2]
if not path then
	print("Usage : lune run tools/lune/check-fighter-asset -- <fichier.rbxm|place> [NomDuModèle]")
	process.exit(2)
end

local function findModel(): any
	local content = fs.readFile(path)
	if string.match(path, "%.rbxlx?$") then
		local game = roblox.deserializePlace(content)
		local storage = game:GetService("ReplicatedStorage")
		local assets = storage:FindFirstChild("Assets")
		local fighters = assets and assets:FindFirstChild("Fighters")
		local model = fighters and fighters:FindFirstChild(wanted or "")
		if not model then
			error("ReplicatedStorage.Assets.Fighters." .. tostring(wanted) .. " introuvable dans la place")
		end
		return model
	end
	local roots = roblox.deserializeModel(content)
	for _, root in roots do
		if root:IsA("Model") and (not wanted or root.Name == wanted) then
			return root
		end
	end
	error("aucun Model dans " .. path)
end

local model = findModel()
local problems = {}
local root = model.PrimaryPart
if not root then
	table.insert(problems, "PrimaryPart manquante")
elseif not root.Anchored then
	table.insert(problems, "PrimaryPart non ancrée")
end

local bones, motors, welds, meshParts, animator = 0, 0, 0, 0, false
for _, descendant in model:GetDescendants() do
	if descendant:IsA("BasePart") and descendant ~= root and descendant.Anchored then
		table.insert(problems, "pièce ancrée : " .. descendant.Name)
	end
	if descendant:IsA("MeshPart") then
		meshParts += 1
		-- Selon la version de Studio, le maillage est enregistré dans MeshId ou
		-- MeshContent : on lit l'un ou l'autre.
		local reference = nil
		for _, property in { "MeshId", "MeshContent" } do
			local ok, value = pcall(function()
				return descendant[property]
			end)
			if ok and value ~= nil and tostring(value) ~= "" then
				reference = tostring(value)
				break
			end
		end
		if reference then
			print(string.format("Maillage    : %s → %s", descendant.Name, reference))
		else
			table.insert(problems, "MeshPart sans référence de maillage : " .. descendant.Name)
		end
	end
	if descendant:IsA("Bone") then
		bones += 1
	elseif descendant:IsA("Motor6D") then
		motors += 1
	elseif descendant:IsA("WeldConstraint") or descendant:IsA("Weld") then
		welds += 1
	elseif descendant:IsA("Animator") then
		local holder = descendant.Parent
		if holder and (holder:IsA("AnimationController") or holder:IsA("Humanoid")) then
			animator = true
		end
	end
end

-- Une pièce et un os de même nom : l'éditeur d'animation de Studio refuse le rig.
local partNames, boneNames = {}, {}
for _, descendant in model:GetDescendants() do
	if descendant:IsA("BasePart") then
		partNames[descendant.Name] = true
	elseif descendant:IsA("Bone") then
		boneNames[descendant.Name] = true
	end
end
for name in partNames do
	if boneNames[name] then
		table.insert(problems, "pièce et os de même nom : " .. name)
	end
end

local kind = if bones > 0 then "Skinned" elseif motors > 0 then "Motor6D" elseif welds > 0 then "Welded" else "Static"
local animatable = animator and (bones > 0 or motors > 0)
print(string.format("Modèle      : %s (%s)", model.Name, path))
print(string.format("PrimaryPart : %s", if root then root.Name else "—"))
print(string.format("Rig         : %s (os %d, Motor6D %d, soudures %d)", kind, bones, motors, welds))
print(string.format("Maillages   : %d MeshPart", meshParts))
print(string.format("Animator    : %s → animable : %s", tostring(animator), tostring(animatable)))
if #problems == 0 then
	print("Contrat     : OK")
else
	print("Contrat     : REFUSÉ")
	for _, problem in problems do
		print("  - " .. problem)
	end
	process.exit(1)
end
