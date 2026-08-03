-- The camera viewfinder overlay: letterbox bars, corner brackets, reticle,
-- REC/settings labels, scanlines, grain flicker, vignette.
--
-- Built ONCE and reused (Show/Hide toggles Enabled) instead of constructing
-- ~200 fresh Frames on every camera Enter. Only the settings-dependent
-- scanline lines are rebuilt per Show (their count/spacing differ per
-- camera), sized from the actual viewport instead of a hardcoded guess.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Modules.Shared.Trove)
local ViewfinderTheme = require(ReplicatedStorage.Modules.Camera.ViewfinderTheme)

local CameraViewfinder = {}

local screenGui = nil
local reticleGhostRing = nil
local reticleGhostStroke = nil
local recLabel = nil
local settingsLabel = nil
local scanlinesContainer = nil
local grainFrame = nil
local vignetteTopStrip = nil
local vignetteBottomStrip = nil
local vignetteTopGradient = nil
local vignetteBottomGradient = nil

local grainTrove = nil

local function createBar(name, anchorTop)
	local bar = Instance.new("Frame")
	bar.Name = name
	bar.Size = UDim2.new(1, 0, ViewfinderTheme.BarHeight, 0)
	bar.Position = anchorTop and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 0, 1 - ViewfinderTheme.BarHeight, 0)
	bar.BackgroundColor3 = Color3.new(0, 0, 0)
	bar.BorderSizePixel = 0
	return bar
end

-- Builds one L-shaped corner bracket out of two thin frames.
-- corner: "TopLeft" | "TopRight" | "BottomLeft" | "BottomRight"
local function createBracket(corner)
	local holder = Instance.new("Frame")
	holder.Name = "Bracket" .. corner
	holder.Size = ViewfinderTheme.BracketSize
	holder.BackgroundTransparency = 1

	local isLeft = corner == "TopLeft" or corner == "BottomLeft"
	local isTop = corner == "TopLeft" or corner == "TopRight"

	holder.Position = UDim2.new(
		isLeft and ViewfinderTheme.BracketMarginX or 1 - ViewfinderTheme.BracketMarginX,
		isLeft and 0 or -ViewfinderTheme.BracketSize.X.Offset,
		isTop and ViewfinderTheme.BracketMarginY or 1 - ViewfinderTheme.BracketMarginY - ViewfinderTheme.BarHeight,
		isTop and 0 or -ViewfinderTheme.BracketSize.Y.Offset
	)

	local horizontal = Instance.new("Frame")
	horizontal.Name = "Horizontal"
	horizontal.Size = UDim2.new(1, 0, 0, ViewfinderTheme.BracketThickness)
	horizontal.Position = isTop and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 0, 1, -ViewfinderTheme.BracketThickness)
	horizontal.BackgroundColor3 = ViewfinderTheme.BracketColor
	horizontal.BorderSizePixel = 0
	horizontal.Parent = holder

	local vertical = Instance.new("Frame")
	vertical.Name = "Vertical"
	vertical.Size = UDim2.new(0, ViewfinderTheme.BracketThickness, 1, 0)
	vertical.Position = isLeft and UDim2.new(0, 0, 0, 0) or UDim2.new(1, -ViewfinderTheme.BracketThickness, 0, 0)
	vertical.BackgroundColor3 = ViewfinderTheme.BracketColor
	vertical.BorderSizePixel = 0
	vertical.Parent = holder

	return holder
end

-- Returns the reticle frame plus the two parts SetBlurAlpha needs to touch.
local function createReticle()
	local reticle = Instance.new("Frame")
	reticle.Name = "Reticle"
	reticle.Size = UDim2.new(0, 24, 0, 24)
	reticle.Position = UDim2.new(0.5, -12, 0.5, -12)
	reticle.BackgroundTransparency = 1

	-- Ghost ring: a second, larger ring that fades in as speed increases,
	-- faking a "soft/unfocused" look since GuiObjects can't use real blur.
	local ghostRing = Instance.new("Frame")
	ghostRing.Name = "GhostRing"
	ghostRing.AnchorPoint = Vector2.new(0.5, 0.5)
	ghostRing.Position = UDim2.new(0.5, 0, 0.5, 0)
	ghostRing.Size = UDim2.new(1, 0, 1, 0)
	ghostRing.BackgroundTransparency = 1
	ghostRing.Parent = reticle

	local ghostCorner = Instance.new("UICorner")
	ghostCorner.CornerRadius = UDim.new(1, 0)
	ghostCorner.Parent = ghostRing

	local ghostStroke = Instance.new("UIStroke")
	ghostStroke.Name = "GhostStroke"
	ghostStroke.Thickness = 3
	ghostStroke.Color = Color3.new(1, 1, 1)
	ghostStroke.Transparency = 1 -- starts invisible, driven by SetBlurAlpha
	ghostStroke.Parent = ghostRing

	-- Main ring, drawn after the ghost so it stays crisp on top.
	local circle = Instance.new("Frame")
	circle.Name = "Circle"
	circle.Size = UDim2.new(1, 0, 1, 0)
	circle.BackgroundTransparency = 1
	circle.BorderSizePixel = 0
	circle.Parent = reticle

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = circle

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.3
	stroke.Parent = circle

	return reticle, ghostRing, ghostStroke
end

local function createCornerLabel(name, corner)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.new(0, 160, 0, 24)
	label.BackgroundTransparency = 1
	label.Font = ViewfinderTheme.LabelFont
	label.TextSize = ViewfinderTheme.LabelTextSize
	label.TextColor3 = ViewfinderTheme.LabelColor
	label.Text = ""

	if corner == "TopLeft" then
		label.Position = UDim2.new(0, 10, ViewfinderTheme.BarHeight, 4)
		label.TextXAlignment = Enum.TextXAlignment.Left
	elseif corner == "TopRight" then
		label.Position = UDim2.new(1, -170, ViewfinderTheme.BarHeight, 4)
		label.TextXAlignment = Enum.TextXAlignment.Right
	end

	return label
end

local function createGrainFrame()
	local grain = Instance.new("Frame")
	grain.Name = "GrainFlicker"
	grain.Size = UDim2.new(1, 0, 1, 0)
	grain.BackgroundColor3 = Color3.new(0, 0, 0)
	grain.BackgroundTransparency = 1
	grain.BorderSizePixel = 0
	grain.ZIndex = 50
	return grain
end

local function createScanlinesContainer()
	local container = Instance.new("Frame")
	container.Name = "Scanlines"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.ClipsDescendants = true
	container.ZIndex = 40
	return container
end

-- vignetteSettings: { Transparency, SizeScale }. Both edge strips exist from
-- build time; ApplyVignette re-sizes/re-colors them per camera.
local function createVignette()
	local vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.new(1, 0, 1, 0)
	vignette.BackgroundTransparency = 1
	vignette.ZIndex = 30

	local function edgeStrip(name, rotation, anchorPoint, position)
		local strip = Instance.new("Frame")
		strip.Name = name
		strip.AnchorPoint = anchorPoint
		strip.Position = position
		strip.BackgroundColor3 = Color3.new(0, 0, 0)
		strip.BorderSizePixel = 0
		strip.Parent = vignette

		local gradient = Instance.new("UIGradient")
		gradient.Name = "Gradient"
		gradient.Rotation = rotation
		gradient.Parent = strip

		return strip, gradient
	end

	local topStrip, topGradient = edgeStrip("TopStrip", 90, Vector2.new(0, 0), UDim2.new(0, 0, 0, 0))
	local bottomStrip, bottomGradient = edgeStrip("BottomStrip", -90, Vector2.new(0, 1), UDim2.new(0, 0, 1, 0))

	return vignette, topStrip, bottomStrip, topGradient, bottomGradient
end

local function ensureBuilt()
	if screenGui then return end

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CameraViewfinderGui"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.IgnoreGuiInset = true
	-- Also exempted by name in CameraSession.hideOtherGuis; the attribute is
	-- belt-and-suspenders so a future rename doesn't silently break it.
	screenGui:SetAttribute("KeepDuringCamera", true)

	local vignette, topStrip, bottomStrip, topGradient, bottomGradient = createVignette()
	vignette.Parent = screenGui
	vignetteTopStrip = topStrip
	vignetteBottomStrip = bottomStrip
	vignetteTopGradient = topGradient
	vignetteBottomGradient = bottomGradient

	createBar("TopBar", true).Parent = screenGui
	createBar("BottomBar", false).Parent = screenGui

	createBracket("TopLeft").Parent = screenGui
	createBracket("TopRight").Parent = screenGui
	createBracket("BottomLeft").Parent = screenGui
	createBracket("BottomRight").Parent = screenGui

	local reticle, ghostRing, ghostStroke = createReticle()
	reticle.Parent = screenGui
	reticleGhostRing = ghostRing
	reticleGhostStroke = ghostStroke

	recLabel = createCornerLabel("RecLabel", "TopLeft")
	recLabel.Parent = screenGui
	settingsLabel = createCornerLabel("SettingsLabel", "TopRight")
	settingsLabel.Parent = screenGui

	scanlinesContainer = createScanlinesContainer()
	scanlinesContainer.Parent = screenGui

	grainFrame = createGrainFrame()
	grainFrame.Parent = screenGui

	screenGui.Parent = playerGui
end

local function applyVignette(vignetteSettings)
	vignetteTopStrip.Size = UDim2.new(1, 0, vignetteSettings.SizeScale, 0)
	vignetteBottomStrip.Size = UDim2.new(1, 0, vignetteSettings.SizeScale, 0)

	local transparencySequence = NumberSequence.new({
		NumberSequenceKeypoint.new(0, vignetteSettings.Transparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	vignetteTopGradient.Transparency = transparencySequence
	vignetteBottomGradient.Transparency = transparencySequence
end

-- scanlineSettings: { LineHeight, LineSpacing, Transparency }
-- Sized from the camera's actual ViewportSize, not a hardcoded guess (this
-- is what used to build ~200 stray frames on a wrong estimate every Enter).
local function applyScanlines(scanlineSettings)
	scanlinesContainer:ClearAllChildren()

	local viewportHeight = workspace.CurrentCamera.ViewportSize.Y
	local lineCount = math.floor(viewportHeight / scanlineSettings.LineSpacing)

	for i = 0, lineCount do
		local line = Instance.new("Frame")
		line.Name = "Line"
		line.Size = UDim2.new(1, 0, 0, scanlineSettings.LineHeight)
		line.Position = UDim2.new(0, 0, 0, i * scanlineSettings.LineSpacing)
		line.BackgroundColor3 = Color3.new(0, 0, 0)
		line.BackgroundTransparency = scanlineSettings.Transparency
		line.BorderSizePixel = 0
		line.Parent = scanlinesContainer
	end
end

-- grainSettings: { FlickerMin, FlickerMax }
local function applyGrain(grainSettings)
	grainFrame.BackgroundTransparency = grainSettings.FlickerMin

	grainTrove:Add(RunService.RenderStepped:Connect(function()
		grainFrame.BackgroundTransparency = grainSettings.FlickerMin
			+ math.random() * (grainSettings.FlickerMax - grainSettings.FlickerMin)
	end))
end

-- effectsSettings: CameraStats.<id>.Effects -- { Grain, Scanlines, Vignette }
-- viewfinderSettings: CameraStats.<id>.Viewfinder -- { RecLabel, SettingsLabel }
function CameraViewfinder.Show(effectsSettings, viewfinderSettings)
	ensureBuilt()

	if grainTrove then
		grainTrove:Clean()
	end
	grainTrove = Trove.new()

	recLabel.Text = (viewfinderSettings and viewfinderSettings.RecLabel) or ""
	settingsLabel.Text = (viewfinderSettings and viewfinderSettings.SettingsLabel) or ""

	applyVignette(effectsSettings.Vignette)
	applyScanlines(effectsSettings.Scanlines)
	applyGrain(effectsSettings.Grain)

	screenGui.Enabled = true
end

function CameraViewfinder.Hide()
	if not screenGui then return end
	screenGui.Enabled = false

	if grainTrove then
		grainTrove:Clean()
		grainTrove = nil
	end
end

-- alpha: 0-1, same value driving world blur (CameraEffects.GetBlurAlpha()).
function CameraViewfinder.SetBlurAlpha(alpha: number)
	if not reticleGhostRing or not reticleGhostStroke then return end

	reticleGhostStroke.Transparency = 1 - (alpha * (1 - ViewfinderTheme.GhostMinTransparency))

	local scale = 1 + (ViewfinderTheme.GhostMaxScale - 1) * alpha
	reticleGhostRing.Size = UDim2.new(scale, 0, scale, 0)
end

return CameraViewfinder
