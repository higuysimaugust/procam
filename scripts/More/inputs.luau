--!strict
-- Helper for remapping keybinds/controls

local Inputs = {
	forwardKey = Input.Key.W,
	backwardKey = Input.Key.S,
	leftKey = Input.Key.A,
	rightKey = Input.Key.D,
	upKey = Input.Key.E,
	downKey = Input.Key.Q,
	gravityAlignedMovementModifier = Input.Key.LeftAlt,
	localMovementAxesDefault = true,

	pitchUpKey = Input.Key.Up,
	pitchDownKey = Input.Key.Down,
	yawLeftKey = Input.Key.Left,
	yawRightKey = Input.Key.Right,

	rollMouseEnable = Input.Key.RightMouseButton,
	rollLeftGp = Input.Gamepad.DPad_Left,
	rollRightGp = Input.Gamepad.DPad_Right,
	rollResetTolerance = 5,
	resetRollGp = Input.Gamepad.LeftThumbstick,
	toggleSmoothingGp = Input.Gamepad.FaceButton_Right,
	frontflipGp = Input.Gamepad.FaceButton_Top,
	backflipGp = Input.Gamepad.FaceButton_Bottom,
	toggleCameraGp = Input.Gamepad.FaceButton_Left,

	fastKey = Input.Key.LeftShift,
	slowKey = Input.Key.LeftControl,

	zoomInGp = Input.Gamepad.DPad_Up,
	zoomOutGp = Input.Gamepad.DPad_Down,
	zoomSpeedGp = 0.5,
	zoomSpeedKb = 5,

	spaceLocationKey = Input.Key.PageUp,
	enableSpaceKeybind = false,

	minFov = 10,
	maxFov = 160,

	rotSpeed = 180,
	fovRotSpeedMultiplier = 2,

	maxMoveSpeed = 25000,
	minMoveSpeed = 200,
	speedAdjustmentRate = 1,
	lookSmoothness = 0,
	lookInputTarget = Vec3.zeroVector,
	rotEuler = Vec3.zeroVector,
	firstTransition = true,
	smoothing = false,
	toggleSmoothingKey = Input.Key.CapsLock,

	gravityChaseSpeed = 6,
	gravitySlowChaseSpeed = 0.5,

	autoFocusKeyKB = Input.Key.MiddleMouseButton,
	autoFocusKeyGP = Input.Gamepad.RightThumbstick,
	continuousAutoFocus = false,
	alignToGravity = true,

	playGoalExplosions = false,
	playScraprunSpinners = false,
	placeBallEnabled = true,
	ballScaleMultiplier = 1,
}

local availableKeybindCategories = {
	{
		name = "Keyboard",
		keys = {
			"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
			"N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
			"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "F1", "F2", "F3",
			"F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "SpaceBar",
			"LeftBracket", "RightBracket", "PageUp", "PageDown", "Home", "End", "Insert",
			"Delete", "Up", "Down", "Left", "Right", "LeftShift", "RightShift",
			"LeftControl", "RightControl", "LeftAlt", "RightAlt", "Tab", "Enter", "Escape",
			"Backspace", "Tilde",
		},
	},
	{
		name = "Mouse",
		keys = { "MouseLeft", "MouseRight", "MouseMiddle", "MouseSide1", "MouseSide2" },
	},
	{
		name = "Controller",
		keys = {
			"ControllerLeftTrigger", "ControllerRightTrigger", "ControllerLeftBumper", "ControllerRightBumper",
			"ControllerFaceUp", "ControllerFaceDown", "ControllerFaceLeft", "ControllerFaceRight",
			"ControllerDPadUp", "ControllerDPadDown", "ControllerDPadLeft", "ControllerDPadRight",
			"ControllerLeftStickClick", "ControllerRightStickClick",
		},
	},
}

local keybindSearchStates = {}
local keybindFilterStates = {}

local aliasMap = {
	MouseLeft = Input.Key.LeftMouseButton,
	MouseRight = Input.Key.RightMouseButton,
	MouseMiddle = Input.Key.MiddleMouseButton,
	MouseSide1 = Input.Key.ThumbMouseButton,
	MouseSide2 = Input.Key.ThumbMouseButton2,
	ControllerLeftTrigger = Input.Gamepad.LeftTrigger,
	ControllerRightTrigger = Input.Gamepad.RightTrigger,
	ControllerLeftBumper = Input.Gamepad.LeftShoulder,
	ControllerRightBumper = Input.Gamepad.RightShoulder,
	ControllerFaceUp = Input.Gamepad.FaceButton_Top,
	ControllerFaceDown = Input.Gamepad.FaceButton_Bottom,
	ControllerFaceLeft = Input.Gamepad.FaceButton_Left,
	ControllerFaceRight = Input.Gamepad.FaceButton_Right,
	ControllerDPadUp = Input.Gamepad.DPad_Up,
	ControllerDPadDown = Input.Gamepad.DPad_Down,
	ControllerDPadLeft = Input.Gamepad.DPad_Left,
	ControllerDPadRight = Input.Gamepad.DPad_Right,
	ControllerLeftStickClick = Input.Gamepad.LeftThumbstick,
	ControllerRightStickClick = Input.Gamepad.RightThumbstick,
	Space = Input.Key.Space,
	SpaceBar = Input.Key.Space,
}

function Inputs.parseKeyStr(keyStr: string)
	-- Uh
	if not keyStr or keyStr == "" then
		return nil
	end

	local normalizedKeyStr = tostring(keyStr):gsub("^%s+", ""):gsub("%s+$", "")
	if normalizedKeyStr == "" then
		return nil
	end

	if aliasMap[normalizedKeyStr] then
		return aliasMap[normalizedKeyStr]
	end

	local normalizedLower = string.lower(normalizedKeyStr)
	for alias, value in pairs(aliasMap) do
		if string.lower(alias) == normalizedLower then
			return value
		end
	end

	return Input.Key[normalizedKeyStr] or Input.Gamepad[normalizedKeyStr]
end

function Inputs.drawKeybindCombo(comboId, currentVal)
	-- I tried making a results not found but the gui didnt let me? Do all combo box must only have tabs or lists? Idk
	if Gui.beginCombo(comboId, currentVal == "" and "None" or currentVal) then
		keybindSearchStates[comboId] = keybindSearchStates[comboId] or ""
		keybindFilterStates[comboId] = keybindFilterStates[comboId] or "All"

		Gui.setNextItemWidth(250)
		keybindSearchStates[comboId] = Gui.inputText(Icon.Search .. comboId, keybindSearchStates[comboId])

		Gui.beginTabBar("Filters##" .. comboId)
		if Gui.beginTabItem("All") then
			keybindFilterStates[comboId] = "All"
			Gui.endTabItem()
		end
		for _, category in ipairs(availableKeybindCategories) do
			if Gui.beginTabItem(category.name) then
				keybindFilterStates[comboId] = category.name
				Gui.endTabItem()
			end
		end
		Gui.endTabBar()

		local filter = keybindFilterStates[comboId]
		local search = string.lower(keybindSearchStates[comboId])
		if Gui.beginChild("##KeysList_" .. comboId, 250, 150, true) then
			for _, category in ipairs(availableKeybindCategories) do
				if filter == "All" or filter == category.name then
					for _, key in ipairs(category.keys) do
						if search == "" or string.find(string.lower(key), search, 1, true) then
							if Gui.selectable(key, currentVal == key) then
								currentVal = key
							end
						end
					end
				end
			end
			Gui.endChild()
		end
		Gui.endCombo()
	end
	return currentVal
end

function Inputs.drawConfigKeybind(options)
	local enabled = Gui.checkbox(options.label, config[options.enabledKey])
	if enabled ~= config[options.enabledKey] then
		config[options.enabledKey] = enabled
		if saveConfig then
			saveConfig()
		end
	end

	Gui.sameLine()
	if not enabled then
		Gui.beginDisabled()
	end
	Gui.setNextItemWidth(options.width or 160)
	local key = Inputs.drawKeybindCombo(options.comboId, config[options.keyKey] or options.defaultKey or "")
	if key ~= config[options.keyKey] then
		config[options.keyKey] = key
		if saveConfig then
			saveConfig()
		end
	end
	if not enabled and not options.keepDisabled then
		Gui.endDisabled()
	end

	if Inputs.parseKeyStr(config[options.keyKey]) == nil then
		Gui.sameLine()
		Gui.textDisabled("Invalid key")
	end

	return enabled, key
end

return Inputs
