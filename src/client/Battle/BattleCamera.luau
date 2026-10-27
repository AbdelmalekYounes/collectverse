-- Caméra et contrôles pendant un combat : caméra fixe sur l'arène,
-- déplacements du personnage et contrôles tactiles désactivés.
-- Tout est restauré à la sortie du combat.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Arena = require(script.Parent.Arena)
local BattleLayout = require(script.Parent.BattleLayout)

local BattleCamera = {}

local saved = nil

-- Champ de vision adapté au format de l'écran (voir BattleLayout.fieldOfView).
local function applyFieldOfView(camera: Camera)
	local size = camera.ViewportSize
	camera.FieldOfView = BattleLayout.fieldOfView(if size.Y > 0 then size.X / size.Y else 0)
end

local function getControls()
	local ok, controls = pcall(function()
		local playerModule = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
		return require(playerModule :: ModuleScript):GetControls()
	end)
	return if ok then controls else nil
end

function BattleCamera.enter()
	local camera = Workspace.CurrentCamera
	if not saved then
		saved = {
			cameraType = camera.CameraType,
			fieldOfView = camera.FieldOfView,
			touchControls = GuiService.TouchControlsEnabled,
		}
	end
	camera.CameraType = Enum.CameraType.Scriptable
	applyFieldOfView(camera)
	camera.CFrame = Arena.cameraCFrame()

	local controls = getControls()
	if controls then
		controls:Disable()
	end
	pcall(function()
		GuiService.TouchControlsEnabled = false
	end)
end

-- Changement de résolution ou d'orientation pendant le combat.
function BattleCamera.refresh()
	local camera = Workspace.CurrentCamera
	if saved and camera then
		applyFieldOfView(camera)
		camera.CFrame = Arena.cameraCFrame()
	end
end

function BattleCamera.exit()
	local camera = Workspace.CurrentCamera
	camera.CameraType = if saved then saved.cameraType else Enum.CameraType.Custom
	camera.FieldOfView = if saved then saved.fieldOfView else 70
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end

	local controls = getControls()
	if controls then
		controls:Enable()
	end
	local touchControls = if saved then saved.touchControls else true
	pcall(function()
		GuiService.TouchControlsEnabled = touchControls
	end)
	saved = nil
end

return BattleCamera
