-- Invocations : exécuté dans Studio uniquement (crée des Instances et des Tweens).

local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Client = StarterPlayer.StarterPlayerScripts.Client
local Arena = require(Client.Battle.Arena)
local SummonController = require(Client.Battle.SummonController)

local UNIT = { uid = "A1", fighterId = "F001", name = "Kael", element = "Fire", side = "Ally", slot = 1 }

-- Transparences des pièces visibles, dans l'ordre de construction (identique d'un modèle à l'autre).
local function transparencies(model: Model)
	local result = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= model.PrimaryPart then
			table.insert(result, part.Transparency)
		end
	end
	return result
end

local function withFolder(callback)
	local folder = Instance.new("Folder")
	folder.Name = "SummonSpec"
	folder.Parent = Workspace
	local ok, err = pcall(callback, folder)
	folder:Destroy()
	if not ok then
		error(err, 0)
	end
end

return function(test, expect)
	test("invocation instantanée : modèle placé et marqué", function()
		withFolder(function(folder)
			local target = Arena.slotCFrame("Enemy", 4)
			local model =
				SummonController.summon(UNIT, target, folder, { mode = "instant", tint = Color3.new(1, 0, 0) })
			expect.equal(model.Parent, folder, "parent")
			expect.equal(model:GetAttribute("Uid"), "A1", "attribut Uid")
			expect.near((model:GetPivot().Position - target.Position).Magnitude, 0, 1e-3, "position")
			local highlight = model:FindFirstChild("FxHighlight")
			expect.truthy(highlight, "Highlight")
			-- Les propriétés Roblox sont stockées en simple précision (0,85 → 0,8500000238).
			expect.near(highlight:GetAttribute("BaseFillTransparency"), 0.85, 1e-6, "teinte des Échos")
		end)
	end)

	test("allié : contour chaud fin et peu opaque, sans remplissage", function()
		withFolder(function(folder)
			local model = SummonController.summon(UNIT, Arena.slotCFrame("Ally", 2), folder, { mode = "instant" })
			local highlight = model:FindFirstChild("FxHighlight") :: Highlight
			local outline = SummonController.AllyOutline
			expect.equal(highlight.FillTransparency, 1, "pas de remplissage")
			expect.near(highlight.OutlineTransparency, outline.transparency, 1e-6, "contour peu opaque")
			expect.truthy(outline.transparency >= 0.5, "jamais un contour plein")
			expect.equal(highlight.OutlineColor:ToHex(), outline.color:ToHex(), "couleur du contour")
			expect.equal(
				highlight:GetAttribute("BaseOutlineColor"),
				highlight.OutlineColor,
				"couleur restaurée après un impact"
			)
			expect.equal(highlight.DepthMode, Enum.HighlightDepthMode.Occluded, "masqué derrière les autres modèles")
		end)
	end)

	test("invocation complète (réduite) : carte nettoyée, modèle entièrement visible", function()
		withFolder(function(folder)
			local target = Arena.slotCFrame("Ally", 2)
			local model = SummonController.summon(UNIT, target, folder, { mode = "reduced" })
			expect.equal(folder:FindFirstChild("SummonCard"), nil, "carte retirée")
			expect.equal(folder:FindFirstChild("SummonGlow"), nil, "halo retiré")
			expect.near((model:GetPivot().Position - target.Position).Magnitude, 0, 1e-2, "position finale")
			local reference = SummonController.summon(UNIT, target, folder, { mode = "instant" })
			local actual, expected = transparencies(model), transparencies(reference)
			expect.equal(#actual, #expected, "nombre de pièces")
			for index = 1, #expected do
				expect.near(actual[index], expected[index], 1e-3, "transparence de la pièce " .. index)
			end
		end)
	end)

	test("passer termine toutes les invocations en cours", function()
		withFolder(function(folder)
			local entries = {}
			for slot = 1, 5 do
				local unit = table.clone(UNIT)
				unit.uid = "A" .. slot
				table.insert(entries, { unit = unit, cframe = Arena.slotCFrame("Ally", slot) })
			end
			task.delay(0.1, SummonController.requestSkip)
			local started = os.clock()
			local models = SummonController.summonAll(entries, folder, "full", function()
				return nil
			end)
			expect.truthy(os.clock() - started < 1, "terminé bien avant 1,3 s + décalages")
			for slot = 1, 5 do
				expect.truthy(models["A" .. slot], "modèle A" .. slot)
			end
			expect.falsy(SummonController.isSkipping(), "drapeau réinitialisé")
		end)
	end)
end
