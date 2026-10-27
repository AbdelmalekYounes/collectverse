-- Animations spécifiques des combattants (préparation V0.2).
--
-- play(model, kind, speed) joue l'animation `kind` (VisualAssets.AnimationKinds)
-- déclarée pour ce combattant dans VisualAssets, si le modèle possède un Animator.
-- Elle renvoie false dans tous les autres cas : pas d'animation déclarée, modèle
-- provisoire sans Animator, asset pas encore chargé ou introuvable. L'appelant
-- joue alors le mouvement générique (BattleFx) : le combat reste lisible sans asset.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VisualAssets = require(ReplicatedStorage.Shared.Visuals.VisualAssets)

local FighterAnimator = {}

-- Pistes chargées par modèle (clés faibles : libérées avec le modèle).
local tracks: { [Model]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any
local warned: { [string]: boolean } = {}

local function animatorOf(model: Model): Animator?
	return model:FindFirstChildWhichIsA("Animator", true)
end

local function trackFor(model: Model, kind: string): AnimationTrack?
	local fighterId = model:GetAttribute("FighterId")
	if type(fighterId) ~= "string" then
		return nil
	end
	local animationId = VisualAssets.animation(fighterId, kind)
	if not animationId then
		return nil
	end
	local byKind = tracks[model]
	if byKind and byKind[kind] then
		return byKind[kind]
	end
	local animator = animatorOf(model)
	if not animator then
		return nil
	end
	local ok, track = pcall(function()
		local animation = Instance.new("Animation")
		animation.AnimationId = animationId
		return animator:LoadAnimation(animation)
	end)
	if not ok then
		local key = fighterId .. "/" .. kind
		if not warned[key] then
			warned[key] = true
			warn(
				string.format("[FighterAnimator] %s : animation %s indisponible (%s)", fighterId, kind, tostring(track))
			)
		end
		return nil
	end
	byKind = byKind or {}
	byKind[kind] = track
	tracks[model] = byKind
	return track
end

-- Prépare toutes les animations déclarées (à l'invocation), pour qu'elles soient
-- chargées au moment de les jouer.
function FighterAnimator.preload(model: Model)
	for _, kind in VisualAssets.AnimationKinds do
		trackFor(model, kind)
	end
end

-- Renvoie true si une animation spécifique a été jouée (sinon : mouvement générique).
function FighterAnimator.play(model: Model, kind: string, speed: number?): boolean
	local track = trackFor(model, kind)
	if not track then
		return false
	end
	track:Play(0.1, 1, speed or 1)
	-- Longueur nulle : asset pas (encore) chargé, rien ne serait visible.
	return track.Length > 0
end

-- Boucle d'attente en combat, si le combattant en possède une.
function FighterAnimator.startIdle(model: Model)
	local track = trackFor(model, "Idle")
	if track then
		track.Looped = true
		track:Play(0.2)
	end
end

-- Arrête la boucle d'attente (défaite : le combattant ne doit pas se relever).
function FighterAnimator.stopIdle(model: Model)
	local byKind = tracks[model]
	local track = byKind and byKind.Idle
	if track then
		track:Stop(0.1)
	end
end

return FighterAnimator
