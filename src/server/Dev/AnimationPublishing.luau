-- Préparation et contrôle de la publication des animations d'un combattant.
-- Outil de production (barre de commande de Studio, hors Play), jamais appelé par
-- le jeu. Il ne publie rien : la publication reste un geste manuel dans Studio
-- (clic droit → Sauvegarder sur Roblox), fait seulement avec l'accord du propriétaire.
--
--   local AP = require(game.ServerScriptService.Server.Dev.AnimationPublishing)
--   -- 1. Construire les 7 séquences (ServerStorage.AnimationSources.<nom>) :
--   print(AP.describe(AP.prepare(modele, dossierDeDonnees, "F001_Kael_AF")))
--   -- 2. Contrôler les sources avant de les publier :
--   print(AP.describe(AP.inspect("F001_Kael_AF", dossierDeDonnees)))
--   -- 3. Après publication, vérifier chaque identifiant contre ses données :
--   print(AP.describe(AP.check({ Idle = "rbxassetid://…", … }, dossierDeDonnees)))
--
-- Hors Play, Studio garde les modules en cache : relancer Studio après une mise à
-- jour de ce module ou de KeyframeBuilder (une copie par :Clone() perdrait son parent).

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ServerStorage = game:GetService("ServerStorage")

local KeyframeBuilder = require(script.Parent.KeyframeBuilder)

local AnimationPublishing = {}

AnimationPublishing.Kinds = { "Idle", "Attack", "Skill", "Ultimate", "Defend", "Hit", "Defeat" }

export type Line = { kind: string, ok: boolean, detail: string }

local function dataOf(folder: Instance): { [string]: any }
	local data = {}
	for _, kind in AnimationPublishing.Kinds do
		local module = folder:FindFirstChild(kind)
		data[kind] = if module then require(module:Clone() :: ModuleScript) else nil
	end
	return data
end

-- Construit les séquences à publier après vérification sur une copie du modèle :
-- os manquants, écart au repos et dérive doivent être nuls (≤ 0,001 stud).
function AnimationPublishing.prepare(model: Model, dataFolder: Instance, name: string): { Line }
	local root = ServerStorage:FindFirstChild("AnimationSources")
	if not root then
		root = Instance.new("Folder")
		root.Name = "AnimationSources"
		root.Parent = ServerStorage
	end
	local destination = root:FindFirstChild(name)
	if destination then
		destination:Destroy() -- sources précédentes de ce nom : régénérées à l'identique
	end
	destination = Instance.new("Folder")
	destination.Name = name
	destination.Parent = root
	local lines = {}
	local copy = model:Clone()
	for kind, data in dataOf(dataFolder) do
		if not data then
			table.insert(lines, { kind = kind, ok = false, detail = "données absentes" })
			continue
		end
		local report = KeyframeBuilder.verify(copy, data)
		local ok = #report.missing == 0 and report.restError <= 1e-3 and report.maxDrift <= 1e-3
		if ok then
			local sequence = KeyframeBuilder.build(model, data)
			sequence.Name = name .. "_" .. kind
			sequence.Parent = destination
		end
		table.insert(lines, { kind = kind, ok = ok, detail = KeyframeBuilder.describe(report) })
	end
	copy:Destroy()
	return lines
end

-- Compare une KeyframeSequence à ses données : nombre d'images, instants, boucle,
-- priorité et nombre de poses par image (un os oublié se verrait ici).
local function compare(sequence: KeyframeSequence, expected): (boolean, string)
	local keyframes = sequence:GetKeyframes()
	table.sort(keyframes, function(a, b)
		return (a :: Keyframe).Time < (b :: Keyframe).Time
	end)
	local timesMatch, posesMatch = #keyframes == #expected.frames, true
	for index, keyframe in keyframes do
		local frame = expected.frames[index]
		if not frame or math.abs((keyframe :: Keyframe).Time - frame.time) > 1e-3 then
			timesMatch = false
		end
		local poses = 0
		for _, descendant in keyframe:GetDescendants() do
			if descendant:IsA("Pose") then
				poses += 1
			end
		end
		if poses ~= #expected.bones then
			posesMatch = false
		end
	end
	local priority = sequence.Priority.Name
	local expectedPriority = if expected.priority == "Idle" or expected.priority == "Movement"
		then expected.priority
		else "Action"
	local same = timesMatch and posesMatch and sequence.Loop == expected.loop and priority == expectedPriority
	return same,
		string.format(
			"%d images (attendu %d), instants %s, poses %s, boucle %s (%s), priorité %s (%s)",
			#keyframes,
			#expected.frames,
			if timesMatch then "OK" else "différents",
			if posesMatch then string.format("%d par image", #expected.bones) else "incomplètes",
			tostring(sequence.Loop),
			tostring(expected.loop),
			priority,
			expectedPriority
		)
end

-- Contrôle des sources préparées (ServerStorage.AnimationSources.<nom>) avant leur
-- publication : chaque séquence <nom>_<Animation> existe et correspond à ses données.
function AnimationPublishing.inspect(name: string, dataFolder: Instance): { Line }
	local root = ServerStorage:FindFirstChild("AnimationSources")
	local folder = root and root:FindFirstChild(name)
	local lines = {}
	for kind, expected in dataOf(dataFolder) do
		local sequence = folder and folder:FindFirstChild(name .. "_" .. kind)
		if not (sequence and sequence:IsA("KeyframeSequence")) then
			table.insert(lines, { kind = kind, ok = false, detail = "séquence source absente" })
		else
			local ok, detail = compare(sequence, expected)
			table.insert(lines, { kind = kind, ok = ok, detail = sequence.Name .. " : " .. detail })
		end
	end
	return lines
end

-- Recharge chaque animation publiée et la compare à ses données. Un identifiant faux,
-- privé d'un autre compte ou en cours de modération échoue ici.
function AnimationPublishing.check(ids: { [string]: string }, dataFolder: Instance): { Line }
	local lines = {}
	local data = dataOf(dataFolder)
	for _, kind in AnimationPublishing.Kinds do
		local id, expected = ids[kind], data[kind]
		if not id or not expected then
			table.insert(lines, { kind = kind, ok = false, detail = "identifiant ou données absents" })
			continue
		end
		local ok, sequence = pcall(function()
			return KeyframeSequenceProvider:GetKeyframeSequenceAsync(id)
		end)
		if not ok or not sequence then
			table.insert(lines, { kind = kind, ok = false, detail = "chargement impossible : " .. tostring(sequence) })
			continue
		end
		local same, detail = compare(sequence, expected)
		table.insert(lines, { kind = kind, ok = same, detail = id .. " : " .. detail })
	end
	return lines
end

function AnimationPublishing.describe(lines: { Line }): string
	local out, failures = {}, 0
	for _, line in lines do
		if not line.ok then
			failures += 1
		end
		table.insert(out, string.format("%s %s | %s", if line.ok then "OK " else "ERR", line.kind, line.detail))
	end
	table.sort(out)
	table.insert(out, if failures == 0 then "=> tout est conforme" else string.format("=> %d échec(s)", failures))
	return table.concat(out, "\n")
end

return AnimationPublishing
