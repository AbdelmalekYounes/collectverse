-- Écran Combat : salle d'attente PvE. Le combat lui-même se joue dans l'arène 3D
-- (BattleDirector) : lancer ferme cet écran et passe en mode combat.
-- Si un combat est déjà en cours côté serveur, il reprend là où il en était.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local GameConfig = require(Shared.Config.GameConfig)
local CardCatalog = require(Shared.Catalog.CardCatalog)
local Encounters = require(Shared.Catalog.Encounters)

local Client = script.Parent.Parent.Parent
local BattleController = require(Client.Controllers.BattleController)
local BattleDirector = require(Client.Controllers.BattleDirector)
local Components = require(Client.UI.Components)

local new = Components.new

local BattleScreen = {
	id = "Battle",
	title = "Combat PvE",
	accent = Theme.Colors.Coral,
}

local ENCOUNTER_ID = "RiftEcho1"

function BattleScreen.build(container: Frame, controller)
	local encounter = Encounters[ENCOUNTER_ID]
	local column = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = container,
	}, { Components.list(Enum.FillDirection.Vertical, 12) })

	local panel = Components.panel({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = column,
	}, { Components.padding(14, 16), Components.list(Enum.FillDirection.Vertical, 6) })
	Components.heading("Rencontre 1", { LayoutOrder = 1, TextColor3 = Theme.Colors.Coral, Parent = panel })
	Components.label({
		Text = encounter.name,
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Heading,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = 2,
		Parent = panel,
	})
	local enemyNames = {}
	for _, enemy in encounter.enemies do
		table.insert(enemyNames, CardCatalog.getFighter(enemy.fighterId).name)
	end
	Components.paragraph(
		encounter.description
			.. " Échos présents : "
			.. table.concat(enemyNames, ", ")
			.. ". Vos "
			.. GameConfig.Team.Size
			.. " combattants seront invoqués dans l'arène. Planifiez leurs actions : la vitesse décide de l'ordre. "
			.. "Une victoire rapporte un booster First Rift.",
		{ LayoutOrder = 3, Parent = panel }
	)

	local actions = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 2,
		Parent = column,
	}, { Components.list(Enum.FillDirection.Horizontal, 10) })

	Components.button({
		text = "Préparer l'équipe",
		size = UDim2.fromOffset(190, 44),
		layoutOrder = 1,
		onClick = function()
			controller.open("Team")
		end,
	}).Parent =
		actions

	local message = Components.label({
		Name = "Message",
		TextColor3 = Theme.Colors.Coral,
		TextSize = Theme.TextSize.Caption,
		LayoutOrder = 3,
		Parent = column,
	})

	local launch
	launch = Components.button({
		text = "Lancer le combat",
		variant = "danger",
		size = UDim2.fromOffset(190, 44),
		layoutOrder = 2,
		onClick = function()
			-- Chaque refus est affiché et écrit dans la sortie : un clic sans effet
			-- visible est impossible à diagnostiquer.
			local function refuse(reason: string)
				message.Text = reason
				warn("[Combat] Lancement refusé : " .. reason)
			end
			if BattleDirector.isActive() then
				refuse("Un combat est déjà en cours d'affichage")
				return
			end
			if BattleController.isBusy() then
				refuse("Une requête de combat est déjà en cours, patientez")
				return
			end
			Components.setButtonEnabled(launch, false)
			message.Text = "Connexion à la faille…"
			local result = BattleController.start(ENCOUNTER_ID)
			Components.setButtonEnabled(launch, true)
			if not result.ok then
				refuse(result.reason or "Impossible de lancer le combat")
				return
			end
			message.Text = ""
			controller.close()
			-- Une reprise replace directement les combattants, sans nouvelle invocation.
			BattleDirector.enter(not result.resumed, encounter.name)
		end,
	})
	launch.Parent = actions

	local state = {}
	state.refresh = function()
		message.Text = ""
	end
	return state
end

function BattleScreen.onOpen(state)
	state.refresh()
end

return BattleScreen
