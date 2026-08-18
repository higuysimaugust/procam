--!strict

local Emotes = {}

local emotes = {
	{ name = "None", label = "None" },
	{ name = "Affirmative", label = "+" },
	{ name = "Negative", label = "-" },
	{ name = "Left (spectator's left)", label = "->", label2 = "-->" },
	{ name = "Right (spectator's right)", label = "<-", label2 = "<--" },
	{ name = "Up", label = "^", label2 = "^^" },
	{ name = "Down", label = "v", label2 = "vv" },
	{ name = "Wave", label = "o_o", label2 = "o_o.", label3 = "o_o;" },
	{ name = "XX", label = "x_x", label2 = "x_X" },
	{ name = "Wink", label = "^-^", label2 = "^_-", label3 = "-_-" },
	{ name = "Suspicious", label = "<_<", label2 = ">_>" },
}

function Emotes.onGui()
	local currentEmote = camera:getEmote() or -1

	for i, emote in emotes do
		local label = emote.label .. "##" .. emote.name

		if currentEmote + 1 == i then
			Gui.beginDisabled()
			Gui.button(label)
			Gui.endDisabled()
		elseif Gui.button(label) then
			camera:setEmote(i - 1)
		end
		Gui.setItemTooltip(emote.name)
		Gui.sameLine()
	end
	Gui.newLine()
	
	local activeEmote = emotes[currentEmote + 1]
end



return Emotes
