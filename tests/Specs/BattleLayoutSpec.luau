-- Mise en page du combat selon l'écran (calculs purs de BattleLayout).

local StarterPlayer = game:GetService("StarterPlayer")

local BattleLayout = require(StarterPlayer.StarterPlayerScripts.Client.Battle.BattleLayout)

-- Demi-champ horizontal (degrés) obtenu avec un champ vertical et un format donnés.
local function horizontalHalf(verticalFov: number, aspect: number): number
	return math.deg(math.atan(math.tan(math.rad(verticalFov / 2)) * aspect))
end

return function(test, expect)
	test("16:9 et plus large : champ de vision de base", function()
		expect.equal(BattleLayout.fieldOfView(16 / 9), BattleLayout.BaseFieldOfView)
		expect.equal(BattleLayout.fieldOfView(2.4), BattleLayout.BaseFieldOfView, "écran ultra-large")
		expect.equal(BattleLayout.fieldOfView(801 / 413), BattleLayout.BaseFieldOfView, "téléphone en paysage")
	end)

	test("écran plus étroit : le champ horizontal conçu est conservé", function()
		local design = horizontalHalf(BattleLayout.BaseFieldOfView, BattleLayout.DesignAspect)
		for _, aspect in { 4 / 3, 1.5, 1 } do
			local fov = BattleLayout.fieldOfView(aspect)
			expect.truthy(fov > BattleLayout.BaseFieldOfView, "champ élargi pour " .. aspect)
			expect.near(horizontalHalf(fov, aspect), design, 0.01, "même largeur visible pour " .. aspect)
		end
	end)

	test("portrait et valeurs absurdes : champ borné, jamais d'erreur", function()
		expect.truthy(BattleLayout.fieldOfView(0.46) <= 110, "portrait borné")
		expect.equal(BattleLayout.fieldOfView(0), BattleLayout.BaseFieldOfView, "viewport nul")
		expect.equal(BattleLayout.fieldOfView(0 / 0), BattleLayout.BaseFieldOfView, "NaN")
	end)

	test("plaques : au sol devant les alliés de la ligne avant, hauteur commune ailleurs", function()
		expect.truthy(BattleLayout.plateOffset("Ally", "Front", 7.38) < 0, "allié avant : sous les pieds")
		expect.truthy(
			BattleLayout.plateOffset("Ally", "Front", 7.38) + 1 <= 0,
			"le haut de la plaque reste sous le sol"
		)
		local reference = BattleLayout.PlateReferenceHeight + BattleLayout.PlateGapAbove
		for _, case in { { "Ally", "Back" }, { "Enemy", "Front" }, { "Enemy", "Back" } } do
			expect.equal(
				BattleLayout.plateOffset(case[1], case[2], 6),
				reference,
				case[1] .. case[2] .. " : hauteur commune"
			)
			expect.equal(
				BattleLayout.plateOffset(case[1], case[2], 7.38),
				reference,
				"même hauteur pour un modèle plus grand"
			)
		end
		expect.equal(
			BattleLayout.plateOffset("Enemy", "Front", 9),
			9 + BattleLayout.PlateGapAbove,
			"modèle hors norme : au-dessus de sa tête"
		)
		expect.equal(BattleLayout.plateOffset("Enemy", "Back", 0 / 0), reference, "hauteur invalide")
	end)

	test("plaques : marge réduite sur petit écran, intacte sur grand écran", function()
		local _, pixelsPc = BattleLayout.plateSize(1080)
		local _, pixelsPhone, _, heightPhone = BattleLayout.plateSize(413)
		expect.equal(pixelsPc, 36, "grand écran : marge complète")
		expect.truthy(pixelsPhone < pixelsPc, "téléphone : marge réduite")
		expect.equal(pixelsPhone, 19, "801 × 413 : facteur 0,52")
		expect.equal(heightPhone, 5)
		local _, pixelsTiny = BattleLayout.plateSize(100)
		expect.equal(pixelsTiny, math.round(36 * 0.35), "facteur minimal")
	end)
end
