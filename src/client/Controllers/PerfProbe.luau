-- Sonde de performance des combats (protocole de mesure sur téléphone, V0.2.5).
--
-- Activation : GameConfig.Debug.PerfProbe = true ET environnement de test (Studio,
-- ou une place dont le PlaceId figure dans GameConfig.Debug.TestPlaceIds). Elle ne
-- s'active jamais dans l'expérience publique, même si l'option reste à true.
--
-- Mesure, côté appareil (RenderStepped), la durée de chaque image, séparément pour
-- chaque phase du combat (BattleDirector.PhaseChanged) : invocations (Summoning),
-- planification (Planning), résolution animée des tours (Resolving). Le rapport est
-- écrit dès l'entrée dans l'écran de résultat (Finished), qui n'est jamais mesuré ;
-- un combat quitté avant la fin donne un rapport marqué « interrompu ». Rapport à
-- l'écran (capture) et dans la console développeur (F9, onglet Log).
-- Présentation seulement : aucun effet sur le jeu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local FrameStats = require(ReplicatedStorage.Shared.Util.FrameStats)
local TestEnvironment = require(ReplicatedStorage.Shared.Util.TestEnvironment)

local BattleDirector = require(script.Parent.BattleDirector)
local GraphicsQuality = require(script.Parent.Parent.State.GraphicsQuality)

local PerfProbe = {}

local recorder: FrameStats.Recorder? = nil
local connection: RBXScriptConnection? = nil
local label: TextLabel? = nil

local function memoryMb(): number?
	local ok, total = pcall(Stats.GetTotalMemoryUsageMb, Stats)
	return if ok then total else nil
end

local function memoryTags(): string
	local okMesh, mesh = pcall(Stats.GetMemoryUsageMbForTag, Stats, Enum.DeveloperMemoryTag.GraphicsMeshParts)
	local okTex, texture = pcall(Stats.GetMemoryUsageMbForTag, Stats, Enum.DeveloperMemoryTag.GraphicsTexture)
	return string.format(
		"maillages %s Mo, textures %s Mo",
		if okMesh then string.format("%.1f", mesh) else "?",
		if okTex then string.format("%.1f", texture) else "?"
	)
end

local function ensureLabel(): TextLabel
	if label and label.Parent then
		return label
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "PerfProbe"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	local text = Instance.new("TextLabel")
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.new(0.5, 0, 0, 4)
	text.BackgroundTransparency = 0.35
	text.BackgroundColor3 = Color3.new(0, 0, 0)
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.TextWrapped = true
	text.Font = Enum.Font.Code
	text.Text = ""
	text.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	label = text
	return text
end

local function context(): string
	local camera = Workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.zero
	return string.format(
		"effets %s, détail %s | écran %d × %d | %s",
		GraphicsQuality.level(),
		GraphicsQuality.modelDetail(),
		size.X,
		size.Y,
		if UserInputService.TouchEnabled then "tactile" else "souris"
	)
end

local function start()
	recorder = FrameStats.newRecorder()
	local text = ensureLabel()
	text.Size = UDim2.fromOffset(260, 16)
	text.Text = "[PerfProbe] mesure…"
	local accumulated, frames, sinceMemory = 0, 0, 0
	connection = RunService.RenderStepped:Connect(function(dt)
		local current = recorder :: FrameStats.Recorder
		FrameStats.record(current, dt * 1000)
		accumulated += dt
		frames += 1
		sinceMemory += dt
		if sinceMemory >= 1 then
			sinceMemory = 0
			local total = memoryMb()
			if total then
				FrameStats.recordMemory(current, total)
			end
		end
		if accumulated >= 0.5 then
			text.Text = string.format("[PerfProbe] %s · %.0f i/s", current.phase, frames / accumulated)
			accumulated, frames = 0, 0
		end
	end)
end

-- Écrit le rapport et arrête la mesure. interrupted : combat quitté avant la fin.
local function stop(interrupted: boolean)
	if connection then
		connection:Disconnect()
		connection = nil
	end
	local current = recorder
	recorder = nil
	if not current then
		return
	end
	local report = FrameStats.report(current)
	if report.combat.frames == 0 then
		return
	end
	local header = string.format(
		"[PerfProbe] %s | %s | %s",
		if interrupted then "combat interrompu" else "combat terminé",
		context(),
		memoryTags()
	)
	print(header)
	for _, line in FrameStats.describeReport(report) do
		print("[PerfProbe] " .. line)
	end
	local text = ensureLabel()
	text.Size = UDim2.fromOffset(780, 64)
	text.Text = header .. "\n" .. table.concat(FrameStats.describeReport(report), "\n")
end

function PerfProbe.isEnabled(): boolean
	return GameConfig.Debug.PerfProbe == true and TestEnvironment.isActive(GameConfig.Debug)
end

function PerfProbe.init()
	if not PerfProbe.isEnabled() then
		return
	end
	BattleDirector.PhaseChanged:Connect(function(phase: string)
		if phase == "Summoning" and not recorder then
			start()
		end
		if recorder then
			FrameStats.setPhase(recorder, phase)
			if phase == "Finished" then
				stop(false)
			elseif phase == "Idle" then
				stop(true)
			end
		end
	end)
	print("[PerfProbe] actif (environnement de test) : rapport à la fin de chaque combat, par phase")
end

return PerfProbe
