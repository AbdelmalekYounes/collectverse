-- Système visuel des cartes (CardStyle) et déroulé de l'ouverture (RevealTimeline).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage.Shared
local Rarities = require(Shared.Catalog.Rarities)
local CardCatalog = require(Shared.Catalog.CardCatalog)
local CardStyle = require(Shared.Visuals.CardStyle)
local VisualAssets = require(Shared.Visuals.VisualAssets)
local RevealTimeline = require(StarterPlayer.StarterPlayerScripts.Client.UI.RevealTimeline)

local HEX = "^#%x%x%x%x%x%x$"

local function isHex(value: any): boolean
	return type(value) == "string" and string.match(value, HEX) ~= nil
end

return function(test, expect)
	test("chaque rareté a un cadre complet, aux couleurs valides", function()
		for _, rarity in Rarities.Order do
			local frame = CardStyle.Frames[rarity]
			expect.truthy(frame, rarity)
			expect.truthy(#frame.border >= 2, rarity .. " : dégradé de contour")
			for _, color in frame.border do
				expect.truthy(isHex(color), rarity .. " : " .. tostring(color))
			end
			expect.truthy(isHex(frame.background[1]) and isHex(frame.background[2]), rarity .. " : fond")
			expect.truthy(isHex(frame.plate) and isHex(frame.accent), rarity .. " : bandeau et accent")
		end
	end)

	test("la richesse du cadre suit la rareté (lecture redondante)", function()
		local previous = nil
		for _, rarity in Rarities.Order do
			local frame = CardStyle.Frames[rarity]
			expect.equal(frame.gems, Rarities.Info[rarity].rank, rarity .. " : une gemme par rang")
			if previous then
				expect.truthy(frame.thickness > previous.thickness, rarity .. " : contour plus épais")
			end
			previous = frame
		end
		expect.truthy(CardStyle.Frames.Legendary.foil, "Légendaire : reflet holographique")
		expect.falsy(CardStyle.Frames.Common.foil, "Commune : pas de reflet")
		expect.truthy(CardStyle.Frames.Epic.ornaments and CardStyle.Frames.Legendary.ornaments, "ornements")
	end)

	test("lisibilité : texte principal et accents contrastés sur les bandeaux sombres", function()
		for _, rarity in Rarities.Order do
			local frame = CardStyle.Frames[rarity]
			local textContrast = CardStyle.contrast(CardStyle.Palette.Text, frame.plate)
			expect.truthy(textContrast >= 4.5, string.format("%s : nom %.1f:1", rarity, textContrast))
			local accentContrast = CardStyle.contrast(frame.accent, frame.plate)
			expect.truthy(accentContrast >= 4.5, string.format("%s : libellé %.1f:1", rarity, accentContrast))
			local mutedContrast = CardStyle.contrast(CardStyle.Palette.TextMuted, frame.background[2])
			expect.truthy(mutedContrast >= 4.5, string.format("%s : sous-titre %.1f:1", rarity, mutedContrast))
		end
		expect.near(CardStyle.contrast("#FFFFFF", "#000000"), 21, 0.01, "référence WCAG")
	end)

	test("variantes : le reflet s'ajoute, la rareté affichée ne change jamais", function()
		local holo = CardStyle.resolve("Common", "Holo")
		expect.truthy(holo.foil, "reflet")
		expect.equal(holo.rarity, "Common", "rareté inchangée")
		expect.equal(holo.frame, CardStyle.Frames.Common, "cadre de la vraie rareté")
		expect.equal(holo.variantLabel, "HOLO")
		local unknown = CardStyle.resolve("Mythique", "Inconnue")
		expect.equal(unknown.rarity, "Common", "rareté inconnue : cadre de repli")
		expect.equal(unknown.variant, "Standard", "variante inconnue : standard")
	end)

	test("classes de taille selon la largeur de la vignette", function()
		expect.equal(CardStyle.sizeClass(100), "Compact", "équipe 100 × 140")
		expect.equal(CardStyle.sizeClass(112), "Standard", "grille 112 × 158")
		expect.equal(CardStyle.sizeClass(116), "Standard", "révélation 116 × 164")
		expect.equal(CardStyle.sizeClass(180), "Large", "fiche 180 × 254")
		local compact, large = CardStyle.SizeClasses.Compact, CardStyle.SizeClasses.Large
		expect.truthy(large.nameMax > compact.nameMax, "texte plus grand sur grande carte")
	end)

	test("la mise en page tient dans la carte, sans chevauchement vertical (toutes les tailles)", function()
		for _, className in CardStyle.SizeOrder do
			local layout = CardStyle.layout(className)
			expect.truthy(layout.art.x + layout.art.width <= 1, className .. " : illustration en largeur")
			-- Gemmes centrées sur le bas de l'illustration, entièrement au-dessus du nom.
			expect.near(layout.gems.y, layout.art.y + layout.art.height, 1e-9, className .. " : gemmes à cheval")
			expect.truthy(
				layout.gems.y + layout.gems.height / 2 <= layout.name.y + 1e-9,
				className .. " : gemmes au-dessus du nom"
			)
			local bottom = 0
			for _, key in { "name", "subtitle", "footer" } do
				local zone = layout[key]
				expect.truthy(zone.y >= bottom - 1e-9, className .. " : " .. key .. " sous la zone précédente")
				bottom = zone.y + zone.height
			end
			expect.truthy(bottom <= 1, className .. " : pied de carte dans la carte")
		end
		expect.equal(CardStyle.layout("Large"), CardStyle.layout("Standard"), "Large reprend Standard")
	end)

	test("Compact : nom et illustration plus grands que Standard", function()
		local compact, standard = CardStyle.layout("Compact"), CardStyle.layout("Standard")
		expect.truthy(compact.name.height > standard.name.height, "nom plus haut")
		expect.truthy(compact.art.height > standard.art.height, "illustration plus haute")
		expect.truthy(CardStyle.SizeClasses.Compact.nameMax >= CardStyle.SizeClasses.Standard.nameMax, "texte du nom")
	end)

	test("recadrage : le sujet d'une illustration 4:5 reste visible à toutes les tailles", function()
		for _, className in CardStyle.SizeOrder do
			local visible = CardStyle.visibleArtHeight(className)
			expect.truthy(
				visible >= CardStyle.ArtSafeBand,
				string.format("%s : %.0f %% de la hauteur visible", className, visible * 100)
			)
		end
		expect.near(CardStyle.artAspect("Standard"), (0.86 * 112) / (0.55 * 158), 1e-6, "fenêtre Standard")
	end)

	test("finition distincte de la rareté : pastille dans l'illustration, loin du badge de quantité", function()
		local badge = CardStyle.FinishBadge
		expect.truthy(badge.x + badge.width <= 1 and badge.y + badge.height <= 1, "dans l'illustration")
		for _, className in CardStyle.SizeOrder do
			local art = CardStyle.layout(className).art
			local right = art.x + (badge.x + badge.width) * art.width
			-- Le badge de quantité occupe le quart droit de la carte (largeur 0.27).
			expect.truthy(right < 0.7, className .. " : aucun chevauchement avec la quantité")
		end
		local holo = CardStyle.resolve("Common", "Holo")
		expect.equal(holo.rarity, "Common", "la rareté affichée reste Commune")
		expect.equal(holo.variantLabel, "HOLO", "la finition a son propre libellé")
	end)

	test("Kael, personnage pilote : variante Holo, sans Asset ID inventé", function()
		expect.equal(VisualAssets.variant("F001"), "Holo")
		expect.equal(VisualAssets.cardArt("F001"), nil, "illustration à fournir : repli")
		expect.equal(VisualAssets.variant("F002"), "Standard")
		local errors = VisualAssets.validate(function(id)
			return CardCatalog.get(id) ~= nil
		end, { F001 = { variant = "Prisme" } })
		expect.equal(#errors, 1, "variante inconnue refusée")
	end)

	test("ouverture : aucune rareté suggérée avant le retournement", function()
		local rarities = { "Common", "Rare", "Common", "Epic", "Legendary" }
		local steps = RevealTimeline.build(rarities)
		expect.equal(steps[1].kind, "Charge")
		expect.equal(steps[2].kind, "Burst")
		expect.equal(steps[3].kind, "Deal")
		local flipped = {}
		local spotlights = {}
		for _, step in steps do
			if step.kind == "Flip" then
				flipped[step.index] = true
			elseif step.kind == "Spotlight" then
				expect.truthy(flipped[step.index], "mise en lumière après le retournement de " .. step.index)
				table.insert(spotlights, step.index)
			else
				expect.equal(step.index, nil, step.kind .. " ne vise aucune carte en particulier")
			end
		end
		expect.equal(#spotlights, 2, "Épique et Légendaire seulement")
		for index = 1, #rarities do
			expect.truthy(flipped[index], "carte " .. index .. " retournée")
		end
	end)

	test("ouverture : Légendaire plus mise en valeur, animations réduites plus courtes", function()
		local rarities = { "Common", "Common", "Common", "Epic", "Legendary" }
		local full = RevealTimeline.build(rarities)
		local reduced = RevealTimeline.build(rarities, { reducedMotion = true })
		local function spotlightOf(steps, index)
			for _, step in steps do
				if step.kind == "Spotlight" and step.index == index then
					return step.duration
				end
			end
			return 0
		end
		expect.truthy(spotlightOf(full, 5) > spotlightOf(full, 4), "Légendaire plus longue qu'Épique")
		local fullTotal = RevealTimeline.totalDuration(full)
		local reducedTotal = RevealTimeline.totalDuration(reduced)
		expect.truthy(reducedTotal < fullTotal / 2, "réduit nettement plus court")
		expect.truthy(fullTotal <= 6, string.format("déroulé complet raisonnable (%.1f s)", fullTotal))
	end)
end
