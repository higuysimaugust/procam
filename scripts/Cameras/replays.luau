-- Idea from myguy and mrcheese, kudos to em

local Replays = {}
local Inputs = require("../More/inputs")
local parseKeyStr = Inputs.parseKeyStr

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

type ReplayState = {
	selected: boolean,
	startTime: number,
}

local replayNoCheckedWarningTimer = 0

local replayStates: { [string]: ReplayState } = {}

local function getReplayState(stateId: string, replay: Replay): ReplayState
	-- fix to actually have all filenames unique
	local state = replayStates[stateId]
	if not state then
		state = {
			selected = false,
			startTime = 0,
		}
		replayStates[stateId] = state
	end

	local duration = replay:getDurationSeconds()
	state.startTime = math.max(0, math.min(state.startTime, duration))
	return state
end

local function getLoadedReplays(): { { fileName: string, replay: Replay, state: ReplayState } }
	-- wait no this is the fixx here
	local loaded = {}
	local nameOccurrences = {}
	for index, fileName in ipairs(Replay.listLoaded()) do
		local replay = Replay.getByIndex(index)
		if replay then
			nameOccurrences[fileName] = (nameOccurrences[fileName] or 0) + 1
			local stateId = fileName .. "\0" .. tostring(nameOccurrences[fileName])
			table.insert(loaded, {
				fileName = fileName,
				replay = replay,
				state = getReplayState(stateId, replay),
			})
		end
	end
	return loaded
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

	Inputs.drawConfigKeybind({
		label = Icon.Play .. "  Play/Pause Checked Replays",
		enabledKey = "replayPauseKeyEnabled",
		keyKey = "replayPauseKeyStr",
		comboId = "##ReplayPauseKey",
		defaultKey = "SpaceBar",
	})

	Inputs.drawConfigKeybind({
		label = Icon.Sync .. "  Reset Checked Replays",
		enabledKey = "replayResetKeyEnabled",
		keyKey = "replayResetKeyStr",
		comboId = "##ReplayResetKey",
	})

	Inputs.drawConfigKeybind({
		label = Icon.FastForward .. "  Fast-forward Checked Replays",
		enabledKey = "replayForwardKeyEnabled",
		keyKey = "replayForwardKeyStr",
		comboId = "##ReplayForwardKey",
		keepDisabled = true,
	})
	Gui.sameLine()
	Gui.setNextItemWidth(160)
	local newReplayFastForwardSeconds =
		Gui.dragFloat("##ReplayForwardAmount", config.replayFastForwardSeconds or 5, 1, 1, 300)
	if newReplayFastForwardSeconds ~= config.replayFastForwardSeconds then
		config.replayFastForwardSeconds = newReplayFastForwardSeconds
		if saveConfig then
			saveConfig()
		end
	end
	if not config.replayForwardKeyEnabled then
		Gui.endDisabled()
	end
	Inputs.drawConfigKeybind({
		label = Icon.FastBackward .. "  Rewind Checked Replays",
		enabledKey = "replayBackwardKeyEnabled",
		keyKey = "replayBackwardKeyStr",
		comboId = "##ReplayBackwardKey",
		keepDisabled = true,
	})
	Gui.sameLine()
	Gui.setNextItemWidth(160)
	local newReplayFastRewindSeconds =
		Gui.dragFloat("##ReplayBackwardAmount", config.replayFastRewindSeconds or 5, 1, 1, 300)
	if newReplayFastRewindSeconds ~= config.replayFastRewindSeconds then
		config.replayFastRewindSeconds = newReplayFastRewindSeconds
		if saveConfig then
			saveConfig()
		end
	end
	if not config.replayBackwardKeyEnabled then
		Gui.endDisabled()
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
	if Gui.buttonColored(LinearColor.new(1, 0, 0, 1), Icon.Trash .. "  Unload All Replays") then
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
