-- MobileSprintButton
-- Place in: StarterPlayer.StarterPlayerScripts (runs as a LocalScript)
--
-- Touch sprint, tap-to-arm:
--   * The button sits at a fixed spot and stays on screen for the whole touch
--     session.
--   * Tapping it ARMS sprint. Nothing happens to your speed yet.
--   * Tapping it again CANCELS -- it is a toggle, so you can drop back to a
--     walk mid-run without letting go of the joystick.
--   * While armed, moving the joystick sprints -- including if you were
--     already moving when you tapped.
--   * Letting the joystick centre disarms it. Sprinting again means tapping
--     again.
--
-- There is deliberately no stretch/gesture trigger any more. Pushing the stick
-- past a threshold to engage was tried and removed: it fired during ordinary
-- movement often enough to be unpredictable, and the tap is unambiguous.
--
-- Touch only, decided per-frame -- see isTouchSession. On desktop this script
-- stays resident and draws nothing; Shift is the input there
-- (PlayerMovementController).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local SprintIntent = require(ReplicatedStorage.Modules.Movement.SprintIntent)
local TouchSession = require(ReplicatedStorage.Modules.Shared.TouchSession)
local PlayerRuntimeStats = require(ReplicatedStorage.Modules.PlayerRuntimeStats)
local PlayerStats = require(ReplicatedStorage.Modules.PlayerStats)
local UIBuilder = require(ReplicatedStorage.Modules.UI.UIBuilder)
local UITheme = require(ReplicatedStorage.Modules.UI.UITheme)

-- There is deliberately NO early return gating on device type here: the touch
-- test is per-frame (TouchSession.IsActive) and this script always stays
-- resident. See Shared/TouchSession for why a one-shot check is wrong.

local player = Players.LocalPlayer

-- Stick displacement (0..1) below which the stick counts as released.
local ACTIVE_MAGNITUDE = 0.15

local BUTTON_SIZE = 72
-- How far above the joystick's resting centre the button sits, in pixels.
local BUTTON_RISE = 112

-- Opacity, disarmed vs armed. 0 = fully solid, 1 = invisible.
local IDLE_TRANSPARENCY = 0.4
local ARMED_TRANSPARENCY = 0.15
local IDLE_STROKE_TRANSPARENCY = 0.45
local ARMED_STROKE_TRANSPARENCY = 0.1

-- Must outrank TouchGui (0) or the thumbstick region covering this button
-- takes the taps, and must stay BELOW the modals that should cover it
-- (DeathScreenGui 40, MatchReceiptGui 50). See the registry in
-- UIBuilder.CreateScreenGui -- equal DisplayOrder is undefined stacking, not
-- "doesn't matter", and 50 collided with the match receipt.
local SPRINT_DISPLAY_ORDER = 30

local screenGui: ScreenGui? = nil
local button: TextButton? = nil
local visible = false
local armedVisual = false

-- Sprint is armed by a tap and cleared when the stick is RELEASED. It is NOT
-- the same thing as sprinting: armed + moving is what sprints.
--
-- stickUsedSinceArming is what makes "tap, then move" work. Disarming on a
-- merely-centred stick clears the arm on the very next frame after the tap,
-- long before the player can move -- the button then looks completely dead.
-- Only an active -> inactive transition counts as a release.
local armed = false
local stickUsedSinceArming = false

local function hasStaminaToStart(): boolean
	return (PlayerRuntimeStats.Get("Stamina") or 0) >= PlayerStats.MinStaminaToSprint
end

-- Arms only. The stick decides when that becomes speed, so tapping while
-- standing still is valid and sprint begins on the first step.
local function tryArm()
	if not hasStaminaToStart() then
		return
	end
	armed = true
	-- Reset here too: tapping mid-run re-arms cleanly, and tapping at a
	-- standstill must not be disarmed by a release that predates it.
	stickUsedSinceArming = false
end

-- The button is a toggle: tapping it again cancels. Without this the only way
-- out of an armed sprint was to stop moving entirely, which is the opposite of
-- what a player wants mid-run when they just need to drop back to a walk.
--
-- Deliberately does not touch SprintIntent. The RenderStepped loop is the
-- single writer of it (`armed and stickActive`), and clearing `armed` here is
-- enough for it to drop the sprint on the very next frame.
local function toggleArm()
	if armed then
		armed = false
		stickUsedSinceArming = false
		return
	end
	tryArm()
end

local function ensureBuilt()
	if screenGui then
		return
	end

	-- DisplayOrder above TouchGui's 0, below CameraTouchHud's 100.
	--
	-- Load-bearing, not cosmetic: DynamicThumbstickFrame is a ~420x322 region
	-- that COVERS this button's position, and with both ScreenGuis at
	-- DisplayOrder 0 the thumbstick rendered on top and swallowed every tap.
	-- Input goes to the topmost GUI, so the button has to outrank it.
	screenGui = UIBuilder.CreateScreenGui("MobileSprintGui", UIBuilder.GetPlayerGui(), SPRINT_DISPLAY_ORDER)
	screenGui.ResetOnSpawn = false
	-- Positions below come from the touch controls' AbsolutePosition, which is
	-- in true screen coordinates. Without this the topbar inset shifts the
	-- button off the joystick by the inset height.
	screenGui.IgnoreGuiInset = true

	button = Instance.new("TextButton")
	button.Name = "SprintButton"
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	-- Replaced by positionAtHome once the joystick is located.
	button.Position = UDim2.fromOffset(90, 0)
	button.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	button.BackgroundColor3 = UITheme.Colors.PanelBackground
	button.BackgroundTransparency = IDLE_TRANSPARENCY
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = UITheme.Fonts.Bold
	button.TextColor3 = UITheme.Colors.Text
	button.TextSize = 13
	button.Text = "SPRINT"
	button.Visible = false
	button.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Ring"
	stroke.Color = UITheme.Colors.Text
	stroke.Transparency = IDLE_STROKE_TRANSPARENCY
	stroke.Thickness = 2
	stroke.Parent = button

	button.Activated:Connect(toggleArm)
end

local function setArmedVisual(isArmed: boolean)
	if armedVisual == isArmed or not button then
		return
	end
	armedVisual = isArmed

	local stroke = button:FindFirstChild("Ring")
	if isArmed then
		button.BackgroundColor3 = UITheme.Colors.Accent
		button.BackgroundTransparency = ARMED_TRANSPARENCY
		button.TextColor3 = UITheme.Colors.PanelBackground
		if stroke and stroke:IsA("UIStroke") then
			stroke.Transparency = ARMED_STROKE_TRANSPARENCY
		end
	else
		button.BackgroundColor3 = UITheme.Colors.PanelBackground
		button.BackgroundTransparency = IDLE_TRANSPARENCY
		button.TextColor3 = UITheme.Colors.Text
		if stroke and stroke:IsA("UIStroke") then
			stroke.Transparency = IDLE_STROKE_TRANSPARENCY
		end
	end
end

local function setVisible(isVisible: boolean)
	if visible == isVisible then
		return
	end
	visible = isVisible
	if button then
		button.Visible = isVisible
	end
	if screenGui then
		-- UIBuilder.CreateScreenGui returns ScreenGuis with Enabled = false --
		-- every caller opts in. Missing this meant the button rendered nowhere
		-- no matter what Visible said.
		screenGui.Enabled = isVisible
	end
end

-- Returns (thumbstickStart, controlsShown). controlsShown is false whenever
-- Roblox has taken the touch controls off screen -- hidden behind a modal UI,
-- during spectate, or whenever ControlModule is disabled. A sprint button with
-- no joystick to pair with has nothing to do, so it follows them off screen.
local function getTouchControls(): (GuiObject?, boolean)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
	if not touchGui or not touchGui:IsA("ScreenGui") or not touchGui.Enabled then
		return nil, false
	end
	local controlFrame = touchGui:FindFirstChild("TouchControlFrame")
	if not controlFrame or not controlFrame:IsA("GuiObject") or not controlFrame.Visible then
		return nil, false
	end
	local thumbFrame = controlFrame:FindFirstChild("DynamicThumbstickFrame")
	local stickStart = thumbFrame and thumbFrame:FindFirstChild("ThumbstickStart")
	if stickStart and stickStart:IsA("GuiObject") then
		return stickStart, true
	end
	return nil, true
end

local function isTouchSession(): boolean
	return TouchSession.IsActive()
end

-- The button's home, captured once and then frozen.
--
-- Frozen deliberately: DynamicThumbstick leaves ThumbstickStart wherever the
-- last touch landed, so re-reading it after the player has dragged returns a
-- contaminated position -- that is what previously stranded the button
-- wherever a run happened to start.
local homeCentre: Vector2? = nil
local homeLocked = false

local function fallbackHome(): Vector2
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(800, 400)
	return Vector2.new(90, viewport.Y - 190 + BUTTON_RISE)
end

local function positionAtHome(stickStart: GuiObject?)
	if not button or homeLocked then
		return
	end
	if stickStart and stickStart.AbsoluteSize.X > 0 then
		homeCentre = stickStart.AbsolutePosition + stickStart.AbsoluteSize / 2
		-- Latched ONLY on a real thumbstick reading. Latching on the viewport
		-- fallback too would freeze the button in the fallback corner for the
		-- whole session whenever the touch controls hadn't finished building
		-- on the first frame this ran.
		homeLocked = true
	end
	local centre = homeCentre or fallbackHome()
	-- Our ScreenGui ignores the topbar inset, TouchGui does not, so their
	-- AbsolutePosition origins differ by exactly that inset.
	local inset = GuiService:GetGuiInset()
	button.Position = UDim2.fromOffset(centre.X, centre.Y - BUTTON_RISE + inset.Y)
end

-- Stick displacement, 0..1. Magnitude is all this needs now -- direction no
-- longer gates anything.
local controlModule = nil

local function getControlModule()
	if controlModule then
		return controlModule
	end
	local playerScripts = player:FindFirstChild("PlayerScripts")
	local playerModuleScript = playerScripts and playerScripts:FindFirstChild("PlayerModule")
	if not playerModuleScript then
		return nil
	end
	local ok, playerModule = pcall(require, playerModuleScript)
	if not ok or not playerModule then
		return nil
	end
	local gotControls, controls = pcall(function()
		return playerModule:GetControls()
	end)
	if not gotControls or not controls or not controls.GetMoveVector then
		return nil
	end
	controlModule = controls
	return controlModule
end

local function getStickMagnitude(): number
	local controls = getControlModule()
	if controls then
		local ok, moveVector = pcall(function()
			return controls:GetMoveVector()
		end)
		if ok and typeof(moveVector) == "Vector3" then
			return math.min(Vector3.new(moveVector.X, 0, moveVector.Z).Magnitude, 1)
		end
	end

	-- ControlModule missing or its API changed. MoveDirection is normalised,
	-- which is fine here: all that is needed is "is the player moving".
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return 0
	end
	local moveDir = humanoid.MoveDirection
	return math.min(Vector3.new(moveDir.X, 0, moveDir.Z).Magnitude, 1)
end

ensureBuilt()

RunService.RenderStepped:Connect(function()
	if not isTouchSession() then
		setVisible(false)
		return
	end

	local stickStart, controlsShown = getTouchControls()
	if not controlsShown then
		armed = false
		SprintIntent.Set(false, "Touch")
		setVisible(false)
		return
	end

	positionAtHome(stickStart)
	setVisible(true)

	local stickActive = getStickMagnitude() >= ACTIVE_MAGNITUDE

	if stickActive then
		stickUsedSinceArming = true
	elseif stickUsedSinceArming then
		-- A real release: the stick was pushed and has now returned to centre.
		-- Sprinting again is a fresh tap -- sprint never survives a stop.
		armed = false
		stickUsedSinceArming = false
	end

	if stickActive and armed and not hasStaminaToStart() and not SprintIntent.Get() then
		-- Armed but too drained to start: drop the arm rather than leaving the
		-- button lit for a sprint that will not happen.
		armed = false
	end

	SprintIntent.Set(armed and stickActive, "TouchButton")

	-- Lit while armed, whether or not the player has started moving yet, so a
	-- tap gives immediate feedback. Drops when stamina runs out mid-sprint.
	setArmedVisual(armed and (PlayerRuntimeStats.Get("Stamina") or 0) > 0)
end)
