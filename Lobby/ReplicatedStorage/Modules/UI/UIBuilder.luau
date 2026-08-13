-- Small shared constructors for the boilerplate every client UI file
-- currently repeats on its own (ScreenGui setup, PlayerGui lookup). Add to
-- this as more files migrate -- see UITheme for why that migration is
-- deliberately incremental.

local Players = game:GetService("Players")

local UITheme = require(script.Parent.UITheme)

local UIBuilder = {}

function UIBuilder.GetPlayerGui(): PlayerGui
	local player = Players.LocalPlayer
	return player:WaitForChild("PlayerGui") :: PlayerGui
end

-- ResetOnSpawn = false, Enabled = false: the convention every ScreenGui in
-- this repo that toggles visibility already follows individually.
--
-- displayOrder defaults to 0 (Roblox's own default) because most of this
-- repo's ScreenGuis genuinely don't compete for the same screen space. Two
-- modals that CAN appear at the same instant (MatchReceipt over DeathScreen,
-- at a solo death-triggered match end) must not both rely on that default --
-- Roblox leaves stacking undefined between GuiObjects at equal DisplayOrder,
-- so an unset order is a coin flip, not a "doesn't matter".
--
-- Every non-zero order in the game, lowest first. This comment IS the
-- registry; there is no runtime table. Pick a gap, never an existing value.
--
--     0    Roblox TouchGui (engine-owned; thumbstick + jump button)
--     0    most ScreenGuis -- no overlap, no opinion
--     0    HudLeftGui        -- persistent left column (Cash + Mission List)
--    15    ItemUseGui        -- support-item hold progress bar + Motion
--                               Sensor warning; must beat the base UI (0) but
--                               lose to the match clock and everything above it
--    20    MatchTimeGui      -- top-centre match clock; must lose to the
--                               sprint button and both modals
--    25    ExitCountdownGui  -- escape dwell countdown; beats the clock (it's
--                               live and time-critical) but loses to the
--                               sprint button and both modals
--    30    MobileSprintGui   -- must beat TouchGui (the thumbstick region
--                               covers it) but lose to both modals below
--    35    ShopGui           -- another interaction modal; must beat the
--                               sprint button but lose to Death/MatchReceipt
--    40    DeathScreenGui
--    50    MatchReceiptGui   -- covers DeathScreen at a death-triggered end
--    60    PurchaseNotificationGui -- built directly, not via this function.
--                               A transient toast that answers a shop click,
--                               so it must beat ShopGui (35)
--   100    CameraTouchHud    -- built directly, not via this function
--  1000    ScreenFlashRenderer
function UIBuilder.CreateScreenGui(name: string, parent: Instance, displayOrder: number?): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = name
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.DisplayOrder = displayOrder or 0
	screenGui.Parent = parent
	return screenGui
end

-- Full-screen dim behind a modal panel. Its own Frame rather than a property
-- of the panel so the panel can stay fully opaque while the dim doesn't.
function UIBuilder.CreateBackdrop(parent: Instance): Frame
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = UITheme.Colors.Backdrop
	backdrop.BackgroundTransparency = 0.45
	backdrop.BorderSizePixel = 0
	backdrop.ZIndex = 0
	backdrop.Parent = parent
	return backdrop
end

-- Centered rounded panel with a hairline border and a subtle top-down
-- gradient. The shared shell for every modal in this repo.
function UIBuilder.CreatePanel(parent: Instance, size: UDim2): Frame
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = size
	panel.BackgroundColor3 = UITheme.Colors.PanelBackground
	panel.BorderSizePixel = 0
	panel.ZIndex = 1

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UITheme.Layout.CornerRadius
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = UITheme.Colors.Divider
	stroke.Thickness = 1
	stroke.Transparency = 0.35
	stroke.Parent = panel

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(UITheme.Colors.PanelElevated, UITheme.Colors.PanelBackground)
	gradient.Parent = panel

	panel.Parent = parent
	return panel
end

-- Circular X in the panel's top-right corner. The caller owns what closing
-- means -- this only reports the click.
function UIBuilder.CreateCloseButton(parent: Instance, onClose: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = "Close"
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -14, 0, 14)
	button.Size = UDim2.fromOffset(28, 28)
	button.BackgroundColor3 = UITheme.Colors.PanelRow
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = UITheme.Fonts.Bold
	button.TextColor3 = UITheme.Colors.TextMuted
	button.TextSize = 16
	button.Text = "X"
	button.ZIndex = 5

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = UITheme.Colors.Divider
	stroke.Thickness = 1
	stroke.Transparency = 0.4
	stroke.Parent = button

	-- Hover state is manual because AutoButtonColor tints the whole button and
	-- reads as muddy against the panel gradient.
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = UITheme.Colors.Danger
		button.TextColor3 = UITheme.Colors.Text
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = UITheme.Colors.PanelRow
		button.TextColor3 = UITheme.Colors.TextMuted
	end)

	button.Activated:Connect(onClose)

	button.Parent = parent
	return button
end

return UIBuilder
