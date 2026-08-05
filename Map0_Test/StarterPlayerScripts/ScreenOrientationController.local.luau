-- Locks mobile clients to landscape.
--
-- Every touch control this game ships is laid out for a wide screen: the
-- thumbstick and sprint button bottom-left, jump bottom-right, camera HUD
-- middle-right. In portrait they crowd into each other and the viewfinder has
-- almost no horizontal room to frame a shot.
--
-- LandscapeSensor rather than LandscapeLeft: it stays landscape but lets the
-- device pick which way up, so a player holding the phone "the other way"
-- isn't upside down. Both landscape orientations are equally playable here;
-- portrait is the only one that isn't.
--
-- No-op on desktop and in Studio's non-emulated Play -- ScreenOrientation only
-- means anything to a device that can rotate.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local ORIENTATION = Enum.ScreenOrientation.LandscapeSensor

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- StarterGui is the value a PlayerGui is created from. Setting it does NOT
-- update the existing PlayerGui (measured: the write holds on StarterGui and
-- PlayerGui keeps its own value), so it is the seed, not the fix.
StarterGui.ScreenOrientation = ORIENTATION

local function apply()
	if playerGui.ScreenOrientation ~= ORIENTATION then
		playerGui.ScreenOrientation = ORIENTATION
	end
end

apply()

-- Re-applied on change rather than written once.
--
-- Measured: a single write at script start silently loses -- the property read
-- back as Sensor several seconds into the session, with no error and nothing
-- visibly reverting it, because this script runs before the engine finishes
-- initialising PlayerGui from StarterGui. A manual write later in the same
-- session held fine and survived a death/respawn, which is what makes this a
-- startup race rather than a repeated overwrite. The guard costs one
-- comparison on a property that almost never changes.
playerGui:GetPropertyChangedSignal("ScreenOrientation"):Connect(apply)

-- Belt and braces for the first spawn specifically, which is when the initial
-- value lands.
player.CharacterAdded:Connect(apply)
