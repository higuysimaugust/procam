local Replays = {}

config = config or {}
config.replayPauseKeyEnabled = config.replayPauseKeyEnabled ~= nil and config.replayPauseKeyEnabled or false
config.replayPauseKeyStr = config.replayPauseKeyStr or "SpaceBar"
config.replayResetKeyEnabled = config.replayResetKeyEnabled ~= nil and config.replayResetKeyEnabled or false
config.replayResetKeyStr = config.replayResetKeyStr or "B"
config.replayForwardKeyEnabled = config.replayForwardKeyEnabled ~= nil and config.replayForwardKeyEnabled or false
config.replayForwardKeyStr = config.replayForwardKeyStr or "Right"
config.replayBackwardKeyEnabled = config.replayBackwardKeyEnabled ~= nil and config.replayBackwardKeyEnabled or false
config.replayBackwardKeyStr = config.replayBackwardKeyStr or "Left"
config.replayFastForwardSeconds = config.replayFastForwardSeconds or 5
config.replayFastRewindSeconds = config.replayFastRewindSeconds or 5

local availableKeybindCategories = {
	{
		name = "Keyboard",
		keys = {
			"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
			"N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
			"0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
			"F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
			"SpaceBar", "LeftBracket", "RightBracket", "PageUp", "PageDown", "Home", "End", "Insert", "Delete",
			"Up", "Down", "Left", "Right",
			"LeftShift", "RightShift", "LeftControl", "RightControl", "LeftAlt", "RightAlt",
			"Tab", "Enter", "Escape", "Backspace", "Tilde"
		}
	},
	{
		name = "Mouse",
		keys = {
			"MouseLeft", "MouseRight", "MouseMiddle", "MouseSide1", "MouseSide2"
		}
	},
	{
		name = "Controller",
		keys = {
			"ControllerLeftTrigger", "ControllerRightTrigger", "ControllerLeftBumper", "ControllerRightBumper",
			"ControllerFaceUp", "ControllerFaceDown", "ControllerFaceLeft", "ControllerFaceRight",
			"ControllerDPadUp", "ControllerDPadDown", "ControllerDPadLeft", "ControllerDPadRight",
			"ControllerLeftStickClick", "ControllerRightStickClick"
		}
	}
}

local keybindSearchStates = {}
local keybindFilterStates = {}

local function drawKeybindCombo(comboId, currentVal)
	if Gui.beginCombo(comboId, currentVal == "" and "None" or currentVal) then
		keybindSearchStates[comboId] = keybindSearchStates[comboId] or ""
		keybindFilterStates[comboId] = keybindFilterStates[comboId] or "All"

		Gui.setNextItemWidth(250)
		keybindSearchStates[comboId] = Gui.inputText(Icon.Search .. comboId, keybindSearchStates[comboId])

		Gui.beginTabBar("Filters##" .. comboId)
		if Gui.beginTabItem("All") then keybindFilterStates[comboId] = "All"; Gui.endTabItem() end
		if Gui.beginTabItem("Keyboard") then keybindFilterStates[comboId] = "Keyboard"; Gui.endTabItem() end
		if Gui.beginTabItem("Mouse") then keybindFilterStates[comboId] = "Mouse"; Gui.endTabItem() end
		if Gui.beginTabItem("Controller") then keybindFilterStates[comboId] = "Controller"; Gui.endTabItem() end
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

type ReplayState = {
	selected: boolean,
	startTime: number,
}

local replayNoCheckedWarningTimer = 0

local replayStates: { [string]: ReplayState } = {}

local function getReplayState(fileName: string, replay: Replay): ReplayState
	local state = replayStates[fileName]
	if not state then
		state = {
			selected = false,
			startTime = 0,
		}
		replayStates[fileName] = state
	end

	local duration = replay:getDurationSeconds()
	state.startTime = math.max(0, math.min(state.startTime, duration))
	return state
end

local function getLoadedReplays(): { { fileName: string, replay: Replay, state: ReplayState } }
	local loaded = {}
	for index, fileName in ipairs(Replay.listLoaded()) do
		local replay = Replay.getByIndex(index)
		if replay then
			table.insert(loaded, {
				fileName = fileName,
				replay = replay,
				state = getReplayState(fileName, replay),
			})
		end
	end
	return loaded
end

local function parseKeyStr(keyStr)
	if not keyStr or keyStr == "" then
		return nil
	end

	local normalizedKeyStr = tostring(keyStr):gsub("^%s+", ""):gsub("%s+$", "")
	if normalizedKeyStr == "" then
		return nil
	end

	local normalizedLower = string.lower(normalizedKeyStr)
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
	if aliasMap[normalizedKeyStr] then
		return aliasMap[normalizedKeyStr]
	end
	for alias, value in pairs(aliasMap) do
		if string.lower(alias) == normalizedLower then
			return value
		end
	end

	return Input.Key[normalizedKeyStr] or Input.Gamepad[normalizedKeyStr]
end

local function applyToSelected(loaded, callback)
	local hadSelected = false
	for _, entry in ipairs(loaded) do
		if entry.state.selected then
			hadSelected = true
			callback(entry.replay, entry.state)
		end
	end
	if not hadSelected then
		replayNoCheckedWarningTimer = 2.0
	end
end

function Replays.tick(dt)
	if replayNoCheckedWarningTimer > 0 then
		replayNoCheckedWarningTimer = math.max(0, replayNoCheckedWarningTimer - dt)
	end

	local loaded = getLoadedReplays()
	if not loaded or #loaded == 0 then
		return
	end

	if config.replayPauseKeyEnabled then
		local pauseKey = parseKeyStr(config.replayPauseKeyStr)
		if pauseKey and Input.getKeyDown(pauseKey) then
			applyToSelected(loaded, function(replay)
				replay.isPlaying = not replay.isPlaying
			end)
		end
	end

	if config.replayResetKeyEnabled then
		local resetKey = parseKeyStr(config.replayResetKeyStr)
		if resetKey and Input.getKeyDown(resetKey) then
			applyToSelected(loaded, function(replay, state)
				replay:setPlaybackTimeSeconds(state.startTime)
			end)
		end
	end

	if config.replayForwardKeyEnabled then
		local forwardKey = parseKeyStr(config.replayForwardKeyStr)
		if forwardKey and Input.getKeyDown(forwardKey) then
			applyToSelected(loaded, function(replay)
				local now = replay:getPlaybackTimeSeconds()
				replay:setPlaybackTimeSeconds(now + (config.replayFastForwardSeconds or 5))
			end)
		end
	end

	if config.replayBackwardKeyEnabled then
		local backwardKey = parseKeyStr(config.replayBackwardKeyStr)
		if backwardKey and Input.getKeyDown(backwardKey) then
			applyToSelected(loaded, function(replay)
				local now = replay:getPlaybackTimeSeconds()
				replay:setPlaybackTimeSeconds(now - (config.replayFastRewindSeconds or 5))
			end)
		end
	end
end

function Replays.onGui()
	local loaded = getLoadedReplays()

	Gui.textDisabled("Load replays in, then check the replays you need")
	Gui.separatorText("Keybinds")

	config.replayPauseKeyEnabled = Gui.checkbox(Icon.Play .. "  Play/Pause Checked Replays", config.replayPauseKeyEnabled)
	if saveConfig then saveConfig() end
	Gui.sameLine()
	if not config.replayPauseKeyEnabled then
		Gui.beginDisabled()
	end
	Gui.setNextItemWidth(160)
	local newPauseKey = drawKeybindCombo("##ReplayPauseKey", config.replayPauseKeyStr or "SpaceBar")
	if newPauseKey ~= config.replayPauseKeyStr then
		config.replayPauseKeyStr = newPauseKey
		if saveConfig then saveConfig() end
	end
	if not config.replayPauseKeyEnabled then
		Gui.endDisabled()
	end
	if parseKeyStr(config.replayPauseKeyStr) == nil then
		Gui.sameLine()
		Gui.textDisabled("Invalid key")
	end

	config.replayResetKeyEnabled = Gui.checkbox(Icon.Sync .. "  Reset Checked Replays", config.replayResetKeyEnabled)
	if saveConfig then saveConfig() end
	Gui.sameLine()
	if not config.replayResetKeyEnabled then
		Gui.beginDisabled()
	end
	Gui.setNextItemWidth(160)
	local newResetKey = drawKeybindCombo("##ReplayResetKey", config.replayResetKeyStr or "")
	if newResetKey ~= config.replayResetKeyStr then
		config.replayResetKeyStr = newResetKey
		if saveConfig then saveConfig() end
	end
	if not config.replayResetKeyEnabled then
		Gui.endDisabled()
	end
	if parseKeyStr(config.replayResetKeyStr) == nil then
		Gui.sameLine()
		Gui.textDisabled("Invalid key")
	end

	config.replayForwardKeyEnabled = Gui.checkbox(Icon.FastForward .. "  Fast-forward Checked Replays", config.replayForwardKeyEnabled)
	if saveConfig then saveConfig() end
	Gui.sameLine()
	if not config.replayForwardKeyEnabled then
		Gui.beginDisabled()
	end
	Gui.setNextItemWidth(160)
	local newForwardKey = drawKeybindCombo("##ReplayForwardKey", config.replayForwardKeyStr or "")
	if newForwardKey ~= config.replayForwardKeyStr then
		config.replayForwardKeyStr = newForwardKey
		if saveConfig then saveConfig() end
	end
	Gui.sameLine()
	Gui.setNextItemWidth(160)
	local newReplayFastForwardSeconds = Gui.dragFloat("##ReplayForwardAmount", config.replayFastForwardSeconds or 5, 1, 1, 300)
	if newReplayFastForwardSeconds ~= config.replayFastForwardSeconds then
		config.replayFastForwardSeconds = newReplayFastForwardSeconds
		if saveConfig then saveConfig() end
	end
	if not config.replayForwardKeyEnabled then
		Gui.endDisabled()
	end
	if parseKeyStr(config.replayForwardKeyStr) == nil then
		Gui.sameLine()
		Gui.textDisabled("Invalid key")
	end

	config.replayBackwardKeyEnabled = Gui.checkbox(Icon.FastBackward .. "  Rewind Checked Replays", config.replayBackwardKeyEnabled)
	if saveConfig then saveConfig() end
	Gui.sameLine()
	if not config.replayBackwardKeyEnabled then
		Gui.beginDisabled()
	end
	Gui.setNextItemWidth(160)
	local newBackwardKey = drawKeybindCombo("##ReplayBackwardKey", config.replayBackwardKeyStr or "")
	if newBackwardKey ~= config.replayBackwardKeyStr then
		config.replayBackwardKeyStr = newBackwardKey
		if saveConfig then saveConfig() end
	end
	Gui.sameLine()
	Gui.setNextItemWidth(160)
	local newReplayFastRewindSeconds = Gui.dragFloat("##ReplayBackwardAmount", config.replayFastRewindSeconds or 5, 1, 1, 300)
	if newReplayFastRewindSeconds ~= config.replayFastRewindSeconds then
		config.replayFastRewindSeconds = newReplayFastRewindSeconds
		if saveConfig then saveConfig() end
	end
	if not config.replayBackwardKeyEnabled then
		Gui.endDisabled()
	end
	if parseKeyStr(config.replayBackwardKeyStr) == nil then
		Gui.sameLine()
		Gui.textDisabled("Invalid key")
	end

	Gui.newLine()
	Gui.separatorText("Controls")

	if Gui.button(Icon.Check .. "  Check All") then
		for _, entry in ipairs(loaded) do
			entry.state.selected = true
		end
	end
	Gui.sameLine()
	if Gui.button(Icon.Times .. "  Uncheck All") then
		for _, entry in ipairs(loaded) do
			entry.state.selected = false
		end
	end
	Gui.sameLine()
	if Gui.buttonColored(LinearColor.new(1,0,0,1), Icon.Trash .. "  Unload All Replays") then
		Replay.unloadAll()
		replayStates = {}
		return
	end

	Gui.separator()

	local anyPlaying = false
	for _, entry in ipairs(loaded) do
		if entry.state.selected and entry.replay.isPlaying then
			anyPlaying = true
			break
		end
	end
	if Gui.button(anyPlaying and (Icon.Pause .. "  Pause All") or (Icon.Play .. "  Play All")) then
		applyToSelected(loaded, function(replay)
			replay.isPlaying = not replay.isPlaying
		end)
	end
	Gui.sameLine()
	if Gui.button(Icon.Undo .. "  Set Replays Back To Start Time") then
		applyToSelected(loaded, function(replay, state)
			replay:setPlaybackTimeSeconds(state.startTime)
		end)
	end

	Gui.separatorText("Loaded Replays (" .. tostring(#loaded) .. ")")
	if #loaded == 0 then
		Gui.textDisabled("No replays are loaded.")
		return
	end

	if Gui.beginTable("LoadedReplaysTable", 5) then
		Gui.tableSetupColumn("Replay")
		Gui.tableSetupColumn("Start Playback Time")
		Gui.tableSetupColumn("Duration")
		Gui.tableSetupColumn("Current Time")
		Gui.tableSetupColumn("Playing")
		Gui.tableHeadersRow()

		for index, entry in ipairs(loaded) do
			local replay = entry.replay
			local state = entry.state
			local duration = replay:getDurationSeconds()

			Gui.pushId("replay_" .. tostring(index))
			Gui.tableNextRow()
			Gui.tableNextColumn()
			state.selected = Gui.checkbox("##selected", state.selected)
			Gui.sameLine()
			local displayName = entry.fileName:match("([^/\\]+)%.a2replay$") or entry.fileName:gsub("%.a2replay$", "")
			Gui.text(displayName)

			Gui.tableNextColumn()
			Gui.setNextItemWidth(140)
			state.startTime = Gui.dragFloat("##startTime", state.startTime, 0.1, 0, duration)

			Gui.tableNextColumn()
			Gui.text(string.format("%.2f s", duration))

			Gui.tableNextColumn()
			Gui.text(string.format("%.2f s", replay:getPlaybackTimeSeconds()))

			Gui.tableNextColumn()
			Gui.text(replay.isPlaying and Icon.Play or Icon.Pause)
			Gui.popId()
		end

		Gui.endTable()
	end

	if replayNoCheckedWarningTimer > 0 then
		Gui.textDisabled("No replays are checked")
	end
end

return Replays
