
-- HUDController
-- Place in: StarterGui (runs as a LocalScript)
--
-- Builds a top-right HUD showing Stamina as an animated bar,
-- driven entirely by PlayerStats.Changed. No polling loop -- bars only update
-- (and tween) when a value actually changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PlayerStats = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PlayerStats"))
local PlayerRuntimeStats = require(ReplicatedStorage.Modules.PlayerRuntimeStats)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Each bar: {statName, maxStatName, fillColor, label text, animated}
-- Stamina is Animated = false: PlayerRuntimeStats.Add drains/regens it every frame
-- while sprinting, which used to fire PlayerStats.Changed -> updateBar every
-- frame too, each call creating a fresh TweenInfo + Tween (~60/sec). The
-- underlying value already moves smoothly frame-by-frame, so tweening it on
-- top was pure duplication -- a direct Size write looks identical and costs
-- nothing. Kept as a per-bar flag so a future bar that changes in discrete
-- jumps (e.g. Health taking damage) can still opt into tweening.
local BAR_CONFIG = {
	{ stat = "Stamina", max = "MaxStamina", color = Color3.fromRGB(230, 200, 60), label = "Stamina", animated = false },
}

local BAR_WIDTH = 220
local BAR_HEIGHT = 18
local BAR_SPACING = 8
local TWEEN_TIME = 0.25

-- === Build the GUI ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "StatsContainer"
container.AnchorPoint = Vector2.new(1, 0)
container.Position = UDim2.new(1, -24, 0, 24)
container.Size = UDim2.new(0, BAR_WIDTH, 0, (BAR_HEIGHT + BAR_SPACING) * #BAR_CONFIG)
container.BackgroundTransparency = 1
container.Parent = screenGui

-- fills[statName] = the Frame we tween the size of
local fills: { [string]: Frame } = {}
local percentLabels: { [string]: TextLabel } = {}
-- One in-flight Tween per bar, cancelled and replaced rather than left to
-- stack, for any bar that does opt into animated = true.
local activeTweens: { [string]: Tween } = {}

local function createBar(order: number, config: { stat: string, max: string, color: Color3, label: string })
	local row = Instance.new("Frame")
	row.Name = config.stat .. "Row"
	row.Size = UDim2.new(1, 0, 0, BAR_HEIGHT)
	row.Position = UDim2.new(0, 0, 0, (order - 1) * (BAR_HEIGHT + BAR_SPACING))
	row.BackgroundTransparency = 1
	row.Parent = container

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	background.BackgroundTransparency = 0.2
	background.BorderSizePixel = 0
	background.Parent = row

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 6)
	bgCorner.Parent = background

	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color = Color3.fromRGB(0, 0, 0)
	bgStroke.Thickness = 1.5
	bgStroke.Transparency = 0.4
	bgStroke.Parent = background

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0) -- starts full; corrected once real stats come in
	fill.BackgroundColor3 = config.color
	fill.BorderSizePixel = 0
	fill.Parent = background

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -8, 1, 0)
	label.Position = UDim2.new(0, 4, 0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.5
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = config.label
	label.ZIndex = 2
	label.Parent = background

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.Size = UDim2.new(1, -8, 1, 0)
	valueLabel.Position = UDim2.new(0, -4, 0, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Font = Enum.Font.Gotham
	valueLabel.TextSize = 12
	valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	valueLabel.TextStrokeTransparency = 0.5
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.Text = ""
	valueLabel.ZIndex = 2
	valueLabel.Parent = background

	fills[config.stat] = fill
	percentLabels[config.stat] = valueLabel
end

for i, config in ipairs(BAR_CONFIG) do
	createBar(i, config)
end

-- === Updating ===
local function updateBar(statName: string)
	local fill = fills[statName]
	if not fill then return end -- not one of our tracked bars (e.g. movement stats changed)

	local config
	for _, c in ipairs(BAR_CONFIG) do
		if c.stat == statName then config = c break end
	end
	if not config then return end

	local current = PlayerRuntimeStats.Get(statName) or 0
	local max = PlayerStats.Get(config.max) or 1
	local percent = max > 0 and math.clamp(current / max, 0, 1) or 0

	if config.animated then
		local existing = activeTweens[statName]
		if existing then
			existing:Cancel()
		end
		local tween = TweenService:Create(fill, TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(percent, 0, 1, 0),
		})
		activeTweens[statName] = tween
		tween:Play()
	else
		fill.Size = UDim2.new(percent, 0, 1, 0)
	end

	local valueLabel = percentLabels[statName]
	if valueLabel then
		valueLabel.Text = string.format("%d / %d", math.floor(current + 0.5), max)
	end
end

-- Initialize bars to current stat values immediately (no tween on first paint).
for _, config in ipairs(BAR_CONFIG) do
	local fill = fills[config.stat]
	local current = PlayerRuntimeStats.Get(config.stat) or 0
	local max = PlayerStats.Get(config.max) or 1
	local percent = max > 0 and math.clamp(current / max, 0, 1) or 0
	fill.Size = UDim2.new(percent, 0, 1, 0)
	percentLabels[config.stat].Text = string.format("%d / %d", math.floor(current + 0.5), max)
end

-- React to runtime stat changes (Stamina). Max* values (PlayerStats) are
-- tuning constants that don't currently change at runtime, so only the
-- runtime-state signal needs a subscriber here.
PlayerRuntimeStats.Changed:Connect(function(statName: string, _newValue: number, _oldValue: number)
	if fills[statName] then
		updateBar(statName)
	end
end)