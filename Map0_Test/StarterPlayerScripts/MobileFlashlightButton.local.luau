-- MobileFlashlightButton
-- Place in: StarterPlayer.StarterPlayerScripts (runs as a LocalScript)
--
-- Touch-only flashlight toggle, positioned directly above the "Camera" button
-- (CameraTouchHud's OpenButton: AnchorPoint (1, 0.5), UDim2.new(1, -24, 0.5, 60)
-- -- middle-right, below screen centre, above the default jump button).
--
-- Requires NOTHING on purpose: this script runs sandboxed, and a sandboxed
-- thread cannot require an unsandboxed ModuleScript. So the handful of values
-- it would otherwise pull from UITheme/UIBuilder/TouchSession are inlined
-- below, each tagged with the module it mirrors. That is a deliberate trade of
-- a little duplication for a script that loads at all.
--
-- Aiming and the 30Hz report live in FlashlightAimLoop.local.luau. On desktop
-- F is the input instead (GiveFlashLight.local.luau).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local toggleRemote = remotesFolder:WaitForChild("FlashlightRequest")

local flashlightSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Tool"):WaitForChild("FlashLightSound")

-- Mirrors UITheme.Colors / UITheme.Fonts.
local COLOR_PANEL_BACKGROUND = Color3.fromRGB(20, 20, 20)
local COLOR_ACCENT = Color3.fromRGB(85, 255, 127)
local COLOR_TEXT = Color3.fromRGB(255, 255, 255)
local FONT_BOLD = Enum.Font.GothamBold

local BUTTON_SIZE = 72
local GAP = 16

-- CameraTouchHud's OpenButton sits at (1, -24, 0.5, 60). Same X so this stacks
-- directly above it, Y up by one button height plus a gap.
local CAMERA_BUTTON_OFFSET_X = -24
local CAMERA_BUTTON_OFFSET_Y = 25
local FLASHLIGHT_RISE = BUTTON_SIZE + GAP

local IDLE_TRANSPARENCY = 0.4
local LIT_TRANSPARENCY = 0.15
local IDLE_STROKE_TRANSPARENCY = 0.45
local LIT_STROKE_TRANSPARENCY = 0.1

-- Mirrors the DisplayOrder registry in UIBuilder.CreateScreenGui: must outrank
-- TouchGui (0), must lose to the modals (40/50).
local FLASHLIGHT_DISPLAY_ORDER = 30

local screenGui: ScreenGui? = nil
local button: TextButton? = nil
local visible = false
local litVisual = false

-- Mirrors TouchSession.IsActive. Called per-frame, never cached -- see that
-- module for why a one-shot device check is wrong (it is false in Studio's
-- device emulator and on any touchscreen laptop).
local function isTouchSession(): boolean
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

local function isFlashlightOn(): boolean
	local character = player.Character
	local emitter = character and character:FindFirstChild("FlashlightEmitter")
	return emitter ~= nil and emitter:IsA("BasePart")
end

local function toggle()
	toggleRemote:FireServer()
	flashlightSound:Play()
end

-- Driven from the render loop off the emitter's actual existence, not from a
-- local flag flipped in toggle(): the beam is server-owned, so a respawn or a
-- rejected toggle would otherwise leave the button lit with no beam behind it.
local function setLitVisual(isOn: boolean)
	if litVisual == isOn or not button then
		return
	end
	litVisual = isOn

	local stroke = button:FindFirstChild("Ring")
	if isOn then
		button.BackgroundColor3 = COLOR_ACCENT
		button.BackgroundTransparency = LIT_TRANSPARENCY
		button.TextColor3 = COLOR_PANEL_BACKGROUND
		if stroke and stroke:IsA("UIStroke") then
			stroke.Transparency = LIT_STROKE_TRANSPARENCY
		end
	else
		button.BackgroundColor3 = COLOR_PANEL_BACKGROUND
		button.BackgroundTransparency = IDLE_TRANSPARENCY
		button.TextColor3 = COLOR_TEXT
		if stroke and stroke:IsA("UIStroke") then
			stroke.Transparency = IDLE_STROKE_TRANSPARENCY
		end
	end
end

local function ensureBuilt()
	if screenGui then
		return
	end

	-- Mirrors UIBuilder.CreateScreenGui's conventions (ResetOnSpawn = false,
	-- Enabled = false until opted in).
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MobileFlashlightGui"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.DisplayOrder = FLASHLIGHT_DISPLAY_ORDER
	screenGui.Parent = player:WaitForChild("PlayerGui")

	button = Instance.new("TextButton")
	button.Name = "FlashlightButton"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, CAMERA_BUTTON_OFFSET_X, 0.5, CAMERA_BUTTON_OFFSET_Y - FLASHLIGHT_RISE)
	button.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	button.BackgroundColor3 = COLOR_PANEL_BACKGROUND
	button.BackgroundTransparency = IDLE_TRANSPARENCY
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = FONT_BOLD
	button.TextColor3 = COLOR_TEXT
	button.TextSize = 12
	button.Text = "LIGHT"
	button.Visible = false
	button.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Ring"
	stroke.Color = COLOR_TEXT
	stroke.Transparency = IDLE_STROKE_TRANSPARENCY
	stroke.Thickness = 2
	stroke.Parent = button

	button.Activated:Connect(toggle)
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
		screenGui.Enabled = isVisible
	end
end

ensureBuilt()

RunService.RenderStepped:Connect(function()
	setVisible(isTouchSession())
	setLitVisual(isFlashlightOn())
end)
