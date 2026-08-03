-- Modular death UI: a panel + a button registry table, so Continue/View
-- Rewards/Retry/Report Player/Return to Lobby become rows a future phase
-- registers, not edits to this panel. Nothing is registered yet -- this is
-- the shell (Phase 5). Phase 7 registers "View Rewards" once a result
-- payload exists, Phase 8 registers "Return to Lobby" once
-- ReturnToLobbyService exists, etc.
--
-- Follows the repo's existing UI convention: raw Instance.new with
-- build*() helpers, lazy ensureBuilt(), colors from UITheme, built through
-- UIBuilder.CreateScreenGui (ResetOnSpawn = false is already that
-- function's default, and mandatory here since the character is dead).

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

local screenGui: ScreenGui? = nil
local buttonHolder: Frame? = nil

local buttonRegistry: { ButtonDef } = {}

function DeathScreen.RegisterButton(button: ButtonDef)
	table.insert(buttonRegistry, button)
	table.sort(buttonRegistry, function(a, b)
		return a.Order < b.Order
	end)
end

local function buildPanel(): Frame
	local frame = Instance.new("Frame")
	frame.Name = "DeathPanel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(320, 200)
	frame.BackgroundColor3 = UITheme.Colors.PanelBackground
	frame.BorderSizePixel = 0
	return frame
end

local function buildMessageLabel(parent: Frame): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.Size = UDim2.new(1, -20, 0, 60)
	label.Position = UDim2.fromOffset(10, 10)
	label.BackgroundTransparency = 1
	label.Font = UITheme.Fonts.Bold
	label.TextColor3 = UITheme.Colors.Text
	label.TextSize = 24
	label.Text = "You died"
	label.Parent = parent
	return label
end

local function buildButtonHolder(parent: Frame): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Buttons"
	holder.Size = UDim2.new(1, -20, 1, -80)
	holder.Position = UDim2.fromOffset(10, 80)
	holder.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = holder

	holder.Parent = parent
	return holder
end

local function ensureBuilt()
	if screenGui then
		return
	end

	screenGui = UIBuilder.CreateScreenGui("DeathScreenGui", UIBuilder.GetPlayerGui())
	local panel = buildPanel()
	buildMessageLabel(panel)
	buttonHolder = buildButtonHolder(panel)
	panel.Parent = screenGui
end

local function renderButtons(context: any)
	for _, child in ipairs(buttonHolder:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for _, button in ipairs(buttonRegistry) do
		if button.Enabled(context) then
			local instance = Instance.new("TextButton")
			instance.Name = button.Id
			instance.Size = UDim2.new(1, 0, 0, 32)
			instance.BackgroundColor3 = UITheme.Colors.Accent
			instance.TextColor3 = UITheme.Colors.Text
			instance.Font = UITheme.Fonts.Bold
			instance.TextSize = 18
			instance.Text = button.Label
			instance.Parent = buttonHolder

			instance.Activated:Connect(function()
				button.OnActivated(context)
			end)
		end
	end
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
