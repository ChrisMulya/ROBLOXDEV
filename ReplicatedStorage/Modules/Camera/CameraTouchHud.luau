-- Touch-only camera controls: an "Open"/"Close" scope button (middle-right,
-- above the jump button) and a "Photo" button (middle-left, above the
-- thumbstick) that only appears while InCamera. Pure UI -- takes callbacks
-- at Init time and knows nothing about CameraSession/CameraToolController,
-- same shape as CameraShelfGui.Build(onClose).
--
-- Gated to touch devices only: on desktop, Init/Show are no-ops and no
-- Instances are ever created.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local CameraTouchHud = {}

local IS_TOUCH_DEVICE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local BUTTON_SIZE = UDim2.new(0, 72, 0, 72)
local BUTTON_BG_COLOR = Color3.fromRGB(40, 40, 40)
local BUTTON_BG_TRANSPARENCY = 0.25
local BUTTON_STROKE_COLOR = Color3.fromRGB(255, 255, 255)
local BUTTON_TEXT_COLOR = Color3.fromRGB(255, 255, 255)

local screenGui = nil
local openButton = nil
local photoButton = nil

local function buildCircleButton(name: string, text: string, anchorPoint: Vector2, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = BUTTON_SIZE
	button.AnchorPoint = anchorPoint
	button.Position = position
	button.BackgroundColor3 = BUTTON_BG_COLOR
	button.BackgroundTransparency = BUTTON_BG_TRANSPARENCY
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.TextColor3 = BUTTON_TEXT_COLOR
	button.Text = text

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = BUTTON_STROKE_COLOR
	stroke.Transparency = 0.5
	stroke.Parent = button

	return button
end

local function ensureBuilt(onOpenPressed: () -> (), onPhotoPressed: () -> ())
	if screenGui then return end

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CameraTouchHud"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.DisplayOrder = 100 -- above the viewfinder (default 0), below CameraFlashEffect (1000)
	screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	-- Exempts this HUD from CameraSession.hideOtherGuis -- without this the
	-- Open/Photo buttons would vanish the instant the session they control
	-- actually starts.
	screenGui:SetAttribute("KeepDuringCamera", true)

	-- Middle-right, above the default jump button.
	openButton = buildCircleButton("OpenButton", "Camera", Vector2.new(1, 0.5), UDim2.new(1, -24, 0.5, 0))
	openButton.Parent = screenGui
	openButton.Activated:Connect(onOpenPressed)

	-- Middle-left, above the default thumbstick. Hidden until InCamera.
	photoButton = buildCircleButton("PhotoButton", "Shoot", Vector2.new(0, 0.5), UDim2.new(0, 24, 0.5, 0))
	photoButton.Visible = false
	photoButton.Parent = screenGui
	photoButton.Activated:Connect(onPhotoPressed)

	screenGui.Parent = playerGui
end

-- Call once. onOpenPressed/onPhotoPressed take no arguments -- the driver
-- closes over whatever tool/session state it needs.
function CameraTouchHud.Init(onOpenPressed: () -> (), onPhotoPressed: () -> ())
	if not IS_TOUCH_DEVICE then return end
	ensureBuilt(onOpenPressed, onPhotoPressed)
end

-- Shows the Open button. Call when a camera tool becomes equipped.
function CameraTouchHud.Show()
	if not IS_TOUCH_DEVICE or not screenGui then return end
	screenGui.Enabled = true
end

-- Hides the whole HUD (Open + Photo). Call when the camera tool is
-- unequipped -- there is nothing left to toggle or shoot with.
function CameraTouchHud.Hide()
	if not IS_TOUCH_DEVICE or not screenGui then return end
	screenGui.Enabled = false
end

-- Toggles the Photo button and restyles Open ("Camera" <-> "Close") to read
-- as a scope toggle.
function CameraTouchHud.SetInCamera(active: boolean)
	if not IS_TOUCH_DEVICE or not screenGui then return end
	photoButton.Visible = active
	openButton.Text = active and "Close" or "Camera"
end

return CameraTouchHud
