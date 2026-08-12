-- Match time bar: a horizontal fill and the current in-game hour, top-centre.
-- Pure UI -- takes data via Update(), shows/hides via Update()/Hide(). No
-- remotes, no game logic, no state ownership. Same convention as SpectateHud.
--
-- Bar anatomy copied from Hudcontroller's stamina bar: Background frame with
-- UICorner + UIStroke, a Fill frame sized by scale, and labels above it at a
-- higher ZIndex.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchPhases = require(script.Parent.MatchPhases)
local UIBuilder = require(ReplicatedStorage.Modules.UI.UIBuilder)
local UITheme = require(ReplicatedStorage.Modules.UI.UITheme)
local UIScaleController = require(ReplicatedStorage.Modules.UI.UIScaleController)
local MatchTimeAnnouncer = require(script.Parent.MatchTimeAnnouncer)
local MatchEventAnnouncer = require(script.Parent.MatchEventAnnouncer)

local MatchTimeHud = {}

-- 20: a free gap below MobileSprintGui (30) so both modals still cover this.
-- See UIBuilder.CreateScreenGui's comment -- that comment is the registry.
local DISPLAY_ORDER = 20

-- Matches Map0_Test's value; Lobby previously used 320x34, a divergence with
-- no documented reason that made the shared UIScale factor produce two
-- differently-sized bars depending on place. See plans/responsive-hud.md.
local BAR_WIDTH = 300
local BAR_HEIGHT = 24

local screenGui: ScreenGui? = nil
local fill: Frame? = nil
local hourLabel: TextLabel? = nil
local lastHourText: string? = nil
local lastFillColor: Color3? = nil

local function ensureBuilt()
	if screenGui then
		return
	end

	screenGui = UIBuilder.CreateScreenGui("MatchTimeGui", UIBuilder.GetPlayerGui(), DISPLAY_ORDER)
	-- Exempts this HUD from CameraSession's hideOtherGuis sweep. Without it
	-- the clock vanishes every time a player raises the camera, which is most
	-- of the match.
	screenGui:SetAttribute("KeepDuringCamera", true)

	-- Column owns the anchor/position the holder used to own directly, and
	-- carries the single UIScale for both the bar and the announcer beneath
	-- it -- one scale factor for the whole widget, never two that could
	-- drift apart. Grows downward (AutomaticSize Y) so adding the announcer
	-- never moves the bar.
	local column = Instance.new("Frame")
	column.Name = "MatchTimeColumn"
	column.AnchorPoint = Vector2.new(0.5, 0)
	column.Position = UDim2.new(0.5, 0, 0, -8)
	column.Size = UDim2.fromOffset(BAR_WIDTH, 0)
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.BackgroundTransparency = 1
	column.Parent = screenGui

	local columnLayout = Instance.new("UIListLayout")
	columnLayout.FillDirection = Enum.FillDirection.Vertical
	columnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	columnLayout.SortOrder = Enum.SortOrder.LayoutOrder
	columnLayout.Padding = UDim.new(0, 6)
	columnLayout.Parent = column

	UIScaleController.Attach(column)

	local holder = Instance.new("Frame")
	holder.Name = "MatchTimeHolder"
	holder.LayoutOrder = 1
	holder.Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT)
	holder.BackgroundColor3 = UITheme.Colors.PanelBackground
	holder.BackgroundTransparency = 0.25
	holder.BorderSizePixel = 0
	holder.Parent = column

	local holderCorner = Instance.new("UICorner")
	holderCorner.CornerRadius = UDim.new(0, 6)
	holderCorner.Parent = holder

	local holderStroke = Instance.new("UIStroke")
	holderStroke.Color = UITheme.Colors.Divider
	holderStroke.Thickness = 1
	holderStroke.Transparency = 0.35
	holderStroke.Parent = holder

	MatchTimeAnnouncer.Attach(column, BAR_WIDTH)
	-- Beneath the time announcer, same column and therefore the same single
	-- UIScale -- see the column comment above.
	MatchEventAnnouncer.Attach(column, BAR_WIDTH)

	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = UITheme.Colors.Accent
	fill.BackgroundTransparency = 0.4
	fill.BorderSizePixel = 0
	fill.ZIndex = 1
	fill.Parent = holder

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	hourLabel = Instance.new("TextLabel")
	hourLabel.Name = "Hour"
	hourLabel.Size = UDim2.fromScale(1, 1)
	hourLabel.BackgroundTransparency = 1
	hourLabel.Font = UITheme.Fonts.Bold
	hourLabel.TextColor3 = UITheme.Colors.Text
	hourLabel.TextSize = 18
	hourLabel.Text = ""
	hourLabel.ZIndex = 2
	hourLabel.Parent = holder

	local hourConstraint = Instance.new("UITextSizeConstraint")
	hourConstraint.MinTextSize = 10
	hourConstraint.MaxTextSize = 22
	hourConstraint.Parent = hourLabel
end

-- The fill is written every tick and deliberately NOT tweened -- same reason
-- Hudcontroller's stamina bar sets animated = false: a value that changes
-- every frame manufactures ~60 Tween objects a second for no visible gain.
--
-- The hour text is written only when the string actually changes (~14 writes
-- a match), the same dirty-check ObjectiveVisualsController uses.
function MatchTimeHud.Update(progress: number, hourText: string, hour: number)
	ensureBuilt()

	fill.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)

	-- Same dirty-check as the hour text: the colour changes twice a match.
	-- MatchPhases owns the bands; this file only paints what it is handed.
	local color = MatchPhases.BarColorFromHour(hour)
	if color ~= lastFillColor then
		lastFillColor = color
		fill.BackgroundColor3 = color
	end

	if hourText ~= lastHourText then
		lastHourText = hourText
		hourLabel.Text = hourText
	end

	screenGui.Enabled = true
end

function MatchTimeHud.Hide()
	if screenGui then
		screenGui.Enabled = false
	end
	lastHourText = nil
	lastFillColor = nil
end

return MatchTimeHud
