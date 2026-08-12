-- Spectate UI: renders the current target's name + index/total, and the
-- prev/next target controls. Pure UI -- takes data via Update(), shows/hides
-- via Show()/Hide(), and reports button presses through the callbacks
-- SetHandlers() installs. No game logic, no remote calls, no state ownership:
-- the HUD never learns that cycling is a server request. Follows the repo's
-- existing UI convention (raw Instance.new, lazy ensureBuilt(), UITheme
-- colors, built through UIBuilder.CreateScreenGui).
--
-- Touch devices get real buttons; keyboard devices get static Q/E hints and
-- no buttons at all. That split is not cosmetic -- spectating runs with the
-- mouse LOCKED to centre (see SpectateCameraController), so on a desktop
-- there is no cursor to click a button with, and a clickable-looking control
-- would be a dead end.

local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local UIBuilder = require(script.Parent.Parent.UI.UIBuilder)
local UITheme = require(script.Parent.Parent.UI.UITheme)

local SpectateHud = {}

local HOLDER_WIDTH = 320
local HOLDER_HEIGHT = 60
local CONTROL_WIDTH = 52
local CONTROL_INSET = 6

-- Keyboard wins when a device reports both (a tablet with a keyboard, Studio's
-- device emulator): the keys are bound in that case too, so showing the hint
-- describes what actually works.
local useKeyboardHints = UserInputService.KeyboardEnabled

local PREV_TEXT = useKeyboardHints and "Q <" or "<"
local NEXT_TEXT = useKeyboardHints and "> E" or ">"

local screenGui: ScreenGui? = nil
local nameLabel: TextLabel? = nil
local indexLabel: TextLabel? = nil

-- Installed by SpectateController. Held as plain fields rather than a Signal
-- because there is exactly one consumer and nothing to fan out to.
local onPrev: (() -> ())? = nil
local onNext: (() -> ())? = nil

-- One geometry, two behaviours: a TextButton on touch, an inert TextLabel of
-- the same size in the same slot on keyboard. Built through the same function
-- so the two device layouts can't drift apart.
local function buildControl(parent: Instance, name: string, text: string, position: UDim2, activate: () -> ())
	local size = UDim2.fromOffset(CONTROL_WIDTH, HOLDER_HEIGHT - CONTROL_INSET * 2)

	if useKeyboardHints then
		local hint = Instance.new("TextLabel")
		hint.Name = name .. "Hint"
		hint.Size = size
		hint.Position = position
		hint.BackgroundTransparency = 1
		hint.Font = UITheme.Fonts.Bold
		hint.TextColor3 = UITheme.Colors.TextMuted
		hint.TextSize = 18
		hint.Text = text
		hint.Parent = parent
		return
	end

	local button = Instance.new("TextButton")
	button.Name = name .. "Button"
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = UITheme.Colors.PanelElevated
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = UITheme.Fonts.Bold
	button.TextColor3 = UITheme.Colors.Text
	button.TextSize = 24
	button.Text = text
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UITheme.Layout.RowCornerRadius
	corner.Parent = button

	button.Activated:Connect(activate)
end

local function ensureBuilt()
	if screenGui then
		return
	end

	screenGui = UIBuilder.CreateScreenGui("SpectateHudGui", UIBuilder.GetPlayerGui())

	local holder = Instance.new("Frame")
	holder.Name = "SpectateHolder"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	-- Sits below the match time bar (MatchTimeHud: y = 12, height 34), which
	-- claimed top-centre when the Match Time System landed. Spectators need
	-- the clock most of anyone, so the bar wins the higher slot.
	holder.Position = UDim2.new(0.5, 0, 0, 56)
	holder.Size = UDim2.fromOffset(HOLDER_WIDTH, HOLDER_HEIGHT)
	holder.BackgroundColor3 = UITheme.Colors.PanelBackground
	holder.BackgroundTransparency = 0.2
	holder.BorderSizePixel = 0
	holder.Parent = screenGui

	-- Both controls occupy the same slots whether they are buttons or hints, so
	-- the text block below is inset by the same amount on either device and the
	-- panel never reflows between them.
	local controlSlot = CONTROL_WIDTH + CONTROL_INSET * 2

	buildControl(holder, "Prev", PREV_TEXT, UDim2.fromOffset(CONTROL_INSET, CONTROL_INSET), function()
		if onPrev then
			onPrev()
		end
	end)
	buildControl(holder, "Next", NEXT_TEXT, UDim2.new(1, -(CONTROL_WIDTH + CONTROL_INSET), 0, CONTROL_INSET), function()
		if onNext then
			onNext()
		end
	end)

	nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "TargetName"
	nameLabel.Size = UDim2.new(1, -controlSlot * 2, 0, 30)
	nameLabel.Position = UDim2.fromOffset(controlSlot, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = UITheme.Fonts.Bold
	nameLabel.TextColor3 = UITheme.Colors.Text
	nameLabel.TextSize = 20
	nameLabel.Text = "Spectating"
	nameLabel.Parent = holder

	indexLabel = Instance.new("TextLabel")
	indexLabel.Name = "Index"
	indexLabel.Size = UDim2.new(1, -controlSlot * 2, 0, 20)
	indexLabel.Position = UDim2.fromOffset(controlSlot, 35)
	indexLabel.BackgroundTransparency = 1
	indexLabel.Font = UITheme.Fonts.Bold
	indexLabel.TextColor3 = UITheme.Colors.Accent
	indexLabel.TextSize = 14
	indexLabel.Text = ""
	indexLabel.Parent = holder
end

-- The backpack belongs to the character you no longer have. Its slots stay on
-- screen through death and spectate otherwise, offering hotkeys for tools that
-- aren't yours to hold. Server-side the tools are destroyed on death
-- (KitLifecycleHook); this hides the strip itself, including its empty slots.
-- CoreGui calls can throw while CoreGui is still initializing, hence the pcall.
local function setBackpackVisible(visible: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, visible)
	end)
end

-- Set once, at require time, before any Update() can build the buttons. The
-- callbacks are read through upvalues at press time rather than captured into
-- the connections, so installing them after the build is still correct.
function SpectateHud.SetHandlers(prev: () -> (), next: () -> ())
	onPrev = prev
	onNext = next
end

function SpectateHud.Update(targetName: string?, index: number, total: number)
	ensureBuilt()
	nameLabel.Text = targetName and ("Spectating " .. targetName) or "Free Camera"
	indexLabel.Text = total > 0 and (index .. " / " .. total) or ""
	screenGui.Enabled = true
	setBackpackVisible(false)
end

function SpectateHud.Hide()
	if screenGui then
		screenGui.Enabled = false
	end
	setBackpackVisible(true)
end

return SpectateHud
