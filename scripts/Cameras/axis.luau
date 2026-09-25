--!strict
-- Notes for script readers
-- Originally forked from Pub's driftvision, then remade into axis, then renamed into handcam, then into playercam, then added 9123291 features and so much more
-- Good luck with this, its 3k lines of puuure misery

local Util = require("../More/util")

local Axis = {}
Axis.isEnabled = false

config = config or {}

config.viewpointOffset = config.viewpointOffset or Vec3.new(0, 0, 0)
config.fov = config.fov or 95
config.nearClip = config.nearClip or 1
if config.hideHead == nil then
	config.hideHead = true
end
config.nameTagType = config.nameTagType or 0
config.currentPlayerId = config.currentPlayerId or nil
config.ownerId = config.ownerId or nil
if config.followBestScraprunPlayer == nil then
	config.followBestScraprunPlayer = false
end
config.useTriggerControl = true
config.headGrabRadius = config.headGrabRadius or 30
config.headDropRadius = config.headDropRadius or 60
config.shoulderDropRadius = config.shoulderDropRadius or 60
config.cameraGrabRadius = config.cameraGrabRadius or 50
config.ownerRecallTime = 1.5
if config.requireTwoHandsRecall == nil then
	config.requireTwoHandsRecall = false
end
config.thirdPersonDistance = config.thirdPersonDistance or 300
config.thirdPersonHeight = config.thirdPersonHeight or 0
config.grabDelayTime = config.grabDelayTime or 1.0

config.throwThreshold = config.throwThreshold or 200
config.throwGravity = config.throwGravity or 250

config.orbitRadius = config.orbitRadius or 300
config.orbitRotSpeed = config.orbitRotSpeed or 180
config.orbitMouseSensitivity = config.orbitMouseSensitivity or 3.6
config.orbitMouseWheelSensitivity = config.orbitMouseWheelSensitivity or 50
config.cameraSmoothness = config.cameraSmoothness or 0.1

config.gripToggleDelayTime = config.gripToggleDelayTime or 0.2
config.grabCameraControl = config.grabCameraControl or "Trigger"
config.recallCameraControl = config.recallCameraControl or "Trigger"
config.modeToggleControl = config.modeToggleControl or "Grip"
if config.floatingLookToggleEnabled == nil then
	config.floatingLookToggleEnabled = true
end

local headGripAttemptTime = 0
local isHeadGripAttempt = false
local headGripToggled = false

local manualOrbitMode = false
local cameraDirectionEuler = Vec3.new(0, 0, 0)

local rightHandOffset = Vec3.new(0, 10, -5)
local leftHandOffset = Vec3.new(0, 10, -5)

if config.extensionEnabled == nil then
	config.extensionEnabled = true
end
config.handheldDistance = config.handheldDistance or config.minExtension or 5
config.minExtension = config.handheldDistance
config.maxExtension = config.maxExtension or 500
config.extensionStep = config.extensionStep or 10
config.extensionSmoothness = config.extensionSmoothness or 0.2
if config.flipEnabled == nil then
	config.flipEnabled = true
end

if config.slingshotEnabled == nil then
	config.slingshotEnabled = true
end
config.slingshotDistance = config.slingshotDistance or 5000
config.slingshotLaunchTime = config.slingshotLaunchTime or 0.5
config.slingshotReturnTime = config.slingshotReturnTime or 1.0
config.slingshotSpinSpeed = config.slingshotSpinSpeed or 360
config.doubleClickThreshold = config.doubleClickThreshold or 0.3

local BALL_GRAB_RADIUS = 50
local BALL_LATENCY = 0.06
local BALL_RAY_OFFSET = 8.5
local BALL_LOST_DISTANCE = 3000

local timer = 0

local t = 0
local activePlayerId = nil
local activePlayerTarget = nil
local selectedPlayerId = nil
local searchText = ""
local debugMode = false

local configDirty = false
local configSaveAtTime = 0

local ownerIsPresent = false
local ownerPlayer = nil
config.ownerName = config.ownerName or "higuysimaugust"
local didAutoAssignDefaultOwner = false
local lastAutoAssignAttemptTime = -1

local viewpointMode = true
local thirdPersonMode = false
local cameraInHand = false
local handHolding = nil
local freeFloatingMode = false
local ballMode = false
local shoulderMode = false
local shoulderSide = "right"
local floatingLookMode = false
local floatingLookPlayerId = nil
local floatingLookButtonsWasPressed = false

local thrownMode = false
local throwVelocity = Vec3.new(0, 0, 0)
local lastRightHandPos = nil
local lastLeftHandPos = nil
local currentRightHandVelocity = Vec3.new(0, 0, 0)
local currentLeftHandVelocity = Vec3.new(0, 0, 0)

local worldUp = Vec3.new(0, 1, 0)

local scraprunCubes = {
	{
		name = "Cube_1",
		position = Vec3.new(-18919.33, 15251.28, 27774.44),
		rotation = Vec3.new(0.00, 32.00, 0.00),
		scale = Vec3.new(2360.00, 7155.00, 1084.00),
		startAxis = "Y",
		endAxis = "-Y",
	},
	{
		name = "Cube_2",
		position = Vec3.new(-16760.00, 17815.97, 28954.72),
		rotation = Vec3.new(180.00, -30.00, 180.00),
		scale = Vec3.new(2524.00, 2429.00, 687.00),
		startAxis = "X",
		endAxis = "-X",
	},
	{
		name = "Cube_3",
		position = Vec3.new(-14276.23, 15356.92, 29497.59),
		rotation = Vec3.new(180.00, -30.00, 180.00),
		scale = Vec3.new(2410.00, 7466.00, 1433.00),
		startAxis = "Y",
		endAxis = "-Y",
	},
	{
		name = "Cube_4",
		position = Vec3.new(-15328.37, 10699.46, 28778.84),
		rotation = Vec3.new(180.00, -30.00, 180.00),
		scale = Vec3.new(4869.00, 1846.00, 1386.00),
		startAxis = "-X",
		endAxis = "X",
	},
	{
		name = "Cube_5",
		position = Vec3.new(-18275.23, 14128.92, 26536.59),
		rotation = Vec3.new(180.00, -30.00, 180.00),
		scale = Vec3.new(2464.00, 10000.00, 1157.00),
		startAxis = "Y",
		endAxis = "-Y",
	},
	{
		name = "Cube_6",
		position = Vec3.new(-14761.37, 17922.00, 27626.84),
		rotation = Vec3.new(180.00, -30.00, 180.00),
		scale = Vec3.new(4695.00, 1718.00, 1386.00),
		startAxis = "X",
		endAxis = "-X",
	},
	{
		name = "Cube_7",
		position = Vec3.new(-13409.23, 13104.92, 28052.59),
		rotation = Vec3.new(180.00, -30.00, 180.00),
		scale = Vec3.new(2464.00, 7880.00, 1157.00),
		startAxis = "Y",
		endAxis = "-Y",
	},
	{
		name = "Cube_8",
		position = Vec3.new(-16351.37, 10357.00, 25820.84),
		rotation = Vec3.new(180.00, -30.00, 180.00),
		scale = Vec3.new(4857.00, 1833.00, 1386.00),
		startAxis = "-X",
		endAxis = "X",
	},
	{
		name = "Cube_9",
		position = Vec3.new(-17518.23, 14532.92, 24900.59),
		rotation = Vec3.new(180.00, -30.00, 180.00),
		scale = Vec3.new(1615.00, 6481.00, 1550.00),
		startAxis = "Y",
		endAxis = "-Y",
	},
}

local scraprunBestPlayerName = "None"
local scraprunBestCubeName = "None"
local scraprunTargetSwitchTimer = 0
local pendingBestPlayerId = nil
local scraprunswitchdebounce = 0.35
local scraprunboxpadding = -300.0

local currentExtension = config.minExtension
local targetExtension = config.minExtension
local facingUser = true
local viewFlipped = false

local lastRightGripState = false
local lastLeftGripState = false
local lastHeadModeToggleRightGripState = false

local lastOwnerRightGripState = false
local lastOwnerLeftGripState = false

local ownerRecallTimer = 0

local grabAttemptTime = 0
local isRightGrabAttempt = false
local isLeftGrabAttempt = false

local slingshotLaunched = false
local slingshotPlayer = nil
local slingshotLaunchStartTime = 0
local slingshotReturnStartTime = 0
local slingshotReturning = false
local slingshotLaunchDirection = Vec3.new(0, 0, 0)
local slingshotStartPosition = Vec3.new(0, 0, 0)
local slingshotTargetPosition = Vec3.new(0, 0, 0)
local slingshotReturnStartPos = Vec3.new(0, 0, 0)
local slingshotReturnTargetPos = Vec3.new(0, 0, 0)
local slingshotSpinAngle = 0
local lastSecondaryTriggerState = false
local triggerPressTimes = {}

local slingshotAngleX, slingshotAngleY, slingshotAngleZ = 0, 0, 0
local slingshotSpinX, slingshotSpinY, slingshotSpinZ = 0, 0, 0

local ballIndex = 0
local ballCount = 0
local lastBallPos = Vec3.new(0, 0, 0)

local initialPovSet = false
local initialDelay = 0

local function updateNameTagsVisibility()
	if not camera then
		return
	end
	if config.nameTagType == 0 then
		camera.showNameTags = true
	elseif config.nameTagType == 1 then
		camera.showNameTags = not viewpointMode
	else
		camera.showNameTags = false
	end
end

local selectedPlayerTarget = nil

local function getPlayers()
	return Util.getPlayers()
end

local function getPlayerById(playerId, sessionIndex)
	return Util.findPlayerById(playerId, sessionIndex)
end

local function getPlayerName(target)
	if not target then
		return "None"
	end
	local player = (type(target) == "table") and getPlayerByTarget(target) or getPlayerById(target)
	if player and player.playerName then
		return player.playerName
	end
	return "Unknown"
end

local function isSameTarget(a, b)
	if not a or not b then
		return false
	end
	return a.id == b.id and a.sessionIndex == b.sessionIndex
end

local function getPlayerByTarget(target)
	if not target or not target.id then
		return nil
	end
	local sessions = getAllGameData()
	if target.sessionIndex and sessions[target.sessionIndex] and sessions[target.sessionIndex].getPlayerById then
		local player = sessions[target.sessionIndex]:getPlayerById(target.id)
		if player then
			return player
		end
	end
	for i = 1, #sessions do
		if sessions[i].getPlayerById then
			local player = sessions[i]:getPlayerById(target.id)
			if player then
				return player
			end
		end
	end
	return nil
end

local function getCurrentTarget()
	if activePlayerTarget and activePlayerTarget.id == activePlayerId then
		return activePlayerTarget
	end
	if activePlayerId then
		return { id = activePlayerId, sessionIndex = nil }
	end
	return nil
end

local function getOwnerTarget()
	if config.ownerTarget and config.ownerTarget.id == config.ownerId then
		return config.ownerTarget
	end
	if config.ownerId then
		return { id = config.ownerId, sessionIndex = nil }
	end
	return nil
end

local function getSpectators()
	local spectators = {}
	local sessions = getAllGameData()
	for i = 1, #sessions do
		local session = sessions[i]
		if session.spectators then
			for j = 1, #session.spectators do
				local spec = session.spectators[j]
				if spec then
					local name = spec.playerName or ("spectator " .. tostring(j))
					table.insert(spectators, { name = name, sessionIndex = i, index = j })
				end
			end
		end
	end
	return spectators
end

local function getSpectatorByKey(key)
	if not key then
		return nil
	end
	local sessions = getAllGameData()
	if key.sessionIndex and sessions[key.sessionIndex] and sessions[key.sessionIndex].spectators then
		local specs = sessions[key.sessionIndex].spectators
		for j = 1, #specs do
			local spec = specs[j]
			if spec and key.playerName and spec.playerName == key.playerName then
				key.index = j
				return spec
			end
		end
		if key.index and specs[key.index] then
			return specs[key.index]
		end
	end
	if key.playerName then
		for i = 1, #sessions do
			local specs = sessions[i].spectators
			if specs then
				for j = 1, #specs do
					local spec = specs[j]
					if spec and spec.playerName == key.playerName then
						key.sessionIndex = i
						key.index = j
						return spec
					end
				end
			end
		end
	end
	return nil
end

local function checkForOwnerPresence()
	ownerIsPresent = false
	ownerPlayer = nil
	if config.ownerId then
		ownerPlayer = getPlayerByTarget(getOwnerTarget())
		ownerIsPresent = (ownerPlayer ~= nil)
	end
	return ownerIsPresent
end

local function findAnyPlayer()
	if config.currentPlayerId then
		local player = getPlayerById(config.currentPlayerId)
		if player then
			return config.currentPlayerId
		end
	end
	if config.ownerId then
		local player = getPlayerByTarget(getOwnerTarget())
		if player then
			return config.ownerId
		end
	end
	local players = getPlayers()
	if #players > 0 then
		return players[1].id
	end
	return nil
end

local function tryAutoAssignDefaultOwner()
	if didAutoAssignDefaultOwner then
		return false
	end
	if config.ownerId ~= nil and getPlayerByTarget(getOwnerTarget()) ~= nil then
		return false
	end
	if config.currentPlayerId ~= nil and getPlayerById(config.currentPlayerId) ~= nil then
		return false
	end
	if selectedPlayerId ~= nil then
		return false
	end

	local players = getPlayers()
	if #players == 0 then
		return false
	end

	local targetLower = string.lower(config.ownerName or "higuysimaugust")
	for i = 1, #players do
		local p = players[i]
		if p and p.id and p.name and string.lower(p.name) == targetLower then
			config.ownerId = p.id
			activePlayerId = p.id
			config.currentPlayerId = p.id
			if saveConfig then
				saveConfig()
			end
			checkForOwnerPresence()
			didAutoAssignDefaultOwner = true
			return true
		end
	end

	return false
end

local function playerMatchesSearch(playerName, search)
	if search == "" then
		return true
	end
	local lowerName = string.lower(playerName)
	local lowerSearch = string.lower(search)
	return string.find(lowerName, lowerSearch) ~= nil
end

local function getHandPosition(player, isLeftHand)
	if not player or not player.root or not player.root.position or not player.root.rotation then
		return nil, nil
	end
	if isLeftHand then
		if player.leftHand and player.leftHand.position and player.leftHand.rotation then
			local handPos = player.root.position + player.root.rotation:rotateVector(player.leftHand.position)
			local handRot = player.root.rotation * player.leftHand.rotation
			return handPos, handRot
		end
	else
		if player.rightHand and player.rightHand.position and player.rightHand.rotation then
			local handPos = player.root.position + player.root.rotation:rotateVector(player.rightHand.position)
			local handRot = player.root.rotation * player.rightHand.rotation
			return handPos, handRot
		end
	end
	return nil, nil
end

local function encodeButtonState(stateBits)
	-- od sends controller buttons as bits because booleasn suck
	if not stateBits then
		return "00000000"
	end
	local output = ""
	for i = 0, 7 do
		if bit32 and bit32.band and bit32.lshift then
			if bit32.band(stateBits, bit32.lshift(1, i)) > 0 then
				output = "1" .. output
			else
				output = "0" .. output
			end
		else
			output = "0" .. output
		end
	end
	return output
end

local function getUserInputState(player, isLeftHand)
	if not player then
		return "00000000"
	end
	local leftInputState = player.leftHandPosebits or 0
	local rightInputState = player.rightHandPosebits or 0
	local leftStateFormatted = encodeButtonState(leftInputState)
	local rightStateFormatted = encodeButtonState(rightInputState)
	return isLeftHand and leftStateFormatted or rightStateFormatted
end

local function isButtonPressed(player, isLeftHand, buttonBit)
	local buttonState = getUserInputState(player, isLeftHand)
	return buttonState:sub(buttonBit, buttonBit) == "1"
end

local function isGripPressed(player, isLeftHand)
	return isButtonPressed(player, isLeftHand, 5)
end

local function isTriggerPressed(player, isLeftHand)
	return isButtonPressed(player, isLeftHand, 7)
end

local function isControlPressed(player, isLeftHand, control)
	if control == "Grip" then
		return isGripPressed(player, isLeftHand)
	elseif control == "Trigger" then
		return isTriggerPressed(player, isLeftHand)
	end
	return false
end

local function isActionPressed(player, isLeftHand, action)
	if action == "Grab Camera" then
		return isControlPressed(player, isLeftHand, config.grabCameraControl)
	elseif action == "Recall Camera" then
		return isControlPressed(player, isLeftHand, config.recallCameraControl)
	elseif action == "Mode Toggle" then
		return isControlPressed(player, isLeftHand, config.modeToggleControl)
	end
	return false
end

local function isFlipPressed(player, isLeftHand)
	if config.grabCameraControl == "Trigger" then
		return isGripPressed(player, isLeftHand)
	elseif config.grabCameraControl == "Grip" then
		return isTriggerPressed(player, isLeftHand)
	end
	return false
end

local function queueConfigSave()
	configDirty = true
	configSaveAtTime = t + 0.25
end

local function applyCameraSmoothness(lockPosition)
	if camera then
		if cameraInHand then
			camera.positionSmoothing = 0
		else
			camera.positionSmoothing = lockPosition and 0 or config.cameraSmoothness
		end
		camera.rotationSmoothing = config.cameraSmoothness
	end
end

local function disableCameraSmoothness()
	if camera then
		camera.positionSmoothing = 0
		camera.rotationSmoothing = 0
	end
end

local function applySettingsChange(changed)
	if not changed then
		return
	end
	if camera then
		camera.nearClippingPlane = config.nearClip
		if not thirdPersonMode then
			camera.fieldOfView = config.fov
		end
		if viewpointMode or thirdPersonMode or manualOrbitMode or cameraInHand then
			applyCameraSmoothness(viewpointMode)
		else
			disableCameraSmoothness()
		end
		if viewpointMode then
			camera.hideNearestHead = config.hideHead
		end
		updateNameTagsVisibility()
	end
	queueConfigSave()
end

local function flipCameraView()
	facingUser = not facingUser
	viewFlipped = not facingUser
end

local function lerp(a, b, t_val)
	return a + (b - a) * t_val
end

local function resetCameraModeState()
	-- every mode owns some of these flags, so reset eeeeverything
	viewpointMode = false
	thirdPersonMode = false
	manualOrbitMode = false
	cameraInHand = false
	thrownMode = false
	handHolding = nil
	freeFloatingMode = false
	ballMode = false
	shoulderMode = false
	shoulderSide = "right"
	floatingLookMode = false
end

local function setViewpointMode(player)
	if not player or not player.head then
		return
	end
	applyCameraSmoothness(true)
	camera.nearClippingPlane = config.nearClip
	camera.fieldOfView = config.fov
	camera.hideNearestHead = config.hideHead
	camera.position = player.head.position
	camera.rotation = player.head.rotation

	resetCameraModeState()
	viewpointMode = true
	ballIndex = 0
	ballCount = 0
	facingUser = true
	viewFlipped = false
	currentExtension = config.minExtension
	targetExtension = config.minExtension

	updateNameTagsVisibility()
end

local function setThirdPersonMode(player)
	if not player or not player.head then
		return
	end
	resetCameraModeState()
	thirdPersonMode = true

	local headPos = player.head.position
	local headRot = player.head.rotation
	local upVector = (player.root and player.root.rotation and player.root.rotation:getUpVector()) or worldUp
	local cameraAnchor = headPos + (upVector * config.thirdPersonHeight)
	local behindVector = headRot:getForwardVector() * -config.thirdPersonDistance
	local hit = camera:castRay(cameraAnchor, cameraAnchor + behindVector)
	if hit.successful then
		camera.position = hit.position + (hit.normal * 10)
	else
		camera.position = cameraAnchor + behindVector
	end
	camera:lookAt(cameraAnchor, upVector)
	camera.hideNearestHead = false
	applyCameraSmoothness()
	updateNameTagsVisibility()
end

local function setManualOrbitMode(player)
	if not player or not player.head then
		return
	end
	resetCameraModeState()
	manualOrbitMode = true

	local headPos = player.head.position
	config.orbitRadius = math.max(50, Vec3.distance(camera.position, headPos))
	if player.root and player.root.rotation then
		local upRot = player.root.rotation
		local offsetDir = (camera.position - headPos):normalize()
		cameraDirectionEuler = (upRot:inverse() * Quat.fromXZ(-offsetDir, upRot:getUpVector())):euler()
	else
		cameraDirectionEuler = Vec3.new(0, 0, 0)
	end

	camera.hideNearestHead = false
	applyCameraSmoothness()
	updateNameTagsVisibility()
end

local function detectShoulderSide(player)
	if not player or not player.head then
		return nil
	end
	local headRight = player.head.rotation and player.head.rotation:getRightVector() or worldUp
	local cameraDelta = camera.position - player.head.position
	local dot = Vec3.dot(cameraDelta, headRight)
	if dot > 20 then
		return "right"
	elseif dot < -20 then
		return "left"
	end
	return nil
end

local function updateShoulderMode(player, dt)
	if not player or not player.head then
		return
	end
	if not shoulderMode then
		return
	end

	local headPos = player.head.position
	local headRot = player.head.rotation
	local rightVector = headRot:getRightVector()
	local upVector = headRot:getUpVector()
	local forwardVector = headRot:getForwardVector()
	local sideSign = shoulderSide == "left" and -1 or 1
	local shoulderOffset = rightVector * sideSign * 30
	shoulderOffset = shoulderOffset + (upVector * -2)
	shoulderOffset = shoulderOffset + (forwardVector * 8)

	camera.position = headPos + shoulderOffset
	camera.rotation = headRot
	camera.hideNearestHead = false
	updateNameTagsVisibility()
end

local function setShoulderMode(player, side)
	if not player or not player.head then
		return
	end
	resetCameraModeState()
	shoulderMode = true
	shoulderSide = side == "left" and "left" or "right"
	ballIndex = 0
	ballCount = 0
	camera.positionSmoothing = 0
	camera.rotationSmoothing = 0
	camera.hideNearestHead = false
	updateNameTagsVisibility()
	updateShoulderMode(player, 0)
end

local function updateManualOrbitMode(player, dt)
	-- manual orbit uses the camera's remembered direction instead of the player's current head rotation cuz yeah
	-- omg spin edit spin edit
	if not player or not player.head then
		return
	end

	local distanceChangeInput = Input.getAnalog(Input.Key.MouseWheelAxis) * -config.orbitMouseWheelSensitivity
	config.orbitRadius = math.max(10, config.orbitRadius + distanceChangeInput)

	local mouse = Input.getMouseDelta()
	local adjustedMouseSensitivity = 2 * (camera.fieldOfView - 90) / 90 + config.orbitMouseSensitivity
	local adjustedRotSpeed = 2 * (camera.fieldOfView - 90) / 90 + config.orbitRotSpeed

	local lookInputTargetDelta = Vec3.new(0, 0, 0)
	if Input.getKey(Input.Key.RightMouseButton) then
		lookInputTargetDelta.z = lookInputTargetDelta.z + mouse.x * adjustedMouseSensitivity
		lookInputTargetDelta.y = lookInputTargetDelta.y + mouse.y * adjustedMouseSensitivity
	end
	if Input.getKey(Input.Key.D) then
		lookInputTargetDelta.z = lookInputTargetDelta.z + adjustedRotSpeed * dt
	end
	if Input.getKey(Input.Key.A) then
		lookInputTargetDelta.z = lookInputTargetDelta.z - adjustedRotSpeed * dt
	end
	if Input.getKey(Input.Key.S) then
		lookInputTargetDelta.y = lookInputTargetDelta.y + adjustedRotSpeed * dt
	end
	if Input.getKey(Input.Key.W) then
		lookInputTargetDelta.y = lookInputTargetDelta.y - adjustedRotSpeed * dt
	end

	cameraDirectionEuler = cameraDirectionEuler + lookInputTargetDelta
	if cameraDirectionEuler.y > 89.9 then
		cameraDirectionEuler.y = 89.9
	end
	if cameraDirectionEuler.y < -89.9 then
		cameraDirectionEuler.y = -89.9
	end

	local upRot = (player.root and player.root.rotation) or Quat.fromEuler(0, 0, 0)
	local cameraDirection = upRot:rotateVector(
		Quat.fromEuler(cameraDirectionEuler.x, cameraDirectionEuler.y, cameraDirectionEuler.z):getForwardVector()
	) * -1

	camera.position = player.head.position + cameraDirection * config.orbitRadius
	local upVector = (player.root and player.root.rotation and player.root.rotation:getUpVector()) or worldUp
	camera:lookAt(player.head.position, upVector)
	camera.hideNearestHead = false
end

local function updateThirdPersonMode(player, dt)
	if not player or not player.head then
		return
	end
	local headPos = player.head.position
	local headRot = player.head.rotation
	local upVector = (player.root and player.root.rotation and player.root.rotation:getUpVector()) or worldUp
	local cameraAnchor = headPos + (upVector * config.thirdPersonHeight)
	local targetPos = cameraAnchor + (headRot:getForwardVector() * -config.thirdPersonDistance)
	local hit = camera:castRay(cameraAnchor, targetPos)
	if hit.successful then
		targetPos = hit.position + (hit.normal * 10)
	end
	camera.position = targetPos
	camera:lookAt(cameraAnchor, upVector)
	camera.hideNearestHead = false
	local distToTarget = Vec3.distance(camera.position, headPos)
	camera.fieldOfView =
		math.max(60, math.min(config.fov, config.fov - ((config.thirdPersonDistance - distToTarget) / 10)))
end

local function updateFloatingLook(player)
	if not floatingLookMode or not player or not player.head then
		return
	end
	camera.positionSmoothing = 0
	camera.rotationSmoothing = config.cameraSmoothness
	camera:lookAt(player.head.position, worldUp)
	camera.hideNearestHead = false
end

local function tryFindBallNearPosition(position)
	local frame = getGameData()
	if not frame or not frame.balls then
		return 0
	end
	local closestIndex = 0
	local closestDist = BALL_GRAB_RADIUS + 0.001
	for i = 1, #frame.balls do
		local ball = frame.balls[i]
		if ball and ball.transform and ball.transform.position then
			local dist = position:distance(ball.transform.position)
			if dist <= BALL_GRAB_RADIUS and dist < closestDist then
				closestDist = dist
				closestIndex = i
			end
		end
	end
	return closestIndex
end

local function enterBallModeFromPosition(position)
	local frame = getGameData()
	if not frame or not frame.balls then
		return false
	end
	local index = tryFindBallNearPosition(position)
	if index == 0 then
		return false
	end
	ballIndex = index
	ballCount = #frame.balls
	if frame.balls[ballIndex] and frame.balls[ballIndex].transform then
		lastBallPos = frame.balls[ballIndex].transform.position
	else
		lastBallPos = position
	end

	ballMode = true
	viewpointMode = false
	thirdPersonMode = false
	manualOrbitMode = false
	cameraInHand = false
	handHolding = nil
	freeFloatingMode = false
	floatingLookMode = false
	camera.hideNearestHead = false
	camera.positionSmoothing = 0
	camera.rotationSmoothing = 0
	updateNameTagsVisibility()
	return true
end

local function exitBallModeToFirstPerson()
	ballMode = false
	ballIndex = 0
	ballCount = 0
	local player = getPlayerByTarget(getCurrentTarget())
	if player then
		setViewpointMode(player)
	else
		freeFloatingMode = true
		floatingLookMode = false
		floatingLookPlayerId = nil
		thrownMode = false
		viewpointMode = false
		thirdPersonMode = false
		manualOrbitMode = false
		cameraInHand = false
		handHolding = nil
		camera.positionSmoothing = 0
		camera.rotationSmoothing = 0
		updateNameTagsVisibility()
	end
end

local function updateBallMode()
	local frame = getGameData()
	if not frame or not frame.balls then
		exitBallModeToFirstPerson()
		return
	end

	local ball = frame.balls[ballIndex]
	if not ball or #frame.balls ~= ballCount then
		local reacquireIndex = tryFindBallNearPosition(lastBallPos)
		if reacquireIndex == 0 then
			exitBallModeToFirstPerson()
			return
		end
		ballIndex = reacquireIndex
		ballCount = #frame.balls
		ball = frame.balls[ballIndex]
	end

	if not ball or not ball.transform or not ball.transform.position then
		exitBallModeToFirstPerson()
		return
	end

	local ballPos = ball.transform.position
	if camera.position:distance(ballPos) > BALL_LOST_DISTANCE then
		exitBallModeToFirstPerson()
		return
	end

	if ball.velocity and ball.velocity:length() > 0 then
		local dir = ball.velocity:normalize()
		local rayStart = ballPos + (dir * BALL_RAY_OFFSET)
		local ray = camera:castRay(rayStart, rayStart + (ball.velocity * BALL_LATENCY))
		if ray.successful then
			local vector = ray.position - ballPos - (dir * BALL_RAY_OFFSET)
			vector = vector:normalize()
			local reflection = vector - (ray.normal * (vector:dot(ray.normal) * 2))
			camera.position = ray.position - reflection
		else
			camera.position = ballPos + (ball.velocity * BALL_LATENCY)
		end
	else
		camera.position = ballPos
	end

	if ball.transform.rotation then
		camera.rotation = ball.transform.rotation
	end
	camera.positionSmoothing = 0
	camera.rotationSmoothing = 0
	camera.hideNearestHead = false
	updateNameTagsVisibility()
	lastBallPos = ballPos
end

local function processOwnerRecall(dt)
	if shoulderMode then
		ownerRecallTimer = 0
		return false
	end

	if not config.ownerId then
		ownerRecallTimer = 0
		return false
	end
	local owner = getPlayerByTarget(getOwnerTarget())
	if not owner or not owner.head then
		ownerRecallTimer = 0
		return false
	end
	if activePlayerId == config.ownerId and (viewpointMode or cameraInHand) then
		ownerRecallTimer = 0
		return false
	end

	local rightHandPos = getHandPosition(owner, false)
	local leftHandPos = getHandPosition(owner, true)

	local rightHeld = isActionPressed(owner, false, "Recall Camera")
	local leftHeld = isActionPressed(owner, true, "Recall Camera")

	local rightNearHead = rightHandPos and (Vec3.distance(rightHandPos, owner.head.position) <= config.headGrabRadius)
	local leftNearHead = leftHandPos and (Vec3.distance(leftHandPos, owner.head.position) <= config.headGrabRadius)

	local validRight = rightHeld and rightNearHead
	local validLeft = leftHeld and leftNearHead

	local recalling = false
	if config.requireTwoHandsRecall then
		recalling = validRight and validLeft
	else
		recalling = validRight or validLeft
	end

	if not recalling then
		ownerRecallTimer = 0
		return false
	end

	ownerRecallTimer = ownerRecallTimer + dt
	if ownerRecallTimer >= config.ownerRecallTime then
		activePlayerId = config.ownerId
		config.currentPlayerId = activePlayerId
		if saveConfig then
			saveConfig()
		end
		setViewpointMode(owner)
		ownerRecallTimer = 0
		return true
	end
	return false
end

local function displayOwnerRecallStatus()
	if config.ownerId then
		local progress = ownerRecallTimer / config.ownerRecallTime
		local progressPct = math.floor(progress * 100)
		Gui.text("Recall Progress: " .. progressPct .. "%")
	end
end

local function launchSlingshot(player)
	if not player or not player.head then
		return
	end
	slingshotLaunched = true
	slingshotPlayer = player
	slingshotReturning = false
	slingshotLaunchStartTime = t
	slingshotStartPosition = camera.position
	slingshotLaunchDirection = -camera.rotation:getForwardVector()
	slingshotTargetPosition = camera.position + slingshotLaunchDirection * config.slingshotDistance

	slingshotAngleX, slingshotAngleY, slingshotAngleZ = 0, 0, 0

	slingshotSpinX = (math.random() - 0.5) * 5000
	slingshotSpinY = (math.random() - 0.5) * 5000
	slingshotSpinZ = (math.random() - 0.5) * 5000

	cameraInHand = false
	thrownMode = false
	handHolding = nil
	freeFloatingMode = true
	viewpointMode = false
	thirdPersonMode = false
	manualOrbitMode = false
end

local function updateSlingshot(dt)
	-- i tried to make boomerang then it turned to this then it coulkdnt rotate then i made throwing then it all sucks idk bro misery
	if not slingshotPlayer or not slingshotPlayer.head then
		slingshotLaunched = false
		slingshotReturning = false
		return
	end

	if not slingshotReturning then
		local elapsed = t - slingshotLaunchStartTime
		if elapsed < config.slingshotLaunchTime then
			local progress = elapsed / config.slingshotLaunchTime
			camera.position = slingshotStartPosition + (slingshotTargetPosition - slingshotStartPosition) * progress

			slingshotAngleX = slingshotAngleX + (slingshotSpinX * dt)
			slingshotAngleY = slingshotAngleY + (slingshotSpinY * dt)
			slingshotAngleZ = slingshotAngleZ + (slingshotSpinZ * dt)

			camera.rotation = Quat.fromAngleAxis(slingshotAngleX, Vec3.new(1, 0, 0))
				* Quat.fromAngleAxis(slingshotAngleY, Vec3.new(0, 1, 0))
				* Quat.fromAngleAxis(slingshotAngleZ, Vec3.new(0, 0, 1))
			camera.positionSmoothing = 0
			camera.rotationSmoothing = 0
		else
			slingshotReturning = true
			slingshotReturnStartTime = t
			slingshotReturnStartPos = camera.position
			slingshotReturnTargetPos = slingshotPlayer.head.position
				+ slingshotPlayer.head.rotation:rotateVector(config.viewpointOffset)
		end
	else
		local elapsed = t - slingshotReturnStartTime
		if elapsed < config.slingshotReturnTime then
			local progress = elapsed / config.slingshotReturnTime
			camera.position = slingshotReturnStartPos + (slingshotReturnTargetPos - slingshotReturnStartPos) * progress
			slingshotSpinAngle = slingshotSpinAngle + dt * config.slingshotSpinSpeed * math.pi / 180
			local currentDirection = (slingshotReturnTargetPos - camera.position):normalize()
			camera.rotation = Quat.lookAt(currentDirection, worldUp)
				* Quat.fromAngleAxis(slingshotSpinAngle, currentDirection)
			camera.positionSmoothing = 0
			camera.rotationSmoothing = 0
		else
			setViewpointMode(slingshotPlayer)
			slingshotLaunched = false
			slingshotReturning = false
			slingshotPlayer = nil
		end
	end
end

function beginRightHandGrip(player, handPos, handRot)
	if not player or not handPos or not handRot then
		return
	end
	local headPos = player.head.position
	local headToHand = handPos - headPos
	local headToHandDir = headToHand:normalize()
	local upVector = worldUp
	local rightVector = Vec3.cross(headToHandDir, upVector):normalize()
	local stableForward = Vec3.cross(upVector, rightVector):normalize()
	local cameraPos = handPos + (upVector * rightHandOffset.y) + (stableForward * rightHandOffset.z)
	camera.position = cameraPos
	if facingUser then
		camera:lookAt(player.head.position, worldUp)
	else
		local lookAwayPoint = cameraPos + (headToHandDir * -100)
		camera:lookAt(lookAwayPoint, worldUp)
	end
	camera.hideNearestHead = false
	updateNameTagsVisibility()
	applyCameraSmoothness()

	currentExtension = config.minExtension
	targetExtension = config.minExtension

	cameraInHand = true
	thrownMode = false
	handHolding = "right"
	viewpointMode = false
	thirdPersonMode = false
	freeFloatingMode = false
	ballMode = false
	shoulderMode = false
	shoulderSide = "right"
	floatingLookMode = false
	floatingLookPlayerId = nil
	floatingLookButtonsWasPressed = false
	ballIndex = 0
	ballCount = 0

	isRightGrabAttempt = false
	isLeftGrabAttempt = false
	grabAttemptTime = 0

	if debugMode then
		print("Camera grabbed with right hand")
	end
end

function beginLeftHandGrip(player, handPos, handRot)
	if not player or not handPos or not handRot then
		return
	end
	local headPos = player.head.position
	local headToHand = handPos - headPos
	local headToHandDir = headToHand:normalize()
	local upVector = worldUp
	local rightVector = Vec3.cross(headToHandDir, upVector):normalize()
	local stableForward = Vec3.cross(upVector, rightVector):normalize()
	local cameraPos = handPos + (upVector * leftHandOffset.y) + (stableForward * leftHandOffset.z)
	camera.position = cameraPos
	if facingUser then
		camera:lookAt(player.head.position, worldUp)
	else
		local lookAwayPoint = cameraPos + (headToHandDir * -100)
		camera:lookAt(lookAwayPoint, worldUp)
	end
	camera.hideNearestHead = false
	updateNameTagsVisibility()
	applyCameraSmoothness()

	currentExtension = config.minExtension
	targetExtension = config.minExtension

	cameraInHand = true
	thrownMode = false
	handHolding = "left"
	viewpointMode = false
	thirdPersonMode = false
	freeFloatingMode = false
	ballMode = false
	shoulderMode = false
	shoulderSide = "right"
	ballIndex = 0
	ballCount = 0

	isRightGrabAttempt = false
	isLeftGrabAttempt = false
	grabAttemptTime = 0

	if debugMode then
		print("Camera grabbed with left hand")
	end
end

local function forceOwnerHandheld()
	local owner = getPlayerByTarget(getOwnerTarget())
	if not owner then
		return false
	end

	local rightHandPos, rightHandRot = getHandPosition(owner, false)
	local leftHandPos, leftHandRot = getHandPosition(owner, true)

	if rightHandPos and rightHandRot then
		activePlayerTarget = getOwnerTarget()
		activePlayerId = config.ownerId
		config.currentPlayerId = activePlayerId
		if saveConfig then
			saveConfig()
		end
		facingUser = true
		viewFlipped = false
		beginRightHandGrip(owner, rightHandPos, rightHandRot)
		return true
	end
	if leftHandPos and leftHandRot then
		activePlayerTarget = getOwnerTarget()
		activePlayerId = config.ownerId
		config.currentPlayerId = activePlayerId
		if saveConfig then
			saveConfig()
		end
		facingUser = true
		viewFlipped = false
		beginLeftHandGrip(owner, leftHandPos, leftHandRot)
		return true
	end
	return false
end

function updateRightHandGrip(player, handPos, handRot, dt)
	if not player or not handPos then
		return
	end
	local headPos = player.head.position
	local headToHand = handPos - headPos
	local headToHandDir = headToHand:normalize()
	local upVector = worldUp
	local rightVector = Vec3.cross(headToHandDir, upVector):normalize()
	local stableForward = Vec3.cross(upVector, rightVector):normalize()
	local basePos = handPos + (upVector * rightHandOffset.y) + (stableForward * rightHandOffset.z)

	local rightFlipPressed = isFlipPressed(player, false)
	local leftGripPressed = isGripPressed(player, true)
	local leftTriggerPressed = isTriggerPressed(player, true)

	if leftTriggerPressed and not lastSecondaryTriggerState then
		table.insert(triggerPressTimes, t)
		while #triggerPressTimes > 0 and t - triggerPressTimes[1] > config.doubleClickThreshold do
			table.remove(triggerPressTimes, 1)
		end
		if #triggerPressTimes >= 2 and config.slingshotEnabled then
			launchSlingshot(player)
			triggerPressTimes = {}
		end
	end
	lastSecondaryTriggerState = leftTriggerPressed

	if config.flipEnabled and rightFlipPressed and not lastRightGripState then
		flipCameraView()
	end
	lastRightGripState = rightFlipPressed

	if config.extensionEnabled then
		if leftTriggerPressed then
			targetExtension = math.min(targetExtension + config.extensionStep * dt * 60, config.maxExtension)
		elseif leftGripPressed then
			targetExtension = math.max(targetExtension - config.extensionStep * dt * 60, config.minExtension)
		end
		if config.extensionSmoothness > 0 then
			currentExtension = lerp(currentExtension, targetExtension, (1 - config.extensionSmoothness))
		else
			currentExtension = targetExtension
		end
	end

	local extensionVector = headToHandDir * currentExtension
	local extendedPos = basePos + extensionVector
	camera.position = extendedPos

	if facingUser then
		camera:lookAt(headPos, worldUp)
	else
		local awayFromHead = (camera.position - headPos):normalize()
		local lookAwayPoint = camera.position + (awayFromHead * 100)
		camera:lookAt(lookAwayPoint, worldUp)
	end

	camera.hideNearestHead = false
	updateNameTagsVisibility()
	applyCameraSmoothness()

	if debugMode then
		print("Right Hand Grip: Extension=" .. tostring(currentExtension) .. ", Facing=" .. tostring(facingUser))
	end
end

function updateLeftHandGrip(player, handPos, handRot, dt)
	if not player or not handPos then
		return
	end
	local headPos = player.head.position
	local headToHand = handPos - headPos
	local headToHandDir = headToHand:normalize()
	local upVector = worldUp
	local rightVector = Vec3.cross(headToHandDir, upVector):normalize()
	local stableForward = Vec3.cross(upVector, rightVector):normalize()
	local basePos = handPos + (upVector * leftHandOffset.y) + (stableForward * leftHandOffset.z)

	local leftFlipPressed = isFlipPressed(player, true)
	local rightGripPressed = isGripPressed(player, false)
	local rightTriggerPressed = isTriggerPressed(player, false)

	if rightTriggerPressed and not lastSecondaryTriggerState then
		table.insert(triggerPressTimes, t)
		while #triggerPressTimes > 0 and t - triggerPressTimes[1] > config.doubleClickThreshold do
			table.remove(triggerPressTimes, 1)
		end
		if #triggerPressTimes >= 2 and config.slingshotEnabled then
			launchSlingshot(player)
			triggerPressTimes = {}
		end
	end
	lastSecondaryTriggerState = rightTriggerPressed

	if config.flipEnabled and leftFlipPressed and not lastLeftGripState then
		flipCameraView()
	end
	lastLeftGripState = leftFlipPressed

	if config.extensionEnabled then
		if rightTriggerPressed then
			targetExtension = math.min(targetExtension + config.extensionStep * dt * 60, config.maxExtension)
		elseif rightGripPressed then
			targetExtension = math.max(targetExtension - config.extensionStep * dt * 60, config.minExtension)
		end
		if config.extensionSmoothness > 0 then
			currentExtension = lerp(currentExtension, targetExtension, (1 - config.extensionSmoothness))
		else
			currentExtension = targetExtension
		end
	end

	local extensionVector = headToHandDir * currentExtension
	local extendedPos = basePos + extensionVector
	camera.position = extendedPos

	if facingUser then
		camera:lookAt(headPos, worldUp)
	else
		local awayFromHead = (camera.position - headPos):normalize()
		local lookAwayPoint = camera.position + (awayFromHead * 100)
		camera:lookAt(lookAwayPoint, worldUp)
	end

	camera.hideNearestHead = false
	updateNameTagsVisibility()
	applyCameraSmoothness()

	if debugMode then
		print("Left Hand Grip: Extension=" .. tostring(currentExtension) .. ", Facing=" .. tostring(facingUser))
	end
end

local function isPointInsideOrientedBox(point, cube)
	if not point or not cube or not cube.position or not cube.rotation or not cube.scale then
		return false
	end

	local rot = Quat.fromEuler(cube.rotation.x, cube.rotation.y, cube.rotation.z)
	local xAxis = rot:getRightVector()
	local yAxis = rot:getUpVector()
	local zAxis = rot:getForwardVector()
	local dx = point - cube.position

	local x = Vec3.dot(dx, xAxis)
	local y = Vec3.dot(dx, yAxis)
	local z = Vec3.dot(dx, zAxis)

	return math.abs(x) <= cube.scale.x * 0.5 and math.abs(y) <= cube.scale.y * 0.5 and math.abs(z) <= cube.scale.z * 0.5
end

local function getScraprunWallAxis(axisName, xAxis, yAxis, zAxis)
	if axisName == "X" then
		return xAxis, 1
	elseif axisName == "-X" then
		return xAxis, -1
	elseif axisName == "Y" then
		return yAxis, 1
	elseif axisName == "-Y" then
		return yAxis, -1
	elseif axisName == "Z" then
		return zAxis, 1
	elseif axisName == "-Z" then
		return zAxis, -1
	end
	return nil, nil
end

local function getScraprunProgress(point, cube)
	if
		not point
		or not cube
		or not cube.position
		or not cube.rotation
		or not cube.scale
		or not cube.startAxis
		or not cube.endAxis
	then
		return nil
	end

	local rot = Quat.fromEuler(cube.rotation.x, cube.rotation.y, cube.rotation.z)
	local xAxis = rot:getRightVector()
	local yAxis = rot:getUpVector()
	local zAxis = rot:getForwardVector()
	local dx = point - cube.position

	local startAxis, startSign = getScraprunWallAxis(cube.startAxis, xAxis, yAxis, zAxis)
	local endAxis, endSign = getScraprunWallAxis(cube.endAxis, xAxis, yAxis, zAxis)
	if not startAxis or not endAxis or startAxis ~= endAxis then
		return nil
	end

	local axisLength = cube.scale[cube.startAxis:sub(-1):lower()]
	if not axisLength or axisLength <= 0 then
		return nil
	end

	local coord = Vec3.dot(dx, startAxis)
	local startCoord = startSign * axisLength * 0.5
	local endCoord = endSign * axisLength * 0.5
	local progress = (coord - startCoord) / (endCoord - startCoord)
	if progress < 0 then
		progress = 0
	end
	if progress > 1 then
		progress = 1
	end
	return progress
end

local function isPointInsideOrientedBox(point, cube, padding)
	padding = padding or scraprunboxpadding or 0
	if not point or not cube or not cube.position or not cube.rotation or not cube.scale then
		return false
	end

	local rot = Quat.fromEuler(cube.rotation.x, cube.rotation.y, cube.rotation.z)
	local xAxis = rot:getRightVector()
	local yAxis = rot:getUpVector()
	local zAxis = rot:getForwardVector()
	local dx = point - cube.position

	local x = Vec3.dot(dx, xAxis)
	local y = Vec3.dot(dx, yAxis)
	local z = Vec3.dot(dx, zAxis)

	return math.abs(x) <= (cube.scale.x * 0.5 + padding)
		and math.abs(y) <= (cube.scale.y * 0.5 + padding)
		and math.abs(z) <= (cube.scale.z * 0.5 + padding)
end

local function getBestScraprunPlayer()
	local players = getPlayers()
	local best = nil
	local bestScore = -math.huge

	for i = 1, #players do
		local p = players[i]
		local player = getPlayerByTarget({ id = p.id, sessionIndex = p.sessionIndex })

		local pos = nil
		if player and player.head and player.head.position then
			pos = player.head.position
		elseif player and player.root and player.root.position then
			pos = player.root.position
		end

		if pos then
			for j = 1, #scraprunCubes do
				local cube = scraprunCubes[j]
				if isPointInsideOrientedBox(pos, cube, scraprunboxpadding) then
					local progress = getScraprunProgress(pos, cube)
					if progress ~= nil then
						local rankScore = (j * 1000000) + (progress * 100000)
						if rankScore > bestScore then
							bestScore = rankScore
							best = {
								id = p.id,
								sessionIndex = p.sessionIndex,
								player = player,
								name = p.name,
								cubeName = cube.name,
								cubeProgress = progress,
								score = rankScore,
							}
						end
					end
				end
			end
		end
	end

	if best then
		scraprunBestPlayerName = best.name or "Unknown"
		scraprunBestCubeName = best.cubeName or "Unknown"
	else
		scraprunBestPlayerName = "None"
		scraprunBestCubeName = "None"
	end

	return best
end

local function updateScraprunFollow(dt)
	local best = getBestScraprunPlayer()

	if not best or not best.player then
		if activePlayerId ~= nil then
			activePlayerId = nil
			activePlayerTarget = nil
			if camera then
				camera.position = Vec3.new(-16749.119, 5031.522, 28948.580)
				camera.rotation = Quat.fromEuler(210, 0, -270.465)
				camera.hideNearestHead = false
				camera.positionSmoothing = 0
				camera.rotationSmoothing = 0
			end
		end
		return
	end

	if best.id ~= activePlayerId then
		if pendingBestPlayerId ~= best.id then
			pendingBestPlayerId = best.id
			scraprunTargetSwitchTimer = 0
		else
			scraprunTargetSwitchTimer = scraprunTargetSwitchTimer + dt
		end

		if scraprunTargetSwitchTimer >= scraprunswitchdebounce or activePlayerId == nil then
			activePlayerTarget = { id = best.id, sessionIndex = best.sessionIndex }
			activePlayerId = best.id
			selectedPlayerTarget = { id = best.id, sessionIndex = best.sessionIndex }
			if saveConfig then
				saveConfig()
			end

			manualOrbitMode = false
			cameraInHand = false
			handHolding = nil
			freeFloatingMode = false
			ballMode = false
			shoulderMode = false
			shoulderSide = "right"
			thrownMode = false
			facingUser = true
			viewFlipped = false

			if thirdPersonMode then
				setThirdPersonMode(best.player)
			else
				setViewpointMode(best.player)
			end
		end
	else
		pendingBestPlayerId = best.id
		scraprunTargetSwitchTimer = 0

		if thirdPersonMode then
			updateThirdPersonMode(best.player, dt)
		else
			if camera and best.player.head then
				camera.position = best.player.head.position
				camera.rotation = best.player.head.rotation
				applyCameraSmoothness(true)
				camera.hideNearestHead = config.hideHead
				updateNameTagsVisibility()
			end
		end
	end
end

local function getNearestSurfaceFloor(position, maxDistance)
	if not camera or not position then
		return nil
	end

	local rayEnd = position - (worldUp * (maxDistance or 100000))
	local hit = camera:castRay(position, rayEnd)
	if hit and hit.successful and hit.position and hit.normal and hit.normal:length() > 0 then
		return hit
	end
	return nil
end

local function getThrownCameraContactDistance(startPos, endPos, player)
	if not startPos or not endPos or not player then
		return nil
	end

	local bodyPositions = {}
	if player.root and player.root.position then
		table.insert(bodyPositions, player.root.position)
	end
	if player.head and player.head.position then
		table.insert(bodyPositions, player.head.position)
	end
	local leftHandPos = getHandPosition(player, true)
	if leftHandPos then
		table.insert(bodyPositions, leftHandPos)
	end
	local rightHandPos = getHandPosition(player, false)
	if rightHandPos then
		table.insert(bodyPositions, rightHandPos)
	end

	local throwVector = endPos - startPos
	local throwLengthSquared = throwVector:squaredLength()
	local closestDist = nil
	for i = 1, #bodyPositions do
		local bodyOffset = bodyPositions[i] - startPos
		local progress = 0
		if throwLengthSquared > 0 then
			progress = math.max(0, math.min(1, Vec3.dot(bodyOffset, throwVector) / throwLengthSquared))
		end
		local contactPos = startPos + (throwVector * progress)
		local dist = Vec3.distance(contactPos, bodyPositions[i])
		if not closestDist or dist < closestDist then
			closestDist = dist
		end
	end

	return closestDist
end

local function tryFollowPlayerOnThrownCameraContact(startPos, endPos)
	local players = getPlayers()
	if #players == 0 then
		return false
	end

	local closestPlayer = nil
	local closestTarget = nil
	local closestDist = math.huge

	for i = 1, #players do
		local p = players[i]
		local target = { id = p.id, sessionIndex = p.sessionIndex }
		if target.id ~= activePlayerId and target.id ~= config.currentPlayerId then
			local player = getPlayerByTarget(target)
			local distToPlayer = getThrownCameraContactDistance(startPos, endPos, player)
			if distToPlayer and distToPlayer <= config.headGrabRadius and distToPlayer < closestDist then
				closestPlayer = player
				closestTarget = target
				closestDist = distToPlayer
			end
		end
	end

	if closestPlayer and closestTarget then
		activePlayerTarget = closestTarget
		activePlayerId = closestTarget.id
		config.currentPlayerId = activePlayerId
		if saveConfig then
			saveConfig()
		end

		facingUser = true
		viewFlipped = false
		currentExtension = config.minExtension
		targetExtension = config.minExtension

		setViewpointMode(closestPlayer)
		return true
	end

	return false
end

local function handleCameraRelease(player, releaseVelocity)
	local headNearby = false
	local newOwnerFound = false
	if enterBallModeFromPosition(camera.position) then
		return newOwnerFound
	end

	if releaseVelocity and releaseVelocity:length() > config.throwThreshold then
		thrownMode = true
		floatingLookMode = false
		throwVelocity = releaseVelocity * 1.25
		viewpointMode = false
		thirdPersonMode = false
		manualOrbitMode = false
		cameraInHand = false
		handHolding = nil
		ballMode = false
		freeFloatingMode = false
		shoulderMode = false
		shoulderSide = "right"
		ballIndex = 0
		ballCount = 0
		camera.positionSmoothing = 0
		camera.rotationSmoothing = 0
		updateNameTagsVisibility()
		return newOwnerFound
	end

	local shoulderSideDetected = detectShoulderSide(player)
	local shoulderDropDistance = player and player.head and Vec3.distance(camera.position, player.head.position)
	if shoulderSideDetected and shoulderDropDistance and shoulderDropDistance <= config.shoulderDropRadius then
		setShoulderMode(player, shoulderSideDetected)
		return newOwnerFound
	end

	local players = getPlayers()
	for i = 1, #players do
		local otherPlayer = getPlayerById(players[i].id)
		if otherPlayer and otherPlayer.head then
			local distToHead = Vec3.distance(camera.position, otherPlayer.head.position)
			if distToHead < config.headDropRadius then
				activePlayerId = players[i].id
				facingUser = true
				viewFlipped = false
				currentExtension = config.minExtension
				targetExtension = config.minExtension
				setViewpointMode(otherPlayer)
				headNearby = true
				newOwnerFound = true
				return newOwnerFound
			end
		end
	end
	if not headNearby and player and player.head then
		local distToHead = Vec3.distance(camera.position, player.head.position)
		if distToHead < config.headDropRadius then
			local headPos = player.head.position
			local camPos = camera.position
			local camForward = camera.rotation:getForwardVector()
			local headToCam = (camPos - headPos):normalize()
			local isFacingHead = Vec3.dot(camForward, headToCam) < 0
			if isFacingHead then
				facingUser = true
				viewFlipped = false
				currentExtension = config.minExtension
				targetExtension = config.minExtension
				setViewpointMode(player)
			else
				setThirdPersonMode(player)
			end
			headNearby = true
			return newOwnerFound
		end
	end
	if not headNearby then
		freeFloatingMode = true
		floatingLookMode = false
		viewpointMode = false
		thirdPersonMode = false
		manualOrbitMode = false
		cameraInHand = false
		handHolding = nil
		ballMode = false
		ballIndex = 0
		ballCount = 0
		camera.positionSmoothing = 0
		camera.rotationSmoothing = 0
		updateNameTagsVisibility()
	end
	return newOwnerFound
end

local function drawHomeTab()
	Gui.separatorText(Icon.InfoCircle .. "  State")

	local ownerPlayerObj = getPlayerByTarget(getOwnerTarget())
	local ownerText = ownerPlayerObj and ownerPlayerObj.playerName or "None"
	local ownerStatus = config.ownerId and (ownerIsPresent and Icon.Check or Icon.Times) or ""

	local followingPlayerObj = getPlayerByTarget(getCurrentTarget())
	local followingText = followingPlayerObj and followingPlayerObj.playerName or "None"
	local modeText = "unknown"
	local modeDetailText = nil

	if shoulderMode then
		modeText = "Shoulder (" .. shoulderSide .. ")"
		modeDetailText = "Shoulder: " .. shoulderSide
	elseif viewpointMode then
		modeText = "First Person"
	elseif thirdPersonMode then
		modeText = "Third Person"
		modeDetailText = "Distance: " .. string.format("%.0f", config.thirdPersonDistance) .. "cm"
	elseif manualOrbitMode then
		modeText = "Manual Orbit"
		modeDetailText = "Radius: " .. string.format("%.0f", config.orbitRadius) .. "cm"
	elseif cameraInHand then
		local handText = (handHolding == "right" and "right" or "left") .. " hand"
		local facingText = facingUser and "facing user" or "facing away"
		local extText = string.format("%.0f", currentExtension) .. "cm"
		modeText = "Handheld (" .. handText .. ")"
		modeDetailText = "Direction: " .. facingText .. "\nextension: " .. extText
	elseif freeFloatingMode then
		modeText = floatingLookMode and "Floating + Looking" or "Floating"
	elseif ballMode then
		modeText = "Ball"
	end

	Gui.beginChild("ownerState##PlayercamHomeOwner", 180, 70, true)
	Gui.text(Icon.Crown .. "  Owner")
	Gui.text(ownerText .. (ownerStatus ~= "" and (" " .. ownerStatus) or ""))
	Gui.endChild()
	Gui.sameLine()

	Gui.beginChild("followingState##PlayercamHomeFollowing", 180, 70, true)
	Gui.text(Icon.ChevronRight .. "  Following")
	Gui.text(followingText)
	Gui.endChild()
	Gui.sameLine()

	Gui.beginChild("modeState##PlayercamHomeMode", 180, 70, true)
	Gui.text(Icon.Camera .. "  Mode")
	Gui.text(modeText)
	Gui.endChild()
	Gui.newLine()

	if config.ownerId and ownerIsPresent then
		displayOwnerRecallStatus()
	end
	if viewpointMode and (isRightGrabAttempt or isLeftGrabAttempt) then
		local progress = (t - grabAttemptTime) / config.grabDelayTime
		local progressPct = math.floor(progress * 100)
		Gui.text("grab progress: " .. progressPct .. "%")
	elseif modeDetailText and not viewpointMode then
		Gui.text(modeDetailText)
	end

	Gui.separatorText(Icon.Users .. "  Players")
	if config.followBestScraprunPlayer then
		Gui.beginDisabled()
	end
	searchText = Gui.inputText(Icon.Search .. "  Search", searchText)
	Gui.setItemTooltip("Filter by name")

	local players = getPlayers()

	if #players > 0 then
		if Gui.beginListBox("Players##Playercam_home") then
			for i = 1, #players do
				Gui.pushId(tostring(i))
				local p = players[i]
				if playerMatchesSearch(p.name, searchText) then
					local displayName = p.name
					if isSameTarget(p, getCurrentTarget()) then
						displayName = "> " .. displayName
					end
					if isSameTarget(p, getOwnerTarget()) then
						displayName = displayName .. " (Owner)"
					end

					local isSelected = isSameTarget(p, selectedPlayerTarget)

					if Gui.selectable(displayName, isSelected) then
						selectedPlayerTarget = { id = p.id, sessionIndex = p.sessionIndex }
					end
				end
				Gui.popId()
			end
			Gui.endListBox()
		end
	end

	if selectedPlayerTarget then
		local isFollowing = isSameTarget(selectedPlayerTarget, getCurrentTarget())
		local followLabel = isFollowing and "Following Player" or "Start Follow"

		if isFollowing then
			Gui.beginDisabled()
		end
		if Gui.button(Icon.ChevronRight .. "  " .. followLabel) then
			config.followBestScraprunPlayer = false
			activePlayerTarget = { id = selectedPlayerTarget.id, sessionIndex = selectedPlayerTarget.sessionIndex }
			activePlayerId = selectedPlayerTarget.id
			if saveConfig then
				saveConfig()
			end
			local newPlayer = getPlayerByTarget(getCurrentTarget())
			if newPlayer then
				setViewpointMode(newPlayer)
			end
		end
		if isFollowing then
			Gui.endDisabled()
		end

		Gui.sameLine()
		local isCurrentlyOwner = isSameTarget(selectedPlayerTarget, getOwnerTarget())
		local ownerButtonText = isCurrentlyOwner and "Remove Owner" or "Set Owner"
		if Gui.button(Icon.Crown .. "  " .. ownerButtonText) then
			if isCurrentlyOwner then
				config.ownerTarget = nil
				config.ownerId = nil
				ownerIsPresent = false
				ownerPlayer = nil
			else
				config.ownerTarget = { id = selectedPlayerTarget.id, sessionIndex = selectedPlayerTarget.sessionIndex }
				config.ownerId = selectedPlayerTarget.id
				checkForOwnerPresence()
			end
			if saveConfig then
				saveConfig()
			end
		end
	else
		Gui.beginDisabled()
		Gui.button(Icon.ChevronRight .. "  Start Follow")
		Gui.sameLine()
		Gui.button(Icon.Crown .. "  Set Owner")
		Gui.endDisabled()
		Gui.textDisabled("Select a player to interact")
	end

	local canForceOwnerHandheld = config.ownerId and ownerIsPresent
	if not canForceOwnerHandheld then
		Gui.beginDisabled()
	end
	if not canForceOwnerHandheld then
		Gui.endDisabled()
	end
	Gui.setItemTooltip("Place the camera in the owner's available hand.")

	if config.followBestScraprunPlayer then
		Gui.endDisabled()
	end

	Gui.separatorText(Icon.Camera .. "  Camera Mode")
	local currentPlayer = getPlayerByTarget(getCurrentTarget())

	if config.followBestScraprunPlayer then
		if Gui.button("First Person Mode") then
			if currentPlayer then
				facingUser = true
				viewFlipped = false
				currentExtension = config.minExtension
				targetExtension = config.minExtension
				setViewpointMode(currentPlayer)
			end
		end
		Gui.setItemTooltip("Attach the camera to the selected player's head.")

		Gui.sameLine()

		if Gui.button("Third Person Mode") then
			if currentPlayer then
				setThirdPersonMode(currentPlayer)
			end
		end
		Gui.setItemTooltip("Track the selected player from behind.")

		Gui.sameLine()

		if not currentPlayer then
			Gui.newLine()
			Gui.textDisabled("Select a player first")
		end
	else
		if viewpointMode then
			Gui.beginDisabled()
		end
		if Gui.button("First Person Mode") then
			if currentPlayer then
				facingUser = true
				viewFlipped = false
				currentExtension = config.minExtension
				targetExtension = config.minExtension
				setViewpointMode(currentPlayer)
			end
		end
		if viewpointMode then
			Gui.endDisabled()
		end
		Gui.setItemTooltip("Attach the camera to the selected player's head.")

		Gui.sameLine()

		if thirdPersonMode then
			Gui.beginDisabled()
		end
		if Gui.button("Third Person Mode") then
			if currentPlayer then
				setThirdPersonMode(currentPlayer)
			end
		end
		if thirdPersonMode then
			Gui.endDisabled()
		end
		Gui.setItemTooltip("Track the selected player from behind.")

		Gui.sameLine()

		if manualOrbitMode then
			Gui.beginDisabled()
		end
		if Gui.button("Manual Orbit") then
			if currentPlayer then
				setManualOrbitMode(currentPlayer)
			end
		end
		if manualOrbitMode then
			Gui.endDisabled()
		end
		Gui.setItemTooltip("Manually orbit around the selected player using WASD and Mouse.")

		local leftShoulderDisabled = shoulderMode and shoulderSide == "left"
		local rightShoulderDisabled = shoulderMode and shoulderSide == "right"

		if leftShoulderDisabled then
			Gui.beginDisabled()
		end
		if Gui.button("Left Shoulder") then
			if currentPlayer then
				setShoulderMode(currentPlayer, "left")
			end
		end
		if leftShoulderDisabled then
			Gui.endDisabled()
		end
		Gui.setItemTooltip("Rests camera at left shoulder")

		Gui.sameLine()

		if rightShoulderDisabled then
			Gui.beginDisabled()
		end
		if Gui.button("Right Shoulder") then
			if currentPlayer then
				setShoulderMode(currentPlayer, "right")
			end
		end
		if rightShoulderDisabled then
			Gui.endDisabled()
		end
		Gui.setItemTooltip("Rests camera at right shoulder")

		if freeFloatingMode then
			Gui.sameLine()
			if Gui.button("Look at player") then
				floatingLookMode = not floatingLookMode
				floatingLookPlayerId = floatingLookMode and activePlayerId or nil
			end
		end
	end
end

local function drawHowToUseTab()
	Gui.separatorText(Icon.InfoCircle .. "  What is Playercam?")
	Gui.text("Playercam is a player camera with first + third person mode, owner, handheld mode, and a bit more.")
	Gui.textDisabled("(Made mainly for simple recording, live streaming, and in-game showing off)")

	Gui.separatorText(Icon.InfoCircle .. "  Credits")
	Gui.text("This is a fork of Pub's DriftVision and all original credit to them!!!!!!!")
	Gui.newLine()

	Gui.separatorText(Icon.Camera .. "  Camera Modes")
	Gui.text("First Person (POV): Attaches directly to the target player's head.")
	Gui.text("Third Person: Tracks behind the player at a configurable distance.")
	Gui.text("Handheld: Grab the camera by holding Trigger near your head.")
	Gui.text("Free-Floating: Release a handheld camera in open space to leave it flying.")
	Gui.text("Ball Mode: Release the camera near a ball to attach and track the ball.")
	Gui.text("Manual Orbit: Use WASD, Right-Click + Drag, and Scroll Wheel to orbit and zoom around the target.")
	Gui.newLine()

	Gui.separatorText(Icon.Keyboard .. "  Controls")

	local function addControl(action, input)
		Gui.text(action .. ":")
		Gui.sameLine()
		Gui.textDisabled(input)
	end

	Gui.text(Icon.InfoCircle .. "  While normal:")
	Gui.indent()

	addControl("Grab Camera", "Hold Trigger near head or camera for  1.5s (customizable)")
	addControl("Toggle POV / Third Person", "Press Grip while hand is near head")

	Gui.unindent()
	Gui.newLine()

	Gui.text(Icon.InfoCircle .. "  While holding:")
	Gui.indent()

	addControl("Flip Camera Direction", "Press Grip on the hand holding the camera")
	addControl("Extend / Retract", "Hold opposite Trigger (extend) or Grip (retract)")
	addControl("Launch Slingshot", "Double-click opposite Trigger while holding camera")
	addControl("Instant Owner Recall", "Hold BOTH Triggers simultaneously for 1.5s")
	addControl("Pass temporarily to Another Player", "Drop handheld camera near another player's head")
	Gui.newLine()

	Gui.unindent()
end

local function drawSettingsTab()
	local changed = false

	Gui.separatorText("Quick Settings")

	local newShowNameTags = Gui.checkbox("Show name tags", config.nameTagType ~= 2)
	if newShowNameTags ~= (config.nameTagType ~= 2) then
		config.nameTagType = newShowNameTags and 0 or 2
		updateNameTagsVisibility()
		changed = true
	end

	local newFov = Gui.sliderFloat("Field of View", config.fov, 80, 130)
	if newFov ~= config.fov then
		config.fov = newFov
		changed = true
	end

	local newCameraSmoothness = Gui.sliderFloat("Smoothness", config.cameraSmoothness, 0, 0.5)
	if newCameraSmoothness ~= config.cameraSmoothness then
		config.cameraSmoothness = newCameraSmoothness
		if thirdPersonMode or manualOrbitMode then
			applyCameraSmoothness()
		else
			disableCameraSmoothness()
		end
		changed = true
	end

	Gui.separatorText("Controls")
	local controlOptions = { "Trigger", "Grip", "Disabled" }
	local controlBindings = {
		{ label = "Grab Camera", configKey = "grabCameraControl" },
		{ label = "Recall Camera", configKey = "recallCameraControl" },
		{ label = "Mode Toggle", configKey = "modeToggleControl" },
	}
	for i = 1, #controlBindings do
		local binding = controlBindings[i]
		local currentControl = config[binding.configKey]
		if Gui.beginCombo(binding.label, currentControl) then
			for j = 1, #controlOptions do
				local option = controlOptions[j]
				if Gui.selectable(option, currentControl == option) then
					config[binding.configKey] = option
					changed = true
				end
			end
			Gui.endCombo()
		end
	end

	local newFloatingLookToggleEnabled = Gui.checkbox("Press all buttons to Look", config.floatingLookToggleEnabled)
	if newFloatingLookToggleEnabled ~= config.floatingLookToggleEnabled then
		config.floatingLookToggleEnabled = newFloatingLookToggleEnabled
		changed = true
	end
	Gui.sameLine()
	Gui.textDisabled("Press All Trigger & Grips, and the camera will always face player")

	Gui.separatorText("Camera")

	local newFlipEnabled = Gui.checkbox("Enable Camera Flipping", config.flipEnabled)
	if newFlipEnabled ~= config.flipEnabled then
		config.flipEnabled = newFlipEnabled
		changed = true
	end

	local newHideHead = Gui.checkbox("Hide Head in First Person", config.hideHead)
	if newHideHead ~= config.hideHead then
		config.hideHead = newHideHead
		changed = true
	end

	local newRequireTwoHandsRecall = Gui.checkbox("Require 2 hands to Recall", config.requireTwoHandsRecall)
	if newRequireTwoHandsRecall ~= config.requireTwoHandsRecall then
		config.requireTwoHandsRecall = newRequireTwoHandsRecall
		changed = true
	end

	local newOwnerRecallTime = Gui.sliderFloat("Recall Hold Time", config.ownerRecallTime, 0.5, 5.0)
	if newOwnerRecallTime ~= config.ownerRecallTime then
		config.ownerRecallTime = newOwnerRecallTime
		changed = true
	end

	Gui.sameLine()
	Gui.textDisabled("(sec)")

	local newGripToggleDelayTime = Gui.sliderFloat("Mode Toggle Hold Time", config.gripToggleDelayTime, 0.0, 2.0)
	if newGripToggleDelayTime ~= config.gripToggleDelayTime then
		config.gripToggleDelayTime = newGripToggleDelayTime
		changed = true
	end
	Gui.sameLine()
	Gui.textDisabled("(sec)")

	local newGrabDelayTime = Gui.sliderFloat("Grab Hold Time", config.grabDelayTime, 0.5, 3.0)
	if newGrabDelayTime ~= config.grabDelayTime then
		config.grabDelayTime = newGrabDelayTime
		changed = true
	end

	Gui.sameLine()
	Gui.textDisabled("(sec)")

	Gui.newLine()

	Gui.separatorText("Throw")
	local newThrowThreshold = Gui.sliderFloat("Throw velocity", config.throwThreshold, 50, 1000)
	if newThrowThreshold ~= config.throwThreshold then
		config.throwThreshold = newThrowThreshold
		changed = true
	end

	local newThrowGravity = Gui.sliderFloat("Throw gravity", config.throwGravity, 100, 3000)
	if newThrowGravity ~= config.throwGravity then
		config.throwGravity = newThrowGravity
		changed = true
	end

	Gui.newLine()

	Gui.separatorText("Range")

	local newHeadGrabRadius = Gui.sliderFloat("Head Grab Range", config.headGrabRadius, 10, 100)
	if newHeadGrabRadius ~= config.headGrabRadius then
		config.headGrabRadius = newHeadGrabRadius
		changed = true
	end

	local newHeadDropRadius = Gui.sliderFloat("Head Drop Range", config.headDropRadius, 10, 50)
	if newHeadDropRadius ~= config.headDropRadius then
		config.headDropRadius = newHeadDropRadius
		changed = true
	end

	local newShoulderDropRadius = Gui.sliderFloat("Shoulder Drop Range", config.shoulderDropRadius, 10, 100)
	if newShoulderDropRadius ~= config.shoulderDropRadius then
		config.shoulderDropRadius = newShoulderDropRadius
		changed = true
	end

	local newCameraGrabRadius = Gui.sliderFloat("Camera Grab Range", config.cameraGrabRadius, 10, 100)
	if newCameraGrabRadius ~= config.cameraGrabRadius then
		config.cameraGrabRadius = newCameraGrabRadius
		changed = true
	end

	Gui.newLine()

	Gui.separatorText("Third Person")
	local newThirdPersonDistance = Gui.sliderFloat("Camera Distance", config.thirdPersonDistance, 50, 500)
	if newThirdPersonDistance ~= config.thirdPersonDistance then
		config.thirdPersonDistance = newThirdPersonDistance
		changed = true
	end

	local newThirdPersonHeight = Gui.sliderFloat("Camera Height", config.thirdPersonHeight, -200, 200)
	if newThirdPersonHeight ~= config.thirdPersonHeight then
		config.thirdPersonHeight = newThirdPersonHeight
		changed = true
	end

	local newExtensionEnabled = Gui.checkbox("Enable Extension Arm", config.extensionEnabled)
	if newExtensionEnabled ~= config.extensionEnabled then
		config.extensionEnabled = newExtensionEnabled
		changed = true
	end

	local newHandheldDistance = Gui.sliderFloat("Handheld Distance", config.handheldDistance, 0, 500)
	if newHandheldDistance ~= config.handheldDistance then
		config.handheldDistance = newHandheldDistance
		config.minExtension = newHandheldDistance
		if cameraInHand then
			currentExtension = newHandheldDistance
			targetExtension = newHandheldDistance
		end
		changed = true
	end

	if config.extensionEnabled then
		local newMaxExtension = Gui.sliderFloat("Maximum Extension", config.maxExtension, 50, 500)
		if newMaxExtension ~= config.maxExtension then
			config.maxExtension = newMaxExtension
			changed = true
		end

		local newExtensionStep = Gui.sliderFloat("Extension Speed", config.extensionStep, 0.5, 20)
		if newExtensionStep ~= config.extensionStep then
			config.extensionStep = newExtensionStep
			changed = true
		end

		local newExtensionSmoothness = Gui.sliderFloat("Extension Smoothing", config.extensionSmoothness, 0, 0.95)
		if newExtensionSmoothness ~= config.extensionSmoothness then
			config.extensionSmoothness = newExtensionSmoothness
			changed = true
		end
	end

	Gui.newLine()

	Gui.separatorText("Clipping")
	local newNearClip = Gui.sliderFloat("Near Clipping Plane", config.nearClip, 0.1, 100)
	if newNearClip ~= config.nearClip then
		config.nearClip = newNearClip
		changed = true
	end

	local newViewOffset = Gui.dragFloat3("View Offset", config.viewpointOffset, 0.1, -10, 10)
	if
		newViewOffset
		and (
			newViewOffset.x ~= config.viewpointOffset.x
			or newViewOffset.y ~= config.viewpointOffset.y
			or newViewOffset.z ~= config.viewpointOffset.z
		)
	then
		config.viewpointOffset = newViewOffset
		changed = true
	end

	Gui.newLine()

	Gui.separatorText("Manual Orbit")
	local newOrbitRadius = Gui.sliderFloat("Orbit Radius", config.orbitRadius, 10, 1000)
	if newOrbitRadius ~= config.orbitRadius then
		config.orbitRadius = newOrbitRadius
		changed = true
	end

	local newOrbitRotSpeed = Gui.sliderFloat("Rotation Speed", config.orbitRotSpeed, 50, 360)
	if newOrbitRotSpeed ~= config.orbitRotSpeed then
		config.orbitRotSpeed = newOrbitRotSpeed
		changed = true
	end

	local newOrbitMouseSensitivity = Gui.sliderFloat("Mouse Sensitivity", config.orbitMouseSensitivity, 0.5, 10.0)
	if newOrbitMouseSensitivity ~= config.orbitMouseSensitivity then
		config.orbitMouseSensitivity = newOrbitMouseSensitivity
		changed = true
	end

	local newOrbitMouseWheelSensitivity =
		Gui.sliderFloat("Scroll Sensitivity", config.orbitMouseWheelSensitivity, 10, 150)
	if newOrbitMouseWheelSensitivity ~= config.orbitMouseWheelSensitivity then
		config.orbitMouseWheelSensitivity = newOrbitMouseWheelSensitivity
		changed = true
	end

	Gui.newLine()

	Gui.separatorText("Slingshot")
	local newSlingshotEnabled = Gui.checkbox("Enable Slingshot", config.slingshotEnabled)
	if newSlingshotEnabled ~= config.slingshotEnabled then
		config.slingshotEnabled = newSlingshotEnabled
		changed = true
	end

	Gui.sameLine()
	Gui.textDisabled("Double-click opposite Trigger while holding camera to launch")

	if config.slingshotEnabled then
		local newSlingshotDistance = Gui.sliderFloat("Slingshot Distance", config.slingshotDistance, 1000, 10000)
		if newSlingshotDistance ~= config.slingshotDistance then
			config.slingshotDistance = newSlingshotDistance
			changed = true
		end

		Gui.sameLine()
		Gui.textDisabled("(cm)")

		local newSlingshotLaunchTime = Gui.sliderFloat("Launch Time", config.slingshotLaunchTime, 0.5, 5.0)
		if newSlingshotLaunchTime ~= config.slingshotLaunchTime then
			config.slingshotLaunchTime = newSlingshotLaunchTime
			changed = true
		end

		Gui.sameLine()
		Gui.textDisabled("(sec)")

		local newSlingshotReturnTime = Gui.sliderFloat("Return Time", config.slingshotReturnTime, 1.0, 10.0)
		if newSlingshotReturnTime ~= config.slingshotReturnTime then
			config.slingshotReturnTime = newSlingshotReturnTime
			changed = true
		end

		Gui.sameLine()
		Gui.textDisabled("(sec)")

		local newDoubleClickThreshold = Gui.sliderFloat("Double-Click Time", config.doubleClickThreshold, 0.1, 1.0)
		if newDoubleClickThreshold ~= config.doubleClickThreshold then
			config.doubleClickThreshold = newDoubleClickThreshold
			changed = true
		end

		Gui.sameLine()
		Gui.textDisabled("(sec)")
	end

	Gui.newLine()

	Gui.separatorText("Scraprun")

	local newFollowBestScraprunPlayer = Gui.checkbox("Enable Scraprun Mode", config.followBestScraprunPlayer)
	if newFollowBestScraprunPlayer ~= config.followBestScraprunPlayer then
		config.followBestScraprunPlayer = newFollowBestScraprunPlayer
		changed = true
	end

	Gui.sameLine()
	Gui.textDisabled("Experimental/broken! The furthest player in Scraprun will be auto-followed.")

	local best = getBestScraprunPlayer()
	if best and best.name and best.cubeName then
		Gui.text("Best runner: " .. best.name)
	else
		Gui.text("Scraprun's empty")
	end

	applySettingsChange(changed)
end

local function drawDebugTab()
	Gui.separatorText("Runtime State")
	Gui.text("Active Player ID: " .. tostring(activePlayerId))
	Gui.text("Selected Player ID: " .. tostring(selectedPlayerId))
	Gui.text("Config Player ID: " .. tostring(config.currentPlayerId))
	Gui.text("Owner ID: " .. tostring(config.ownerId))
	Gui.text("Owner Present: " .. tostring(ownerIsPresent))
	Gui.text("Viewpoint Mode: " .. tostring(viewpointMode))
	Gui.text("Third Person Mode: " .. tostring(thirdPersonMode))
	Gui.text("Camera In Hand: " .. tostring(cameraInHand))
	Gui.text("Holding Hand: " .. tostring(handHolding))
	Gui.text("Free-Floating Mode: " .. tostring(freeFloatingMode))
	Gui.text("Ball Mode: " .. tostring(ballMode))
	Gui.text("Ball Index: " .. tostring(ballIndex))
	Gui.text("Facing User: " .. tostring(facingUser))
	Gui.text("View Flipped: " .. tostring(viewFlipped))
	Gui.text("Current Extension: " .. string.format("%.2f", currentExtension))
	Gui.text("Target Extension: " .. string.format("%.2f", targetExtension))
	Gui.text("Right Hand Grab Attempt: " .. tostring(isRightGrabAttempt))
	Gui.text("Left Hand Grab Attempt: " .. tostring(isLeftGrabAttempt))
	if isRightGrabAttempt or isLeftGrabAttempt then
		local timeRemaining = config.grabDelayTime - (t - grabAttemptTime)
		Gui.text("Grab Time Remaining: " .. string.format("%.1f", timeRemaining) .. " sec")
	end
	Gui.text("Manual Orbit Mode: " .. tostring(manualOrbitMode))
	Gui.text("Orbit Radius: " .. string.format("%.2f", config.orbitRadius))

	Gui.separatorText("Actions")
	if Gui.button("Force Rescan") then
		activePlayerId = nil
	end

	Gui.sameLine()

	if Gui.button("Force Owner Handheld") then
		forceOwnerHandheld()
	end

	Gui.sameLine()

	if Gui.button("Clear Saved Player") then
		config.currentPlayerId = nil
		if saveConfig then
			saveConfig()
		end
	end

	if ownerIsPresent then
		if Gui.button("Test Owner Recall") then
			activePlayerId = config.ownerId
			config.currentPlayerId = activePlayerId
			if saveConfig then
				saveConfig()
			end
			setViewpointMode(ownerPlayer)
		end
	else
		Gui.beginDisabled()
		Gui.button("Test Owner Recall")
		Gui.endDisabled()
	end

	Gui.sameLine()

	if Gui.button("Test Third Person") then
		local player = getPlayerByTarget(getCurrentTarget())
		if player then
			setThirdPersonMode(player)
		end
	end
end

function Axis.onLoad()
	if camera then
		camera.fieldOfView = config.fov
		camera.nearClippingPlane = config.nearClip
		camera.hideNearestHead = config.hideHead
		updateNameTagsVisibility()
		applyCameraSmoothness()
	end

	slingshotAngleX, slingshotAngleY, slingshotAngleZ = 0, 0, 0
	slingshotSpinX, slingshotSpinY, slingshotSpinZ = 0, 0, 0

	headGripAttemptTime = 0
	isHeadGripAttempt = false
	headGripToggled = false
	thrownMode = false
	activePlayerId = nil
	viewpointMode = true
	thirdPersonMode = false
	manualOrbitMode = false
	cameraInHand = false
	handHolding = nil
	freeFloatingMode = false
	ballMode = false
	shoulderMode = false
	shoulderSide = "right"
	floatingLookMode = false
	floatingLookPlayerId = nil
	ballIndex = 0
	ballCount = 0
	facingUser = true
	viewFlipped = false
	currentExtension = config.minExtension
	targetExtension = config.minExtension
	lastRightGripState = false
	lastLeftGripState = false
	lastHeadModeToggleRightGripState = false
	grabAttemptTime = 0
	isRightGrabAttempt = false
	isLeftGrabAttempt = false

	slingshotLaunched = false
	slingshotPlayer = nil
	slingshotReturning = false
	slingshotSpinAngle = 0
	lastSecondaryTriggerState = false
	triggerPressTimes = {}

	ballIndex = 0
	ballCount = 0
	lastBallPos = Vec3.new(0, 0, 0)

	checkForOwnerPresence()

	didAutoAssignDefaultOwner = false
	lastAutoAssignAttemptTime = -1
	tryAutoAssignDefaultOwner()
	activePlayerId = activePlayerId or findAnyPlayer()
	initialPovSet = false
	initialDelay = 0
end

function Axis.onUnload()
	if camera then
		camera.hideNearestHead = false
		camera.showNameTags = true

		Util.clearAxisSmoothing()
	end
	if activePlayerId then
		config.currentPlayerId = activePlayerId
		if saveConfig then
			saveConfig()
		end
	end
end

function Axis.tick(dt)
	t = t + dt

	if config.followBestScraprunPlayer then
		updateScraprunFollow(dt)
		return
	end

	if configDirty and t >= configSaveAtTime then
		if saveConfig then
			saveConfig()
		end
		configDirty = false
	end

	if camera and not thirdPersonMode then
		camera.fieldOfView = config.fov
	end

	if slingshotLaunched then
		updateSlingshot(dt)
		return
	end

	if
		not didAutoAssignDefaultOwner
		and config.ownerId == nil
		and config.currentPlayerId == nil
		and selectedPlayerId == nil
		and (lastAutoAssignAttemptTime < 0 or (t - lastAutoAssignAttemptTime) >= 0.5)
	then
		lastAutoAssignAttemptTime = t
		local assigned = tryAutoAssignDefaultOwner()
		if assigned then
			initialPovSet = false
			initialDelay = 0
		end
	end

	if not initialPovSet then
		initialDelay = initialDelay + dt
		if initialDelay >= 0.1 then
			local currentPlayer = getPlayerByTarget(getCurrentTarget())
			if currentPlayer and currentPlayer.head then
				setViewpointMode(currentPlayer)
				initialPovSet = true
			end
		end
	end

	if gravity and gravity.upDirection and gravity.upDirection ~= Vec3.zeroVector then
		worldUp = gravity.upDirection
	end

	if math.floor(t) % 5 == 0 then
		checkForOwnerPresence()
	end

	if not activePlayerId then
		tryAutoAssignDefaultOwner()
		activePlayerId = findAnyPlayer()
		if not activePlayerId then
			return
		end
	end

	local currentPlayer = getPlayerByTarget(getCurrentTarget())
	if not currentPlayer or not currentPlayer.head then
		activePlayerId = findAnyPlayer()
		if not activePlayerId then
			return
		end
		currentPlayer = getPlayerByTarget(getCurrentTarget())
		if not currentPlayer or not currentPlayer.head then
			return
		end
	end

	local recallTriggered = processOwnerRecall(dt)
	if recallTriggered then
		return
	end

	local rightHandPos, rightHandRot = getHandPosition(currentPlayer, false)
	local leftHandPos, leftHandRot = getHandPosition(currentPlayer, true)
	local isRightTrigger = isActionPressed(currentPlayer, false, "Grab Camera")
	local isLeftTrigger = isActionPressed(currentPlayer, true, "Grab Camera")
	local allButtonsPressed = isGripPressed(currentPlayer, false)
		and isTriggerPressed(currentPlayer, false)
		and isGripPressed(currentPlayer, true)
		and isTriggerPressed(currentPlayer, true)
	if not freeFloatingMode then
		floatingLookMode = false
		floatingLookPlayerId = nil
		floatingLookButtonsWasPressed = false
	elseif floatingLookMode and floatingLookPlayerId ~= activePlayerId then
		floatingLookMode = false
		floatingLookPlayerId = nil
	elseif config.floatingLookToggleEnabled and allButtonsPressed and not floatingLookButtonsWasPressed then
		floatingLookMode = not floatingLookMode
		floatingLookPlayerId = floatingLookMode and activePlayerId or nil
	end
	if freeFloatingMode then
		floatingLookButtonsWasPressed = allButtonsPressed
	end

	if dt > 0 then
		if rightHandPos and lastRightHandPos then
			currentRightHandVelocity = (rightHandPos - lastRightHandPos) / dt
		else
			currentRightHandVelocity = Vec3.new(0, 0, 0)
		end
		lastRightHandPos = rightHandPos

		if leftHandPos and lastLeftHandPos then
			currentLeftHandVelocity = (leftHandPos - lastLeftHandPos) / dt
		else
			currentLeftHandVelocity = Vec3.new(0, 0, 0)
		end
		lastLeftHandPos = leftHandPos
	end

	if (viewpointMode or thirdPersonMode) and currentPlayer.head then
		local rightGripPressed = isActionPressed(currentPlayer, false, "Mode Toggle")
		local leftGripPressed = isActionPressed(currentPlayer, true, "Mode Toggle")
		local rightNear = rightHandPos
			and (Vec3.distance(rightHandPos, currentPlayer.head.position) <= config.headDropRadius)
		local leftNear = leftHandPos
			and (Vec3.distance(leftHandPos, currentPlayer.head.position) <= config.headDropRadius)
		local isGripActive = (rightGripPressed and rightNear) or (leftGripPressed and leftNear)

		if isGripActive then
			if not headGripToggled then
				if not isHeadGripAttempt then
					isHeadGripAttempt = true
					headGripAttemptTime = t
				elseif (t - headGripAttemptTime) >= config.gripToggleDelayTime then
					isHeadGripAttempt = false
					headGripToggled = true
					isRightGrabAttempt = false
					isLeftGrabAttempt = false
					grabAttemptTime = 0
					if viewpointMode then
						setThirdPersonMode(currentPlayer)
					else
						setViewpointMode(currentPlayer)
					end
				end
			end
		else
			isHeadGripAttempt = false
			headGripToggled = false
			headGripAttemptTime = 0
		end
	else
		isHeadGripAttempt = false
		headGripToggled = false
		headGripAttemptTime = 0
	end

	if ballMode then
		updateBallMode()
		if rightHandPos and isRightTrigger then
			local distToCamera = Vec3.distance(rightHandPos, camera.position)
			if distToCamera <= config.cameraGrabRadius then
				beginRightHandGrip(currentPlayer, rightHandPos, rightHandRot)
			end
		elseif leftHandPos and isLeftTrigger then
			local distToCamera = Vec3.distance(leftHandPos, camera.position)
			if distToCamera <= config.cameraGrabRadius then
				beginLeftHandGrip(currentPlayer, leftHandPos, leftHandRot)
			end
		end
		return
	end

	if viewpointMode then
		if rightHandPos and isRightTrigger then
			local distToHead = Vec3.distance(rightHandPos, currentPlayer.head.position)
			if distToHead <= config.headGrabRadius then
				if not isRightGrabAttempt and not isLeftGrabAttempt then
					isRightGrabAttempt = true
					grabAttemptTime = t
				end
				if isRightGrabAttempt and (t - grabAttemptTime) >= config.grabDelayTime then
					beginRightHandGrip(currentPlayer, rightHandPos, rightHandRot)
					isRightGrabAttempt = false
					isLeftGrabAttempt = false
					grabAttemptTime = 0
				end
			else
				if isRightGrabAttempt then
					isRightGrabAttempt = false
					grabAttemptTime = 0
				end
			end
		else
			if isRightGrabAttempt then
				isRightGrabAttempt = false
				grabAttemptTime = 0
			end
		end

		if leftHandPos and isLeftTrigger then
			local distToHead = Vec3.distance(leftHandPos, currentPlayer.head.position)
			if distToHead <= config.headGrabRadius then
				if not isLeftGrabAttempt and not isRightGrabAttempt then
					isLeftGrabAttempt = true
					grabAttemptTime = t
				end
				if isLeftGrabAttempt and (t - grabAttemptTime) >= config.grabDelayTime then
					beginLeftHandGrip(currentPlayer, leftHandPos, leftHandRot)
					isRightGrabAttempt = false
					isLeftGrabAttempt = false
					grabAttemptTime = 0
				end
			else
				if isLeftGrabAttempt then
					isLeftGrabAttempt = false
					grabAttemptTime = 0
				end
			end
		else
			if isLeftGrabAttempt then
				isLeftGrabAttempt = false
				grabAttemptTime = 0
			end
		end

		applyCameraSmoothness(true)
		camera.hideNearestHead = config.hideHead
		camera.position = currentPlayer.head.position
		camera.rotation = currentPlayer.head.rotation
		updateNameTagsVisibility()
	elseif thirdPersonMode then
		updateThirdPersonMode(currentPlayer, dt)
		if rightHandPos and isRightTrigger then
			local distToCamera = Vec3.distance(rightHandPos, camera.position)
			if distToCamera <= config.cameraGrabRadius then
				beginRightHandGrip(currentPlayer, rightHandPos, rightHandRot)
			end
		elseif leftHandPos and isLeftTrigger then
			local distToCamera = Vec3.distance(leftHandPos, camera.position)
			if distToCamera <= config.cameraGrabRadius then
				beginLeftHandGrip(currentPlayer, leftHandPos, leftHandRot)
			end
		end
	elseif manualOrbitMode then
		updateManualOrbitMode(currentPlayer, dt)
		if rightHandPos and isRightTrigger then
			local distToCamera = Vec3.distance(rightHandPos, camera.position)
			if distToCamera <= config.cameraGrabRadius then
				beginRightHandGrip(currentPlayer, rightHandPos, rightHandRot)
			end
		elseif leftHandPos and isLeftTrigger then
			local distToCamera = Vec3.distance(leftHandPos, camera.position)
			if distToCamera <= config.cameraGrabRadius then
				beginLeftHandGrip(currentPlayer, leftHandPos, leftHandRot)
			end
		end
	elseif cameraInHand then
		if handHolding == "right" then
			if isRightTrigger then
				updateRightHandGrip(currentPlayer, rightHandPos, rightHandRot, dt)
			else
				handleCameraRelease(currentPlayer, currentRightHandVelocity)
			end
		elseif handHolding == "left" then
			if isLeftTrigger then
				updateLeftHandGrip(currentPlayer, leftHandPos, leftHandRot, dt)
			else
				handleCameraRelease(currentPlayer, currentLeftHandVelocity)
			end
		end
	elseif shoulderMode then
		updateShoulderMode(currentPlayer, dt)

		if rightHandPos and isRightTrigger then
			local distToCamera = Vec3.distance(rightHandPos, camera.position)
			if distToCamera <= config.cameraGrabRadius then
				if not isRightGrabAttempt and not isLeftGrabAttempt then
					isRightGrabAttempt = true
					grabAttemptTime = t
				end
				if isRightGrabAttempt and (t - grabAttemptTime) >= config.grabDelayTime then
					beginRightHandGrip(currentPlayer, rightHandPos, rightHandRot)
					isRightGrabAttempt = false
					isLeftGrabAttempt = false
					grabAttemptTime = 0
				end
			else
				if isRightGrabAttempt then
					isRightGrabAttempt = false
					grabAttemptTime = 0
				end
			end
		else
			if isRightGrabAttempt then
				isRightGrabAttempt = false
				grabAttemptTime = 0
			end
		end

		if leftHandPos and isLeftTrigger then
			local distToCamera = Vec3.distance(leftHandPos, camera.position)
			if distToCamera <= config.cameraGrabRadius then
				if not isLeftGrabAttempt and not isRightGrabAttempt then
					isLeftGrabAttempt = true
					grabAttemptTime = t
				end
				if isLeftGrabAttempt and (t - grabAttemptTime) >= config.grabDelayTime then
					beginLeftHandGrip(currentPlayer, leftHandPos, leftHandRot)
					isRightGrabAttempt = false
					isLeftGrabAttempt = false
					grabAttemptTime = 0
				end
			else
				if isLeftGrabAttempt then
					isLeftGrabAttempt = false
					grabAttemptTime = 0
				end
			end
		else
			if isLeftGrabAttempt then
				isLeftGrabAttempt = false
				grabAttemptTime = 0
			end
		end
	elseif thrownMode then
		throwVelocity = throwVelocity - (worldUp * (config.throwGravity * dt))
		local nextPos = camera.position + (throwVelocity * dt)

		local followedPlayer = tryFollowPlayerOnThrownCameraContact(camera.position, nextPos)
		if not followedPlayer then
			local floorHit = getNearestSurfaceFloor(camera.position, 100000)
			if floorHit and floorHit.normal then
				local floorNormal = floorHit.normal:getSafeNormal()
				if floorNormal:length() > 0 then
					local floorPlaneDist = Vec3.dot(nextPos - floorHit.position, floorNormal)
					if floorPlaneDist <= 0 then
						camera.position = floorHit.position + (floorNormal * 5)
						thrownMode = false
						freeFloatingMode = true
						floatingLookMode = false
						floatingLookPlayerId = nil
						camera.positionSmoothing = 0
						camera.rotationSmoothing = 0
						camera.hideNearestHead = false
						updateNameTagsVisibility()
					else
						local pathHit = camera:castRay(camera.position, nextPos)
						if pathHit.successful then
							camera.position = pathHit.position + (pathHit.normal * 5)
							thrownMode = false
							freeFloatingMode = true
							floatingLookMode = false
							floatingLookPlayerId = nil
						else
							camera.position = nextPos
							local speed = throwVelocity:length()
							if speed > 0 then
								local spinAxis = Vec3.cross(throwVelocity, worldUp)
								if spinAxis:length() > 0.001 then
									spinAxis = spinAxis:normalize()
									local spinSpeed = speed * dt * 0.1
									camera.rotation = Quat.fromAngleAxis(spinSpeed, spinAxis) * camera.rotation
								end
							end
						end
					end
				else
					local pathHit = camera:castRay(camera.position, nextPos)
					if pathHit.successful then
						camera.position = pathHit.position + (pathHit.normal * 5)
						thrownMode = false
						freeFloatingMode = true
						floatingLookMode = false
						floatingLookPlayerId = nil
					else
						camera.position = nextPos
						local speed = throwVelocity:length()
						if speed > 0 then
							local spinAxis = Vec3.cross(throwVelocity, worldUp)
							if spinAxis:length() > 0.001 then
								spinAxis = spinAxis:normalize()
								local spinSpeed = speed * dt * 0.1
								camera.rotation = Quat.fromAngleAxis(spinSpeed, spinAxis) * camera.rotation
							end
						end
					end
				end
			else
				local pathHit = camera:castRay(camera.position, nextPos)
				if pathHit.successful then
					camera.position = pathHit.position + (pathHit.normal * 5)
					thrownMode = false
					freeFloatingMode = true
					floatingLookMode = false
					floatingLookPlayerId = nil
				else
					camera.position = nextPos
					local speed = throwVelocity:length()
					if speed > 0 then
						local spinAxis = Vec3.cross(throwVelocity, worldUp)
						if spinAxis:length() > 0.001 then
							spinAxis = spinAxis:normalize()
							local spinSpeed = speed * dt * 0.1
							camera.rotation = Quat.fromAngleAxis(spinSpeed, spinAxis) * camera.rotation
						end
					end
				end
			end
		end

		camera.positionSmoothing = 0
		camera.rotationSmoothing = 0
		camera.hideNearestHead = false
		updateNameTagsVisibility()
	elseif freeFloatingMode then
		if rightHandPos and isRightTrigger then
			local distToCamera = Vec3.distance(rightHandPos, camera.position)
			if distToCamera <= config.cameraGrabRadius then
				beginRightHandGrip(currentPlayer, rightHandPos, rightHandRot)
			end
		elseif leftHandPos and isLeftTrigger then
			local distToCamera = Vec3.distance(leftHandPos, camera.position)
			if distToCamera <= config.cameraGrabRadius then
				beginLeftHandGrip(currentPlayer, leftHandPos, leftHandRot)
			end
		end
		camera.positionSmoothing = 0
		if floatingLookMode then
			updateFloatingLook(currentPlayer)
		else
			camera.rotationSmoothing = 0
		end
		camera.hideNearestHead = false
		updateNameTagsVisibility()
	end
end

function Axis.onGui()
	local wasEnabled = Axis.isEnabled
	Axis.isEnabled = Gui.checkbox("Use Playercam", Axis.isEnabled)
	Gui.setItemTooltip("Enable Playercam and disable Freecam.")

	if Axis.isEnabled ~= wasEnabled then
		if Axis.isEnabled then
			Axis.onLoad()
		else
			Axis.onUnload()
		end
	end

	if not Axis.isEnabled then
		Gui.sameLine()
		Gui.textDisabled("Enable to use Playercam instead of Freecam")
		return
	end

	Gui.separator()
	Gui.beginTabBar("PlayercamSubTabs")
	if Gui.beginTabItem(Icon.Home .. "  Home") then
		drawHomeTab()
		Gui.endTabItem()
	end
	if Gui.beginTabItem(Icon.Cog .. "  Settings") then
		drawSettingsTab()
		Gui.endTabItem()
	end
	if Gui.beginTabItem(Icon.QuestionCircle .. "  How to use") then
		drawHowToUseTab()
		Gui.endTabItem()
	end
	if config.showAxisDebug and Gui.beginTabItem(Icon.Bug .. "  Debug") then
		drawDebugTab()
		Gui.endTabItem()
	end
	Gui.endTabBar()
end

return Axis
