-- Pure UI for the match loading curtain. No state, no remotes -- LoadingController
-- owns the stage machine and tells this what to render, same XxxHud/XxxController
-- split as every other feature UI in the repo (see MatchTimeHudController's header).
--
-- Adopts, rather than rebuilds, the ScreenGui ReplicatedFirst/LoadingCurtain
-- already created (by name, "LoadingCurtainGui") -- that script has to build an
-- opaque curtain before ReplicatedStorage.Modules has even replicated, so it
-- can't depend on this module or on UITheme. Build() here finds that instance
-- and upgrades it in place (adds the progress bar, applies the real theme)
-- rather than tearing it down and losing a frame of coverage.
--
-- Built once and reused, same "build once, cancel the in-flight tween at every
-- entry point" rule as ScreenFlashRenderer.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UITheme = require(script.Parent.UITheme)
local UIBuilder = require(script.Parent.UIBuilder)

local LoadingHud = {}

local GUI_NAME = "LoadingCurtainGui"
local DISPLAY_ORDER = 2000
local BAR_WIDTH = 360
local SWEEP_WIDTH_SCALE = 0.28

local player = Players.LocalPlayer

local screenGui: ScreenGui? = nil
local statusLabel: TextLabel? = nil
local subLabel: TextLabel? = nil
local barTrack: Frame? = nil
local barFill: Frame? = nil
local failurePanel: Frame? = nil
local failureButton: TextButton? = nil
local onReturnToLobby: (() -> ())? = nil

local sweepTween: Tween? = nil
local fadeTween: Tween? = nil

local function cancelSweep()
	if sweepTween then
		sweepTween:Cancel()
		sweepTween = nil
	end
end

local function cancelFade()
	if fadeTween then
		fadeTween:Cancel()
		fadeTween = nil
	end
end

local function ensureGui()
	if screenGui and screenGui.Parent then
		return
	end

	local playerGui = UIBuilder.GetPlayerGui()

	local existing = playerGui:FindFirstChild(GUI_NAME)
	screenGui = (existing :: ScreenGui?) or Instance.new("ScreenGui")
	screenGui.Name = GUI_NAME
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = DISPLAY_ORDER
	-- Exempts the curtain from CameraSession.hideOtherGuis -- without this it
	-- would be disabled the moment a camera session opens, same bug
	-- ScreenFlashRenderer documents for CameraFlashGui.
	screenGui:SetAttribute("KeepDuringCamera", true)
	screenGui.Enabled = true
	screenGui.Parent = playerGui

	local backdrop = screenGui:FindFirstChild("Backdrop") :: Frame?
	if not backdrop then
		backdrop = Instance.new("Frame")
		backdrop.Name = "Backdrop"
		backdrop.BorderSizePixel = 0
		backdrop.ZIndex = 0
		backdrop.Parent = screenGui
	end
	-- Fully opaque, not the 0.45-alpha modal dim UIBuilder.CreateBackdrop
	-- makes -- this has to hide the whole map, not tint it.
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = UITheme.Colors.Backdrop
	backdrop.BackgroundTransparency = 0

	statusLabel = backdrop:FindFirstChild("StatusLabel") :: TextLabel?
	if not statusLabel then
		statusLabel = Instance.new("TextLabel")
		statusLabel.Name = "StatusLabel"
		statusLabel.Parent = backdrop
	end
	statusLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	statusLabel.Position = UDim2.new(0.5, 0, 0.5, -24)
	statusLabel.Size = UDim2.fromOffset(480, 32)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = UITheme.Fonts.Bold
	statusLabel.TextSize = 22
	statusLabel.TextColor3 = UITheme.Colors.Text
	statusLabel.Text = "Loading..."
	statusLabel.ZIndex = 2

	subLabel = backdrop:FindFirstChild("SubLabel") :: TextLabel?
	if not subLabel then
		subLabel = Instance.new("TextLabel")
		subLabel.Name = "SubLabel"
		subLabel.Parent = backdrop
	end
	subLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	subLabel.Position = UDim2.new(0.5, 0, 0.5, 44)
	subLabel.Size = UDim2.fromOffset(480, 20)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = UITheme.Fonts.Regular
	subLabel.TextSize = 14
	subLabel.TextColor3 = UITheme.Colors.TextMuted
	subLabel.Text = ""
	subLabel.ZIndex = 2

	barTrack = backdrop:FindFirstChild("BarTrack") :: Frame?
	if not barTrack then
		barTrack = Instance.new("Frame")
		barTrack.Name = "BarTrack"
		barTrack.Parent = backdrop

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UITheme.Layout.RowCornerRadius
		corner.Parent = barTrack
	end
	barTrack.AnchorPoint = Vector2.new(0.5, 0.5)
	barTrack.Position = UDim2.new(0.5, 0, 0.5, 12)
	barTrack.Size = UDim2.fromOffset(BAR_WIDTH, 10)
	barTrack.BackgroundColor3 = UITheme.Colors.PanelRow
	barTrack.BorderSizePixel = 0
	barTrack.ClipsDescendants = true
	barTrack.ZIndex = 2

	barFill = barTrack:FindFirstChild("BarFill") :: Frame?
	if not barFill then
		barFill = Instance.new("Frame")
		barFill.Name = "BarFill"
		barFill.Parent = barTrack

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UITheme.Layout.RowCornerRadius
		fillCorner.Parent = barFill
	end
	barFill.BackgroundColor3 = UITheme.Colors.Accent
	barFill.BorderSizePixel = 0
	barFill.ZIndex = 3

	failurePanel = screenGui:FindFirstChild("FailurePanel") :: Frame?
	if not failurePanel then
		failurePanel = UIBuilder.CreatePanel(screenGui, UDim2.fromOffset(360, 180))
		failurePanel.Name = "FailurePanel"

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.AnchorPoint = Vector2.new(0.5, 0)
		title.Position = UDim2.new(0.5, 0, 0, 24)
		title.Size = UDim2.new(1, -32, 0, 28)
		title.BackgroundTransparency = 1
		title.Font = UITheme.Fonts.Bold
		title.TextSize = 20
		title.TextColor3 = UITheme.Colors.Danger
		title.Text = "Match failed to start"
		title.Parent = failurePanel

		local message = Instance.new("TextLabel")
		message.Name = "Message"
		message.AnchorPoint = Vector2.new(0.5, 0)
		message.Position = UDim2.new(0.5, 0, 0, 60)
		message.Size = UDim2.new(1, -32, 0, 44)
		message.BackgroundTransparency = 1
		message.TextWrapped = true
		message.Font = UITheme.Fonts.Regular
		message.TextSize = 14
		message.TextColor3 = UITheme.Colors.TextMuted
		message.Text = "Loading is taking much longer than expected."
		message.Parent = failurePanel

		failureButton = Instance.new("TextButton")
		failureButton.Name = "ReturnButton"
		failureButton.AnchorPoint = Vector2.new(0.5, 1)
		failureButton.Position = UDim2.new(0.5, 0, 1, -20)
		failureButton.Size = UDim2.fromOffset(200, 40)
		failureButton.BackgroundColor3 = UITheme.Colors.Danger
		failureButton.BorderSizePixel = 0
		failureButton.AutoButtonColor = true
		failureButton.Font = UITheme.Fonts.Bold
		failureButton.TextSize = 16
		failureButton.TextColor3 = UITheme.Colors.Text
		failureButton.Text = "Return to Lobby"
		failureButton.Parent = failurePanel

		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UITheme.Layout.RowCornerRadius
		buttonCorner.Parent = failureButton

		failureButton.Activated:Connect(function()
			if onReturnToLobby then
				onReturnToLobby()
			end
		end)
	end
	failurePanel.Visible = false
end

function LoadingHud.Show()
	ensureGui()
	cancelFade()
	screenGui.Enabled = true
	local backdrop = screenGui:FindFirstChild("Backdrop") :: Frame
	backdrop.BackgroundTransparency = 0
	failurePanel.Visible = false
end

-- fraction: nil for an indeterminate sweep, or 0..1 for a real determinate
-- percentage. Never guessed -- the caller only passes a fraction when it has
-- a genuine numerator/denominator (see LoadingController's stage B).
function LoadingHud.SetStage(text: string, fraction: number?)
	ensureGui()
	statusLabel.Text = text

	if fraction then
		cancelSweep()
		barFill.Position = UDim2.fromScale(0, 0)
		barFill.Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0)
		return
	end

	if sweepTween then
		return
	end

	barFill.Size = UDim2.new(SWEEP_WIDTH_SCALE, 0, 1, 0)
	barFill.Position = UDim2.fromScale(-SWEEP_WIDTH_SCALE, 0)

	local forward = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local function loop()
		sweepTween = TweenService:Create(barFill, forward, { Position = UDim2.fromScale(1, 0) })
		sweepTween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and sweepTween then
				barFill.Position = UDim2.fromScale(-SWEEP_WIDTH_SCALE, 0)
				loop()
			end
		end)
		sweepTween:Play()
	end
	loop()
end

function LoadingHud.SetSubtext(text: string)
	ensureGui()
	subLabel.Text = text
end

function LoadingHud.ShowFailure(message: string, callback: () -> ())
	ensureGui()
	onReturnToLobby = callback
	local messageLabel = failurePanel:FindFirstChild("Message") :: TextLabel
	messageLabel.Text = message
	failurePanel.Visible = true
end

function LoadingHud.FadeOut(duration: number, onComplete: (() -> ())?)
	ensureGui()
	cancelSweep()
	cancelFade()

	local backdrop = screenGui:FindFirstChild("Backdrop") :: Frame
	fadeTween = TweenService:Create(
		backdrop,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)
	fadeTween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			screenGui.Enabled = false
			if onComplete then
				onComplete()
			end
		end
	end)
	fadeTween:Play()
end

function LoadingHud.HideInstant()
	ensureGui()
	cancelSweep()
	cancelFade()
	screenGui.Enabled = false
end

return LoadingHud
