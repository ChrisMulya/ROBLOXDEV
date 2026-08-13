-- Pure item-use UI: the 3-second hold progress bar and the Motion Sensor's
-- "Motion Detected!" warning. No remotes, no Player lookups -- ItemUseClient
-- owns those and calls in, same seam as ShopGui/PlayerShop.
--
-- The hotbar itself is Roblox's default Backpack CoreGui, which cannot be
-- parented to or measured -- there is no literal "directly above the
-- selected slot" available. This is an overlay pinned just above the hotbar
-- strip instead, offset horizontally by a caller-supplied pixel amount
-- (ItemUseClient maps the equipped Tool's slot name to that offset). On
-- touch the offset is dropped by the caller and the bar renders centred --
-- the mobile hotbar geometry isn't stable enough to track.

local RunService = game:GetService("RunService")

local UIBuilder = require(script.Parent.Parent.UI.UIBuilder)
local UITheme = require(script.Parent.Parent.UI.UITheme)
local UIScaleController = require(script.Parent.Parent.UI.UIScaleController)

local ItemUseHud = {}

local BAR_SIZE = UDim2.fromOffset(90, 6)
local BAR_BOTTOM_OFFSET = 96 -- px above the default hotbar strip
local WARNING_BOTTOM_OFFSET = BAR_BOTTOM_OFFSET + 26
local BLINK_HZ = 4

local screenGui: ScreenGui? = nil
local barBackground: Frame? = nil
local barFill: Frame? = nil
local warningLabel: TextLabel? = nil

local activeEndsAt: number? = nil
local activeHoldSeconds: number? = nil
local warningActive = false

local function ensureBuilt()
	if screenGui then
		return
	end

	-- DisplayOrder 15 -- registered in UIBuilder.CreateScreenGui's comment:
	-- a free gap between HudLeftGui(0) and MatchTimeGui(20).
	screenGui = UIBuilder.CreateScreenGui("ItemUseGui", UIBuilder.GetPlayerGui(), 15)

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = screenGui
	UIScaleController.Attach(root)

	barBackground = Instance.new("Frame")
	barBackground.Name = "ProgressBar"
	barBackground.AnchorPoint = Vector2.new(0.5, 1)
	barBackground.Position = UDim2.new(0.5, 0, 1, -BAR_BOTTOM_OFFSET)
	barBackground.Size = BAR_SIZE
	barBackground.BackgroundColor3 = UITheme.Colors.PanelRow
	barBackground.BackgroundTransparency = 0.1
	barBackground.BorderSizePixel = 0
	barBackground.Visible = false
	barBackground.Parent = root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = barBackground

	barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.AnchorPoint = Vector2.new(0, 0.5)
	barFill.Position = UDim2.new(0, 0, 0.5, 0)
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = UITheme.Colors.Accent
	barFill.BorderSizePixel = 0
	barFill.Parent = barBackground

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = barFill

	warningLabel = Instance.new("TextLabel")
	warningLabel.Name = "MotionWarning"
	warningLabel.AnchorPoint = Vector2.new(0.5, 1)
	warningLabel.Position = UDim2.new(0.5, 0, 1, -WARNING_BOTTOM_OFFSET)
	warningLabel.Size = UDim2.fromOffset(220, 22)
	warningLabel.BackgroundTransparency = 1
	warningLabel.Font = UITheme.Fonts.Bold
	warningLabel.TextColor3 = UITheme.Colors.Danger
	warningLabel.TextSize = 16
	warningLabel.Text = "Motion Detected!"
	warningLabel.Visible = false
	warningLabel.Parent = root

	screenGui.Enabled = true

	-- One persistent loop for the life of the session, same as Hudcontroller
	-- -- cheap no-ops when neither the bar nor the warning is active.
	RunService.RenderStepped:Connect(function()
		if activeEndsAt and barFill then
			local now = workspace:GetServerTimeNow()
			local remaining = activeEndsAt - now
			local alpha = 1 - math.clamp(remaining / (activeHoldSeconds or 1), 0, 1)
			barFill.Size = UDim2.new(alpha, 0, 1, 0)
		end
		if warningActive and warningLabel then
			warningLabel.TextTransparency = (math.floor(os.clock() * BLINK_HZ) % 2 == 0) and 0 or 1
		end
	end)
end

-- offsetX: pixels from screen-centre, or 0 to render centred (touch).
function ItemUseHud.Begin(offsetX: number, endsAt: number, holdSeconds: number)
	ensureBuilt()
	activeEndsAt = endsAt
	activeHoldSeconds = holdSeconds
	local bg = barBackground :: Frame
	bg.Position = UDim2.new(0.5, offsetX, 1, -BAR_BOTTOM_OFFSET)
	bg.Visible = true
	;(barFill :: Frame).Size = UDim2.new(0, 0, 1, 0)
end

local function hideBar()
	activeEndsAt = nil
	activeHoldSeconds = nil
	if barBackground then
		barBackground.Visible = false
	end
end

function ItemUseHud.Cancel()
	hideBar()
end

function ItemUseHud.Complete()
	hideBar()
end

function ItemUseHud.SetMotionDetected(active: boolean)
	ensureBuilt()
	warningActive = active
	local label = warningLabel :: TextLabel
	label.Visible = active
	if not active then
		label.TextTransparency = 0
	end
end

return ItemUseHud
