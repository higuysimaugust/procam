-- WHo likes math anyway

local Path = {}
local Inputs = require("../More/inputs")
local parseKeyStr = Inputs.parseKeyStr

config = config or {}
config.pathPlayKeyEnabled = config.pathPlayKeyEnabled ~= nil and config.pathPlayKeyEnabled or false
config.pathPlayKeyStr = config.pathPlayKeyStr or "SpaceBar"
config.pathAddKeyEnabled = config.pathAddKeyEnabled ~= nil and config.pathAddKeyEnabled or false
config.pathAddKeyStr = config.pathAddKeyStr or "V"

Path.keyframes = {}
Path.isPlaying = false
Path.overrideNextTick = false
Path.canResume = false
Path.currentTime = 0
Path.enableSmoothness = config.pathEnableSmoothness ~= nil and config.pathEnableSmoothness or true
Path.smoothnessFactor = config.pathSmoothnessFactor ~= nil and config.pathSmoothnessFactor or 1
Path.loopPlayback = config.pathLoopPlayback ~= nil and config.pathLoopPlayback or false
Path.defaultDuration = 2.0
Path.endPadding = 0.25
Path.cache = {
	posVel = {},
	fovVel = {},
	rotControl = {},
}

local function matchQuat(ref, q)
	-- q and -q are the same rotation, but interpolation does not know that..........rude.
	local dot = ref.x * q.x + ref.y * q.y + ref.z * q.z + ref.w * q.w
	if dot < 0 then
		return Quat.new(-q.x, -q.y, -q.z, -q.w)
	end
	return q
end

local function quatInv(q)
	return Quat.new(-q.x, -q.y, -q.z, q.w)
end

local function quatMul(q1, q2)
	return Quat.new(
		q1.w * q2.x + q1.x * q2.w + q1.y * q2.z - q1.z * q2.y,
		q1.w * q2.y - q1.x * q2.z + q1.y * q2.w + q1.z * q2.x,
		q1.w * q2.z + q1.x * q2.y - q1.y * q2.x + q1.z * q2.w,
		q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z
	)
end

local function quatLog(q)
	local len = math.sqrt(q.x * q.x + q.y * q.y + q.z * q.z)
	if len < 0.00001 then
		return Vec3.new(0, 0, 0)
	end
	local angle = math.atan2(len, q.w)
	local coeff = angle / len
	return Vec3.new(q.x * coeff, q.y * coeff, q.z * coeff)
end

local function quatExp(v)
	local len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
	if len < 0.00001 then
		return Quat.new(0, 0, 0, 1)
	end
	local sinA = math.sin(len)
	local cosA = math.cos(len)
	local coeff = sinA / len
	return Quat.new(v.x * coeff, v.y * coeff, v.z * coeff, cosA)
end

local function squad(q1, q2, s1, s2, t)
	q2 = matchQuat(q1, q2)
	s1 = matchQuat(q1, s1)
	s2 = matchQuat(q2, s2)
	local q12 = Quat.slerp(q1, q2, t)
	local s12 = Quat.slerp(s1, s2, t)
	s12 = matchQuat(q12, s12)
	return Quat.slerp(q12, s12, 2 * t * (1 - t))
end

local function hermiteVec3(p1, v1, p2, v2, t)
	local t2 = t * t
	local t3 = t2 * t
	local h00 = 2 * t3 - 3 * t2 + 1
	local h10 = t3 - 2 * t2 + t
	local h01 = -2 * t3 + 3 * t2
	local h11 = t3 - t2
	return p1 * h00 + v1 * h10 + p2 * h01 + v2 * h11
end

local function hermiteNumber(n1, v1, n2, v2, t)
	local t2 = t * t
	local t3 = t2 * t
	local h00 = 2 * t3 - 3 * t2 + 1
	local h10 = t3 - 2 * t2 + t
	local h01 = -2 * t3 + 3 * t2
	local h11 = t3 - t2
	return n1 * h00 + v1 * h10 + n2 * h01 + v2 * h11
end

local function solveSplineSystem(a, b, c, rPos, rFov)
	-- who in hell is thomas
	local cPrime = {}
	local rPosPrime = {}
	local rFovPrime = {}

	cPrime[1] = c[1] / b[1]
	rPosPrime[1] = rPos[1] * (1 / b[1])
	rFovPrime[1] = rFov[1] / b[1]

	for i = 2, #b do
		local denom = b[i] - a[i] * cPrime[i - 1]
		cPrime[i] = c[i] / denom
		rPosPrime[i] = (rPos[i] - rPosPrime[i - 1] * a[i]) * (1 / denom)
		rFovPrime[i] = (rFov[i] - rFovPrime[i - 1] * a[i]) / denom
	end

	local posVel = {}
	local fovVel = {}
	posVel[#b] = rPosPrime[#b]
	fovVel[#b] = rFovPrime[#b]
	for i = #b - 1, 1, -1 do
		posVel[i] = rPosPrime[i] - posVel[i + 1] * cPrime[i]
		fovVel[i] = rFovPrime[i] - fovVel[i + 1] * cPrime[i]
	end
	return posVel, fovVel
end

function Path.rebuildSplineCache()
	local kfs = Path.keyframes
	local n = #kfs
	Path.cache.posVel = {}
	Path.cache.fovVel = {}
	-- cahching velocities booi
	Path.cache.rotControl = {}

	if n < 2 then
		return
	end

	if not Path.loopPlayback then
		if n == 2 then
			local d = kfs[1].duration or Path.defaultDuration
			if d <= 0 then d = Path.defaultDuration end
			local posV = (kfs[2].position - kfs[1].position) * (1 / d)
			local fovV = (kfs[2].fieldOfView - kfs[1].fieldOfView) / d
			Path.cache.posVel = { posV, Vec3.zeroVector }
			Path.cache.fovVel = { fovV, 0 }
			Path.cache.rotControl = { kfs[1].rotation, kfs[2].rotation }
			return
		end

		local a, b, c, rPos, rFov = {}, {}, {}, {}, {}
		for i = 1, n do
			a[i], b[i], c[i] = 0, 0, 0
			rPos[i] = Vec3.new(0, 0, 0)
			rFov[i] = 0
		end

		local d1 = kfs[1].duration or Path.defaultDuration
		if d1 <= 0 then d1 = Path.defaultDuration end
		b[1] = 2
		c[1] = 1
		rPos[1] = (kfs[2].position - kfs[1].position) * (3 / d1)
		rFov[1] = (kfs[2].fieldOfView - kfs[1].fieldOfView) * (3 / d1)

		for i = 2, n - 1 do
			local dim1 = kfs[i - 1].duration or Path.defaultDuration
			local di = kfs[i].duration or Path.defaultDuration
			if dim1 <= 0 then dim1 = Path.defaultDuration end
			if di <= 0 then di = Path.defaultDuration end

			a[i] = 1 / dim1
			b[i] = 2 * (1 / dim1 + 1 / di)
			c[i] = 1 / di
			rPos[i] = (kfs[i].position - kfs[i - 1].position) * (3 / (dim1 * dim1))
				+ (kfs[i + 1].position - kfs[i].position) * (3 / (di * di))
			rFov[i] = (kfs[i].fieldOfView - kfs[i - 1].fieldOfView) * (3 / (dim1 * dim1))
				+ (kfs[i + 1].fieldOfView - kfs[i].fieldOfView) * (3 / (di * di))
		end

		local dnm1 = kfs[n - 1].duration or Path.defaultDuration
		if dnm1 <= 0 then dnm1 = Path.defaultDuration end
		a[n] = 1
		b[n] = 2
		rPos[n] = (kfs[n].position - kfs[n - 1].position) * (3 / dnm1)
		rFov[n] = (kfs[n].fieldOfView - kfs[n - 1].fieldOfView) * (3 / dnm1)

		Path.cache.posVel, Path.cache.fovVel = solveSplineSystem(a, b, c, rPos, rFov)

		Path.cache.posVel[n] = Vec3.zeroVector
		Path.cache.fovVel[n] = 0

		for i = 1, n do
			if i == 1 then
				Path.cache.rotControl[1] = kfs[1].rotation
			elseif i == n then
				Path.cache.rotControl[n] = kfs[n].rotation
			else
				local qPrev = matchQuat(kfs[i].rotation, kfs[i - 1].rotation)
				local qCurr = kfs[i].rotation
				local qNext = matchQuat(qCurr, kfs[i + 1].rotation)

				local invQ = quatInv(qCurr)
				local dp = quatLog(quatMul(invQ, qNext))
				local dm = quatLog(quatMul(invQ, qPrev))

				local sumLog = (dp + dm) * (-0.25)
				Path.cache.rotControl[i] = quatMul(qCurr, quatExp(sumLog))
			end
		end
	else
		-- duplicate the ends so the loop joins using the same spline math as the middle its 2 am btw pls send help if oyou read this
		local extKfs = {}
		table.insert(extKfs, kfs[n - 1])
		table.insert(extKfs, kfs[n])
		for i = 1, n do
			table.insert(extKfs, kfs[i])
		end
		table.insert(extKfs, kfs[1])
		table.insert(extKfs, kfs[2])

		local extN = #extKfs
		local a, b, c, rPos, rFov = {}, {}, {}, {}, {}
		for i = 1, extN do
			a[i], b[i], c[i] = 0, 0, 0
			rPos[i] = Vec3.new(0, 0, 0)
			rFov[i] = 0
		end

		local d1 = extKfs[1].duration or Path.defaultDuration
		if d1 <= 0 then d1 = Path.defaultDuration end
		b[1] = 2
		c[1] = 1
		rPos[1] = (extKfs[2].position - extKfs[1].position) * (3 / d1)
		rFov[1] = (extKfs[2].fieldOfView - extKfs[1].fieldOfView) * (3 / d1)

		for i = 2, extN - 1 do
			local dim1 = extKfs[i - 1].duration or Path.defaultDuration
			local di = extKfs[i].duration or Path.defaultDuration
			if dim1 <= 0 then dim1 = Path.defaultDuration end
			if di <= 0 then di = Path.defaultDuration end

			a[i] = 1 / dim1
			b[i] = 2 * (1 / dim1 + 1 / di)
			c[i] = 1 / di
			rPos[i] = (extKfs[i].position - extKfs[i - 1].position) * (3 / (dim1 * dim1))
				+ (extKfs[i + 1].position - extKfs[i].position) * (3 / (di * di))
			rFov[i] = (extKfs[i].fieldOfView - extKfs[i - 1].fieldOfView) * (3 / (dim1 * dim1))
				+ (extKfs[i + 1].fieldOfView - extKfs[i].fieldOfView) * (3 / (di * di))
		end

		local dnm1 = extKfs[extN - 1].duration or Path.defaultDuration
		if dnm1 <= 0 then dnm1 = Path.defaultDuration end
		a[extN] = 1
		b[extN] = 2
		rPos[extN] = (extKfs[extN].position - extKfs[extN - 1].position) * (3 / dnm1)
		rFov[extN] = (extKfs[extN].fieldOfView - extKfs[extN - 1].fieldOfView) * (3 / dnm1)

		local extPosVel, extFovVel = solveSplineSystem(a, b, c, rPos, rFov)

		for i = 1, n do
			Path.cache.posVel[i] = extPosVel[i + 2]
			Path.cache.fovVel[i] = extFovVel[i + 2]
		end

		for i = 1, n do
			local iPrev = (i == 1) and n or (i - 1)
			local iNext = (i == n) and 1 or (i + 1)
			local qPrev = matchQuat(kfs[i].rotation, kfs[iPrev].rotation)
			local qCurr = kfs[i].rotation
			local qNext = matchQuat(qCurr, kfs[iNext].rotation)

			local invQ = quatInv(qCurr)
			local dp = quatLog(quatMul(invQ, qNext))
			local dm = quatLog(quatMul(invQ, qPrev))

			local sumLog = (dp + dm) * (-0.25)
			Path.cache.rotControl[i] = quatMul(qCurr, quatExp(sumLog))
			-- if youre reading this then i deleted liek ~40 lines of debug comments just for you
		end
	end
end

local function loadKeyframesFromConfig()
	for _, savedKeyframe in ipairs(config.pathKeyframes or {}) do
		if savedKeyframe.position and savedKeyframe.rotation then
			table.insert(Path.keyframes, {
				position = Vec3.new(savedKeyframe.position.x, savedKeyframe.position.y, savedKeyframe.position.z),
				rotation = Quat.new(
					savedKeyframe.rotation.x,
					savedKeyframe.rotation.y,
					savedKeyframe.rotation.z,
					savedKeyframe.rotation.w
				),
				rotEuler = savedKeyframe.rotEuler and Vec3.new(
					savedKeyframe.rotEuler.x,
					savedKeyframe.rotEuler.y,
					savedKeyframe.rotEuler.z
				) or nil,
				fieldOfView = savedKeyframe.fieldOfView,
				duration = savedKeyframe.duration or Path.defaultDuration,
			})
		end
	end
	Path.rebuildSplineCache()
end

local function savePathConfig()
	config.pathLoopPlayback = Path.loopPlayback
	config.pathEnableSmoothness = Path.enableSmoothness
	config.pathSmoothnessFactor = Path.smoothnessFactor
	config.pathKeyframes = {}
	for _, keyframe in ipairs(Path.keyframes) do
		table.insert(config.pathKeyframes, {
			position = {
				x = keyframe.position.x,
				y = keyframe.position.y,
				z = keyframe.position.z,
			},
			rotation = {
				x = keyframe.rotation.x,
				y = keyframe.rotation.y,
				z = keyframe.rotation.z,
				w = keyframe.rotation.w,
			},
			rotEuler = keyframe.rotEuler and {
				x = keyframe.rotEuler.x,
				y = keyframe.rotEuler.y,
				z = keyframe.rotEuler.z,
			} or nil,
			fieldOfView = keyframe.fieldOfView,
			duration = keyframe.duration,
		})
	end
	if saveConfig then
		saveConfig()
	end
end

loadKeyframesFromConfig()

function Path.isPlaybackActive()
	return Path.isPlaying
end

function Path.getPathDuration()
	local count = #Path.keyframes
	if count < 2 then
		return 0
	end
	local total = 0
	local segmentCount = Path.loopPlayback and count or (count - 1)
	for i = 1, segmentCount do
		total = total + (Path.keyframes[i].duration or Path.defaultDuration)
	end
	if not Path.loopPlayback then
		total = total + Path.endPadding
	end
	return total
end

function Path.getTotalDuration()
	return Path.getPathDuration()
end

function Path.addKeyframe()
	table.insert(Path.keyframes, {
		position = Vec3.new(camera.position.x, camera.position.y, camera.position.z),
		rotation = camera.rotation,
		rotEuler = Vec3.new(Inputs.rotEuler.x, Inputs.rotEuler.y, Inputs.rotEuler.z),
		fieldOfView = camera.fieldOfView,
		duration = Path.defaultDuration,
	})
	Path.rebuildSplineCache()
	savePathConfig()
end

function Path.play()
	if #Path.keyframes == 0 then
		return
	end
	Path.isPlaying = true
	Path.canResume = false
	Path.currentTime = 0
	Path.applyStateAtTime(0)
end

function Path.stop()
	Path.isPlaying = false
	Path.canResume = false
end

function Path.pause()
	Path.isPlaying = false
	Path.canResume = Path.currentTime > 0 and Path.currentTime < Path.getTotalDuration()
end

function Path.resume()
	if Path.currentTime >= Path.getTotalDuration() or Path.getTotalDuration() <= 0 then
		return
	end
	Path.canResume = false
	Path.isPlaying = true
end

function Path.applyKeyframe(keyframe)
	camera.position = keyframe.position
	camera.rotation = keyframe.rotation
	camera.fieldOfView = keyframe.fieldOfView
	if keyframe.rotEuler then
		Inputs.rotEuler = Vec3.new(keyframe.rotEuler.x, keyframe.rotEuler.y, keyframe.rotEuler.z)
	end
	Path.overrideNextTick = true
end

function Path.releaseCamera()
	Path.overrideNextTick = false
end

function Path.consumeCameraOverride()
	if not Path.overrideNextTick then
		return false
	end
	Path.overrideNextTick = false
	return true
end

function Path.evaluateAtTime(targetTime)
	local count = #Path.keyframes
	if count == 0 then
		return camera.position, camera.rotation, camera.fieldOfView, Inputs.rotEuler
	end
	if count == 1 then
		return Path.keyframes[1].position,
			Path.keyframes[1].rotation,
			Path.keyframes[1].fieldOfView,
			Path.keyframes[1].rotEuler or Inputs.rotEuler
	end

	local totalDuration = Path.getPathDuration()
	if totalDuration <= 0 then
		return Path.keyframes[1].position,
			Path.keyframes[1].rotation,
			Path.keyframes[1].fieldOfView,
			Path.keyframes[1].rotEuler or Inputs.rotEuler
	end

	local clampedTime = math.clamp(targetTime, 0, totalDuration)
	local accumulatedTime = 0
	local segmentIndex = 1
	local segmentProgress = 0
	local segmentCount = Path.loopPlayback and count or (count - 1)

	for i = 1, segmentCount do
		local segDuration = Path.keyframes[i].duration or Path.defaultDuration
		if clampedTime <= accumulatedTime + segDuration or i == segmentCount then
			segmentIndex = i
			if segDuration > 0 then
				segmentProgress = (clampedTime - accumulatedTime) / segDuration
			else
				segmentProgress = 1
			end
			break
		end
		accumulatedTime = accumulatedTime + segDuration
	end

	local t = math.clamp(segmentProgress, 0, 1)
	if not Path.loopPlayback and segmentIndex == count - 1 then
		t = 1 - (1 - t) ^ 3
	end

	local idx1 = segmentIndex
	local idx2 = (segmentIndex % count) + 1

	local k1 = Path.keyframes[idx1]
	local k2 = Path.keyframes[idx2]

	local segDuration = k1.duration or Path.defaultDuration
	if segDuration <= 0 then segDuration = Path.defaultDuration end

	local p1, p2 = k1.position, k2.position
	local linearPosVel = (p2 - p1) * (1 / segDuration)

	local V1 = Path.cache.posVel[idx1] or linearPosVel
	local V2 = Path.cache.posVel[idx2] or linearPosVel

	local smoothness = Path.enableSmoothness and Path.smoothnessFactor or 0

	local effV1 = linearPosVel + (V1 - linearPosVel) * smoothness
	local effV2 = linearPosVel + (V2 - linearPosVel) * smoothness

	local finalPos = hermiteVec3(p1, effV1 * segDuration, p2, effV2 * segDuration, t)

	local q1 = k1.rotation
	local q2 = matchQuat(q1, k2.rotation)
	local s1 = Path.cache.rotControl[idx1] or q1
	local s2 = Path.cache.rotControl[idx2] or q2

	local linearRot = Quat.slerp(q1, q2, t)
	local squadRot = squad(q1, q2, s1, s2, t)
	squadRot = matchQuat(linearRot, squadRot)
	local finalRot = Quat.slerp(linearRot, squadRot, smoothness)

	local f1, f2 = k1.fieldOfView, k2.fieldOfView
	local linearFovVel = (f2 - f1) / segDuration

	local VF1 = Path.cache.fovVel[idx1] or linearFovVel
	local VF2 = Path.cache.fovVel[idx2] or linearFovVel

	local effVF1 = linearFovVel + (VF1 - linearFovVel) * smoothness
	local effVF2 = linearFovVel + (VF2 - linearFovVel) * smoothness

	local finalFov = hermiteNumber(f1, effVF1 * segDuration, f2, effVF2 * segDuration, t)

	local finalRotEuler = finalRot:euler()

	return finalPos, finalRot, finalFov, finalRotEuler
end

function Path.applyStateAtTime(targetTime)
	local pos, rot, fov, rotEuler = Path.evaluateAtTime(targetTime)
	camera.position = pos
	camera.rotation = rot
	camera.fieldOfView = fov
	if rotEuler then
		Inputs.rotEuler = Vec3.new(rotEuler.x, rotEuler.y, rotEuler.z)
	end
	Path.overrideNextTick = true
end

function Path.tick(dt)
	if config.pathPlayKeyEnabled then
		local playKey = parseKeyStr(config.pathPlayKeyStr)
		if playKey and Input.getKeyDown(playKey) then
			Path.play()
		end
	end
	if config.pathAddKeyEnabled then
		local addKey = parseKeyStr(config.pathAddKeyStr)
		if addKey and Input.getKeyDown(addKey) then
			Path.stop()
			Path.addKeyframe()
		end
	end

	if not Path.isPlaying then
		return
	end

	local totalDuration = Path.getTotalDuration()
	if totalDuration <= 0 then
		Path.isPlaying = false
		return
	end

	Path.currentTime = Path.currentTime + dt

	if Path.currentTime >= totalDuration then
		if Path.loopPlayback then
			Path.currentTime = Path.currentTime % totalDuration
		else
			Path.currentTime = totalDuration
			Path.isPlaying = false
			Path.canResume = false
		end
	end

	Path.applyStateAtTime(Path.currentTime)
end

function Path.onGui(isFreecam)
	if not isFreecam then
		Gui.textDisabled("Disable Playercam to use Path")
		return
	end

	Gui.textDisabled("Create keyframes and play them back to create cinematic shots!")

	Gui.separatorText("Keybinds")
	Inputs.drawConfigKeybind({
		label = Icon.Play .. "  Play From Start##keybind",
		enabledKey = "pathPlayKeyEnabled",
		keyKey = "pathPlayKeyStr",
		comboId = "##PathPlayKey",
		defaultKey = "SpaceBar",
	})

	Inputs.drawConfigKeybind({
		label = Icon.Plus .. "  Add New Keyframe",
		enabledKey = "pathAddKeyEnabled",
		keyKey = "pathAddKeyStr",
		comboId = "##PathAddKey",
		defaultKey = "V",
	})

	Gui.separatorText("Settings")
	local loopPlayback = Gui.checkbox("Loop Playback", Path.loopPlayback)
	if loopPlayback ~= Path.loopPlayback then
		Path.stop()
		Path.loopPlayback = loopPlayback
		Path.rebuildSplineCache()
		savePathConfig()
	end

	local enableSmoothness = Gui.checkbox("Playback Smoothness", Path.enableSmoothness)
	if enableSmoothness ~= Path.enableSmoothness then
		Path.stop()
		Path.enableSmoothness = enableSmoothness
		savePathConfig()
	end

	if Path.enableSmoothness then
		Gui.sameLine()
		Gui.setNextItemWidth(300)
		local smoothnessFactor = Gui.sliderFloat("##ps", Path.smoothnessFactor, 0.0, 1.0)
		if smoothnessFactor ~= Path.smoothnessFactor then
			Path.stop()
			Path.smoothnessFactor = smoothnessFactor
			savePathConfig()
		end
	end

	Gui.separatorText("Playback")

	if Path.isPlaying then
		Gui.beginDisabled()
		if Gui.button(Icon.Play .. "  Play From Start") then
		end
		Gui.endDisabled()
		Gui.sameLine()
		if Gui.button(Icon.Pause .. "  Pause") then
			Path.pause()
		end
		Gui.sameLine()
		if Gui.button(Icon.Stop .. "  Stop") then
			Path.stop()
		end
	elseif #Path.keyframes > 0 then
		if Gui.button(Icon.Play .. "  Play From Start") then
			Path.play()
		end
		if Path.canResume then
			Gui.sameLine()
			if Gui.button(Icon.Play .. "  Resume") then
				Path.resume()
			end
		end
	else
		Gui.beginDisabled()
		Gui.button(Icon.Play .. "  Play From Start")
		Gui.endDisabled()
	end

	local totalDuration = Path.getTotalDuration()
	local newProgress = Gui.sliderFloat("Playback", Path.currentTime, 0, totalDuration)

	if math.abs(newProgress - Path.currentTime) > 0.001 and totalDuration > 0 then
		Path.stop()
		Path.currentTime = newProgress
		Path.applyStateAtTime(Path.currentTime)
	end

	Gui.sameLine()
	Gui.textDisabled(string.format("%.2f / %.2f s", Path.currentTime, totalDuration))

	Gui.separatorText("Keyframes (" .. tostring(#Path.keyframes) .. ")")

	if Gui.button(Icon.Plus .. "  Create Keyframe") then
		Path.stop()
		Path.addKeyframe()
	end
	Gui.sameLine()
	if Gui.buttonColored(LinearColor.new(1, 0, 0, 1), Icon.Trash .. "  Clear All") then
		Path.stop()
		Path.keyframes = {}
		Path.currentTime = 0
		Path.rebuildSplineCache()
		savePathConfig()
	end

	local toRemove = nil
	Gui.beginHorizontal("Keyframes area")
	if #Path.keyframes > 0 then
		Gui.beginDisabled()
		Gui.vSliderInt("##keyframes", #Path.keyframes * 103, #Path.keyframes, 1, #Path.keyframes)
		Gui.endDisabled()
	end
	Gui.beginVertical("Keyframes list")
	for i, kf in ipairs(Path.keyframes) do
		Gui.pushId("kf_" .. tostring(i))
		Gui.beginHorizontal("Keyframe horizontal " .. tostring(i))

		Gui.beginVertical("up/down " .. tostring(i))
		Gui.text(tostring(i))
		if i == 1 then
			Gui.beginDisabled()
		end
		if Gui.button(Icon.CaretUp) then
			if i > 1 then
				local temp = Path.keyframes[i]
				Path.keyframes[i] = Path.keyframes[i - 1]
				Path.keyframes[i - 1] = temp
				Path.rebuildSplineCache()
				savePathConfig()
			end
		end
		if i == 1 then
			Gui.endDisabled()
		end
		Gui.setItemTooltip("Move Up")
		if i == #Path.keyframes then
			Gui.beginDisabled()
		end
		if Gui.button(Icon.CaretDown) then
			if i < #Path.keyframes then
				local temp = Path.keyframes[i]
				Path.keyframes[i] = Path.keyframes[i + 1]
				Path.keyframes[i + 1] = temp
				Path.rebuildSplineCache()
				savePathConfig()
			end
		end
		if i == #Path.keyframes then
			Gui.endDisabled()
		end
		Gui.setItemTooltip("Move Down")
		Gui.endVertical()

		Gui.beginVertical("Keyframe vertical " .. tostring(i))

		if i > 1 then
		-- i hated the first separator also does it look better with each having separators? imo it does thars why its tehre
			Gui.separator()
		end

		Gui.textDisabled("Position: " .. string.format("%.2f, %.2f, %.2f", kf.position.x, kf.position.y, kf.position.z))

		local duration = Gui.sliderFloat("Duration##" .. tostring(i), kf.duration or Path.defaultDuration, 0.1, 10.0)
		if duration ~= kf.duration then
			Path.stop()
			kf.duration = duration
			Path.rebuildSplineCache()
			savePathConfig()
		end

		Gui.sameLine()
		Gui.textDisabled("(sec)")

		if Gui.buttonColored(LinearColor.new(0,0,0,0), Icon.LocationArrow .. "  Jump To##" .. tostring(i)) then
			Path.stop()
			Path.applyKeyframe(kf)
		end

		Gui.sameLine()

		if Gui.buttonColored(LinearColor.new(0,0,0,0), Icon.Sync .. "  Update##" .. tostring(i)) then
			Path.stop()
			kf.position = Vec3.new(camera.position.x, camera.position.y, camera.position.z)
			kf.rotation = camera.rotation
			kf.rotEuler = Vec3.new(Inputs.rotEuler.x, Inputs.rotEuler.y, Inputs.rotEuler.z)
			kf.fieldOfView = camera.fieldOfView
			Path.rebuildSplineCache()
			savePathConfig()
		end

		Gui.sameLine()

		if Gui.buttonColored(LinearColor.new(9,0,0,0.5), Icon.Trash .. "  Delete##" .. tostring(i)) then
			Path.stop()
			toRemove = i
		end
		Gui.endVertical()
		Gui.endHorizontal()
		Gui.popId()
	end
	Gui.endVertical()
	Gui.endHorizontal()

	if toRemove then
		table.remove(Path.keyframes, toRemove)
		Path.rebuildSplineCache()
		savePathConfig()
	end
end

return Path