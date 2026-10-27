-- Construit une KeyframeSequence Roblox à partir des images-clés exportées de
-- Blender (art/kael/kael_anim_export.py). Outil de production (barre de commande
-- de Studio), jamais appelé par le jeu.
--
-- Données par image et par os (axes Roblox, relatives au pivot du modèle, aux pieds) :
--   p : position de la tête de l'os animé ;
--   q : rotation « monde » de la pose de repos vers la pose animée (w, x, y, z).
-- Ces grandeurs ne dépendent pas des axes locaux des os, qui diffèrent entre
-- Blender et Roblox. Pour chaque os, de la racine vers les extrémités :
--   cible     = CFrame(p) * rotation(q) * orientation de repos (rig importé)
--   Transform = (pose du parent * Bone.CFrame)⁻¹ * cible
-- Bone.Transform est exactement ce que joue une Pose de KeyframeSequence ;
-- l'Animator associe les poses aux os par leur nom (vérifié en V0.2.3).
--
--   local KB = require(game.ServerScriptService.Server.Dev.KeyframeBuilder)
--   local data = require(game.ServerScriptService.Server.Dev.AnimationData.F001_Kael.Attack)
--   local model = game.ReplicatedStorage.Assets.Fighters.F001_Kael
--   print(KB.describe(KB.verify(model, data)))
--   local sequence = KB.build(model, data)

local KeyframeBuilder = {}

export type BoneSample = { p: { number }, q: { number } }
export type Frame = { time: number, bones: { [string]: BoneSample } }
export type AnimationData = {
	animation: string,
	model: string,
	length: number,
	loop: boolean,
	priority: string,
	bones: { string },
	parents: { [string]: string? },
	rest: { [string]: { number } },
	frames: { Frame },
}

export type Report = {
	animation: string,
	frames: number,
	bones: number,
	missing: { string }, -- os des données absents du modèle
	restError: number, -- écart max (studs) entre repos Blender et repos du rig importé
	maxError: number, -- écart max (studs) entre os animés et cibles, toutes images
	-- Translation max d'un Transform hors racine mobile : les os ne font que tourner.
	-- Une valeur non nulle trahirait une rotation mal convertie (compensée en translation).
	maxDrift: number,
	driftBone: string?,
	worstBone: string?,
	worstTime: number?,
}

local function boneMap(model: Instance): { [string]: Bone }
	local bones = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Bone") then
			bones[descendant.Name] = descendant
		end
	end
	return bones
end

-- Le pivot du modèle (pieds, orientation du personnage) : repère des données.
local function pivotOf(model: Model): CFrame
	return if model.PrimaryPart then model.PrimaryPart.CFrame else model:GetPivot()
end

local function targetFor(sample: BoneSample, restRotation: CFrame): CFrame
	local p, q = sample.p, sample.q
	-- CFrame.new(x, y, z, qX, qY, qZ, qW) ; les données sont (w, x, y, z).
	local delta = CFrame.new(0, 0, 0, q[2], q[3], q[4], q[1])
	return CFrame.new(p[1], p[2], p[3]) * delta * restRotation
end

-- Repère de repos de chaque os, relatif au pivot du modèle, calculé uniquement à
-- partir des Bone.CFrame (sans aucun Transform) : Bone.WorldCFrame, lui, suit les
-- Transform des os parents et fausserait le calcul pendant une animation.
local function restFrames(model: Model, bones: { [string]: Bone }): { [Bone]: CFrame }
	local pivotInverse = pivotOf(model):Inverse()
	local rest: { [Bone]: CFrame } = {}
	local function restOf(bone: Bone): CFrame
		local cached = rest[bone]
		if cached then
			return cached
		end
		local parent = bone.Parent
		local parentRest
		if parent and parent:IsA("Bone") then
			parentRest = restOf(parent)
		elseif parent and parent:IsA("BasePart") then
			parentRest = pivotInverse * parent.CFrame
		else
			parentRest = CFrame.identity
		end
		local result = parentRest * bone.CFrame
		rest[bone] = result
		return result
	end
	for _, bone in bones do
		restOf(bone)
	end
	return rest
end

-- Transform de chaque os pour une image : { [nom] = CFrame }.
function KeyframeBuilder.solve(model: Model, data: AnimationData, frame: Frame): { [string]: CFrame }
	local bones = boneMap(model)
	local rest = restFrames(model, bones)
	local pivotInverse = pivotOf(model):Inverse()
	local posed: { [string]: CFrame } = {}
	local transforms = {}
	for _, name in data.bones do
		local bone = bones[name]
		local sample = frame.bones[name]
		if bone and sample then
			local target = targetFor(sample, rest[bone].Rotation)
			local parent = bone.Parent
			local parentPosed
			if parent and parent:IsA("Bone") and posed[parent.Name] then
				parentPosed = posed[parent.Name]
			elseif parent and parent:IsA("Bone") then
				parentPosed = rest[parent]
			elseif parent and parent:IsA("BasePart") then
				parentPosed = pivotInverse * parent.CFrame
			else
				parentPosed = CFrame.identity
			end
			transforms[name] = (parentPosed * bone.CFrame):Inverse() * target
			posed[name] = target
		end
	end
	return transforms
end

local PRIORITIES = {
	Idle = Enum.AnimationPriority.Idle,
	Movement = Enum.AnimationPriority.Movement,
	Action = Enum.AnimationPriority.Action,
}

-- Construit la KeyframeSequence (poses imbriquées comme les os, interpolation linéaire).
function KeyframeBuilder.build(model: Model, data: AnimationData): KeyframeSequence
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = data.model .. "_" .. data.animation
	sequence.Loop = data.loop
	sequence.Priority = PRIORITIES[data.priority] or Enum.AnimationPriority.Action
	local bones = boneMap(model)
	for _, frame in data.frames do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = frame.time
		local transforms = KeyframeBuilder.solve(model, data, frame)
		local poses: { [string]: Pose } = {}
		for _, name in data.bones do
			if bones[name] then
				local pose = Instance.new("Pose")
				pose.Name = name
				pose.Weight = 1
				pose.EasingStyle = Enum.PoseEasingStyle.Linear
				pose.CFrame = transforms[name] or CFrame.identity
				local parentName = data.parents[name]
				pose.Parent = if parentName and poses[parentName] then poses[parentName] else keyframe
				poses[name] = pose
			end
		end
		keyframe.Parent = sequence
	end
	return sequence
end

-- Os qui se déplacent réellement dans les animations (racine mobile).
local MOVING = { HumanoidRootPart = true }

-- Applique une image directement aux os puis mesure l'écart avec les cibles.
local function measure(model: Model, data: AnimationData, frame: Frame, bones, pivot: CFrame)
	local transforms = KeyframeBuilder.solve(model, data, frame)
	local drift, driftBone = 0, nil
	for name, transform in transforms do
		bones[name].Transform = transform
		if not MOVING[name] and transform.Position.Magnitude > drift then
			drift, driftBone = transform.Position.Magnitude, name
		end
	end
	local worst, worstBone = 0, nil
	for name, sample in frame.bones do
		local bone = bones[name]
		if bone then
			local actual = (pivot:Inverse() * bone.TransformedWorldCFrame).Position
			local p = sample.p
			local error = (actual - Vector3.new(p[1], p[2], p[3])).Magnitude
			if error > worst then
				worst, worstBone = error, name
			end
		end
	end
	return worst, worstBone, drift, driftBone
end

-- Vérifie la conversion sur le vrai rig, sans Animator : chaque image est appliquée
-- aux os (Bone.Transform), puis la position de chaque os est comparée à sa cible
-- Blender. Les Transform sont remis à zéro ensuite.
function KeyframeBuilder.verify(model: Model, data: AnimationData): Report
	local bones = boneMap(model)
	local pivot = pivotOf(model)
	local missing = {}
	for _, name in data.bones do
		if not bones[name] then
			table.insert(missing, name)
		end
	end
	local restError = 0
	local rest = restFrames(model, bones)
	for name, position in data.rest do
		local bone = bones[name]
		if bone then
			local actual = rest[bone].Position
			restError = math.max(restError, (actual - Vector3.new(position[1], position[2], position[3])).Magnitude)
		end
	end
	local report: Report = {
		animation = data.animation,
		frames = #data.frames,
		bones = #data.bones,
		missing = missing,
		restError = restError,
		maxError = 0,
		worstBone = nil,
		worstTime = nil,
		maxDrift = 0,
		driftBone = nil,
	}
	for _, frame in data.frames do
		local error, bone, drift, driftBone = measure(model, data, frame, bones, pivot)
		if error > report.maxError then
			report.maxError, report.worstBone, report.worstTime = error, bone, frame.time
		end
		if drift > report.maxDrift then
			report.maxDrift, report.driftBone = drift, driftBone
		end
	end
	for _, bone in bones do
		bone.Transform = CFrame.identity
	end
	return report
end

function KeyframeBuilder.describe(report: Report): string
	return string.format(
		"%s : %d images, %d os, manquants %d | écart au repos %.4f | écart max %.4f (%s à %.2f s) | dérive %.4f (%s)",
		report.animation,
		report.frames,
		report.bones,
		#report.missing,
		report.restError,
		report.maxError,
		tostring(report.worstBone),
		report.worstTime or 0,
		report.maxDrift,
		tostring(report.driftBone)
	)
end

return KeyframeBuilder
