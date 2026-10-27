-- Exécute les tests au démarrage d'une session Studio (Play / Run).
-- Jamais en production : RunService:IsStudio() est faux sur les serveurs Roblox.
-- Désactivable via GameConfig.Debug.RunTestsInStudio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

if not RunService:IsStudio() or not GameConfig.Debug.RunTestsInStudio then
	return
end

local TestRunner = require(script.Parent.TestRunner)
local results = TestRunner.run(script.Parent.Specs)

-- Résumé lisible depuis l'Explorateur (attributs de Workspace) pendant la session.
Workspace:SetAttribute("TestsPassed", results.passed)
Workspace:SetAttribute("TestsFailed", results.failed)
