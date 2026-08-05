-- Modular death UI: a panel + a button registry table, so Continue/View
-- Rewards/Retry/Report Player/Return to Lobby become rows a future phase
-- registers, not edits to this panel. Nothing is registered yet -- this is
-- still the shell, and the panel sizes itself to however many buttons exist
-- so an empty registry doesn't leave a hole under the title.
--
-- Panel chrome (backdrop, rounded panel, close button) comes from UIBuilder,
-- shared with MatchReceipt so the two modals look like one system.
--
-- ResetOnSpawn = false is UIBuilder.CreateScreenGui's default and is
-- mandatory here, since the character is dead when this shows.

local UIBuilder = require(script.Parent.UIBuilder)
local UITheme = require(script.Parent.UITheme)

local DeathScreen = {}

type ButtonDef = {
	Id: string,
	Label: string,
	Order: number,
	Enabled: (context: any) -> boolean,
	OnActivated: (context: any) -> (),
}

local BUTTON_HEIGHT = 36
local BUTTON_PADDING = 8
local HEADER_HEIGHT = 104

local screenGui: ScreenGui? = nil
local panel: Frame? = nil
local buttonHolder: Frame? = nil

local buttonRegistry: { ButtonDef } = {}

function DeathScreen.RegisterButton(button: ButtonDef)
	table.insert(buttonRegistry, button)
	table.sort(buttonRegistry, function(a, b)
		return a.Order < b.Order
	end)
end

local function buildHeader(parent: Frame)
	local pad = UITheme.Layout.PanelPadding

	-- A thin accent rule above the title, rather than a coloured title bar:
	-- it reads as "something bad happened" without shouting.
	local accentRule = Instance.new("Frame")
	accentRule.Name = "AccentRule"
	accentRule.Size = UDim2.fromOffset(38, 3)
	accentRule.Position = UDim2.fromOffset(pad, 26)
	accentRule.BackgroundColor3 = UITheme.Colors.Danger
	accentRule.BorderSizePixel = 0
	accentRule.ZIndex = 2

	local ruleCorner = Instance.new("UICorner")
	ruleCorner.CornerRadius = UDim.new(1, 0)
	ruleCorner.Parent = accentRule

	accentRule.Parent = parent

	local title = Instance.new("TextLabel")
	title.Name = "Message"
	title.Size = UDim2.new(1, -(pad * 2) - 34, 0, 34)
	title.Position = UDim2.fromOffset(pad, 40)
	title.BackgroundTransparency = 1
	title.Font = UITheme.Fonts.Bold
	title.TextColor3 = UITheme.Colors.Text
	title.TextSize = 28
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 2
	title.Text = "You died"
	title.Parent = parent

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, -(pad * 2), 0, 16)
	subtitle.Position = UDim2.fromOffset(pad, 74)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = UITheme.Fonts.Regular
	subtitle.TextColor3 = UITheme.Colors.TextMuted
	subtitle.TextSize = 13
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.ZIndex = 2
	subtitle.Text = "Spectating shortly..."
	subtitle.Parent = parent
end

local function buildButtonHolder(parent: Frame): Frame
	local pad = UITheme.Layout.PanelPadding

	local holder = Instance.new("Frame")
	holder.Name = "Buttons"
	holder.Size = UDim2.new(1, -(pad * 2), 1, -HEADER_HEIGHT)
	holder.Position = UDim2.fromOffset(pad, HEADER_HEIGHT)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 2

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, BUTTON_PADDING)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder

	holder.Parent = parent
	return holder
end

local function ensureBuilt()
	if screenGui then
		return
	end

	-- DisplayOrder 40: below MatchReceiptGui (50) -- see UIBuilder.CreateScreenGui.
	screenGui = UIBuilder.CreateScreenGui("DeathScreenGui", UIBuilder.GetPlayerGui(), 40)
	UIBuilder.CreateBackdrop(screenGui)

	panel = UIBuilder.CreatePanel(screenGui, UDim2.fromOffset(340, HEADER_HEIGHT + 24))
	UIBuilder.CreateCloseButton(panel, function()
		DeathScreen.Hide()
	end)

	buildHeader(panel)
	buttonHolder = buildButtonHolder(panel)
end

local function buildButton(button: ButtonDef, context: any, order: number): TextButton
	local instance = Instance.new("TextButton")
	instance.Name = button.Id
	instance.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
	instance.BackgroundColor3 = UITheme.Colors.Accent
	instance.BorderSizePixel = 0
	instance.AutoButtonColor = false
	instance.Font = UITheme.Fonts.Bold
	-- Dark text on the bright accent -- white on this green is unreadable.
	instance.TextColor3 = UITheme.Colors.PanelBackground
	instance.TextSize = 16
	instance.Text = button.Label
	instance.LayoutOrder = order
	instance.ZIndex = 3

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UITheme.Layout.RowCornerRadius
	corner.Parent = instance

	instance.MouseEnter:Connect(function()
		instance.BackgroundTransparency = 0.15
	end)
	instance.MouseLeave:Connect(function()
		instance.BackgroundTransparency = 0
	end)

	instance.Activated:Connect(function()
		button.OnActivated(context)
	end)

	return instance
end

local function renderButtons(context: any)
	for _, child in ipairs(buttonHolder:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local shown = 0
	for _, button in ipairs(buttonRegistry) do
		if button.Enabled(context) then
			shown += 1
			buildButton(button, context, shown).Parent = buttonHolder
		end
	end

	-- Grow the panel to fit however many buttons survived the Enabled filter,
	-- so the shell with zero registered buttons is a compact card rather than
	-- a mostly-empty box.
	local buttonsHeight = shown > 0 and (shown * BUTTON_HEIGHT + (shown - 1) * BUTTON_PADDING) or 0
	local bottomPadding = shown > 0 and UITheme.Layout.PanelPadding or 6
	panel.Size = UDim2.fromOffset(340, HEADER_HEIGHT + buttonsHeight + bottomPadding)
end

function DeathScreen.Show(context: any)
	ensureBuilt()
	renderButtons(context)
	screenGui.Enabled = true
end

function DeathScreen.Hide()
	if screenGui then
		screenGui.Enabled = false
	end
end

return DeathScreen
