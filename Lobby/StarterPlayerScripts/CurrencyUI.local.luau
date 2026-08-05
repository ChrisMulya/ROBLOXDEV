local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local UITheme = require(ReplicatedStorage.Modules.UI.UITheme)
local UIBuilder = require(ReplicatedStorage.Modules.UI.UIBuilder)
local ShowCurrencyUI = Remotes.Get("ShowCurrencyUI")
local HideCurrencyUI = Remotes.Get("HideCurrencyUI")

local playerGui = UIBuilder.GetPlayerGui()

-- Built once and reused across Show/Hide cycles instead of rebuilt per Show --
-- ShowCurrencyUI can fire more than once per session (re-kitting after a death
-- clears the kit), and rebuilding used to stack a second CashGui plus a second
-- cash.Changed connection every time, leaking both forever.
local screenGui: ScreenGui? = nil
local label: TextLabel? = nil
local cashConnection: RBXScriptConnection? = nil

local function ensureBuilt()
	if screenGui and screenGui.Parent then
		return
	end

	screenGui = UIBuilder.CreateScreenGui("CashGui", playerGui)

	label = Instance.new("TextLabel")
	label.Name = "CashLabel"
	label.Size = UDim2.new(0, 150, 0, 40)
	label.Position = UDim2.new(0, 10, 0, 10)
	label.BackgroundColor3 = UITheme.Colors.PanelBackground
	label.BackgroundTransparency = 0.3
	label.TextColor3 = UITheme.Colors.Accent
	label.TextScaled = true
	label.Font = UITheme.Fonts.Bold
	label.Parent = screenGui
end

local function showCurrencyUI()
	local leaderstats = player:WaitForChild("leaderstats")
	local cash = leaderstats:WaitForChild("Cash")

	ensureBuilt()
	label.Text = "$" .. cash.Value
	screenGui.Enabled = true

	if cashConnection then
		cashConnection:Disconnect()
	end
	cashConnection = cash.Changed:Connect(function(newValue)
		label.Text = "$" .. newValue
	end)
end

HideCurrencyUI.OnClientEvent:Connect(function()
	if screenGui then
		screenGui.Enabled = false
	end
	if cashConnection then
		cashConnection:Disconnect()
		cashConnection = nil
	end
end)

ShowCurrencyUI.OnClientEvent:Connect(showCurrencyUI)