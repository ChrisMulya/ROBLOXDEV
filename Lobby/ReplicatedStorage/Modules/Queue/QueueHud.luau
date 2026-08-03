-- Queue UI: one toggle button (Join/Leave) plus a position/size readout.
-- Pure UI -- takes data via Update(), reports intent via the
-- SetActionHandler callback, shows/hides via Show()/Hide(). No remote calls,
-- no state ownership. Same convention as SpectateHud (UIBuilder/UITheme,
-- lazy ensureBuilt()), extended with a real interactive control since this
-- is the production replacement for DebugLaunchTrigger's chat command --
-- unlike SpectateHud, nobody else initiates this action for the player.

local UIBuilder = require(script.Parent.Parent.UI.UIBuilder)
local UITheme = require(script.Parent.Parent.UI.UITheme)

local QueueHud = {}

local screenGui: ScreenGui? = nil
local statusLabel: TextLabel? = nil
local actionButton: TextButton? = nil

local actionHandler: ((string) -> ())? = nil
local isQueued = false

local function ensureBuilt()
	if screenGui then
		return
	end

	screenGui = UIBuilder.CreateScreenGui("QueueHudGui", UIBuilder.GetPlayerGui())

	local holder = Instance.new("Frame")
	holder.Name = "QueueHolder"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -20)
	holder.Size = UDim2.fromOffset(220, 80)
	holder.BackgroundColor3 = UITheme.Colors.PanelBackground
	holder.BackgroundTransparency = 0.2
	holder.BorderSizePixel = 0
	holder.Parent = screenGui

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(1, -20, 0, 24)
	statusLabel.Position = UDim2.fromOffset(10, 6)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = UITheme.Fonts.Bold
	statusLabel.TextColor3 = UITheme.Colors.Text
	statusLabel.TextSize = 14
	statusLabel.Text = "Not Queued"
	statusLabel.Parent = holder

	actionButton = Instance.new("TextButton")
	actionButton.Name = "Action"
	actionButton.Size = UDim2.new(1, -20, 0, 34)
	actionButton.Position = UDim2.fromOffset(10, 36)
	actionButton.BackgroundColor3 = UITheme.Colors.Accent
	actionButton.Font = UITheme.Fonts.Bold
	actionButton.TextColor3 = Color3.fromRGB(0, 0, 0)
	actionButton.TextSize = 16
	actionButton.Text = "Join Queue"
	actionButton.Parent = holder

	actionButton.MouseButton1Click:Connect(function()
		if actionHandler then
			actionHandler(isQueued and "Leave" or "Join")
		end
	end)
end

function QueueHud.SetActionHandler(fn: (string) -> ())
	actionHandler = fn
end

function QueueHud.Update(payload: { queued: boolean, position: number?, size: number, message: string? })
	ensureBuilt()

	isQueued = payload.queued
	actionButton.Text = isQueued and "Leave Queue" or "Join Queue"

	if payload.message and payload.message ~= "" then
		statusLabel.Text = payload.message
	elseif isQueued then
		statusLabel.Text = ("Queued: %d / %d"):format(payload.position or 0, payload.size)
	else
		statusLabel.Text = "Not Queued"
	end

	screenGui.Enabled = true
end

-- Updates only the status text, leaving the queued/button state exactly as
-- it was -- for transient result messages (errors, rate limits) that must
-- not be mistaken for a change in whether the player is actually queued.
function QueueHud.SetMessage(message: string)
	ensureBuilt()
	if message ~= "" then
		statusLabel.Text = message
	end
end

function QueueHud.Show()
	ensureBuilt()
	screenGui.Enabled = true
end

function QueueHud.Hide()
	if screenGui then
		screenGui.Enabled = false
	end
end

return QueueHud
