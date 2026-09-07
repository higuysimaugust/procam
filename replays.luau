local Replays = {}

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

local function applyToSelected(loaded, callback)
	for _, entry in ipairs(loaded) do
		if entry.state.selected then
			callback(entry.replay, entry.state)
		end
	end
end

function Replays.onGui()
	local loaded = getLoadedReplays()

	Gui.textDisabled("Load replays in, then check the replays you need")
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
