-- Shared left-hand HUD container. Cash and the Mission List both parent into
-- this one column so they share a single anchor and a single UIScale and
-- stack via LayoutOrder -- the same AutomaticSize.Y + UIListLayout pattern
-- MatchTimeHud's MatchTimeColumn uses for the announcer beneath the clock.
--
-- Deliberately not tagged KeepDuringCamera: CameraSession.hideOtherGuis
-- already hides any untagged, Enabled ScreenGui on camera entry and restores
-- it on exit -- exactly the behaviour Cash's own ScreenGui already had.
-- Enabled is set exactly once, at first build, and never touched again here;
-- slot owners express their own show/hide as their holder's .Visible,
-- layered underneath whatever hideOtherGuis is doing to Enabled.

local UIBuilder = require(script.Parent.UIBuilder)
local UIScaleController = require(script.Parent.UIScaleController)

local HudLeftColumn = {}

local screenGui: ScreenGui? = nil
local column: Frame? = nil

local function ensureBuilt()
	if screenGui and screenGui.Parent then
		return
	end

	screenGui = UIBuilder.CreateScreenGui("HudLeftGui", UIBuilder.GetPlayerGui(), 0)

	column = Instance.new("Frame")
	column.Name = "HudLeftColumn"
	column.AnchorPoint = Vector2.new(0, 0)
	column.Position = UDim2.new(0, 10, 0, 10)
	column.Size = UDim2.fromOffset(180, 0)
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.BackgroundTransparency = 1
	column.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = column

	UIScaleController.Attach(column)

	screenGui.Enabled = true
end

function HudLeftColumn.Get(): Frame
	ensureBuilt()
	return column :: Frame
end

return HudLeftColumn
