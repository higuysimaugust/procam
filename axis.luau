local Axis = {}
Axis.isEnabled = false

config = config or {}

config.viewpointOffset = config.viewpointOffset or Vec3.new(0, 0, 0)
config.fov = config.fov or 95
config.nearClip = config.nearClip or 1
if config.hideHead == nil then config.hideHead = true end
config.nameTagType = config.nameTagType or 0
config.currentPlayerId = config.currentPlayerId or nil
config.ownerId = config.ownerId or nil
config.useTriggerControl = true
config.headGrabRadius = config.headGrabRadius or 30
config.headDropRadius = config.headDropRadius or 22
config.cameraGrabRadius = config.cameraGrabRadius or 50
config.ownerRecallTime = 1.5
config.thirdPersonDistance = config.thirdPersonDistance or 300
config.grabDelayTime = config.grabDelayTime or 1.0

config.orbitRadius = config.orbitRadius or 300
config.orbitRotSpeed = config.orbitRotSpeed or 180
config.orbitMouseSensitivity = config.orbitMouseSensitivity or 3.6
config.orbitMouseWheelSensitivity = config.orbitMouseWheelSensitivity or 50

local manualOrbitMode = false
local cameraDirectionEuler = Vec3.new(0, 0, 0)

local rightHandOffset = Vec3.new(0, 10, -5)
local leftHandOffset = Vec3.new(0, 10, -5)

if config.extensionEnabled == nil then config.extensionEnabled = true end
config.minExtension = config.minExtension or 5
config.maxExtension = config.maxExtension or 500
config.extensionStep = config.extensionStep or 10
config.extensionSmoothness = config.extensionSmoothness or 0.2
if config.flipEnabled == nil then config.flipEnabled = true end

if config.slingshotEnabled == nil then config.slingshotEnabled = true end
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
config.defaultOwnerName = config.defaultOwnerName or "higuysimaugust"
local didAutoAssignDefaultOwner = false
local lastAutoAssignAttemptTime = -1

local viewpointMode = true
local thirdPersonMode = false
local cameraInHand = false
local handHolding = nil
local freeFloatingMode = false
local ballMode = false

local worldUp = Vec3.new(0, 1, 0)

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
local slingshotLaunchDirection = Vec3.new(0,0,0)
local slingshotStartPosition = Vec3.new(0,0,0)
local slingshotTargetPosition = Vec3.new(0,0,0)
local slingshotReturnStartPos = Vec3.new(0,0,0)
local slingshotReturnTargetPos = Vec3.new(0,0,0)
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
    if not camera then return end
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
    local players = {}
    local sessions = getAllGameData()
    for i = 1, #sessions do
        if sessions[i].players then
            for j = 1, #sessions[i].players do
                local playerId = sessions[i].players[j].playerId
                local player = sessions[i]:getPlayerById(playerId)
                if player and player.playerName then
                    table.insert(players, { id = playerId, sessionIndex = i, name = player.playerName })
                end
            end
        end
    end
    return players
end

local function getPlayerById(playerId, sessionIndex)
    if not playerId then return nil end
    local sessions = getAllGameData()
    if sessionIndex and sessions[sessionIndex] and sessions[sessionIndex].getPlayerById then
        local player = sessions[sessionIndex]:getPlayerById(playerId)
        if player then return player end
    end
    for i = 1, #sessions do
        if sessions[i].getPlayerById then
            local player = sessions[i]:getPlayerById(playerId)
            if player then return player end
        end
    end
    return nil
end

local function getPlayerName(target)
    if not target then return "None" end
    local player = (type(target) == "table") and getPlayerByTarget(target) or getPlayerById(target)
    if player and player.playerName then
        return player.playerName
    end
    return "Unknown"
end

local function isSameTarget(a, b)
    if not a or not b then return false end
    return a.id == b.id and a.sessionIndex == b.sessionIndex
end

local function getPlayerByTarget(target)
    if not target or not target.id then return nil end
    local sessions = getAllGameData()
    if target.sessionIndex and sessions[target.sessionIndex] and sessions[target.sessionIndex].getPlayerById then
        local player = sessions[target.sessionIndex]:getPlayerById(target.id)
        if player then return player end
    end
    for i = 1, #sessions do
        if sessions[i].getPlayerById then
            local player = sessions[i]:getPlayerById(target.id)
            if player then return player end
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
    if not key then return nil end
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
        if player then return config.currentPlayerId end
    end
    if config.ownerId then
        local player = getPlayerByTarget(getOwnerTarget())
        if player then return config.ownerId end
    end
    local players = getPlayers()
    if #players > 0 then return players[1].id end
    return nil
end

local function tryAutoAssignDefaultOwner()
    if didAutoAssignDefaultOwner then return false end
    if config.ownerId ~= nil and getPlayerByTarget(getOwnerTarget()) ~= nil then return false end
    if config.currentPlayerId ~= nil and getPlayerById(config.currentPlayerId) ~= nil then return false end
    if selectedPlayerId ~= nil then return false end

    local players = getPlayers()
    if #players == 0 then return false end

    local targetLower = string.lower(config.defaultOwnerName or "higuysimaugust")
    for i = 1, #players do
        local p = players[i]
        if p and p.id and p.name and string.lower(p.name) == targetLower then
            config.ownerId = p.id
            activePlayerId = p.id
            config.currentPlayerId = p.id
            if saveConfig then saveConfig() end
            checkForOwnerPresence()
            didAutoAssignDefaultOwner = true
            return true
        end
    end

    return false
end

local function playerMatchesSearch(playerName, search)
    if search == "" then return true end
    local lowerName = string.lower(playerName)
    local lowerSearch = string.lower(search)
    return string.find(lowerName, lowerSearch) ~= nil
end

local function getHandPosition(player, isLeftHand)
    if not player or not player.root or not player.root.position or not player.root.rotation then return nil, nil end
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
    if not stateBits then return "00000000" end
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
    if not player then return "00000000" end
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

local function queueConfigSave()
    configDirty = true
    configSaveAtTime = t + 0.25
end

local function applySettingsChange(changed)
    if not changed then return end
    if camera then
        camera.nearClippingPlane = config.nearClip
        if not thirdPersonMode then
            camera.fieldOfView = config.fov
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

local function setViewpointMode(player)
    if not player or not player.head then return end
    camera.positionSmoothing = 0
    camera.rotationSmoothing = 0
    camera.nearClippingPlane = config.nearClip
    camera.fieldOfView = config.fov
    camera.hideNearestHead = config.hideHead
    camera.position = player.head.position
    camera.rotation = player.head.rotation

    viewpointMode = true
    thirdPersonMode = false
    manualOrbitMode = false
    cameraInHand = false
    handHolding = nil
    freeFloatingMode = false
    ballMode = false
    ballIndex = 0
    ballCount = 0
    facingUser = true
    viewFlipped = false
    currentExtension = config.minExtension
    targetExtension = config.minExtension

    updateNameTagsVisibility()
end

local function setThirdPersonMode(player)
    if not player or not player.head then return end
    viewpointMode = false
    thirdPersonMode = true
    manualOrbitMode = false
    cameraInHand = false
    handHolding = nil
    freeFloatingMode = false
    ballMode = false

    local headPos = player.head.position
    local headRot = player.head.rotation
    local behindVector = headRot:getForwardVector() * -config.thirdPersonDistance
    local hit = camera:castRay(headPos, headPos + behindVector)
    if hit.successful then
        camera.position = hit.position + (hit.normal * 10)
    else
        camera.position = headPos + behindVector
    end
    camera.rotation = headRot
    camera.hideNearestHead = false
    camera.positionSmoothing = 0.1
    camera.rotationSmoothing = 0.1
    updateNameTagsVisibility()
end

local function setManualOrbitMode(player)
    if not player or not player.head then return end
    viewpointMode = false
    thirdPersonMode = false
    manualOrbitMode = true
    cameraInHand = false
    handHolding = nil
    freeFloatingMode = false
    ballMode = false

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
    camera.positionSmoothing = 0.1
    camera.rotationSmoothing = 0.1
    updateNameTagsVisibility()
end

local function updateManualOrbitMode(player, dt)
    if not player or not player.head then return end

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
    local upVector = (player.root and player.root.rotation and player.root.rotation:getUpVector()) or worldUp
    local cameraDirection = upRot:rotateVector(
        Quat.fromEuler(cameraDirectionEuler.x, cameraDirectionEuler.y, cameraDirectionEuler.z):getForwardVector()
    ) * -1

    camera.positionSmoothing = 0.1
    camera.rotationSmoothing = 0.1
    camera.position = player.head.position + cameraDirection * config.orbitRadius
    local upVector = (player.root and player.root.rotation and player.root.rotation:getUpVector()) or worldUp
    camera:lookAt(player.head.position, upVector)
    camera.hideNearestHead = false
end

local function updateThirdPersonMode(player, dt)
    if not player or not player.head then return end
    local headPos = player.head.position
    local headRot = player.head.rotation
    local targetPos = headPos + (headRot:getForwardVector() * -config.thirdPersonDistance)
    local hit = camera:castRay(headPos, targetPos)
    if hit.successful then
        targetPos = hit.position + (hit.normal * 10)
    end
    camera.positionSmoothing = 0.1
    camera.rotationSmoothing = 0.1
    camera.position = targetPos
    local upVector = (player.root and player.root.rotation and player.root.rotation:getUpVector()) or worldUp
    camera:lookAt(headPos, upVector)
    camera.hideNearestHead = false
    local distToTarget = Vec3.distance(camera.position, headPos)
    camera.fieldOfView = math.max(60, math.min(config.fov, config.fov - ((config.thirdPersonDistance - distToTarget) / 10)))
end

local function tryFindBallNearPosition(position)
    local frame = getGameData()
    if not frame or not frame.balls then return 0 end
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
    if not frame or not frame.balls then return false end
    local index = tryFindBallNearPosition(position)
    if index == 0 then return false end
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
    local rightHeld = isTriggerPressed(owner, false)
    local leftHeld = isTriggerPressed(owner, true)
    if not (rightHeld or leftHeld) then
        ownerRecallTimer = 0
        return false
    end
    ownerRecallTimer = ownerRecallTimer + dt
    if ownerRecallTimer >= config.ownerRecallTime then
        activePlayerId = config.ownerId
        config.currentPlayerId = activePlayerId
        if saveConfig then saveConfig() end
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
    if not player or not player.head then return end
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
    handHolding = nil
    freeFloatingMode = true
    viewpointMode = false
    thirdPersonMode = false
    manualOrbitMode = false
end

local function updateSlingshot(dt)
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
            
            camera.rotation = Quat.fromAngleAxis(slingshotAngleX, Vec3.new(1,0,0)) *
                              Quat.fromAngleAxis(slingshotAngleY, Vec3.new(0,1,0)) *
                              Quat.fromAngleAxis(slingshotAngleZ, Vec3.new(0,0,1))
            camera.positionSmoothing = 0
            camera.rotationSmoothing = 0
        else
            slingshotReturning = true
            slingshotReturnStartTime = t
            slingshotReturnStartPos = camera.position
            slingshotReturnTargetPos = slingshotPlayer.head.position + slingshotPlayer.head.rotation:rotateVector(config.viewpointOffset)
        end
    else
        local elapsed = t - slingshotReturnStartTime
        if elapsed < config.slingshotReturnTime then
            local progress = elapsed / config.slingshotReturnTime
            camera.position = slingshotReturnStartPos + (slingshotReturnTargetPos - slingshotReturnStartPos) * progress
            slingshotSpinAngle = slingshotSpinAngle + dt * config.slingshotSpinSpeed * math.pi / 180
            local currentDirection = (slingshotReturnTargetPos - camera.position):normalize()
            camera.rotation = Quat.lookAt(currentDirection, worldUp) * Quat.fromAngleAxis(slingshotSpinAngle, currentDirection)
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
    if not player or not handPos or not handRot then return end
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

    currentExtension = config.minExtension
    targetExtension = config.minExtension

    cameraInHand = true
    handHolding = "right"
    viewpointMode = false
    thirdPersonMode = false
    freeFloatingMode = false
    ballMode = false
    ballIndex = 0
    ballCount = 0

    isRightGrabAttempt = false
    isLeftGrabAttempt = false
    grabAttemptTime = 0

    if debugMode then print("Camera grabbed with right hand") end
end

function beginLeftHandGrip(player, handPos, handRot)
    if not player or not handPos or not handRot then return end
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

    currentExtension = config.minExtension
    targetExtension = config.minExtension

    cameraInHand = true
    handHolding = "left"
    viewpointMode = false
    thirdPersonMode = false
    freeFloatingMode = false
    ballMode = false
    ballIndex = 0
    ballCount = 0

    isRightGrabAttempt = false
    isLeftGrabAttempt = false
    grabAttemptTime = 0

    if debugMode then print("Camera grabbed with left hand") end
end

function updateRightHandGrip(player, handPos, handRot, dt)
    if not player or not handPos or not handRot then return end
    local headPos = player.head.position
    local headToHand = handPos - headPos
    local headToHandDir = headToHand:normalize()
    local upVector = worldUp
    local rightVector = Vec3.cross(headToHandDir, upVector):normalize()
    local stableForward = Vec3.cross(upVector, rightVector):normalize()
    local basePos = handPos + (upVector * rightHandOffset.y) + (stableForward * rightHandOffset.z)
    
    local rightGripPressed = isGripPressed(player, false)
    local leftGripPressed = isGripPressed(player, true)
    local leftTriggerPressed = isTriggerPressed(player, true)
    
    -- Detect double-click on secondary trigger (left trigger)
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
    
    if config.flipEnabled and rightGripPressed and not lastRightGripState then
        flipCameraView()
    end
    lastRightGripState = rightGripPressed
    
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
    camera.positionSmoothing = 0
    
    if debugMode then
        print("Right Hand Grip: Extension=" .. tostring(currentExtension) .. ", Facing=" .. tostring(facingUser))
    end
end

function updateLeftHandGrip(player, handPos, handRot, dt)
    if not player or not handPos or not handRot then return end
    local headPos = player.head.position
    local headToHand = handPos - headPos
    local headToHandDir = headToHand:normalize()
    local upVector = worldUp
    local rightVector = Vec3.cross(headToHandDir, upVector):normalize()
    local stableForward = Vec3.cross(upVector, rightVector):normalize()
    local basePos = handPos + (upVector * leftHandOffset.y) + (stableForward * leftHandOffset.z)
    
    local leftGripPressed = isGripPressed(player, true)
    local rightGripPressed = isGripPressed(player, false)
    local rightTriggerPressed = isTriggerPressed(player, false)
    
    -- Detect double-click on secondary trigger (right trigger)
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
    
    if config.flipEnabled and leftGripPressed and not lastLeftGripState then
        flipCameraView()
    end
    lastLeftGripState = leftGripPressed
    
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
    camera.positionSmoothing = 0
    
    if debugMode then
        print("Left Hand Grip: Extension=" .. tostring(currentExtension) .. ", Facing=" .. tostring(facingUser))
    end
end

local function handleCameraRelease(player)
    local headNearby = false
    local newOwnerFound = false
    if enterBallModeFromPosition(camera.position) then
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
    local ownerText = ownerPlayerObj and ownerPlayerObj.playerName or "none"
    local ownerStatus = config.ownerId and (ownerIsPresent and "[online]" or "[dead]") or ""

    local followingPlayerObj = getPlayerByTarget(getCurrentTarget())
    local followingText = followingPlayerObj and followingPlayerObj.playerName or "None"
    local modeText = "unknown"
    local modeDetailText = nil

    if viewpointMode then
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
        modeText = "Floating"
    elseif ballMode then
        modeText = "Ball"
    end

    Gui.beginChild("ownerState##HandcamHomeOwner", 180, 70, true)
    Gui.text(Icon.Crown .. "  Owner")
    Gui.text(ownerText .. (ownerStatus ~= "" and (" " .. ownerStatus) or ""))
    Gui.endChild()
    Gui.sameLine()

    Gui.beginChild("followingState##HandcamHomeFollowing", 180, 70, true)
    Gui.text(Icon.ChevronRight .. "  Following")
    Gui.text(followingText)
    Gui.endChild()
    Gui.sameLine()

    Gui.beginChild("modeState##HandcamHomeMode", 180, 70, true)
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
    searchText = Gui.inputText(Icon.Search .. "  Search", searchText)
    Gui.setItemTooltip("Filter by name")

    local players = getPlayers()

    if #players > 0 then
        if Gui.beginListBox("Players##Handcam_home") then
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
    else
        Gui.textDisabled("no players found")
    end

    if selectedPlayerTarget then
        local isFollowing = isSameTarget(selectedPlayerTarget, getCurrentTarget())
        local followLabel = isFollowing and "Following Player" or "Start Follow"

        if isFollowing then
            Gui.beginDisabled()
        end
        if Gui.button(Icon.ChevronRight .. "  " .. followLabel) then
            activePlayerTarget = { id = selectedPlayerTarget.id, sessionIndex = selectedPlayerTarget.sessionIndex }
            activePlayerId = selectedPlayerTarget.id
            if saveConfig then saveConfig() end
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
            if saveConfig then saveConfig() end
        end
    else
        Gui.beginDisabled()
        Gui.button(Icon.ChevronRight .. "  Start Follow")
        Gui.sameLine()
        Gui.button(Icon.Crown .. "  Set Owner")
        Gui.endDisabled()
        Gui.textDisabled("Select a player to interact")
    end

    Gui.separatorText(Icon.Camera .. "  Camera Mode")
    local currentPlayer = getPlayerByTarget(getCurrentTarget())

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

    if not currentPlayer then
        Gui.textDisabled("a valid player target is needed for mode switches.")
    end
end

local function drawHowToUseTab()
    Gui.separatorText(Icon.InfoCircle .. "  What is Handcam?")
    Gui.text("Handcam is a player camera with first + third person mode, owner, handheld mode, and a bit more.")
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

    local newDefaultOwner = Gui.inputText("Default Owner Name", config.defaultOwnerName or "")
    if newDefaultOwner ~= config.defaultOwnerName then
        config.defaultOwnerName = newDefaultOwner
        didAutoAssignDefaultOwner = false
        changed = true
    end

    Gui.setItemTooltip("If present in server, automatically gives player owner and follows")

    local newFov = Gui.sliderFloat("Field of View", config.fov, 60, 120)
    if newFov ~= config.fov then
        config.fov = newFov
        changed = true
    end

    local nameTagTypeString = "Show Name Tags when not in POV"
    if config.nameTagType == 0 then
        nameTagTypeString = "Always show Name Tags"
    elseif config.nameTagType == 1 then
        nameTagTypeString = "Show Name Tags when not in POV"
    elseif config.nameTagType == 2 then
        nameTagTypeString = "Always hide Name Tags"
    end
    if Gui.beginCombo("Name Tags Visibility", nameTagTypeString) then
        local is0Selected = (config.nameTagType == 0)
        local is1Selected = (config.nameTagType == 1)
        local is2Selected = (config.nameTagType == 2)
        if Gui.selectable("Always show Name Tags", is0Selected) then
            config.nameTagType = 0
            updateNameTagsVisibility()
            changed = true
        end
        if Gui.selectable("Show Name Tags when not in POV", is1Selected) then
            config.nameTagType = 1
            updateNameTagsVisibility()
            changed = true
        end
        if Gui.selectable("Always hide Name Tags", is2Selected) then
            config.nameTagType = 2
            updateNameTagsVisibility()
            changed = true
        end
        Gui.endCombo()
    end

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

    Gui.newLine()

    if Gui.collapsingHeader("Viewpoint") then

        local newNearClip = Gui.sliderFloat("near clipping plane", config.nearClip, 0.1, 100)
        if newNearClip ~= config.nearClip then
            config.nearClip = newNearClip
            changed = true
        end

        Gui.text("view offset:")
        local newViewOffset = Gui.dragFloat3("view offset", config.viewpointOffset, 0.1, -10, 10)
        if newViewOffset
            and (
                newViewOffset.x ~= config.viewpointOffset.x
                or newViewOffset.y ~= config.viewpointOffset.y
                or newViewOffset.z ~= config.viewpointOffset.z
            )
        then
            config.viewpointOffset = newViewOffset
            changed = true
        end

    end

    if Gui.collapsingHeader("Manual Orbit") then
        local newOrbitRadius = Gui.sliderFloat("orbit radius", config.orbitRadius, 10, 1000)
        if newOrbitRadius ~= config.orbitRadius then
            config.orbitRadius = newOrbitRadius
            changed = true
        end

        local newOrbitRotSpeed = Gui.sliderFloat("rotation speed", config.orbitRotSpeed, 50, 360)
        if newOrbitRotSpeed ~= config.orbitRotSpeed then
            config.orbitRotSpeed = newOrbitRotSpeed
            changed = true
        end

        local newOrbitMouseSensitivity = Gui.sliderFloat("mouse sensitivity", config.orbitMouseSensitivity, 0.5, 10.0)
        if newOrbitMouseSensitivity ~= config.orbitMouseSensitivity then
            config.orbitMouseSensitivity = newOrbitMouseSensitivity
            changed = true
        end

        local newOrbitMouseWheelSensitivity = Gui.sliderFloat("scroll sensitivity", config.orbitMouseWheelSensitivity, 10, 150)
        if newOrbitMouseWheelSensitivity ~= config.orbitMouseWheelSensitivity then
            config.orbitMouseWheelSensitivity = newOrbitMouseWheelSensitivity
            changed = true
        end
    end

    if Gui.collapsingHeader("Interaction") then

        local newOwnerRecallTime = Gui.sliderFloat("owner recall time (sec)", config.ownerRecallTime, 0.5, 5.0)
        if newOwnerRecallTime ~= config.ownerRecallTime then
            config.ownerRecallTime = newOwnerRecallTime
            changed = true
        end

        local newHeadGrabRadius = Gui.sliderFloat("head grab range", config.headGrabRadius, 10, 100)
        if newHeadGrabRadius ~= config.headGrabRadius then
            config.headGrabRadius = newHeadGrabRadius
            changed = true
        end

        local newHeadDropRadius = Gui.sliderFloat("head drop range", config.headDropRadius, 10, 50)
        if newHeadDropRadius ~= config.headDropRadius then
            config.headDropRadius = newHeadDropRadius
            changed = true
        end

        local newCameraGrabRadius = Gui.sliderFloat("camera grab range", config.cameraGrabRadius, 10, 100)
        if newCameraGrabRadius ~= config.cameraGrabRadius then
            config.cameraGrabRadius = newCameraGrabRadius
            changed = true
        end

        local newGrabDelayTime = Gui.sliderFloat("grab delay time (sec)", config.grabDelayTime, 0.5, 3.0)
        if newGrabDelayTime ~= config.grabDelayTime then
            config.grabDelayTime = newGrabDelayTime
            changed = true
        end
    end

    if Gui.collapsingHeader("Third Person") then
        local newThirdPersonDistance = Gui.sliderFloat("camera distance", config.thirdPersonDistance, 50, 500)
        if newThirdPersonDistance ~= config.thirdPersonDistance then
            config.thirdPersonDistance = newThirdPersonDistance
            changed = true
        end

        Gui.separatorText("extension arm")
        local newExtensionEnabled = Gui.checkbox("enable extension arm", config.extensionEnabled)
        if newExtensionEnabled ~= config.extensionEnabled then
            config.extensionEnabled = newExtensionEnabled
            changed = true
        end

        if config.extensionEnabled then
            local newMinExtension = Gui.sliderFloat("minimum extension", config.minExtension, 0, 50)
            if newMinExtension ~= config.minExtension then
                config.minExtension = newMinExtension
                changed = true
            end

            local newMaxExtension = Gui.sliderFloat("maximum extension", config.maxExtension, 50, 500)
            if newMaxExtension ~= config.maxExtension then
                config.maxExtension = newMaxExtension
                changed = true
            end

            local newExtensionStep = Gui.sliderFloat("extension speed", config.extensionStep, 0.5, 20)
            if newExtensionStep ~= config.extensionStep then
                config.extensionStep = newExtensionStep
                changed = true
            end

            local newExtensionSmoothness = Gui.sliderFloat("extension smoothing", config.extensionSmoothness, 0, 0.95)
            if newExtensionSmoothness ~= config.extensionSmoothness then
                config.extensionSmoothness = newExtensionSmoothness
                changed = true
            end
        end
    end
   
    if Gui.collapsingHeader("Slingshot") then
        local newSlingshotEnabled = Gui.checkbox("enable slingshot", config.slingshotEnabled)
        if newSlingshotEnabled ~= config.slingshotEnabled then
            config.slingshotEnabled = newSlingshotEnabled
            changed = true
        end
        if config.slingshotEnabled then
            local newSlingshotDistance = Gui.sliderFloat("slingshot distance (cm)", config.slingshotDistance, 1000, 10000)
            if newSlingshotDistance ~= config.slingshotDistance then
                config.slingshotDistance = newSlingshotDistance
                changed = true
            end

            local newSlingshotLaunchTime = Gui.sliderFloat("launch time (sec)", config.slingshotLaunchTime, 0.5, 5.0)
            if newSlingshotLaunchTime ~= config.slingshotLaunchTime then
                config.slingshotLaunchTime = newSlingshotLaunchTime
                changed = true
            end

            local newSlingshotReturnTime = Gui.sliderFloat("return time (sec)", config.slingshotReturnTime, 1.0, 10.0)
            if newSlingshotReturnTime ~= config.slingshotReturnTime then
                config.slingshotReturnTime = newSlingshotReturnTime
                changed = true
            end

            local newDoubleClickThreshold = Gui.sliderFloat("double-click threshold (sec)", config.doubleClickThreshold, 0.1, 1.0)
            if newDoubleClickThreshold ~= config.doubleClickThreshold then
                config.doubleClickThreshold = newDoubleClickThreshold
                changed = true
            end
        end
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

    if Gui.button("Clear Saved Player") then
        config.currentPlayerId = nil
        if saveConfig then saveConfig() end
    end

    if ownerIsPresent then
        if Gui.button("Test Owner Recall") then
            activePlayerId = config.ownerId
            config.currentPlayerId = activePlayerId
            if saveConfig then saveConfig() end
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
        camera.rotationSmoothing = 0
        camera.positionSmoothing = 0
    end

    slingshotAngleX, slingshotAngleY, slingshotAngleZ = 0, 0, 0
    slingshotSpinX, slingshotSpinY, slingshotSpinZ = 0, 0, 0

    activePlayerId = nil
    viewpointMode = true
    thirdPersonMode = false
    manualOrbitMode = false
    cameraInHand = false
    handHolding = nil
    freeFloatingMode = false
    ballMode = false
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
    end
    if activePlayerId then
        config.currentPlayerId = activePlayerId
        if saveConfig then saveConfig() end
    end
end

function Axis.tick(dt)
    t = t + dt

    if configDirty and t >= configSaveAtTime then
        if saveConfig then saveConfig() end
        configDirty = false
    end

    if camera and not thirdPersonMode then
        camera.fieldOfView = config.fov
    end

    if slingshotLaunched then
        updateSlingshot(dt)
        return
    end

    if not didAutoAssignDefaultOwner
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
        if not activePlayerId then return end
    end

    local currentPlayer = getPlayerByTarget(getCurrentTarget())
    if not currentPlayer or not currentPlayer.head then
        activePlayerId = findAnyPlayer()
        if not activePlayerId then return end
        currentPlayer = getPlayerByTarget(getCurrentTarget())
        if not currentPlayer or not currentPlayer.head then return end
    end

    local recallTriggered = processOwnerRecall(dt)
    if recallTriggered then
        return
    end

    local rightHandPos, rightHandRot = getHandPosition(currentPlayer, false)
    local leftHandPos, leftHandRot = getHandPosition(currentPlayer, true)
    local isRightTrigger = isTriggerPressed(currentPlayer, false)
    local isLeftTrigger = isTriggerPressed(currentPlayer, true)

    local rightGripPressed = isGripPressed(currentPlayer, false)
    if (viewpointMode or thirdPersonMode) and rightHandPos and currentPlayer.head then
        local distToHead = Vec3.distance(rightHandPos, currentPlayer.head.position)
        if distToHead <= config.headDropRadius and rightGripPressed and not lastHeadModeToggleRightGripState then
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
    lastHeadModeToggleRightGripState = rightGripPressed

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

        camera.positionSmoothing = 0
        camera.rotationSmoothing = 0
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
                handleCameraRelease(currentPlayer)
            end
        elseif handHolding == "left" then
            if isLeftTrigger then
                updateLeftHandGrip(currentPlayer, leftHandPos, leftHandRot, dt)
            else
                handleCameraRelease(currentPlayer)
            end
        end
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
        camera.rotationSmoothing = 0
        camera.hideNearestHead = false
        updateNameTagsVisibility()
    end
end

function Axis.onGui()
    local wasEnabled = Axis.isEnabled
    Axis.isEnabled = Gui.checkbox("Use Handcam", Axis.isEnabled)
    Gui.setItemTooltip("Enable Handcam and disable Freecam.")

    if Axis.isEnabled ~= wasEnabled then
        if Axis.isEnabled then
            Axis.onLoad()
        else
            Axis.onUnload()
        end
    end

    if not Axis.isEnabled then
        Gui.sameLine()
        Gui.textDisabled("Enable to use Handcam instead of Freecam")
        return
    end

    Gui.separator()
    Gui.beginTabBar("HandcamSubTabs")
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
