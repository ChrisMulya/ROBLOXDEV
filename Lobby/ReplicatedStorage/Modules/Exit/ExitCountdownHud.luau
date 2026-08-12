-- The escape dwell countdown. Pure UI -- takes numbers via Update(), hides
-- via Hide(). No remotes, no timer of its own: the countdown it renders is
-- ExitService's, sampled server-side, so a client that stalls or tampers
-- with this file changes nothing about whether the escape lands.
--
-- Same convention as MatchTimeHud/MissionHud: built once, dirty-checked on
-- write, never rebuilt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIBuilder = require(script.Parent.Parent.UI.UIBuilder)
local UITheme = require(script.Parent.Parent.UI.UITheme)

local ExitCountdownHud = {}

local PANEL_WIDTH = 300
local PANEL_HEIGHT = 62
local BAR_HEIGHT = 8

-- Sits below centre: high enough to read at a glance, low enough that it
-- isn't covering whatever the player is nervously watching for.
local PANEL_POSITION = UDim2.fromScale(0.5, 0.74)

local screenGui: ScreenGui? = nil
local holder: Frame? = nil
local label: TextLabel? = nil
local barFill: Frame? = nil

local lastText: string? = nil

local function ensureBuilt()
	if screenGui then
		return
	end

	-- DisplayOrder 25: above the match clock (20) since this is a live,
	-- time-critical prompt, but below the sprint button (30) and both modals
	-- (40/50) -- see the registry comment in UIBuilder.CreateScreenGui.
	screenGui = UIBuilder.CreateScreenGui("ExitCountdownGui", UIBuilder.GetPlayerGui(), 25)

	holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = PANEL_POSITION
	holder.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
	holder.BackgroundTransparency = 1
	holder.Parent = screenGui

	label = Instance.new("TextLabel")
	label.Name = "Countdown"
	label.Size = UDim2.new(1, 0, 0, PANEL_HEIGHT - BAR_HEIGHT - 8)
	label.BackgroundTransparency = 1
	label.Font = UITheme.Fonts.Bold
	label.TextColor3 = UITheme.Colors.Text
	label.TextSize = 28
	label.TextStrokeTransparency = 0.4
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Text = ""
	label.ZIndex = 2
	label.Parent = holder

	local barBackground = Instance.new("Frame")
	barBackground.Name = "Bar"
	barBackground.AnchorPoint = Vector2.new(0.5, 1)
	barBackground.Position = UDim2.new(0.5, 0, 1, 0)
	barBackground.Size = UDim2.new(1, 0, 0, BAR_HEIGHT)
	barBackground.BackgroundColor3 = UITheme.Colors.PanelBackground
	barBackground.BackgroundTransparency = 0.35
	barBackground.BorderSizePixel = 0
	barBackground.ZIndex = 2
	barBackground.Parent = holder

	local backgroundCorner = Instance.new("UICorner")
	backgroundCorner.CornerRadius = UDim.new(1, 0)
	backgroundCorner.Parent = barBackground

	barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = UITheme.Colors.Accent
	barFill.BorderSizePixel = 0
	barFill.ZIndex = 3
	barFill.Parent = barBackground

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = barFill
end

-- remaining/total are seconds. The bar fills as the dwell completes, so it
-- reads as progress toward escaping rather than as a draining timer.
function ExitCountdownHud.Update(remaining: number, total: number)
	ensureBuilt()

	local seconds = math.max(0, math.ceil(remaining))
	local text = ("ESCAPING IN %d"):format(seconds)
	if text ~= lastText then
		lastText = text
		label.Text = text
	end

	local progress = 0
	if total > 0 then
		progress = math.clamp(1 - (remaining / total), 0, 1)
	end
	barFill.Size = UDim2.new(progress, 0, 1, 0)

	screenGui.Enabled = true
end

function ExitCountdownHud.Hide()
	if screenGui then
		screenGui.Enabled = false
	end
	lastText = nil
end

return ExitCountdownHud
