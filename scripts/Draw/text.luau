--!strict

local Text = {}

local symbolFiles: { [string]: string } = {
	["!"] = "exclamation.glb",
	['"'] = "quote.glb",
	["#"] = "hash.glb",
	["$"] = "dollar.glb",
	["%"] = "percent.glb",
	["&"] = "ampersand.glb",
	["'"] = "apostrophe.glb",
	["("] = "left_parenthesis.glb",
	[")"] = "right_parenthesis.glb",
	["*"] = "asterisk.glb",
	["+"] = "plus.glb",
	[","] = "comma.glb",
	["-"] = "hyphen.glb",
	["."] = "period.glb",
	["/"] = "slash.glb",
	[":"] = "colon.glb",
	[";"] = "semicolon.glb",
	["<"] = "less_than.glb",
	["="] = "equals.glb",
	[">"] = "greater_than.glb",
	["?"] = "question.glb",
	["@"] = "at.glb",
	["["] = "left_bracket.glb",
	["\\"] = "backslash.glb",
	["]"] = "right_bracket.glb",
	["^"] = "caret.glb",
	["_"] = "underscore.glb",
	["`"] = "backtick.glb",
	["{"] = "left_brace.glb",
	["|"] = "pipe.glb",
	["}"] = "right_brace.glb",
	["~"] = "tilde.glb",
}

local ADVANCE_WIDTHS: { [string]: number } = {
	["A"] = 0.5720,
	["B"] = 0.5830,
	["C"] = 0.5500,
	["D"] = 0.6500,
	["E"] = 0.6070,
	["F"] = 0.5130,
	["G"] = 0.6750,
	["H"] = 0.6070,
	["I"] = 0.2900,
	["J"] = 0.4500,
	["K"] = 0.6950,
	["L"] = 0.5980,
	["M"] = 0.8250,
	["N"] = 0.6900,
	["O"] = 0.6520,
	["P"] = 0.6750,
	["Q"] = 0.6550,
	["R"] = 0.6500,
	["S"] = 0.6450,
	["T"] = 0.5950,
	["U"] = 0.6050,
	["V"] = 0.6850,
	["W"] = 0.8780,
	["X"] = 0.6720,
	["Y"] = 0.6820,
	["Z"] = 0.6200,
	["a"] = 0.5170,
	["b"] = 0.5460,
	["c"] = 0.5050,
	["d"] = 0.5450,
	["e"] = 0.5500,
	["f"] = 0.3760,
	["g"] = 0.5490,
	["h"] = 0.5200,
	["i"] = 0.2500,
	["j"] = 0.3120,
	["k"] = 0.5550,
	["l"] = 0.2480,
	["m"] = 0.7550,
	["n"] = 0.5080,
	["o"] = 0.5820,
	["p"] = 0.5500,
	["q"] = 0.5550,
	["r"] = 0.3880,
	["s"] = 0.4930,
	["t"] = 0.3780,
	["u"] = 0.5090,
	["v"] = 0.5090,
	["w"] = 0.7700,
	["x"] = 0.5300,
	["y"] = 0.5020,
	["z"] = 0.4800,
	["0"] = 0.6440,
	["1"] = 0.3500,
	["2"] = 0.6310,
	["3"] = 0.6340,
	["4"] = 0.6850,
	["5"] = 0.6300,
	["6"] = 0.6400,
	["7"] = 0.5300,
	["8"] = 0.6440,
	["9"] = 0.6400,
	[" "] = 0.2330,
	["!"] = 0.2930,
	['"'] = 0.4560,
	["#"] = 0.8680,
	["$"] = 0.6700,
	["%"] = 0.8020,
	["&"] = 0.7640,
	["'"] = 0.2590,
	["("] = 0.3910,
	[")"] = 0.3910,
	["*"] = 0.5010,
	["+"] = 0.6430,
	[","] = 0.3170,
	["-"] = 0.4620,
	["."] = 0.2700,
	["/"] = 0.5120,
	[":"] = 0.2700,
	[";"] = 0.3170,
	["<"] = 0.6450,
	["="] = 0.6440,
	[">"] = 0.6450,
	["?"] = 0.4820,
	["@"] = 1.0000,
	["["] = 0.3920,
	["\\"] = 0.5120,
	["]"] = 0.3920,
	["^"] = 0.6020,
	["_"] = 0.5620,
	["`"] = 0.3200,
	["{"] = 0.3240,
	["|"] = 0.1950,
	["}"] = 0.3240,
	["~"] = 0.6280,
}

Text.ADVANCE_WIDTHS = ADVANCE_WIDTHS

function Text.getAdvanceWidth(char: string): number
	-- just in case
	return ADVANCE_WIDTHS[char] or 0.5
end

function Text.getCharFileName(char: string): string?
	if char >= "A" and char <= "Z" then
		return "upper_" .. char .. ".glb"
	elseif char >= "a" and char <= "z" then
		return "lower_" .. char .. ".glb"
	elseif char >= "0" and char <= "9" then
		return char .. ".glb"
	end
	return symbolFiles[char]
end

function Text.hsvToRgb(h: number, s: number, v: number)
	-- hsv is nicer for rainbow text but also rainbwos go brr
	local r, g, b
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then
		r, g, b = v, t, p
	elseif i == 1 then
		r, g, b = q, v, p
	elseif i == 2 then
		r, g, b = p, v, t
	elseif i == 3 then
		r, g, b = p, q, v
	elseif i == 4 then
		r, g, b = t, p, v
	else
		r, g, b = v, p, q
	end
	return { r = r, g = g, b = b }
end

return Text
