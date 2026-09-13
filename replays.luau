local Replays = {}

config = config or {}
config.replayPauseKeyEnabled = config.replayPauseKeyEnabled ~= nil and config.replayPauseKeyEnabled or false
config.replayPauseKeyStr = config.replayPauseKeyStr or "Space"
config.replayResetKeyEnabled = config.replayResetKeyEnabled ~= nil and config.replayResetKeyEnabled or false
config.replayResetKeyStr = config.replayResetKeyStr or "B"
config.replayForwardKeyEnabled = config.replayForwardKeyEnabled ~= nil and config.replayForwardKeyEnabled or false
config.replayForwardKeyStr = config.replayForwardKeyStr or "Right"
config.replayBackwardKeyEnabled = config.replayBackwardKeyEnabled ~= nil and config.replayBackwardKeyEnabled or false
config.replayBackwardKeyStr = config.replayBackwardKeyStr or "Left"
config.replayFastForwardSeconds = config.replayFastForwardSeconds or 5
config.replayFastRewindSeconds = config.replayFastRewindSeconds or 5

type ReplayState = {
	selected: boolean,
	startTime: number,
}

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
		Space = Input.Key.Space,
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
	for _, entry in ipairs(loaded) do
		if entry.state.selected then
			callback(entry.replay, entry.state)
		end
	end
end

function Replays.tick(dt)
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

	config.replayPauseKeyEnabled = Gui.checkbox("Pause / Unpause checked replays", config.replayPauseKeyEnabled)
	Gui.sameLine()
	if not config.replayPauseKeyEnabled then
		Gui.beginDisabled()
	end
	Gui.setNextItemWidth(160)
	local newPauseKey = Gui.inputText("##ReplayPauseKey", config.replayPauseKeyStr or "Space")
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

	config.replayResetKeyEnabled = Gui.checkbox("Set checked replays back to start", config.replayResetKeyEnabled)
	Gui.sameLine()
	if not config.replayResetKeyEnabled then
		Gui.beginDisabled()
	end
	Gui.setNextItemWidth(160)
	local newResetKey = Gui.inputText("##ReplayResetKey", config.replayResetKeyStr or "")
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

	config.replayForwardKeyEnabled = Gui.checkbox("Fast-forward checked replays forward", config.replayForwardKeyEnabled)
	Gui.sameLine()
	if not config.replayForwardKeyEnabled then
		Gui.beginDisabled()
	end
	Gui.setNextItemWidth(160)
	local newForwardKey = Gui.inputText("##ReplayForwardKey", config.replayForwardKeyStr or "")
	if newForwardKey ~= config.replayForwardKeyStr then
		config.replayForwardKeyStr = newForwardKey
		if saveConfig then saveConfig() end
	end
	Gui.sameLine()
	Gui.setNextItemWidth(160)
	config.replayFastForwardSeconds = Gui.dragFloat("##ReplayForwardAmount", config.replayFastForwardSeconds or 5, 1, 1, 300)
	if not config.replayForwardKeyEnabled then
		Gui.endDisabled()
	end
	if parseKeyStr(config.replayForwardKeyStr) == nil then
		Gui.sameLine()
		Gui.textDisabled("Invalid key")
	end

	config.replayBackwardKeyEnabled = Gui.checkbox("Fast-forward checked replays back", config.replayBackwardKeyEnabled)
	Gui.sameLine()
	if not config.replayBackwardKeyEnabled then
		Gui.beginDisabled()
	end
	Gui.setNextItemWidth(160)
	local newBackwardKey = Gui.inputText("##ReplayBackwardKey", config.replayBackwardKeyStr or "")
	if newBackwardKey ~= config.replayBackwardKeyStr then
		config.replayBackwardKeyStr = newBackwardKey
		if saveConfig then saveConfig() end
	end
	Gui.sameLine()
	Gui.setNextItemWidth(160)
	config.replayFastRewindSeconds = Gui.dragFloat("##ReplayBackwardAmount", config.replayFastRewindSeconds or 5, 1, 1, 300)
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
	if Gui.button(Icon.Play .. "  Play All") then
		applyToSelected(loaded, function(replay)
			replay.isPlaying = true
		end)
	end

	if Gui.button(Icon.Undo .. "  Set Replays Back To Start Time") then
		applyToSelected(loaded, function(replay, state)
			replay:setPlaybackTimeSeconds(state.startTime)
		end)
	end
	Gui.sameLine()
	if Gui.button(Icon.Trash .. "  Unload All Replays") then
		Replay.unloadAll()
		replayStates = {}
		return
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
			Gui.text(entry.fileName:sub(-28))

			Gui.tableNextColumn()
			Gui.setNextItemWidth(140)
			state.startTime = Gui.dragFloat("##startTime", state.startTime, 0.1, 0, duration)

			Gui.tableNextColumn()
			Gui.text(string.format("%.2f s", duration))

			Gui.tableNextColumn()
			Gui.text(string.format("%.2f s", replay:getPlaybackTimeSeconds()))

			Gui.tableNextColumn()
			Gui.text(replay.isPlaying and "Playing" or "Paused")
			Gui.popId()
		end

		Gui.endTable()
	end
end

return Replays
