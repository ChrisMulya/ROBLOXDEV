-- Shared reason codes for camera-shelf swap results, and their player-facing
-- display strings. Keeps the server's returned code and the client's
-- rendered text in one place instead of scattered print()s.

local ShelfResultCodes = {}

ShelfResultCodes.Messages = {
	Success = "Camera equipped.",
	AlreadyHolding = "You're already holding this camera.",
	PreferenceSaved = "Saved -- you'll start with this camera next time.",
	InvalidCamera = "That camera doesn't exist.",
	NoBackpack = "Couldn't swap cameras right now.",
	InCameraSession = "Exit camera mode before switching cameras.",
	TooFarAway = "Move closer to the shelf.",
}

function ShelfResultCodes.GetMessage(code: string?): string
	return (code and ShelfResultCodes.Messages[code]) or "Something went wrong."
end

return ShelfResultCodes
