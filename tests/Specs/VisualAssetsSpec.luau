-- Registre des assets visuels V0.2 et politique d'effets graphiques.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CardCatalog = require(Shared.Catalog.CardCatalog)
local VisualAssets = require(Shared.Visuals.VisualAssets)
local EffectsPolicy = require(Shared.Visuals.EffectsPolicy)

local function isKnown(id: string): boolean
	return CardCatalog.get(id) ~= nil
end

return function(test, expect)
	test("le registre du jeu est valide", function()
		local errors = VisualAssets.validate(isKnown)
		expect.equal(#errors, 0, table.concat(errors, " ; "))
	end)

	test("sans asset déclaré : fallback partout (hors Kael, pilote)", function()
		for _, card in CardCatalog.getAll() do
			expect.equal(VisualAssets.cardArt(card.id), nil, card.id .. " : illustration provisoire")
		end
		for _, fighter in CardCatalog.getFighters() do
			local expected = if fighter.id == "F001" then "F001_Kael" else fighter.id
			expect.equal(VisualAssets.modelName(fighter.id), expected, "nom du modèle cherché")
			if fighter.id ~= "F001" then
				for _, kind in VisualAssets.AnimationKinds do
					expect.equal(
						VisualAssets.animation(fighter.id, kind),
						nil,
						fighter.id .. " : mouvement générique"
					)
				end
			end
		end
	end)

	test("Kael : les 7 animations sont déclarées, chacune avec un identifiant distinct", function()
		local seen = {}
		for _, kind in VisualAssets.AnimationKinds do
			local id = VisualAssets.animation("F001", kind)
			expect.truthy(id and string.match(id, "^rbxassetid://%d+$"), kind .. " : identifiant Roblox")
			expect.falsy(seen[id], kind .. " : identifiant non réutilisé")
			seen[id] = true
		end
	end)

	test("chaque action de combat a une animation reconnue", function()
		local kinds = {}
		for _, kind in VisualAssets.AnimationKinds do
			kinds[kind] = true
		end
		for _, slot in { "basic", "skill", "ultimate", "defend" } do
			expect.truthy(kinds[VisualAssets.ActionAnimation[slot]], slot)
		end
	end)

	test("le validateur refuse les entrées mal formées", function()
		local errors = VisualAssets.validate(isKnown, {
			F001 = { art = "123", model = "", animations = { Attack = "rbxassetid://5", Dance = "rbxassetid://6" } },
			F002 = { animations = { Hit = "http://exemple" } },
			X999 = {},
			F003 = { art = "rbxassetid://42", model = "F003_Lyra", animations = { Idle = "rbxassetid://7" } },
		})
		local text = table.concat(errors, "\n")
		expect.contains(text, "F001 : illustration invalide")
		expect.contains(text, "F001 : nom de modèle invalide")
		expect.contains(text, "F001 : animation inconnue Dance")
		expect.contains(text, "F002 : AnimationId invalide pour Hit")
		expect.contains(text, "X999 : carte inconnue")
		expect.equal(#errors, 5, "l'entrée F003, valide, ne produit aucune erreur")
	end)

	test("effets : réduits sur demande ou en qualité graphique basse", function()
		expect.equal(EffectsPolicy.level(false, nil), "Full", "qualité automatique")
		expect.equal(EffectsPolicy.level(true, nil), "Reduced", "option du joueur")
		expect.equal(EffectsPolicy.level(false, 2), "Reduced", "qualité basse")
		expect.equal(EffectsPolicy.level(false, 3), "Reduced", "seuil inclus")
		expect.equal(EffectsPolicy.level(false, 8), "Full", "qualité haute")
		local full, reduced = EffectsPolicy.budget("Full"), EffectsPolicy.budget("Reduced")
		expect.truthy(reduced.summonParticles < full.summonParticles, "moins de particules")
		expect.falsy(reduced.dynamicLights, "pas de lumières dynamiques")
		expect.truthy(full.arenaLight, "lumière d'arène en qualité complète")
		expect.truthy(reduced.arenaLight, "lumière d'arène gardée en effets réduits")
		expect.truthy(full.modelParticles, "braises des modèles en qualité complète")
		expect.falsy(reduced.modelParticles, "pas de particules permanentes sur les modèles")
		expect.equal(EffectsPolicy.budget("Inconnu"), full, "niveau inconnu : budget complet")
	end)
end
