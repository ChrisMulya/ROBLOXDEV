-- Transient message strip for queue outcomes. Stays hidden until there is
-- something to say, then hides itself again.
--
-- The Join/Leave button this HUD used to own is gone: the lobby's queue pads
-- are the only way to enter a queue, and occupancy/countdown are rendered in
-- world space over the pad itself (QueuePadDisplay). What's left is the one
-- thing a pad can't show -- a message aimed at one player ("Queue Is Full",
-- "Couldn't Start A Match"). Pure UI: no remote calls, no state ownership.

local UIBuilder = require(script.Parent.Parent.UI.UIBuilder)
local UITheme = require(script.Parent.Parent.UI.UITheme)

local QueueHud = {}

local MESSAGE_DURATION = 4

local screenGui: ScreenGui? = nil
local statusLabel: TextLabel? = nil
local hideToken = 0

local function ensureBuilt()
	if screenGui then
		return
	end

	screenGui = UIBuilder.CreateScreenGui("QueueHudGui", UIBuilder.GetPlayerGui())
	screenGui.Enabled = false

	local holder = Instance.new("Frame")
	holder.Name = "QueueHolder"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -20)
	holder.Size = UDim2.fromOffset(260, 36)
	holder.BackgroundColor3 = UITheme.Colors.PanelBackground
	holder.BackgroundTransparency = 0.2
	holder.BorderSizePixel = 0
	holder.Parent = screenGui

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(1, -20, 1, 0)
	statusLabel.Position = UDim2.fromOffset(10, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = UITheme.Fonts.Bold
	statusLabel.TextColor3 = UITheme.Colors.Text
	statusLabel.TextSize = 14
	statusLabel.Text = ""
	statusLabel.Parent = holder
end

-- An empty message is a no-op rather than an empty strip: "Ok" resolves to ""
-- through QueueResultCodes.GetMessage, and success needs no announcement --
-- the pad's own countdown already showed it.
function QueueHud.SetMessage(message: string)
	if message == "" then
		return
	end

	ensureBuilt()
	statusLabel.Text = message
	screenGui.Enabled = true

	hideToken += 1
	local token = hideToken
	task.delay(MESSAGE_DURATION, function()
		if token == hideToken then
			QueueHud.Hide()
		end
	end)
end

function QueueHud.Hide()
	if screenGui then
		screenGui.Enabled = false
	end
end

return QueueHud
