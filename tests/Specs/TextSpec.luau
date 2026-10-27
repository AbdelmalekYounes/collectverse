local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Text = require(ReplicatedStorage.Shared.Util.Text)

return function(test, expect)
	test("majuscules accentuées", function()
		expect.equal(Text.upper("Compétence"), "COMPÉTENCE")
		expect.equal(Text.upper("Équipe"), "ÉQUIPE")
		expect.equal(Text.upper("à ç è ê ë î ï ô ù û ü ÿ œ"), "À Ç È Ê Ë Î Ï Ô Ù Û Ü Ÿ Œ")
		expect.equal(Text.upper("Défense · 3"), "DÉFENSE · 3", "symboles conservés")
		expect.equal(Text.upper("First Rift"), "FIRST RIFT", "ASCII")
		expect.equal(Text.upper(""), "", "chaîne vide")
	end)

	test("texte non UTF-8 : repli ASCII sans erreur", function()
		expect.equal(Text.upper("ab\255"), "AB\255")
	end)
end
