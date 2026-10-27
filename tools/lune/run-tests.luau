--[[
	Exécute hors de Roblox les specs de logique pure (aucune Instance Roblox).

	Le script reconstruit l'arbre Rojo (default.project.json) sous forme d'objets
	factices qui imitent le strict nécessaire : `script`, `.Parent`, l'accès aux
	enfants par nom, WaitForChild, FindFirstChild, GetChildren, IsA et
	game:GetService. Les modules sont chargés tels quels, sans modification.

	Usage, depuis la racine du projet :
		lune run tools/lune/run-tests
		lune run tools/lune/run-tests -- BattleEngineSpec CombatAISpec

	Les specs qui créent des Instances (ModelFactorySpec) restent réservées à Studio.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")

-- Specs exigeant le moteur Roblox (Instance.new, workspace…)
local STUDIO_ONLY = { ModelFactorySpec = true, SummonSpec = true, FighterAssetPrepSpec = true }

local CLASS_BY_SUFFIX = {
	{ suffix = ".server.luau", class = "Script" },
	{ suffix = ".client.luau", class = "LocalScript" },
	{ suffix = ".luau", class = "ModuleScript" },
}

-- Objets factices -----------------------------------------------------------

local Node = {}
local methods = {}

local function newNode(name: string, className: string, parent, filePath: string?)
	local node = setmetatable({
		__name = name,
		__class = className,
		__parent = parent,
		__children = {},
		__file = filePath,
	}, Node)
	if parent then
		rawget(parent, "__children")[name] = node
	end
	return node
end

local function fullName(node): string
	local parts = {}
	local current = node
	while current and rawget(current, "__parent") do
		table.insert(parts, 1, rawget(current, "__name"))
		current = rawget(current, "__parent")
	end
	return table.concat(parts, ".")
end

Node.__index = function(self, key)
	if key == "Name" then
		return rawget(self, "__name")
	elseif key == "Parent" then
		return rawget(self, "__parent")
	elseif key == "ClassName" then
		return rawget(self, "__class")
	end
	if methods[key] then
		return methods[key]
	end
	local child = rawget(self, "__children")[key]
	if child then
		return child
	end
	error(string.format("%s n'est pas un enfant valide de %s", tostring(key), fullName(self)), 2)
end

Node.__tostring = fullName

function methods.FindFirstChild(self, name: string)
	return rawget(self, "__children")[name]
end

function methods.WaitForChild(self, name: string)
	local child = rawget(self, "__children")[name]
	if not child then
		error(string.format("WaitForChild : %s introuvable dans %s", name, fullName(self)), 2)
	end
	return child
end

function methods.GetChildren(self)
	local list = {}
	for _, child in rawget(self, "__children") do
		table.insert(list, child)
	end
	table.sort(list, function(a, b)
		return rawget(a, "__name") < rawget(b, "__name")
	end)
	return list
end

function methods.IsA(self, className: string): boolean
	return rawget(self, "__class") == className
end

function methods.GetFullName(self): string
	return fullName(self)
end

function methods.GetService(self, name: string)
	local service = rawget(self, "__children")[name]
	if not service then
		error("Service non émulé hors de Roblox : " .. name, 2)
	end
	return service
end

-- Arbre Rojo -----------------------------------------------------------------

local function classify(fileName: string): (string?, string?)
	for _, entry in CLASS_BY_SUFFIX do
		if string.sub(fileName, -#entry.suffix) == entry.suffix then
			return string.sub(fileName, 1, -#entry.suffix - 1), entry.class
		end
	end
	return nil, nil
end

local function mapDirectory(directory: string, node)
	for _, entry in fs.readDir(directory) do
		local path = directory .. "/" .. entry
		if fs.isDir(path) then
			mapDirectory(path, newNode(entry, "Folder", node))
		else
			local name, className = classify(entry)
			if name then
				newNode(name, className :: string, node, path)
			end
		end
	end
end

local function mapProject(tree, node)
	if tree["$path"] then
		mapDirectory(tree["$path"], node)
	end
	for key, child in tree do
		if string.sub(key, 1, 1) ~= "$" then
			mapProject(child, newNode(key, child["$className"] or "Service", node))
		end
	end
end

local project = serde.decode("json", fs.readFile("default.project.json"))
local game = newNode("game", "DataModel", nil)
mapProject(project.tree, game)

-- Chargement des modules ----------------------------------------------------

local cache = {}
local loading = {}

local function requireNode(node)
	if type(node) ~= "table" or getmetatable(node) ~= Node then
		error("require attend un ModuleScript de l'arbre Rojo, reçu " .. typeof(node), 2)
	end
	if rawget(node, "__class") ~= "ModuleScript" then
		error(fullName(node) .. " n'est pas un ModuleScript", 2)
	end
	if cache[node] ~= nil then
		return cache[node]
	end
	if loading[node] then
		error("Dépendance circulaire : " .. fullName(node), 2)
	end
	loading[node] = true

	local file = rawget(node, "__file")
	local chunk = luau.load(fs.readFile(file), {
		debugName = file,
		environment = {
			script = node,
			require = requireNode,
			game = game,
		},
	})
	local result = chunk()
	loading[node] = nil
	cache[node] = result
	return result
end

-- Exécution -----------------------------------------------------------------

local requested = {}
for _, name in process.args do
	requested[name] = true
end
local filterByName = next(requested) ~= nil

-- Dossier factice ne contenant que les specs exécutables hors de Studio
local specs = game.ServerScriptService.Tests.Specs
local selection = newNode("Specs", "Folder", nil)
for _, spec in specs:GetChildren() do
	local name = rawget(spec, "__name")
	if not STUDIO_ONLY[name] and (not filterByName or requested[name]) then
		rawget(selection, "__children")[name] = spec
	end
end

local TestRunner = requireNode(game.ServerScriptService.Tests.TestRunner)
local results = TestRunner.run(selection)
process.exit(if results.failed > 0 then 1 else 0)
