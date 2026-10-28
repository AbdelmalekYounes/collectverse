--[[
	Met à jour les 7 AnimationId de Kael (F001) dans VisualAssets à partir d'un
	fichier JSON { "Idle": "rbxassetid://…", … } (par exemple perf/af_animation_ids.json,
	rempli après la publication des animations, avec l'accord du propriétaire).

	Aperçu seulement par défaut ; --write pour modifier le fichier.

		lune run tools/lune/apply-animation-ids -- perf/af_animation_ids.json
		lune run tools/lune/apply-animation-ids -- perf/af_animation_ids.json --write

	Option --target <fichier> : autre fichier que src/shared/Visuals/VisualAssets.luau.
	Refuse : identifiant manquant, mal formé (rbxassetid://<nombre>) ou en double.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local KINDS = { "Idle", "Attack", "Skill", "Ultimate", "Defend", "Hit", "Defeat" }

local args = {}
for _, value in process.args do
	if value ~= "--" then
		table.insert(args, value)
	end
end
local source = args[1]
if not source then
	print("Usage : lune run tools/lune/apply-animation-ids -- <ids.json> [--write] [--target <fichier>]")
	process.exit(2)
end
local write = table.find(args, "--write") ~= nil
local targetIndex = table.find(args, "--target")
local target = if targetIndex then args[targetIndex + 1] else "src/shared/Visuals/VisualAssets.luau"

local ids = serde.decode("json", fs.readFile(source))
local seen, errors = {}, {}
for _, kind in KINDS do
	local id = ids[kind]
	if type(id) ~= "string" or not string.match(id, "^rbxassetid://%d+$") then
		table.insert(errors, kind .. " : identifiant manquant ou mal formé (" .. tostring(id) .. ")")
	elseif seen[id] then
		table.insert(errors, kind .. " : identifiant déjà utilisé par " .. seen[id])
	else
		seen[id] = kind
	end
end
if #errors > 0 then
	print("Refusé :\n  " .. table.concat(errors, "\n  "))
	process.exit(1)
end

local text = fs.readFile(target)
-- Bloc « animations = { … } » de l'entrée F001 (entre « F001 = { » et sa fin).
local entryStart = string.find(text, "\n\tF001 = {", 1, true)
assert(entryStart, "entrée F001 introuvable dans " .. target)
local blockStart, blockOpenEnd = string.find(text, "animations = {\n", entryStart, true)
assert(blockStart, "bloc animations de F001 introuvable")
local blockClose = string.find(text, "\n\t\t},", blockOpenEnd, true)
assert(blockClose, "fin du bloc animations introuvable")

local old = string.sub(text, blockOpenEnd + 1, blockClose)
local lines = {}
for _, kind in KINDS do
	table.insert(lines, string.format('\t\t\t%s = "%s",', kind, ids[kind]))
end
local new = table.concat(lines, "\n") .. "\n"
print("Avant :\n" .. old)
print("Après :\n" .. new)
if old == new then
	print("Aucun changement.")
	return
end
if write then
	fs.writeFile(target, string.sub(text, 1, blockOpenEnd) .. new .. string.sub(text, blockClose + 1))
	print("Écrit : " .. target .. " (pensez à mettre à jour le commentaire de l'entrée F001)")
else
	print("Aperçu seulement : ajouter --write pour modifier " .. target)
end
