local Inputs = require("inputs")
local Util = require("util")
local Emotes = require("emotes")
local Models = require("models")
local Axis = require("axis")

config = config or {}

local moveSpeed = config.moveSpeed or 1600
local mouseSensitivity = config.mouseSensitivity or 3.6
local collisionEnabled = config.collisionEnabled
if collisionEnabled == nil then collisionEnabled = false end
local collisionRadius = 100
local gravityChaser = gravity.upRotation
local tabTitleMode = config.tabTitleMode or "icon+name"
local showModelsTab = config.showModelsTab
if showModelsTab == nil then showModelsTab = true end
config.showAxisDebug = config.showAxisDebug ~= nil and config.showAxisDebug or false
Inputs.enableSpaceKeybind = config.enableSpaceKeybind ~= nil and config.enableSpaceKeybind or false
if config.alignToGravity == nil then config.alignToGravity = true end
Inputs.alignToGravity = config.alignToGravity
if config.localMovementAxesDefault == nil then config.localMovementAxesDefault = true end
Inputs.localMovementAxesDefault = config.localMovementAxesDefault
Inputs.speedAdjustmentRate = config.speedAdjustmentRate or Inputs.speedAdjustmentRate
Inputs.lookSmoothness = config.lookSmoothness or Inputs.lookSmoothness
Inputs.smoothing = config.smoothing ~= nil and config.smoothing or false
Inputs.playGoalExplosions = config.playGoalExplosions ~= nil and config.playGoalExplosions or false
Inputs.playScraprunSpinners = config.playScraprunSpinners ~= nil and config.playScraprunSpinners or false
if config.placeBallEnabled == nil then config.placeBallEnabled = true end
Inputs.placeBallEnabled = config.placeBallEnabled
Inputs.ballScaleMultiplier = config.ballScaleMultiplier or Inputs.ballScaleMultiplier
if config.showNameTags == nil then config.showNameTags = camera.showNameTags end
camera.showNameTags = config.showNameTags
local mutedPlayers = {}

local screenshotWidth = config.screenshotWidth or 1920
local screenshotHeight = config.screenshotHeight or 1080
local screenshotSuccessTimer = 0

local enableScreenshotKey = config.enableScreenshotKey
if enableScreenshotKey == nil then
		enableScreenshotKey = config.useF9Screenshot
		if enableScreenshotKey == nil then enableScreenshotKey = true end
end
local screenshotKeyStr = config.screenshotKeyStr or "F9"

local enableFreecamKey = config.enableFreecamKey ~= nil and config.enableFreecamKey or false
local freecamKeyStr = config.freecamKeyStr or "LeftBracket"

local enableHandcamKey = config.enableHandcamKey ~= nil and config.enableHandcamKey or false
local handcamKeyStr = config.handcamKeyStr or "RightBracket"

local enableEmoteToggleKey = config.enableEmoteToggleKey
if enableEmoteToggleKey == nil then
		enableEmoteToggleKey = config.toggleWinkEmote
		if enableEmoteToggleKey == nil then enableEmoteToggleKey = true end
end
local emoteToggleKeyStr = config.emoteToggleKeyStr or "L"
local emoteToggleId = config.emoteToggleId or 9

local enableTeleportKey = config.enableTeleportKey
if enableTeleportKey == nil then
		enableTeleportKey = config.enableSpaceKeybind
		if enableTeleportKey == nil then enableTeleportKey = true end
end
local teleportKeyStr = config.teleportKeyStr or "PageUp"
local teleportMapType = config.teleportMapType or "Orion"
local teleportName = config.teleportName or "Club District"

local enableDisconnectKey = config.enableDisconnectKey ~= nil and config.enableDisconnectKey or false
local disconnectKeyStr = config.disconnectKeyStr or "R"
local ownerName = config.ownerName or "Playername"
config.ownerName = ownerName

local function parseKeyStr(keyStr: string)
	if not keyStr or keyStr == "" then
		return nil
	end
	if string.find(keyStr, "Mouse") then
		return nil
	end
	return Input.Key[keyStr]
end

local emoteLabels = {
	[0] = { "None" },
	[1] = { "+" },
	[2] = { "-" },
	[3] = { "->", "-->" },
	[4] = { "<-", "<--" },
	[5] = { "^", "^^" },
	[6] = { "v", "vv" },
	[7] = { "o_o", "o_o.", "o_o;" },
	[8] = { "x_x", "x_X" },
	[9] = { "^-^", "^_-", "-_-" },
	[10] = { "<_<", ">_>" }
}

local emoteNames = {
	[0] = "None",
	[1] = "Affirmative",
	[2] = "Negative",
	[3] = "Left",
	[4] = "Right",
	[5] = "Up",
	[6] = "Down",
	[7] = "Wave",
	[8] = "XX",
	[9] = "Wink",
	[10] = "Suspicious",
}

local currentEmoteTimer = 0
local currentEmoteFrame = 1

camera.fieldOfView = 90

local function triggerScreenshot()
	Screenshot.takeScreenshot(screenshotWidth, screenshotHeight)
	screenshotSuccessTimer = 3.0
end

type CameraTransform = {
	position: Vec3,
	rotation: Quat,
	fieldOfView: number,
}
local startLocations: { [string]: { [string]: CameraTransform } } = {
    Orion = {
        ["Driftball District"] = { position = Vec3.new(0, -3000, -27000), rotation = Quat.fromEuler(0, 0, 90), fieldOfView = 90 },
        ["Sparks Supplies"] = { position = Vec3.new(-3616.6, 2623.2, -28411.3), rotation = Quat.fromEuler(0.0, -0.8, 179.7), fieldOfView = 90.0 },
		["Mainframe"] = { position = Vec3.new(-786.7, 2476.6, -29148.3), rotation = Quat.fromEuler(0.0, -2.1, 31.3), fieldOfView = 80.0 },
		["Plaza West"] = { position = Vec3.new(2752.6, 18540.0, -29478.3), rotation = Quat.fromEuler(-0.0, -2.0, -0.7), fieldOfView = 80.0 },
		["Plaza East"] = { position = Vec3.new(-2629.0, 18576.3, -29338.3), rotation = Quat.fromEuler(-0.0, -2.5, -179.5), fieldOfView = 80.0 },
		["Prime"] = { position = Vec3.new(5.7, 25270.0, -27899.1), rotation = Quat.fromEuler(0.0, -0.9, 90.4), fieldOfView = 80.0 },
		["4v4 West"] = { position = Vec3.new(-14160.8, 27898.6, -23246.5), rotation = Quat.fromEuler(28.5, -4.9, -89.6), fieldOfView = 90.0 },
        ["4v4 East"] = { position = Vec3.new(13688.8, 28096.6, -23525.5), rotation = Quat.fromEuler(-30.1, -4.9, -89.6), fieldOfView = 90.0 },
        ["Fieldhouse"] = { position = Vec3.new(46.5, 22785.3, -29127.5), rotation = Quat.fromEuler(0.0, -5.6, 91.1), fieldOfView = 90.0 },
        ["Club District"] = { position = Vec3.new(24000, 1000, 14000), rotation = Quat.fromEuler(0, 0, 90), fieldOfView = 90 },
        ["Sparks Supplies"] = { position = Vec3.new(22868.9, 6266.6, 17292.1), rotation = Quat.fromEuler(179.3, 60.1, 179.2), fieldOfView = 90.0 },
		["Mainframe"] = { position = Vec3.new(25653.1, 2461.7, 13850.4), rotation = Quat.fromEuler(137.6, 49.9, 129.0), fieldOfView = 75.0 },
		["Volleyfall"] = { position = Vec3.new(22496.1, 12093.4, 18064.3), rotation = Quat.fromEuler(129.4, -37.8, 63.2), fieldOfView = 75.0 },
		["Z-Drift Plaza"] = { position = Vec3.new(6448.4, 6560.7, 3734.8), rotation = Quat.fromEuler(-120.3, 0.5, -89.4), fieldOfView = 90.0 },
		["Alpha"] = { position = Vec3.new(8734.7, -5412.5, -2669.4), rotation = Quat.fromEuler(-60.2, 0.7, -90.5), fieldOfView = 90.0 },
		["Beta"] = { position = Vec3.new(7571.8, -5406.4, 4377.9), rotation = Quat.fromEuler(-120.3, -0.6, -90.2), fieldOfView = 90.0 },
		["Gamma"] = { position = Vec3.new(2049.0, -5450.9, 8889.3), rotation = Quat.fromEuler(179.7, -1.6, -90.4), fieldOfView = 90.0 },
		["Cargo Bay"] = { position = Vec3.new(133.7, 8087.4, -7414.6), rotation = Quat.fromEuler(0.5, -2.5, -90.2), fieldOfView = 90.0 },
		["Z-Draft"] = { position = Vec3.new(-6797.9, 8024.8, 4058.9), rotation = Quat.fromEuler(120.0, -2.0, -89.5), fieldOfView = 90.0 },
		["Parkour District"] = { position = Vec3.new(-24150, 1457, 14100), rotation = Quat.fromEuler(0, 0, 90), fieldOfView = 90 },
        ["Scraprun"] = { position = Vec3.new(-16857.9, 7397.9, 29016.7), rotation = Quat.fromEuler(-150.0, 1.4, 91.2), fieldOfView = 90.0 },
        ["DRAFT District"] = { position = Vec3.new(186.2, 1769.9, 28125.7), rotation = Quat.fromEuler(-179.3, 1.4, 91.2), fieldOfView = 90.0 },
        ["DRAFT Underground"] = { position = Vec3.new(83.3, 3755.6, 29812.3), rotation = Quat.fromEuler(180.0, 3.0, 91.3), fieldOfView = 75.0 },
		["The Spine"] = { position = Vec3.new(-0.0, -0.0, 0.0), rotation = Quat.fromEuler(0.0, -0.0, 0.0), fieldOfView = 90.0 },
        ["Driftblitz"] = { position = Vec3.new(27009.3, 5353.3, -211.0), rotation = Quat.fromEuler(90.0, -0.4, 85.5), fieldOfView = 90.0 },
        ["Baseball"] = { position = Vec3.new(13899.7, 1254.5, 24347.8), rotation = Quat.fromEuler(149.9, -0.4, 85.5), fieldOfView = 90.0 },
        ["Club Fieldhouse"] = { position = Vec3.new(23232.2, 28749.7, 16914.5), rotation = Quat.fromEuler(-179.5, -53.9, -0.5), fieldOfView = 90.0 },
		["Space"] = { position = Vec3.new(-373165.7, -3660.2, -314114.9), rotation = Quat.fromEuler(-0.0, -0.0, 0.0), fieldOfView = 90.0 },
	},
    Ares = {
        ["Ares Plaza"] = { position = Vec3.new(2215.4, -5997.9, 132.4), rotation = Quat.fromEuler(0, 0, -180), fieldOfView = 90 },
		["Alpha 03"] = { position = Vec3.new(-14.8, -17975.0, -8070.0), rotation = Quat.fromEuler(0, 0, -1), fieldOfView = 90 },
		["Alpha 02"] = { position = Vec3.new(-17.2, -5940.6, -7962.8), rotation = Quat.fromEuler(0, 0, -1), fieldOfView = 90 },
		["Alpha 01"] = { position = Vec3.new(-19.6, 5977.0, -8087.2), rotation = Quat.fromEuler(0, 0, -1), fieldOfView = 90 },
		["Beta 03"] = { position = Vec3.new(6993.7, -18012.6, 4014.6), rotation = Quat.fromEuler(1, -1, -0), fieldOfView = 90 },
		["Beta 02"] = { position = Vec3.new(7000.7, -5987.9, 4049.0), rotation = Quat.fromEuler(1, -1, -0), fieldOfView = 90 },
		["Beta 01"]= { position = Vec3.new(6964.6, 6062.1, 4028.4), rotation = Quat.fromEuler(1, -1, -0), fieldOfView = 90 },
		["Gamma 03"]= {position = Vec3.new(-6992.7, -17947.0, 4031.9), rotation = Quat.fromEuler(-1, 1, -0), fieldOfView = 90 },
		["Gamma 02"]= { position = Vec3.new(-7001.6, -5993.0, 4024.1), rotation = Quat.fromEuler(-1, 1, -0), fieldOfView = 90 },
		["Gamma 01"]= {position = Vec3.new(-6985.0, 5999.7, 4031.8), rotation = Quat.fromEuler(-1, 1, -0), fieldOfView = 90 },	
		["Space"] = { position = Vec3.new(150800.7, 94700.2, -62450.9), rotation = Quat.fromEuler(-0.0, -0.0, 0.0), fieldOfView = 90.0 },
	},
    Shuttle = {
        ["Shuttle"] = { position = Vec3.new(1325, 15, 84), rotation = Quat.fromEuler(0, -5, -53), fieldOfView = 90 },
    },
}
local orionLocationGroups = {
    {
        title = "Driftball District",
        labels = { "Driftball District", "Sparks Supplies", "Mainframe", "Plaza West", "Plaza East", "Prime", "4v4 West", "4v4 East" },
    },
    
    {
        title = "Parkour District",
        labels = { "Parkour District", "Scraprun", "DRAFT District", "DRAFT Underground" },
    },
	{
        title = "Orion",
        labels = { "Space" },
    }
}

local orionLocationGroups2 = {
    {
        title = "Club District",
        labels = { "Club District", "Sparks Supplies", "Mainframe", "Volleyfall", "Fieldhouse", "Baseball", "Driftblitz" },
    },
	{
		title = "Z-Drift",
		labels = { "Z-Drift Plaza", "Cargo Bay", "Alpha", "Beta", "Gamma", "Z-Draft" }
	}
}

local aresLocationGroups = {
    {
        title = "Ares",
        labels = { "Ares Plaza", "Space" },
    },
    {
        title = "Alpha",
        labels = { "Alpha 01", "Alpha 02", "Alpha 03" },
    },
    {
        title = "Beta",
        labels = { "Beta 01", "Beta 02", "Beta 03" },
    },
	{
        title = "Gamma",
        labels = { "Gamma 01", "Gamma 02", "Gamma 03" },
    },
}

local function detectMapType()
    if not SpectatorGamemodes or not SpectatorGamemodes.listGamemodeIds then
        return "Orion"
    end

    local gamemodes = SpectatorGamemodes.listGamemodeIds()
    if #gamemodes == 0 then
        return "Shuttle"
    end

    for _, gamemode in ipairs(gamemodes) do
        if gamemode:find("scraprun") or gamemode:find("TKB_") then
            return "Orion"
        elseif gamemode:find("Gamma 0") or gamemode:find("Beta 0") or gamemode:find("Alpha 0") then
            return "Ares"
        end
    end

    return "Orion"
end

local function drawLocationCombo(comboId, selectedMapType, selectedName)
    if Gui.beginCombo(comboId, selectedName) then
        local function drawMapType(MapTypeName, groups)
            if Gui.collapsingHeader(MapTypeName) then
                local firstGroup = true
                for _, group in ipairs(groups) do
                    if not firstGroup then
                        Gui.separator()
                    end
                    firstGroup = false

                    for _, locationName in ipairs(group.labels) do
                        if startLocations[MapTypeName][locationName] and Gui.selectable(locationName, selectedMapType == MapTypeName and selectedName == locationName) then
                            selectedMapType = MapTypeName
                            selectedName = locationName
                        end
                    end
                end
            end
        end

        drawMapType("Orion", orionLocationGroups)
        drawMapType("Orion", orionLocationGroups2)
        drawMapType("Ares", aresLocationGroups)
        if Gui.collapsingHeader("Shuttle##teleport") then
            if startLocations.Shuttle and startLocations.Shuttle.Shuttle and Gui.selectable("Shuttle", selectedMapType == "Shuttle" and selectedName == "Shuttle") then
                selectedMapType = "Shuttle"
                selectedName = "Shuttle"
            end
        end

        Gui.endCombo()
    end
    return selectedMapType, selectedName
end

local defaultSpawnMapType = config.defaultSpawnMapType or "Orion"
local defaultSpawnName = config.defaultSpawnName or "Driftball District"
local startLocation = startLocations[defaultSpawnMapType] and startLocations[defaultSpawnMapType][defaultSpawnName]
if not startLocation then
    startLocation = startLocations.Orion["Driftball District"]
end

local pendingGravitySnap = false

local playerSearchText = ""
local selectedPlayerTarget = nil
local followSpectatorEnabled = false
local selectedSpectatorName = ""
local spectatorSearchText = ""
local spectatorList = {}
local debugLocationName = "New Location"
local showLocationWriter = config.showLocationWriter or false

local emoteCycling = config.emoteCycling ~= nil and config.emoteCycling or false
local lastEmoteCycleTime = 0
local emoteCycleInterval = config.emoteCycleInterval or 1.0
local timer = 0

local flipActive = false
local flipDirection = 1
local flipTimer = 0
local flipDuration = 0.5

local ntimer = 0
local ndelay = 0.01

local function snapToGravity()
	gravityChaser = gravity.upRotation
	Inputs.rotEuler.x = 0
end

local function goToLocation(transform: CameraTransform)
	Inputs.rotEuler = transform.rotation:euler()
	Inputs.rotEuler.x = 0
	camera.position = transform.position
	camera.rotation = transform.rotation
	camera.fieldOfView = transform.fieldOfView
	snapToGravity()
	pendingGravitySnap = true
	ntimer = 0
end

local function formatLocationLine(locationName: string, pos: Vec3, rot: Quat, fov: number): string
	local euler = rot:euler()
	return string.format('		["%s"] = { position = Vec3.new(%.1f, %.1f, %.1f), rotation = Quat.fromEuler(%.1f, %.1f, %.1f), fieldOfView = %.1f },',
		locationName, pos.x, pos.y, pos.z, euler.x, euler.y, euler.z, fov)
end

local function getTabTitle(icon: string, name: string)
	if tabTitleMode == "name" then
		return name
	elseif tabTitleMode == "icon" then
		return icon
	end
	return icon .. "  " .. name
end

function onTransitionBegin(transitionInfo: Transition)
	if Inputs.firstTransition then
		transitionInfo.length = 10
		goToLocation(startLocation)
	else
		goToLocation({
			position = transitionInfo.startPosition,
			rotation = transitionInfo.startRotation,
			fieldOfView = transitionInfo.startFieldOfView,
		})
	end
	Inputs.firstTransition = false
	Util.setSmoothing(Inputs.smoothing, Inputs)
	Models.onTransitionBegin()
end

local serverName = "Offline"

do
	local ok, result = pcall(Network.getCurrentServer)
	if ok and type(result) == "string" and result ~= "" and result:lower() ~= "unknown" then
		serverName = result
	end
end

function onGui()
	local activeCam = "Freecam"
	if Axis.isEnabled then
		activeCam = "Handcam"
	end
	if followSpectatorEnabled then
		activeCam = "Spectator Follow"
	end

	Gui.text("Using " .. activeCam)

	local serverPlayerCount = 0
	local serverSessions = getAllGameData and getAllGameData() or (getGameData and { getGameData() } or {})
	for _, session in ipairs(serverSessions) do
		if session and session.players then
			for _, playerInfo in ipairs(session.players) do
				if playerInfo and playerInfo.playerId then
					local player = session.getPlayerById and session:getPlayerById(playerInfo.playerId) or playerInfo
					if player and player.playerName then
						serverPlayerCount += 1
					end
				end
			end
		end
	end
	local serverGameData = getGameData and getGameData()
	local serverSpectatorCount = serverGameData and serverGameData.spectators and #serverGameData.spectators or 0
	local spectatorLabel = serverSpectatorCount == 1 and "Spectator" or "Spectators"
	Gui.sameLine()
	Gui.textDisabled(serverName .. "   |   " .. Icon.Users .. "  " .. tostring(serverPlayerCount) .. " Players   |   " .. Icon.Eye .. "  " .. tostring(serverSpectatorCount) .. " " .. spectatorLabel)

	Gui.beginTabBar("FreecamTabs")

	if Gui.beginTabItem(getTabTitle(Icon.Home, "Home")) then
		Gui.separatorText("Quick Settings")

		local newShowNameTags = Gui.checkbox("Show name tags", camera.showNameTags)
		if newShowNameTags ~= camera.showNameTags then
			camera.showNameTags = newShowNameTags
			config.showNameTags = newShowNameTags
			if saveConfig then saveConfig() end
		end
		local newAlignToGravity = Gui.checkbox("Automatically Align to Gravity", Inputs.alignToGravity)
		if newAlignToGravity ~= Inputs.alignToGravity then
			Inputs.alignToGravity = newAlignToGravity
			config.alignToGravity = newAlignToGravity
			if saveConfig then saveConfig() end
		end
		local newSmoothing = Gui.checkbox("Enable Smoothing##smoothingCheckbox", Inputs.smoothing)
		local newLocalMovementAxes = Gui.checkbox("Use Local Movement Axes", Inputs.localMovementAxesDefault)
		if newLocalMovementAxes ~= Inputs.localMovementAxesDefault then
			Inputs.localMovementAxesDefault = newLocalMovementAxes
			config.localMovementAxesDefault = newLocalMovementAxes
			if saveConfig then saveConfig() end
		end
		Gui.setItemTooltip("Use Alt to switch between gravity and local movement axes")

		Gui.separatorText("Movement")

		local newMoveSpeed = Gui.sliderFloat("Move Speed", moveSpeed, Inputs.minMoveSpeed, Inputs.maxMoveSpeed)
		if newMoveSpeed ~= moveSpeed then
			moveSpeed = newMoveSpeed
			config.moveSpeed = newMoveSpeed
			if saveConfig then saveConfig() end
		end
		local newMouseSensitivity = Gui.sliderFloat("Mouse Sensitivity", mouseSensitivity, 0, 10)
		if newMouseSensitivity ~= mouseSensitivity then
			mouseSensitivity = newMouseSensitivity
			config.mouseSensitivity = newMouseSensitivity
			if saveConfig then saveConfig() end
		end
		local newSpeedAdjustmentRate = Gui.sliderFloat("Speed Acceleration", Inputs.speedAdjustmentRate, 0, 5)
		if newSpeedAdjustmentRate ~= Inputs.speedAdjustmentRate then
			Inputs.speedAdjustmentRate = newSpeedAdjustmentRate
			config.speedAdjustmentRate = newSpeedAdjustmentRate
			if saveConfig then saveConfig() end
		end
		Gui.setItemTooltip("How fast the speed adjustment buttons affect the camera speed")

		if not Inputs.smoothing then
			Gui.beginDisabled()
		end
		local newLookSmoothness = Gui.sliderFloat("Smoothness", Inputs.lookSmoothness, 0, 1)
		if not Inputs.smoothing then
			Gui.endDisabled()
		end
		if newSmoothing ~= Inputs.smoothing then
			Inputs.smoothing = newSmoothing
			config.smoothing = newSmoothing
			Util.setSmoothing(Inputs.smoothing, Inputs)
			if saveConfig then saveConfig() end
		end
		if newLookSmoothness ~= Inputs.lookSmoothness then
			Inputs.lookSmoothness = newLookSmoothness
			config.lookSmoothness = newLookSmoothness
			if saveConfig then saveConfig() end
		end
		
		Gui.separatorText("Camera Controls")

		camera.position = Gui.dragFloat3("Position", camera.position, 10, -100000, 100000)
		local newRot = Gui.dragFloat3("Rotation", Inputs.rotEuler, 1, -180, 180)
		Gui.sameLine()
			Gui.textDisabled("roll, pitch, yaw")
		if Gui.isItemActive() then
			gravityChaser = gravity.upRotation
			Inputs.rotEuler = newRot
			camera.rotation = Quat.fromEuler(Inputs.rotEuler.x, Inputs.rotEuler.y, Inputs.rotEuler.z)
		end
		camera.fieldOfView = Gui.sliderFloat("Field of View", camera.fieldOfView, Inputs.minFov, Inputs.maxFov)

		Gui.newLine()

		if Gui.collapsingHeader("Emotes") then	
			Emotes.onGui()

			local currentEmoteId = camera:getEmote() or 0

			Gui.beginChild("homeCurrentEmote", 180, 70, true)
			Gui.text("Current Emote")

			local labels = emoteLabels[currentEmoteId] or { "None" }
			Gui.text(labels[currentEmoteFrame] or labels[1])

			Gui.endChild()
			Gui.sameLine()

			Gui.beginChild("homeEmoteCycling", 180, 70, true)
			Gui.text("Emote Cycling")
			if emoteCycling then
				local remaining = math.max(0, emoteCycleInterval - (timer - lastEmoteCycleTime))
				Gui.text(Icon.Sync .. "  " .. string.format("%.1f", remaining))
			else
				Gui.text("Disabled")
			end
			Gui.endChild()

			local newEmoteCycling = Gui.checkbox("Cycle Emotes", emoteCycling)
			if newEmoteCycling ~= emoteCycling then
				emoteCycling = newEmoteCycling
				config.emoteCycling = emoteCycling
				if saveConfig then saveConfig() end
			end
			Gui.setItemTooltip("Enable cycling through emotes")

			if emoteCycling then
				Gui.sameLine()
                local newEmoteCycleInterval = Gui.sliderFloat("Cycle Rate (s)", emoteCycleInterval, 0.1, 5.0)
				if newEmoteCycleInterval ~= emoteCycleInterval then
					emoteCycleInterval = newEmoteCycleInterval
					config.emoteCycleInterval = emoteCycleInterval
					if saveConfig then saveConfig() end
				end
            end
		end

				if Gui.collapsingHeader("Screenshots") then
			local presetMap = {
				["1K"] = {
					["16:9"] = { 1920, 1080 },
					["9:16"] = { 1080, 1920 },
					["4:3"] = { 1440, 1080 },
					["Ultrawide"] = { 2560, 1080 },
				},
				["2K"] = {
					["16:9"] = { 2560, 1440 },
					["9:16"] = { 1440, 2560 },
					["4:3"] = { 1920, 1440 },
					["Ultrawide"] = { 3440, 1440 },
				},
				["4K"] = {
					["16:9"] = { 3840, 2160 },
					["9:16"] = { 2160, 3840 },
					["4:3"] = { 2880, 2160 },
					["Ultrawide"] = { 5120, 2160 },
				},
			}

			local activeQuality, activeAspect
			for qKey, qAspects in pairs(presetMap) do
				for aKey, res in pairs(qAspects) do
					if screenshotWidth == res[1] and screenshotHeight == res[2] then
						activeQuality = qKey
						activeAspect = aKey
						break
					end
				end
			end

			local targetQuality = activeQuality or "4K"
			local targetAspect = activeAspect or "16:9"

			local function drawOption(label, isActive, onClick)
				if isActive then
					Gui.beginDisabled()
					Gui.button(label)
					Gui.endDisabled()
				else
					if Gui.buttonColored(LinearColor.new(0, 0, 0, 0), label) then
						onClick()
					end
				end
			end

			local qualityList = { "1K", "2K", "4K" }
			for i, q in ipairs(qualityList) do
				if i > 1 then Gui.sameLine() end
				drawOption(q, activeQuality == q, function()
					local res = presetMap[q][targetAspect]
					screenshotWidth, screenshotHeight = res[1], res[2]
					config.screenshotWidth, config.screenshotHeight = screenshotWidth, screenshotHeight
					if saveConfig then saveConfig() end
				end)
			end

			Gui.sameLine()
			Gui.textDisabled("|")
			Gui.sameLine()

			local aspectList = { "16:9", "9:16", "4:3", "Ultrawide" }
			for i, a in ipairs(aspectList) do
				if i > 1 then Gui.sameLine() end
				drawOption(a, activeAspect == a, function()
					local res = presetMap[targetQuality][a]
					screenshotWidth, screenshotHeight = res[1], res[2]
					config.screenshotWidth, config.screenshotHeight = screenshotWidth, screenshotHeight
					if saveConfig then saveConfig() end
				end)
			end

			local currentRes = Vec2.new(screenshotWidth, screenshotHeight)
			local newRes = Gui.dragFloat2("Resolution", currentRes, 10, 100, 7680)
			Gui.sameLine()
			Gui.textDisabled("in pixels")
			local newWidth = math.floor(newRes.x + 0.5)
			local newHeight = math.clamp(math.floor(newRes.y + 0.5), 100, 4320)
			if newWidth ~= screenshotWidth or newHeight ~= screenshotHeight then
				screenshotWidth = newWidth
				screenshotHeight = newHeight
				config.screenshotWidth = screenshotWidth
				config.screenshotHeight = screenshotHeight
				if saveConfig then saveConfig() end
			end

			Gui.separator()

			if Gui.button(Icon.Camera .. "  Take Screenshot") then
				triggerScreenshot()
			end

			if screenshotSuccessTimer > 0 then
				Gui.sameLine()
				Gui.text("Screenshot saved successfully!")
			end
		end

		if Gui.collapsingHeader("Locations") then
			local currentMapType = detectMapType()

			if Gui.beginCombo("##SpawnLocationCombo", defaultSpawnName) then
				if Gui.collapsingHeader("Orion") then
					local firstGroup = true
					local combinedOrion = { orionLocationGroups, orionLocationGroups2 }
					for _, groups in ipairs(combinedOrion) do
						for _, group in ipairs(groups) do
							if not firstGroup then
								Gui.separator()
							end
							firstGroup = false

							for _, locName in ipairs(group.labels) do
								if startLocations.Orion[locName] then
									if Gui.selectable(locName, defaultSpawnName == locName) then
										defaultSpawnMapType = "Orion"
										defaultSpawnName = locName
										config.defaultSpawnMapType = defaultSpawnMapType
										config.defaultSpawnName = defaultSpawnName
										if saveConfig then saveConfig() end
									end
								end
							end
						end
					end
				end

				if Gui.collapsingHeader("Ares") then
					local firstGroup = true

					for _, group in ipairs(aresLocationGroups) do
						if not firstGroup then
							Gui.separator()
						end
						firstGroup = false

						for _, locName in ipairs(group.labels) do
							if startLocations.Ares[locName] then
								if Gui.selectable(locName, defaultSpawnName == locName) then
									defaultSpawnMapType = "Ares"
									defaultSpawnName = locName
									config.defaultSpawnMapType = defaultSpawnMapType
									config.defaultSpawnName = defaultSpawnName
									if saveConfig then saveConfig() end
								end
							end
						end
					end
				end

				if Gui.collapsingHeader("Shuttle##g") then
					if startLocations.Shuttle and startLocations.Shuttle["Shuttle"] then
						if Gui.selectable("Shuttle##tp", defaultSpawnName == "Shuttle") then
							defaultSpawnMapType = "Shuttle"
							defaultSpawnName = "Shuttle"
							config.defaultSpawnMapType = defaultSpawnMapType
							config.defaultSpawnName = defaultSpawnName
							if saveConfig then saveConfig() end
						end
					end
				end

				Gui.endCombo()
			end

			Gui.sameLine()
			Gui.text("Default Spawn")

			if currentMapType == "Ares" then
				Gui.beginChild("ares_column_single", 605, 300, true)
				for idx, group in ipairs(aresLocationGroups) do
					if idx > 1 then
						Gui.separator()
					end
					for _, label in ipairs(group.labels) do
						local location = startLocations.Ares[label]
						if location and Gui.selectable(label, false) then
							goToLocation(location)
						end
					end
				end
				Gui.endChild()
			else
				Gui.beginHorizontal("location_columns")

				Gui.beginChild("orion_column_left", 300, 350, true)
				for idx, group in ipairs(orionLocationGroups) do
					if idx > 1 then
						Gui.separator()
					end
					for _, label in ipairs(group.labels) do
						local location = startLocations.Orion[label]
						if location and Gui.selectable(label, false) then
							goToLocation(location)
						end
					end
				end
				Gui.endChild()

				Gui.beginChild("orion_column_right", 300, 350, true)
				for idx, group in ipairs(orionLocationGroups2) do
					if idx > 1 then
						Gui.separator()
					end
					for _, label in ipairs(group.labels) do
						local location = startLocations.Orion[label]
						if location and Gui.selectable(label, false) then
							goToLocation(location)
						end
					end
				end
				Gui.endChild()

				Gui.endHorizontal()
			end
		end

		if showLocationWriter then
			if Gui.collapsingHeader("Location Writer##debugLocationWriter") then
				Gui.textDisabled("Debug tool to make more locations")
				
				Gui.setNextItemWidth(300)
				debugLocationName = Gui.inputText("##LocationNameInput", debugLocationName)
				Gui.sameLine()
				Gui.textDisabled("Location name")
				
				if Gui.button("Send to logs##captureLocation") then
					local line = formatLocationLine(debugLocationName, camera.position, camera.rotation, camera.fieldOfView)
					print(line)
				end
			end
		end

        Gui.newLine()

		Gui.endTabItem()
	end

	if Gui.beginTabItem(getTabTitle(Icon.Video or Icon.Camera or "", "Handcam")) then
		Axis.onGui()
		Gui.endTabItem()
	end

	if Gui.beginTabItem(getTabTitle(Icon.Cog, "Settings")) then
		if Gui.collapsingHeader("Controls") then
			if Gui.beginTable("ControlsTable", 3) then
				Gui.tableSetupColumn("Action", 0, 0.4)
				Gui.tableSetupColumn("Keyboard & Mouse", 0, 0.3)
				Gui.tableSetupColumn("Controller", 0, 0.3)
				Gui.tableHeadersRow()

				local function addRow(action, keyboard, controller)
					Gui.tableNextRow()
					Gui.tableNextColumn()
					Gui.text(action)
					Gui.tableNextColumn()
					Gui.textDisabled(keyboard or "")
					Gui.tableNextColumn()
					Gui.textDisabled(controller or "")
				end

				addRow("Move", "WASD", "Left Stick")
				addRow("Fly Up or Down", "Q / E", "Triggers")
				addRow("Speed Up", "Left Shift", "Right Shoulder")
				addRow("Slow Down", "Left Control", "Left Shoulder")
				addRow("Pan", "Mouse", "Right Stick")
				addRow("Roll", "Hold Right Click", "D-Pad Left and Right")
				addRow("Reset Roll", "Middle Mouse Click", "Left Stick Click")
				addRow("Align to Gravity", "Spacebar", "Right Stick Click")
				addRow("Frontflip", "Arrow Up", "Y / Face Up")
				addRow("Backflip", "Arrow Down", "A / Face Down")
				addRow("Toggle Smoothing", "Caps Lock", "B / Face Right")
				addRow("Toggle Freecam/Handcam", "--", "X / Face Left")
				addRow("Zoom", "Scrollwheel", "D-Pad Up and Down")

				Gui.endTable()
			end
		end

		Gui.separatorText("Keybinds")
		Gui.textDisabled("Type key names like F9, L, or SpaceBar. Mouse keybinds are not recognized.")

		enableScreenshotKey = Gui.checkbox(Icon.Camera .. "  Screenshot", enableScreenshotKey)
		if enableScreenshotKey ~= config.enableScreenshotKey then
			config.enableScreenshotKey = enableScreenshotKey
			if saveConfig then saveConfig() end
		end
		Gui.sameLine()
		if not enableScreenshotKey then
			Gui.beginDisabled()
		end
		Gui.setNextItemWidth(200)
		local newScreenshotKey = Gui.inputText("##ShotKeyInput", screenshotKeyStr)
		if newScreenshotKey ~= screenshotKeyStr then
			screenshotKeyStr = newScreenshotKey
			config.screenshotKeyStr = screenshotKeyStr
			if saveConfig then saveConfig() end
		end
		if not enableScreenshotKey then
			Gui.endDisabled()
		end
		if parseKeyStr(screenshotKeyStr) == nil then
			Gui.sameLine()
			Gui.textDisabled("Invalid key")
		end

		enableDisconnectKey = Gui.checkbox(Icon.SignOutAlt .. "  Disconnect", enableDisconnectKey)
		Gui.sameLine()
		if not enableDisconnectKey then
			Gui.beginDisabled()
		end
		Gui.setNextItemWidth(200)
		local newDisconnectKey = Gui.inputText("##DisconnectKeyInput", disconnectKeyStr)
		if newDisconnectKey ~= disconnectKeyStr then
			disconnectKeyStr = newDisconnectKey
			config.disconnectKeyStr = disconnectKeyStr
			if saveConfig then saveConfig() end
		end
		if enableDisconnectKey ~= config.enableDisconnectKey then
			config.enableDisconnectKey = enableDisconnectKey
			if saveConfig then saveConfig() end
		end
		if not enableDisconnectKey then
			Gui.endDisabled()
		end
		if parseKeyStr(disconnectKeyStr) == nil then
			Gui.sameLine()
			Gui.textDisabled("Invalid text")
		end

		enableFreecamKey = Gui.checkbox(Icon.CameraRetro .. "  Freecam##EnableFree", enableFreecamKey)
		if enableFreecamKey ~= config.enableFreecamKey then
			config.enableFreecamKey = enableFreecamKey
			if saveConfig then saveConfig() end
		end
		Gui.sameLine()
		if not enableFreecamKey then
			Gui.beginDisabled()
		end
		Gui.setNextItemWidth(200)
		local newFreecamKey = Gui.inputText("##FreeKeyInput", freecamKeyStr)
		if newFreecamKey ~= freecamKeyStr then
			freecamKeyStr = newFreecamKey
			config.freecamKeyStr = freecamKeyStr
			if saveConfig then saveConfig() end
		end
		if not enableFreecamKey then
			Gui.endDisabled()
		end
		if parseKeyStr(freecamKeyStr) == nil then
			Gui.sameLine()
			Gui.textDisabled("Invalid key")
		end

		enableHandcamKey = Gui.checkbox(Icon.User .. "  Handcam##EnableHand", enableHandcamKey)
		if enableHandcamKey ~= config.enableHandcamKey then
			config.enableHandcamKey = enableHandcamKey
			if saveConfig then saveConfig() end
		end
		Gui.sameLine()
		if not enableHandcamKey then
			Gui.beginDisabled()
		end
		Gui.setNextItemWidth(200)
		local newHandcamKey = Gui.inputText("##HandKeyInput", handcamKeyStr)
		if newHandcamKey ~= handcamKeyStr then
			handcamKeyStr = newHandcamKey
			config.handcamKeyStr = handcamKeyStr
			if saveConfig then saveConfig() end
		end
		if not enableHandcamKey then
			Gui.endDisabled()
		end
		if parseKeyStr(handcamKeyStr) == nil then
			Gui.sameLine()
			Gui.textDisabled("Invalid key")
		end

		enableEmoteToggleKey = Gui.checkbox(Icon.Smile .. "  Toggle emote##EnableEmoteToggle", enableEmoteToggleKey)
		Gui.sameLine()
		if not enableEmoteToggleKey then
			Gui.beginDisabled()
		end
		Gui.setNextItemWidth(100)
		local newEmoteToggleKey = Gui.inputText("##EmoteToggleKeyInput", emoteToggleKeyStr)
		if newEmoteToggleKey ~= emoteToggleKeyStr then
			emoteToggleKeyStr = newEmoteToggleKey
			config.emoteToggleKeyStr = emoteToggleKeyStr
			if saveConfig then saveConfig() end
		end
		if enableEmoteToggleKey ~= config.enableEmoteToggleKey then
			config.enableEmoteToggleKey = enableEmoteToggleKey
			if saveConfig then saveConfig() end
		end
		if parseKeyStr(emoteToggleKeyStr) == nil then
			Gui.sameLine()
			Gui.textDisabled("Invalid key")
		end

		Gui.sameLine()
		Gui.setNextItemWidth(200)
		local emoteToggleLabel = emoteNames[emoteToggleId] or emoteNames[9]
		if Gui.beginCombo("Emote", emoteToggleLabel) then
			for id = 0, 10 do
				local label = emoteNames[id]
				if Gui.selectable(label, emoteToggleId == id) then
					emoteToggleId = id
					config.emoteToggleId = emoteToggleId
					if saveConfig then saveConfig() end
				end
			end
			Gui.endCombo()
		end
		if not enableEmoteToggleKey then
			Gui.endDisabled()
		end

		enableTeleportKey = Gui.checkbox(Icon.LocationArrow .. "  Teleport to location##EnableTeleport", enableTeleportKey)
		Gui.sameLine()
		if not enableTeleportKey then
			Gui.beginDisabled()
		end
		Gui.setNextItemWidth(100)
		local newTeleportKey = Gui. inputText("##TeleportKeyInput", teleportKeyStr)
		if newTeleportKey ~= teleportKeyStr then
			teleportKeyStr = newTeleportKey
			config.teleportKeyStr = teleportKeyStr
			if saveConfig then saveConfig() end
		end
		if enableTeleportKey ~= config.enableTeleportKey then
			config.enableTeleportKey = enableTeleportKey
			if saveConfig then saveConfig() end
		end
		if parseKeyStr(teleportKeyStr) == nil then
			Gui.sameLine()
			Gui.textDisabled("Invalid key")
		end

		Gui.sameLine()
		Gui.setNextItemWidth(200)
		local newTeleportMapType, newTeleportName = drawLocationCombo("Location", teleportMapType, teleportName)
		if newTeleportMapType ~= teleportMapType or newTeleportName ~= teleportName then
			teleportMapType = newTeleportMapType
			teleportName = newTeleportName
			config.teleportMapType = teleportMapType
			config.teleportName = teleportName
			if saveConfig then saveConfig() end
		end
		if not enableTeleportKey then
			Gui.endDisabled()
		end

		Gui.newLine()

		Gui.separatorText("Customization")

		local newShowModelsTab = Gui.checkbox("Show Draw tab", showModelsTab)
		if newShowModelsTab ~= showModelsTab then
			showModelsTab = newShowModelsTab
			config.showModelsTab = showModelsTab
			if saveConfig then saveConfig() end
		end

		local tabTitleModeLabel = "Icon + name"
		if tabTitleMode == "name" then
			tabTitleModeLabel = "Name"
		elseif tabTitleMode == "icon" then
			tabTitleModeLabel = "Icon"
		end
		
		if Gui.beginCombo("Tab Item Style", tabTitleModeLabel) then
			if Gui.selectable("Icon + name", tabTitleMode == "icon+name") then
				tabTitleMode = "icon+name"
				config.tabTitleMode = tabTitleMode
				if saveConfig then saveConfig() end
			end
			if Gui.selectable("Name", tabTitleMode == "name") then
				tabTitleMode = "name"
				config.tabTitleMode = tabTitleMode
				if saveConfig then saveConfig() end
			end
			if Gui.selectable("Icon", tabTitleMode == "icon") then
				tabTitleMode = "icon"
				config.tabTitleMode = tabTitleMode
				if saveConfig then saveConfig() end
			end
			Gui.endCombo()
		end

		Gui.newLine()

		Gui.separatorText("Owner")
		Gui.textDisabled("Set yourself as the owner to appear first in player lists and handcam!")

		local newOwnerName = Gui.inputText("Owner", ownerName)
		if newOwnerName ~= ownerName then
			ownerName = newOwnerName
			config.ownerName = ownerName
			config.ownerId = nil
			config.currentPlayerId = nil
			if saveConfig then saveConfig() end
		end

		Gui.newLine()

		Gui.separatorText("Other")

		local newCollisionEnabled = Gui.checkbox("Enable Collisions", collisionEnabled)
		if newCollisionEnabled ~= collisionEnabled then
			collisionEnabled = newCollisionEnabled
			config.collisionEnabled = collisionEnabled
			if saveConfig then saveConfig() end
		end
		local newShowAxisDebug = Gui.checkbox("Show Handcam debug tab", config.showAxisDebug)
		if newShowAxisDebug ~= config.showAxisDebug then
			config.showAxisDebug = newShowAxisDebug
			if saveConfig then saveConfig() end
		end

		local newShowLocationWriter = Gui.checkbox("Show Location Writer##debugShowLocationWriter", showLocationWriter)
		if newShowLocationWriter ~= showLocationWriter then
			showLocationWriter = newShowLocationWriter
			config.showLocationWriter = showLocationWriter
			if saveConfig then saveConfig() end
		end

		local newGoalExplosions = Gui.checkbox("Goal explosions", Inputs.playGoalExplosions)
		if newGoalExplosions ~= Inputs.playGoalExplosions then
			Inputs.playGoalExplosions = newGoalExplosions
			config.playGoalExplosions = newGoalExplosions
			spectatorDebug.goalExplosions = Inputs.playGoalExplosions
			if saveConfig then saveConfig() end
		end

		local newScraprunSpinners = Gui.checkbox("Scraprun spinners", Inputs.playScraprunSpinners)
		if newScraprunSpinners ~= Inputs.playScraprunSpinners then
			Inputs.playScraprunSpinners = newScraprunSpinners
			config.playScraprunSpinners = newScraprunSpinners
			spectatorDebug.scrapRunSpinners = Inputs.playScraprunSpinners
			if saveConfig then saveConfig() end
		end

		local newPlaceBallEnabled = Gui.checkbox("'Place Ball' visuals", Inputs.placeBallEnabled)
		if newPlaceBallEnabled ~= Inputs.placeBallEnabled then
			Inputs.placeBallEnabled = newPlaceBallEnabled
			config.placeBallEnabled = newPlaceBallEnabled
			spectatorDebug.placeBallHereVisuals = Inputs.placeBallEnabled
			if saveConfig then saveConfig() end
		end

		local newBallScaleMultiplier = Gui.sliderFloat("Ball scale multiplier", Inputs.ballScaleMultiplier, 0, 10)
		if newBallScaleMultiplier ~= Inputs.ballScaleMultiplier then
			Inputs.ballScaleMultiplier = newBallScaleMultiplier
			config.ballScaleMultiplier = newBallScaleMultiplier
			spectatorDebug.replayBallScaleMultiplier = Inputs.ballScaleMultiplier
			if saveConfig then saveConfig() end
		end

		Gui.endTabItem()
	end

	if Gui.beginTabItem(getTabTitle(Icon.Users, "Players")) then
		local players = {}
		local sessions = getAllGameData and getAllGameData() or (getGameData and { getGameData() } or {})

		for i = 1, #sessions do
			local session = sessions[i]
			if session and session.players then
				for j = 1, #session.players do
					local pInfo = session.players[j]
					if pInfo and pInfo.playerId then
						local p = session.getPlayerById and session:getPlayerById(pInfo.playerId) or pInfo
						if p and p.playerName then
							table.insert(players, { id = pInfo.playerId, sessionIndex = i, name = p.playerName, object = p })
						end
					end
				end
			end
		end

		local ownerNameLower = string.lower(ownerName)
		table.sort(players, function(firstPlayer, secondPlayer)
			local firstIsOwner = ownerNameLower ~= "" and string.lower(firstPlayer.name) == ownerNameLower
			local secondIsOwner = ownerNameLower ~= "" and string.lower(secondPlayer.name) == ownerNameLower
			return firstIsOwner and not secondIsOwner
		end)

		local gameData = getGameData()
		local spectatorList = (gameData and gameData.spectators) and gameData.spectators or {}

		local selectedPlayerObj = nil
		if selectedPlayerTarget then
			for _, p in ipairs(players) do
				if p.id == selectedPlayerTarget.id and p.sessionIndex == selectedPlayerTarget.sessionIndex then
					selectedPlayerObj = p.object
					break
				end
			end
		end

        local selectedSpectator = nil
        if selectedSpectatorName ~= "" then
            for _, spec in ipairs(spectatorList) do
                local name = spec.playerName or ("Spectator #" .. spec.playerId)
                if name == selectedSpectatorName then selectedSpectator = spec; break end
            end
        end

        Gui.beginChild("playerCountBox", 140, 70, true)
        Gui.textDisabled(Icon.Users .. "  Players")
        Gui.text(tostring(#players))
        Gui.endChild()
        
        Gui.sameLine()
        
        Gui.beginChild("spectatorCountBox", 140, 70, true)
        Gui.textDisabled(Icon.Eye .. "  Spectators")
        Gui.text(tostring(#spectatorList))
        Gui.endChild()

        Gui.sameLine()

        Gui.beginChild("targetStatusBox", 200, 70, true)
        Gui.textDisabled(Icon.ChevronRight .. "  Spectator Target")
        Gui.text(selectedSpectatorName ~= "" and selectedSpectatorName or "None")
        if followSpectatorEnabled then
            Gui.sameLine()
            Gui.textDisabled("(Following)")
        end
        Gui.endChild()

        Gui.newLine()

        Gui.separatorText(Icon.Users .. "  Players (" .. tostring(#players) .. ")")
        Gui.indent()
        playerSearchText = Gui.inputText(Icon.Search .. "  Search Players", playerSearchText)
        
        if Gui.beginListBox("##PlayersList") then
			for i, p in ipairs(players) do
				Gui.pushId(tostring(i))
				if playerSearchText == "" or string.find(string.lower(p.name), string.lower(playerSearchText), 1, true) then
					local isSelected = selectedPlayerTarget ~= nil 
						and p.id == selectedPlayerTarget.id 
						and p.sessionIndex == selectedPlayerTarget.sessionIndex

					if Gui.selectable(p.name, isSelected) then
						selectedPlayerTarget = { id = p.id, sessionIndex = p.sessionIndex }
					end
				end
				Gui.popId()
			end
			Gui.endListBox()
		end


        if selectedPlayerObj then
            if Gui.button(Icon.LocationArrow .. "  Teleport to " .. (selectedPlayerObj.playerName or "")) then
                local targetPos = (selectedPlayerObj.head and selectedPlayerObj.head.position)
                    or (selectedPlayerObj.root and selectedPlayerObj.root.position)
                    or (selectedPlayerObj.transform and selectedPlayerObj.transform.position)
                if targetPos then camera.position = targetPos end
            end

            if readLocation == 0 then
                Gui.sameLine()

                local targetName = selectedPlayerObj.playerName or ""
                local isMuted = mutedPlayers[targetName] or false
                local muteIcon = isMuted and (Icon.VolumeUp or "") or (Icon.VolumeMute or "")
                local buttonText = isMuted and (muteIcon .. "  Unmute") or (muteIcon .. "  Mute")

                if Gui.button(buttonText .. "##Mute_" .. targetName) then
                    local newState = not isMuted
                    local success = Settings.mutePlayerByName(targetName, newState)
                    if success then
                        mutedPlayers[targetName] = newState
                    end
                end
            else
				Gui.sameLine()
				Gui.beginDisabled()
				Gui.button(Icon.VolumeMute .. "  Mute")
				Gui.setItemTooltip("You can't mute players from replays!")
				Gui.endDisabled()
			end

			Gui.sameLine()

			if Gui.button(Icon.ChevronRight .. "  Start Handcam following") then
				config.currentPlayerId = selectedPlayerTarget.id
				if saveConfig then saveConfig() end
				
				if not Axis.isEnabled then
					Axis.isEnabled = true
				end
				Axis.onLoad()
			end
		else
			Gui.textDisabled("Select a player above to interact.")
		end
		Gui.unindent()
		Gui.newLine()

		Gui.separatorText(Icon.Eye .. "  Spectators (" .. tostring(#spectatorList) .. ")")
		Gui.indent()
		spectatorSearchText = Gui.inputText(Icon.Search .. "  Search Spectators", spectatorSearchText)
		
		if Gui.beginListBox("##SpectatorsList") then
			for _, spec in ipairs(spectatorList) do
				local name = spec.playerName or ("Spectator #" .. spec.playerId)
				if spectatorSearchText == "" or string.find(string.lower(name), string.lower(spectatorSearchText), 1, true) then
					if Gui.selectable(name, selectedSpectatorName == name) then
						selectedSpectatorName = name
					end
				end
			end
			Gui.endListBox()
		end

		if selectedSpectator then
			Gui.beginHorizontal("SpecActions")
				if Gui.button(Icon.LocationArrow .. "  Teleport") then
					local targetPos = (selectedSpectator.transform and selectedSpectator.transform.position)
						or (selectedSpectator.root and selectedSpectator.root.position)
					if targetPos then camera.position = targetPos end
				end
				
				local followText = followSpectatorEnabled and (Icon.Pause .. " Stop Following") or (Icon.Play .. "  Start Following")
				if Gui.button(followText) then
					followSpectatorEnabled = not followSpectatorEnabled
				end
			Gui.endHorizontal()
		else
			Gui.textDisabled("Select a spectator above to interact.")
		end
		Gui.unindent()
		Gui.newLine()

    	Gui.endTabItem()
	end

	if showModelsTab and Gui.beginTabItem(getTabTitle(Icon.VectorSquare, "Draw")) then
		Gui.beginTabBar("DrawSubTabs")
		
		if Gui.beginTabItem(Icon.Shapes .. "  Models") then
			Models.onModelsGui()
			Gui.endTabItem()
		end
		
		if Gui.beginTabItem(Icon.Image .. "  Images & GIFs") then
			Models.onImagesGui()
			Gui.endTabItem()
		end
		
		if Gui.beginTabItem(Icon.Font .. "  Text") then
			Models.onTextGui()
			Gui.endTabItem()
		end

		if Gui.beginTabItem(Icon.Lightbulb .. "  Lights") then
			Models.onLightsGui()
			Gui.endTabItem()
		end
		
		Gui.endTabBar()
		Gui.endTabItem()
	end

	Gui.endTabBar()
end

function tick(dt)
	if pendingGravitySnap then
		ntimer += dt
		snapToGravity()
		if ntimer >= ndelay then
			snapToGravity()
			pendingGravitySnap = false
			ntimer = 0
		end
	end

	Models.tick(dt)
	timer = timer + dt

	if screenshotSuccessTimer > 0 then
		screenshotSuccessTimer = math.max(0, screenshotSuccessTimer - dt)
	end

	if enableScreenshotKey then
		local keyEnum = parseKeyStr(screenshotKeyStr)
		if keyEnum and Input.getKeyDown(keyEnum) then
			triggerScreenshot()
		end
	end

	if enableDisconnectKey then
		local keyEnum = parseKeyStr(disconnectKeyStr)
		if keyEnum and Input.getKeyDown(keyEnum) then
			Network.disconnectFromServer()
		end
	end

	if enableFreecamKey then
		local keyEnum = parseKeyStr(freecamKeyStr)
		if keyEnum and Input.getKeyDown(keyEnum) then
			if Axis.isEnabled then
				Axis.isEnabled = false
				Axis.onUnload()
				Util.setSmoothing(Inputs.smoothing, Inputs)
			end
		end
	end

	if enableHandcamKey then
		local keyEnum = parseKeyStr(handcamKeyStr)
		if keyEnum and Input.getKeyDown(keyEnum) then
			if not Axis.isEnabled then
				Axis.isEnabled = true
				Axis.onLoad()
			end
		end
	end

	if Input.getKeyDown(Inputs.toggleCameraGp) then
		if Axis.isEnabled then
			Axis.isEnabled = false
			Axis.onUnload()
			Util.setSmoothing(Inputs.smoothing, Inputs)
		else
			Axis.isEnabled = true
			Axis.onLoad()
		end
	end

	currentEmoteTimer += dt

	if currentEmoteTimer >= 0.5 then
		currentEmoteTimer -= 0.5

		local currentEmoteId = camera:getEmote() or 0
		local labels = emoteLabels[currentEmoteId] or { "None" }

		currentEmoteFrame += 1

		if currentEmoteFrame > #labels then
			currentEmoteFrame = 1
		end
	end

	if emoteCycling and timer - lastEmoteCycleTime > emoteCycleInterval then
        local currentId = camera:getEmote() or 0
        local nextId = (currentId + 1) % 11
        camera:setEmote(nextId)
        lastEmoteCycleTime = timer
    end

	if Axis.isEnabled then
		Axis.tick(dt)
		Models.updateHud(dt)
		return
	end

	local forward = camera.rotation:getForwardVector()
	local currentGravityDirection = gravityChaser:getUpVector()
	local gravityForward = Util.projectVectorOntoPlane(forward, currentGravityDirection):getSafeNormal()
	local right = camera.rotation:getRightVector()
	local up = camera.rotation:getUpVector()
	local useLocalMovementAxes = Util.xor(Inputs.localMovementAxesDefault, Input.getKey(Inputs.gravityAlignedMovementModifier))

	if Input.getKey(Inputs.fastKey) or Input.getKey(Input.Gamepad.RightShoulder) then
		moveSpeed *= (1 + Inputs.speedAdjustmentRate * dt)
		if moveSpeed < Inputs.minMoveSpeed then
			moveSpeed = Inputs.minMoveSpeed
		end
		if moveSpeed > Inputs.maxMoveSpeed then
			moveSpeed = Inputs.maxMoveSpeed
		end
	elseif Input.getKey(Inputs.slowKey) or Input.getKey(Input.Gamepad.LeftShoulder) then
		moveSpeed *= (1 - Inputs.speedAdjustmentRate * dt)
		if moveSpeed > Inputs.maxMoveSpeed then
			moveSpeed = Inputs.maxMoveSpeed
		end
	end

	if Input.getKeyDown(Inputs.toggleSmoothingKey) or Input.getKeyDown(Inputs.toggleSmoothingGp) then
		Inputs.smoothing = not Inputs.smoothing
		Util.setSmoothing(Inputs.smoothing, Inputs)
	end

	if enableTeleportKey then
		local keyEnum = parseKeyStr(teleportKeyStr)
		if keyEnum and Input.getKeyDown(keyEnum) then
			local teleportLocation = startLocations[teleportMapType] and startLocations[teleportMapType][teleportName]
			if teleportLocation then
				goToLocation(teleportLocation)
			end
		end
	end

	if enableEmoteToggleKey then
		local keyEnum = parseKeyStr(emoteToggleKeyStr)
		if keyEnum and Input.getKeyDown(keyEnum) then
		local currentEmote = camera:getEmote()
			camera:setEmote(currentEmote == emoteToggleId and 0 or emoteToggleId)
		end
	end

	if (Input.getKeyDown(Input.Key.Up) or Input.getKeyDown(Inputs.frontflipGp)) and not flipActive then
        flipActive = true
        flipDirection = 1
        flipTimer = 0
	elseif (Input.getKeyDown(Input.Key.Down) or Input.getKeyDown(Inputs.backflipGp)) and not flipActive then
        flipActive = true
        flipDirection = -1
        flipTimer = 0
    end

    local currentFlipOffset = 0
    if flipActive then
        flipTimer = flipTimer + dt
        local progress = flipTimer / flipDuration
        if progress >= 1 then
            progress = 1
            flipActive = false
        end
        currentFlipOffset = progress * 360 * flipDirection
    end

	camera.fieldOfView -= Input.getAnalog(Input.Key.MouseWheelAxis) * Inputs.zoomSpeedKb
	if Input.getKey(Inputs.zoomInGp) then
		camera.fieldOfView -= Inputs.zoomSpeedGp
	elseif Input.getKey(Inputs.zoomOutGp) then
		camera.fieldOfView += Inputs.zoomSpeedGp
	end

	camera.fieldOfView = math.clamp(camera.fieldOfView, Inputs.minFov, Inputs.maxFov)

	local input = Vec3.zeroVector
	if Input.getKey(Inputs.forwardKey) then
		if useLocalMovementAxes then
			input += forward
		else
			input += gravityForward
		end
	end
	if Input.getKey(Inputs.backwardKey) then
		if useLocalMovementAxes then
			input -= forward
		else
			input -= gravityForward
		end
	end
	if Input.getKey(Inputs.rightKey) then
		input += right
	end
	if Input.getKey(Inputs.leftKey) then
		input -= right
	end
	if Input.getKey(Inputs.upKey) then
		if useLocalMovementAxes then
			input += up
		else
			input += currentGravityDirection
		end
	end
	if Input.getKey(Inputs.downKey) then
		if useLocalMovementAxes then
			input -= up
		else
			input -= currentGravityDirection
		end
	end

	input += right * Input.getAnalog(Input.Gamepad.LeftX)
	input += forward * Input.getAnalog(Input.Gamepad.LeftY)
	input += up * Input.getAnalog(Input.Gamepad.RightTriggerAxis)
	input -= up * Input.getAnalog(Input.Gamepad.LeftTriggerAxis)

	if Input.getKeyDown(Input.Key.MiddleMouseButton) or Input.getKeyDown(Inputs.resetRollGp) then
		Inputs.rotEuler.x = 0
		Inputs.lookInputTarget.x = 0
	end

	local adjustedRotSpeed = Inputs.fovRotSpeedMultiplier * (camera.fieldOfView - 90) / 90 + Inputs.rotSpeed
	local adjustedMouseSensitivity = Inputs.fovRotSpeedMultiplier * (camera.fieldOfView - 90) / 90 + mouseSensitivity
	local adjustedLookSmoothness = 1 - (1 - Inputs.lookSmoothness) ^ 3
	local lookInputTargetDelta = Vec3.zeroVector

	local mouse = Input.getMouseDelta()
	local rollAngle = -Inputs.rotEuler.x * math.pi / 180.0
	if mouse and mouse.x then
		if Input.getKey(Inputs.rollMouseEnable) then
			lookInputTargetDelta.x += mouse.x * mouseSensitivity / 2.0
		else
			lookInputTargetDelta.z += mouse.x * adjustedMouseSensitivity
			lookInputTargetDelta.y += mouse.y * adjustedMouseSensitivity
		end
	end

	if Input.getKey(Inputs.rollRightGp) then
		lookInputTargetDelta.x += Inputs.rotSpeed * dt / 2
	elseif Input.getKey(Inputs.rollLeftGp) then
		lookInputTargetDelta.x -= Inputs.rotSpeed * dt / 2
	end
	lookInputTargetDelta.z += Input.getAnalog(Input.Gamepad.RightX) * adjustedRotSpeed * dt
	lookInputTargetDelta.y += Input.getAnalog(Input.Gamepad.RightY) * adjustedRotSpeed * dt

	local rollAdjustedInput = Vec3.new(
		lookInputTargetDelta.x,
		lookInputTargetDelta.y * math.cos(rollAngle) + lookInputTargetDelta.z * math.sin(rollAngle),
		lookInputTargetDelta.z * math.cos(rollAngle) - lookInputTargetDelta.y * math.sin(rollAngle)
	)
	Inputs.lookInputTarget += rollAdjustedInput
	local nextLookDiff = Inputs.lookInputTarget * math.min((1 - adjustedLookSmoothness) * dt * 60, 1)

	if Inputs.alignToGravity then
		if gravityChaser ~= gravity.upRotation and gravity.strength ~= 0 then
			local inputTotal = nextLookDiff:length()
			local nextGravityChaser = Quat.slerp(gravityChaser, gravity.upRotation, (inputTotal * Inputs.gravityChaseSpeed + Inputs.gravitySlowChaseSpeed) * dt)
			local nextRotation = nextGravityChaser:inverse() * Quat.fromXZ(forward, nextGravityChaser:rotateVector(Vec3.new(0, 0, 1)))
			Inputs.rotEuler = nextRotation:euler() + Vec3.new(Inputs.rotEuler.x, 0, 0)
			gravityChaser = nextGravityChaser
		end
	end
	if Input.getKeyDown(Inputs.snapToGravityKey) or Input.getKeyDown(Inputs.alignToGravityGp) then
		snapToGravity()
	end

	Inputs.rotEuler += nextLookDiff
	Inputs.lookInputTarget -= nextLookDiff

	if Inputs.rotEuler.y > 89.9 then
		Inputs.rotEuler.y = 89.9
	end
	if Inputs.rotEuler.y < -89.9 then
		Inputs.rotEuler.y = -89.9
	end

	if Input.getKeyUp(Inputs.rollMouseEnable) or Input.getKeyUp(Inputs.rollRightGp) or Input.getKeyUp(Inputs.rollLeftGp) then
		local clampedRoll = math.abs(Inputs.rotEuler.x) % 360
		if clampedRoll <= Inputs.rollResetTolerance then
			Inputs.rotEuler.x = 0
			Inputs.lookInputTarget.x = 0
		end
	end

	local movement = input * moveSpeed * dt
	if collisionEnabled and movement:length() > 0.01 then
		local hit = camera:castRay(
			camera.position,
			camera.position + movement:getSafeNormal() * (movement:length() + collisionRadius)
		)
		if hit.successful then
			movement -= hit.normal * movement:dot(hit.normal)
		end
	end
	camera.position += movement
	camera.rotation = gravityChaser * Quat.fromEuler(Inputs.rotEuler.x, Inputs.rotEuler.y + currentFlipOffset, Inputs.rotEuler.z)
	local gameData = getGameData()
	if gameData and gameData.spectators then
		spectatorList = gameData.spectators
	else
		spectatorList = {}
	end

	local selectedSpectator = nil
	if selectedSpectatorName ~= "" then
		for _, spec in ipairs(spectatorList) do
			local name = spec.playerName or ("Spectator #" .. spec.playerId)
			if name == selectedSpectatorName then
				selectedSpectator = spec
				break
			end
		end
	end

	if followSpectatorEnabled and selectedSpectator then
		local targetPos = selectedSpectator.transform.position
		local targetRot = selectedSpectator.transform.rotation
		camera.position = targetPos
		camera.rotation = targetRot
		Inputs.rotEuler = camera.rotation:euler()
	end

	Models.updateHud(dt)

end

function onMessageReceived(message)
	if message.messageType == "setTransform" then
		goToLocation({
			position = message.position,
			rotation = message.rotation,
			fieldOfView = message.fieldOfView,
		})
	elseif message.messageType == "lookAt" then
		camera:lookAt(message.target, message.upVector)
		Inputs.rotEuler = camera.rotation:euler()
	end
end