--!strict

local Util = {}

function Util.getSessions()
	-- Used in 912321 scenarios so i added it here
	return getAllGameData and getAllGameData() or (getGameData and { getGameData() } or {})
end

function Util.findPlayerById(playerId, preferredSessionIndex)
	if not playerId then
		return nil
	end

	local sessions = Util.getSessions()
	if preferredSessionIndex and sessions[preferredSessionIndex] and sessions[preferredSessionIndex].getPlayerById then
		local player = sessions[preferredSessionIndex]:getPlayerById(playerId)
		if player then
			return player
		end
	end

	for _, session in ipairs(sessions) do
		if session and session.getPlayerById then
			local player = session:getPlayerById(playerId)
			if player then
				return player
			end
		end
	end

	return nil
end

function Util.getPlayers()
	local players = {}
	for sessionIndex, session in ipairs(Util.getSessions()) do
		if session and session.players then
			for _, playerInfo in ipairs(session.players) do
				if playerInfo and playerInfo.playerId then
					local player = session.getPlayerById and session:getPlayerById(playerInfo.playerId) or playerInfo
					if player and player.playerName then
						table.insert(players, {
							id = playerInfo.playerId,
							sessionIndex = sessionIndex,
							name = player.playerName,
							object = player,
						})
					end
				end
			end
		end
	end
	return players
end

function Util.saveConfigIfAvailable()
	if saveConfig then
		saveConfig()
	end
end

function Util.projectVectorOntoPlane(vec: Vec3, normal: Vec3)
	-- Removes only the part pointing into the plane normal
	local normalizedNormal = normal:getSafeNormal()
	local dot1 = vec:dot(normalizedNormal)
	local proj = normalizedNormal * dot1
	local answer = vec - proj
	return answer
end

function Util.xor(a, b)
	return (a and not b) or (not a and b)
end

function Util.setSmoothing(smoothing: boolean, Inputs)
	if smoothing then
		camera.positionSmoothing = 0.15
		camera.rotationSmoothing = 0.02
		camera.fieldOfViewSmoothing = 0.15
		if Inputs and Inputs.lookSmoothness ~= nil then
			Inputs.lookSmoothness = 0.7
		end
	else
		camera.positionSmoothing = 0.02
		camera.rotationSmoothing = 0.02
		camera.fieldOfViewSmoothing = 0.05
		if Inputs and Inputs.lookSmoothness ~= nil then
			Inputs.lookSmoothness = 0
		end
	end
end

function Util.clearAxisSmoothing(Inputs)
	-- I hated this bug so i just forced playercam when turned off to constantly toggle on off aaand it works lmfao
	if camera then
		camera.positionSmoothing = 0.02
		camera.rotationSmoothing = 0.02
		camera.fieldOfViewSmoothing = 0.05
	end
	if Inputs and Inputs.lookSmoothness ~= nil then
		Inputs.lookSmoothness = 0
	end
	Util.setSmoothing(true, Inputs)
	Util.setSmoothing(false, Inputs)
	Util.setSmoothing(false, Inputs)
end

function Util.autoFocusCenter()
	local maxAutoFocusDistance = 1000000
	local hit =
		camera:castRay(camera.position, camera.position + camera.rotation:getForwardVector() * maxAutoFocusDistance)
	if hit.successful then
		local distanceToHit = Vec3.distance(camera.position, hit.position)
		postProcessSettings.depthOfFieldFocalDistance = distanceToHit
	end
end

return Util
