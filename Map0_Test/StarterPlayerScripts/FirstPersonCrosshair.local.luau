-- FirstPersonCrosshair
-- Place in: StarterPlayer.StarterPlayerScripts (runs as a LocalScript)
--
-- Two responsibilities that only make sense paired: forcing the camera into
-- LockFirstPerson, and replacing the OS cursor Roblox pins at screen centre
-- in that mode with a custom "+" reticle. Locking the camera without also
-- doing something about that cursor just swaps one center dot for another.
--
-- Deliberately does not fight CameraShelfClient / PlayerShop / CameraSession:
-- those already own MouseIconEnabled/MouseBehavior for their own menus and
-- restore it on their own exit (see their per-frame MouseBehavior=Default
-- binds). This script only ever WRITES MouseIconEnabled = false, and only
-- while UserInputService.MouseBehavior already reads LockCenter AND no
-- camera-tool session is active -- i.e. only in the "plain FPS gameplay"
-- state those other systems already leave alone. It never writes
-- MouseIconEnabled = true from the per-frame loop, so it can never undo a
-- menu's own restore -- the one exception is the death/spectate transition
-- below, a one-shot edge write, same shape as CameraSession's own Enter/Exit.
--
-- Both the lock and the crosshair are gated on PlayerStateClient: a dead or
-- spectating player needs a free cursor to click the death screen / spectate
-- HUD, and the root cause of the lock is CameraMode itself -- Roblox's own
-- camera script re-forces MouseBehavior to LockCenter every frame for as
-- long as CameraMode stays LockFirstPerson, independent of anything this
-- script does in its RenderStepped loop. So "let the cursor move" has to mean
-- "stop setting CameraMode to LockFirstPerson while dead," not just "stop
-- hiding the icon."

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraState = require(ReplicatedStorage.Modules.Camera.CameraState)
local PlayerStateClient = require(ReplicatedStorage.Modules.Shared.PlayerStateClient)
local PlayerStates = require(ReplicatedStorage.Modules.Shared.PlayerStates)

local player = Players.LocalPlayer

-- === Force first person, alive only ===
-- CanControlCharacter is false for Dead/Spectating/Disconnected/Leaving and
-- true only for Alive -- the same flag DeathService/SpectateService gate on,
-- so this follows the same definition of "alive" the rest of the game uses
-- rather than hardcoding "Dead" and missing Spectating.
--
-- nil (no PlayerState attribute yet, e.g. the first frames of a fresh join
-- before PlayerStateService seeds it) is treated as alive -- the safe default
-- that matches this script's pre-existing unconditional-lock behavior.
local function isAlive(): boolean
	local state = PlayerStateClient.Get()
	return state == nil or PlayerStates.CanControlCharacter(state)
end

-- Reasserted on every CharacterAdded AND on every PlayerStateClient.Changed:
-- CharacterAdded alone would miss the Dead/Spectating edge, since dying does
-- not destroy the character on this state transition (see DeathService) --
-- the cursor would stay locked through the whole death screen.
--
-- No fight with CameraSession.Enter: it captures `player.CameraMode` as its
-- OWN restore point when the camera tool opens, and since this script always
-- keeps that value at LockFirstPerson whenever alive and not in a session,
-- the capture and the restore agree.
local function applyCameraModeForState()
	player.CameraMode = isAlive() and Enum.CameraMode.LockFirstPerson or Enum.CameraMode.Classic
end

PlayerStateClient.Start()
applyCameraModeForState()
player.CharacterAdded:Connect(applyCameraModeForState)
PlayerStateClient.Changed:Connect(function()
	applyCameraModeForState()
	-- One-shot, not a per-frame write (see the header) -- the moment the
	-- player stops being alive, both need restoring explicitly. Verified live
	-- that leaving CameraMode is NOT enough on its own: Roblox's camera script
	-- only actively fights to keep MouseBehavior at LockCenter while
	-- CameraMode is LockFirstPerson -- it never cleans MouseBehavior back to
	-- Default on the way out, so without this line the cursor stayed
	-- position-locked (just invisible-then-visible) even after CameraMode
	-- had already changed to Classic.
	if not isAlive() then
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

-- === Crosshair ===
local CROSSHAIR_SIZE = 16 -- px, full width/height of the "+"
local BAR_THICKNESS = 2   -- px
local TRANSPARENCY = 0.5
-- Above ordinary gameplay UI (0), below MatchTimeGui (20) -- see the registry
-- in UIBuilder.CreateScreenGui.
local CROSSHAIR_DISPLAY_ORDER = 10

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FirstPersonCrosshairGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = CROSSHAIR_DISPLAY_ORDER
screenGui.Parent = player:WaitForChild("PlayerGui")

local function buildBar(size: UDim2): Frame
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(0.5, 0.5)
	bar.Size = size
	bar.BackgroundColor3 = Color3.new(1, 1, 1)
	bar.BackgroundTransparency = TRANSPARENCY
	bar.BorderSizePixel = 0
	bar.Parent = screenGui
	return bar
end

buildBar(UDim2.fromOffset(CROSSHAIR_SIZE, BAR_THICKNESS)) -- horizontal bar
buildBar(UDim2.fromOffset(BAR_THICKNESS, CROSSHAIR_SIZE)) -- vertical bar

-- Gated on MouseBehavior rather than a device check: on touch, MouseBehavior
-- never reads LockCenter (there is no mouse to lock), so this naturally never
-- shows there without any extra branching.
RunService.RenderStepped:Connect(function()
	local inCamera = CameraState.Get()
	local isLocked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
	local showCrosshair = isAlive() and isLocked and not inCamera

	screenGui.Enabled = showCrosshair
	if showCrosshair then
		UserInputService.MouseIconEnabled = false
	end
end)
