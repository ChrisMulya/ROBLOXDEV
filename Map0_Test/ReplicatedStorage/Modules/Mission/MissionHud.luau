-- Mission List rows: Monster Photo score, Soft Objective count, Document
-- placeholder. Pure UI -- takes data via Update(), shows/hides via
-- Update()/Hide(). No remotes, no game logic, no state ownership. Same
-- convention as MatchTimeHud.
--
-- Parents into HudLeftColumn at LayoutOrder 2, beneath Cash (LayoutOrder 1),
-- so the two share one UIScale and stack without either owning the other's
-- position.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage.Modules.UI.UITheme)
local HudLeftColumn = require(ReplicatedStorage.Modules.UI.HudLeftColumn)

local MissionHud = {}

-- One row per mission. Adding a fourth mission is one entry here plus one
-- attribute pair on MissionReplicator/MissionClient -- no layout change.
local MISSION_ROWS = {
	{ key = "Photo", label = "Photo score", format = "score", order = 1 },
	{ key = "Objective", label = "Soft Objective", format = "fraction", order = 2 },
	{ key = "Document", label = "Document", format = "fraction", order = 3 },
}

local holder: Frame? = nil
local rowLabels: { [string]: TextLabel } = {}

local function formatRow(row, snapshot): string
	if row.format == "score" then
		return row.label .. ": " .. snapshot.photoScore
	end

	local completed, total
	if row.key == "Objective" then
		completed, total = snapshot.objectivesCompleted, snapshot.objectivesTotal
	else
		completed, total = snapshot.documentsCollected, snapshot.documentsTotal
	end
	return row.label .. ": " .. completed .. "/" .. total
end

local function ensureBuilt()
	if holder then
		return
	end

	local column = HudLeftColumn.Get()

	holder = Instance.new("Frame")
	holder.Name = "MissionHolder"
	holder.LayoutOrder = 2
	holder.Size = UDim2.fromOffset(180, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundColor3 = UITheme.Colors.PanelBackground
	holder.BackgroundTransparency = 0.3
	holder.BorderSizePixel = 0
	holder.Visible = false
	holder.Parent = column

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UITheme.Layout.RowCornerRadius
	corner.Parent = holder

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = holder

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Vertical
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Padding = UDim.new(0, 2)
	rowLayout.Parent = holder

	for _, row in ipairs(MISSION_ROWS) do
		local label = Instance.new("TextLabel")
		label.Name = row.key .. "Row"
		label.LayoutOrder = row.order
		label.Size = UDim2.new(1, 0, 0, 18)
		label.BackgroundTransparency = 1
		label.Font = UITheme.Fonts.Medium
		label.TextColor3 = UITheme.Colors.Accent
		label.TextXAlignment = Enum.TextXAlignment.Left
		-- Fixed size under UIScale, same reasoning as CurrencyUI: TextScaled
		-- makes glyph height a function of string length, so "1000 score" and
		-- "50 score" would render at different sizes.
		label.TextSize = 16
		label.Text = ""
		label.Parent = holder

		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MinTextSize = 10
		constraint.MaxTextSize = 20
		constraint.Parent = label

		rowLabels[row.key] = label
	end
end

-- Writes labels whether or not the holder is visible, so on camera exit the
-- restored GUI already shows the latest synchronized values with no repaint
-- delay. snapshot nil (no match / mid-Ending) hides instead of drawing zeros.
function MissionHud.Update(snapshot)
	ensureBuilt()

	if not snapshot then
		MissionHud.Hide()
		return
	end

	for _, row in ipairs(MISSION_ROWS) do
		rowLabels[row.key].Text = formatRow(row, snapshot)
	end

	holder.Visible = true
end

function MissionHud.Hide()
	if holder then
		holder.Visible = false
	end
end

return MissionHud
