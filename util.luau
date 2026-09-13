--!strict

local Util = {}

function Util.projectVectorOntoPlane(vec: Vec3, normal: Vec3)
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
	-- Reset the camera to the freecam/off state and pulse smoothing ON then OFF twice
	-- so the stale handcam axes values cannot remain stuck in the background.
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
	local hit = camera:castRay(camera.position, camera.position + camera.rotation:getForwardVector() * maxAutoFocusDistance)
	if hit.successful then
		local distanceToHit = Vec3.distance(camera.position, hit.position)
		postProcessSettings.depthOfFieldFocalDistance = distanceToHit
	end
end

return Util
