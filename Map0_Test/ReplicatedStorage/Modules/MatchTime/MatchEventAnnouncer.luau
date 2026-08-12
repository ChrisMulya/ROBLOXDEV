-- The event announcer line, directly beneath MatchTimeAnnouncer. Pure UI --
-- takes text/colour via Update(), hides via Hide(). Same convention as
-- MatchTimeAnnouncer: no remotes, no game logic, and no timer of its own (the
-- 10-second life of a message is MatchTimeHudController's business, so this
-- file can't drift out of sync with a clock it doesn't own).
--
-- Font is fixed to MatchEvents.Font (Source Sans Pro) rather than taken per
-- call: unlike the line above, every event announcement renders in one face.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage.Modules.UI.UITheme)
local MatchEvents = require(script.Parent.MatchEvents)

local MatchEventAnnouncer = {}

local label: TextLabel? = nil
local lastText: string? = nil
local lastColor: Color3? = nil

-- Built once into the caller's column (see MatchTimeHud) at LayoutOrder 3, so
-- the column's UIListLayout puts it under the bar (1) and the time announcer
-- (2) with no explicit positioning here.
--
-- TextWrapped + AutomaticSize.Y rather than the fixed 20px height the line
-- above uses: event text is a sentence, not a countdown, and a long one must
-- wrap to a second line instead of shrinking to unreadable via the size
-- constraint. The column is itself AutomaticSize.Y, so growing here pushes
-- nothing else around.
function MatchEventAnnouncer.Attach(parent: Instance, width: number): TextLabel
	if label and label.Parent then
		return label
	end

	label = Instance.new("TextLabel")
	label.Name = "EventAnnouncerLabel"
	label.LayoutOrder = 3
	label.Size = UDim2.fromOffset(width, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.TextColor3 = UITheme.Colors.Text
	label.Font = MatchEvents.Font
	label.TextSize = 20
	label.TextWrapped = true
	label.TextStrokeTransparency = 0.5
	label.Text = ""
	label.Visible = false
	label.ZIndex = 2
	label.Parent = parent

	lastText = nil
	lastColor = nil

	return label
end

-- text == nil means blank. Dirty-checked against the last APPLIED state for
-- the same reason MatchTimeAnnouncer.Update is: this is called on every 10 Hz
-- controller tick, and for almost the entire match there is nothing to say.
function MatchEventAnnouncer.Update(text: string?, color: Color3?)
	if not label then
		return
	end

	if text == nil then
		if label.Visible then
			label.Visible = false
			lastText = nil
			lastColor = nil
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
end

function MatchEventAnnouncer.Hide()
	if label then
		label.Visible = false
	end
	lastText = nil
	lastColor = nil
end

return MatchEventAnnouncer
