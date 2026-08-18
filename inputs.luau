--!strict

return {
	forwardKey = Input.Key.W,
	backwardKey = Input.Key.S,
	leftKey = Input.Key.A,
	rightKey = Input.Key.D,
	upKey = Input.Key.E,
	downKey = Input.Key.Q,
	gravityAlignedMovementModifier = Input.Key.LeftAlt,
	localMovementAxesDefault = true,

	snapToGravityKey = Input.Key.SpaceBar,

	pitchUpKey = Input.Key.Up,
	pitchDownKey = Input.Key.Down,
	yawLeftKey = Input.Key.Left,
	yawRightKey = Input.Key.Right,

	rollMouseEnable = Input.Key.RightMouseButton,
	rollLeftGp = Input.Gamepad.DPad_Left,
	rollRightGp = Input.Gamepad.DPad_Right,
	rollResetTolerance = 5,

	fastKey = Input.Key.LeftShift,
	slowKey = Input.Key.LeftControl,

	zoomInGp = Input.Gamepad.DPad_Up,
	zoomOutGp = Input.Gamepad.DPad_Down,
	zoomSpeedGp = 0.5,
	zoomSpeedKb = 5,

	spaceLocationKey = Input.Key.PageUp,
	enableSpaceKeybind = false,

	minFov = 10,
	maxFov = 160,

	rotSpeed = 180,
	fovRotSpeedMultiplier = 2,

	maxMoveSpeed = 25000,
	minMoveSpeed = 200,
	speedAdjustmentRate = 1,
	lookSmoothness = 0,
	lookInputTarget = Vec3.zeroVector,
	rotEuler = Vec3.zeroVector,
	firstTransition = true,
	smoothing = false,
	toggleSmoothingKey = Input.Key.CapsLock,

	gravityChaseSpeed = 6,
	gravitySlowChaseSpeed = 0.5,

	autoFocusKeyKB = Input.Key.MiddleMouseButton,
	autoFocusKeyGP = Input.Gamepad.RightThumbstick,
	continuousAutoFocus = false,
	alignToGravity = true,

	playGoalExplosions = false,
	playScraprunSpinners = false,
	placeBallEnabled = true,
	ballScaleMultiplier = 1,
}
