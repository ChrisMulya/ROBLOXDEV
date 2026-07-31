-- Pure UI: renders whatever MatchResultSync's payload contains. Follows the
-- repo's existing UI convention (DeathScreen/SpectateHud) -- raw Instance.new
-- with build*() helpers, lazy ensureBuilt(), colors from UITheme, built
-- through UIBuilder.CreateScreenGui. No remote access, no game logic.
--
-- Renders generically rather than assuming specific perPlayer keys, since
-- MatchResultBuilder's contributors are an open registry (R2) -- a future
-- contributor's field appears here without this file changing.

local UIBuilder = require(script.Parent.UIBuilder)
local UITheme = require(script.Parent.UITheme)
local MatchResultCodes = require(script.Parent.Parent.Shared.MatchResultCodes)

local MatchReceipt = {}

local screenGui: ScreenGui? = nil
local messageLabel: TextLabel? = nil
local detailLabel: TextLabel? = nil

local function buildPanel(): Frame
	local frame = Instance.new("Frame")
	frame.Name = "MatchReceiptPanel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(360, 220)
	frame.BackgroundColor3 = UITheme.Colors.PanelBackground
	frame.BorderSizePixel = 0
	return frame
end

local function buildMessageLabel(parent: Frame): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.Size = UDim2.new(1, -20, 0, 40)
	label.Position = UDim2.fromOffset(10, 10)
	label.BackgroundTransparency = 1
	label.Font = UITheme.Fonts.Bold
	label.TextColor3 = UITheme.Colors.Text
	label.TextSize = 22
	label.Parent = parent
	return label
end

local function buildDetailLabel(parent: Frame): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Detail"
	label.Size = UDim2.new(1, -20, 1, -70)
	label.Position = UDim2.fromOffset(10, 60)
	label.BackgroundTransparency = 1
	label.Font = UITheme.Fonts.Bold
	label.TextColor3 = UITheme.Colors.Text
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function ensureBuilt()
	if screenGui then
		return
	end

	screenGui = UIBuilder.CreateScreenGui("MatchReceiptGui", UIBuilder.GetPlayerGui())
	local panel = buildPanel()
	messageLabel = buildMessageLabel(panel)
	detailLabel = buildDetailLabel(panel)
	panel.Parent = screenGui
end

-- Renders every key in perPlayer as its own line, generically -- this is
-- what lets a future contributor's field show up here with zero edits.
local function formatDetail(perPlayer: { [string]: any }): string
	local lines = {}
	for contributorName, slice in pairs(perPlayer) do
		if typeof(slice) == "table" then
			for key, value in pairs(slice) do
				table.insert(lines, ("%s.%s: %s"):format(contributorName, key, tostring(value)))
			end
		else
			table.insert(lines, ("%s: %s"):format(contributorName, tostring(slice)))
		end
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end

-- payload: { resultCode: string?, durationSeconds: number?, perPlayer: table? }
function MatchReceipt.Show(payload: { [string]: any })
	ensureBuilt()

	messageLabel.Text = MatchResultCodes.GetMessage(payload.resultCode)
	detailLabel.Text = formatDetail(payload.perPlayer or {})

	screenGui.Enabled = true
end

function MatchReceipt.Hide()
	if screenGui then
		screenGui.Enabled = false
	end
end

return MatchReceipt
