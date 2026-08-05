-- "Is this client currently being driven by touch?" -- the one answer every
-- touch-only UI in the repo should ask for. Client-only in practice; lives in
-- ReplicatedStorage because that is where shared client modules go.
--
-- Two things make the obvious test wrong, and both cost real debugging time:
--
--   1. `TouchEnabled and not KeyboardEnabled` reads as "a phone", but
--      KeyboardEnabled is TRUE on a touchscreen laptop and TRUE in Studio's
--      Test -> Device emulator (the developer's real keyboard). Any UI behind
--      that gate is invisible in the emulator, so it cannot be tested there at
--      all.
--   2. Reading UserInputService ONCE at module load is a snapshot. Switching
--      Studio to a phone preset after pressing Play flips TouchEnabled long
--      afterwards, and a script that already decided (or already returned)
--      never notices.
--
-- Hence: call IsActive() per frame / per call, never cache it in an upvalue.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local TouchSession = {}

-- True when Roblox is showing this client the touch controls. PlayerGui.TouchGui
-- is the strong signal -- the engine creates it exactly when it decides this
-- client gets a thumbstick, which is the same condition touch-only UI cares
-- about. It appears a few seconds into a session (after the controls build),
-- so the fallback covers the gap and any layout that renames/replaces it.
function TouchSession.IsActive(): boolean
	local player = Players.LocalPlayer
	if not player then
		return false
	end

	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui and playerGui:FindFirstChild("TouchGui") then
		return true
	end

	return UserInputService.TouchEnabled
		and UserInputService:GetLastInputType() == Enum.UserInputType.Touch
end

return TouchSession
