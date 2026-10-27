-- Outils de texte compatibles UTF-8.
-- string.upper de Luau ne traite que l'ASCII : « Compétence » donnait « COMPéTENCE ».

local Text = {}

-- Minuscules accentuées hors du bloc Latin-1 « -0x20 »
local SPECIAL_UPPER = {
	[0x00FF] = 0x0178, -- ÿ → Ÿ
	[0x0153] = 0x0152, -- œ → Œ
}

local function upperCodepoint(codepoint: number): number
	if codepoint < 0x80 then
		return string.byte(string.upper(string.char(codepoint)))
	end
	-- Latin-1 : à (0xE0) … þ (0xFE) → À … Þ, sauf ÷ (0xF7)
	if codepoint >= 0xE0 and codepoint <= 0xFE and codepoint ~= 0xF7 then
		return codepoint - 0x20
	end
	return SPECIAL_UPPER[codepoint] or codepoint
end

-- Majuscules, accents compris (« Équipe » → « ÉQUIPE »).
function Text.upper(text: string): string
	local ok, result = pcall(function()
		local characters = {}
		for _, codepoint in utf8.codes(text) do
			table.insert(characters, utf8.char(upperCodepoint(codepoint)))
		end
		return table.concat(characters)
	end)
	-- Texte non UTF-8 : repli sur la version ASCII plutôt qu'une erreur d'affichage.
	return if ok then result else string.upper(text)
end

return Text
