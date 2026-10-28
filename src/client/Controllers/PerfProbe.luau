-- Sonde de performance des combats (protocole de mesure sur téléphone, V0.2.5).
-- Désactivée par défaut : GameConfig.Debug.PerfProbe = true dans une copie de test
-- de l'expérience. Pendant chaque combat, enregistre la durée de chaque image
-- (RenderStepped, côté appareil), affiche les i/s en direct dans un coin de l'écran,
-- puis écrit un résumé à la fin du combat : à l'écran (pour une capture) et dans la
-- console développeur (F9, onglet Log). Présentation seulement : aucun effet sur le jeu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local FrameStats = require(ReplicatedStorage.Shared.Util.FrameStats)

local BattleDirector = require(script.Parent.BattleDirector)
local GraphicsQuality = require(script.Parent.Parent.State.GraphicsQuality)

local PerfProbe = {}

local MAX_SAMPLES = 36000 -- 10 min à 60 i/s

local samples: { number } = {}
local connection: RBXScriptConnection? = nil
local label: TextLabel? = nil

local function memoryMb(): string
	local ok, total = pcall(Stats.GetTotalMemoryUsageMb, Stats)
	local okMesh, mesh = pcall(Stats.GetMemoryUsageMbForTag, Stats, Enum.DeveloperMemoryTag.GraphicsMeshParts)
	local okTex, texture = pcall(Stats.GetMemoryUsageMbForTag, Stats, Enum.DeveloperMemoryTag.GraphicsTexture)
	return string.format(
		"mémoire %s Mo (maillages %s, textures %s)",
		if ok then string.format("%.0f", total) else "?",
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
	gui.IgnoreGuiInset = false
	local text = Instance.new("TextLabel")
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.new(0.5, 0, 0, 4)
	text.Size = UDim2.fromOffset(240, 16)
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
		"effets %s | écran %d × %d | %s",
		GraphicsQuality.level(),
		size.X,
		size.Y,
		if UserInputService.TouchEnabled then "tactile" else "souris"
	)
end

local function start()
	table.clear(samples)
	local text = ensureLabel()
	text.Size = UDim2.fromOffset(240, 16)
	local accumulated, frames = 0, 0
	connection = RunService.RenderStepped:Connect(function(dt)
		if #samples < MAX_SAMPLES then
			table.insert(samples, dt * 1000)
		end
		accumulated += dt
		frames += 1
		if accumulated >= 0.5 then
			text.Text = string.format("[PerfProbe] %.0f i/s", frames / accumulated)
			accumulated, frames = 0, 0
		end
	end)
end

local function stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if #samples == 0 then
		return
	end
	local summary = FrameStats.summarize(samples)
	local line = string.format("[PerfProbe] combat : %s | %s | %s", FrameStats.describe(summary), memoryMb(), context())
	print(line)
	local text = ensureLabel()
	text.Size = UDim2.fromOffset(760, 40)
	text.Text = line
end

function PerfProbe.init()
	if not GameConfig.Debug.PerfProbe then
		return
	end
	BattleDirector.ModeChanged:Connect(function(active: boolean)
		if active then
			start()
		else
			stop()
		end
	end)
	print("[PerfProbe] actif : mesure des combats (résumé à la fin de chaque combat)")
end

return PerfProbe
