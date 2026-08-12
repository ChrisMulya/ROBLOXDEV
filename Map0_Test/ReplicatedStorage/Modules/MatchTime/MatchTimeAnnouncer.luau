-- The announcer text line beneath the match-time bar. Pure UI -- takes
-- style via Update(), hides via Hide(). Same convention as MatchTimeHud:
-- no remotes, no game logic, no clock of its own.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage.Modules.UI.UITheme)

local MatchTimeAnnouncer = {}

local label: TextLabel? = nil
local lastText: string? = nil
local lastColor: Color3? = nil
local lastFont: Enum.Font? = nil

-- Built once into the caller's column (see MatchTimeHud) rather than owning
-- its own ScreenGui -- the announcer is one line inside the existing
-- MatchTimeGui, not a second widget. width matches the caller's bar width so
-- neither file hardcodes the other's constant.
function MatchTimeAnnouncer.Attach(parent: Instance, width: number): TextLabel
	if label and label.Parent then
		return label
	end

	label = Instance.new("TextLabel")
	label.Name = "AnnouncerLabel"
	label.LayoutOrder = 2
	label.Size = UDim2.fromOffset(width, 20)
	label.BackgroundTransparency = 1
	label.TextColor3 = UITheme.Colors.Text
	label.Font = UITheme.Fonts.Bold
	label.TextSize = 20
	label.TextStrokeTransparency = 0.5
	label.Text = ""
	label.Visible = false
	label.ZIndex = 2
	label.Parent = parent

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 10
	constraint.MaxTextSize = 24
	constraint.Parent = label

	lastText = nil
	lastColor = nil
	lastFont = nil

	return label
end

-- text == nil means blank. Dirty-checked against the last APPLIED state, not
-- the last call -- across the ~500s the announcer is blank between 7 PM and
-- 3 AM this writes nothing at all despite being sampled every tick.
function MatchTimeAnnouncer.Update(text: string?, color: Color3?, font: Enum.Font?)
	if not label then
		return
	end

	if text == nil then
		if label.Visible then
			label.Visible = false
			lastText = nil
			lastColor = nil
			lastFont = nil
		end
		return
	end

	if not label.Visible then
		label.Visible = true
	end

	if text ~= lastText then
		lastText = text
		label.Text = text
	end

	if color ~= lastColor then
		lastColor = color
		label.TextColor3 = color :: Color3
	end

	if font ~= lastFont then
		lastFont = font
		label.Font = font :: Enum.Font
	end
end

function MatchTimeAnnouncer.Hide()
	if label then
		label.Visible = false
	end
	lastText = nil
	lastColor = nil
	lastFont = nil
end

return MatchTimeAnnouncer
