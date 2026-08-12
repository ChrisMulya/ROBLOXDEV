local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local UITheme = require(ReplicatedStorage.Modules.UI.UITheme)
local HudLeftColumn = require(ReplicatedStorage.Modules.UI.HudLeftColumn)
local ShowCurrencyUI = Remotes.Get("ShowCurrencyUI")
local HideCurrencyUI = Remotes.Get("HideCurrencyUI")

-- Built once and reused across Show/Hide cycles instead of rebuilt per Show --
-- ShowCurrencyUI can fire more than once per session (re-kitting after a death
-- clears the kit), and rebuilding used to stack a second CashHolder plus a
-- second cash.Changed connection every time, leaking both forever.
local holder: Frame? = nil
local label: TextLabel? = nil
local cashConnection: RBXScriptConnection? = nil

-- Parents into the shared left column (below Mission at LayoutOrder 2) rather
-- than owning its own ScreenGui, so Cash and the Mission List scale and hide
-- together under one UIScale and one CameraSession sweep.
local function ensureBuilt()
	if holder and holder.Parent then
		return
	end

	local column = HudLeftColumn.Get()

	holder = Instance.new("Frame")
	holder.Name = "CashHolder"
	holder.LayoutOrder = 1
	holder.Size = UDim2.fromOffset(150, 40)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = column

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = holder

	label = Instance.new("TextLabel")
	label.Name = "CashLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.Position = UDim2.new()
	label.BackgroundColor3 = UITheme.Colors.PanelBackground
	label.BackgroundTransparency = 0.3
	label.TextColor3 = UITheme.Colors.Accent
	-- TextScaled makes glyph height a function of string length ("$7" huge,
	-- "$142850" small); a fixed size under UIScale scales uniformly instead.
	label.TextSize = 22
	label.Font = UITheme.Fonts.Bold
	label.Parent = holder

	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MinTextSize = 12
	textConstraint.MaxTextSize = 26
	textConstraint.Parent = label
end

local function showCurrencyUI()
	local leaderstats = player:WaitForChild("leaderstats")
	local cash = leaderstats:WaitForChild("Cash")

	ensureBuilt()
	label.Text = "$" .. cash.Value
	holder.Visible = true

	if cashConnection then
		cashConnection:Disconnect()
	end
	cashConnection = cash.Changed:Connect(function(newValue)
		label.Text = "$" .. newValue
	end)
end

HideCurrencyUI.OnClientEvent:Connect(function()
	if holder then
		holder.Visible = false
	end
	if cashConnection then
		cashConnection:Disconnect()
		cashConnection = nil
	end
end)

ShowCurrencyUI.OnClientEvent:Connect(showCurrencyUI)