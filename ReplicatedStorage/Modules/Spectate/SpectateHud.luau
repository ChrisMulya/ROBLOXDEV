-- Spectate UI: renders the current target's name + index/total. Pure UI --
-- takes data via Update(), shows/hides via Show()/Hide(). No game logic, no
-- remote calls, no state ownership. Follows the repo's existing UI
-- convention (raw Instance.new, lazy ensureBuilt(), UITheme colors, built
-- through UIBuilder.CreateScreenGui).

local UIBuilder = require(script.Parent.Parent.UI.UIBuilder)
local UITheme = require(script.Parent.Parent.UI.UITheme)

local SpectateHud = {}

local screenGui: ScreenGui? = nil
local nameLabel: TextLabel? = nil
local indexLabel: TextLabel? = nil

local function ensureBuilt()
	if screenGui then
		return
	end

	screenGui = UIBuilder.CreateScreenGui("SpectateHudGui", UIBuilder.GetPlayerGui())

	local holder = Instance.new("Frame")
	holder.Name = "SpectateHolder"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 20)
	holder.Size = UDim2.fromOffset(260, 60)
	holder.BackgroundColor3 = UITheme.Colors.PanelBackground
	holder.BackgroundTransparency = 0.2
	holder.BorderSizePixel = 0
	holder.Parent = screenGui

	nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "TargetName"
	nameLabel.Size = UDim2.new(1, -20, 0, 30)
	nameLabel.Position = UDim2.fromOffset(10, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = UITheme.Fonts.Bold
	nameLabel.TextColor3 = UITheme.Colors.Text
	nameLabel.TextSize = 20
	nameLabel.Text = "Spectating"
	nameLabel.Parent = holder

	indexLabel = Instance.new("TextLabel")
	indexLabel.Name = "Index"
	indexLabel.Size = UDim2.new(1, -20, 0, 20)
	indexLabel.Position = UDim2.fromOffset(10, 35)
	indexLabel.BackgroundTransparency = 1
	indexLabel.Font = UITheme.Fonts.Bold
	indexLabel.TextColor3 = UITheme.Colors.Accent
	indexLabel.TextSize = 14
	indexLabel.Text = ""
	indexLabel.Parent = holder
end

function SpectateHud.Update(targetName: string?, index: number, total: number)
	ensureBuilt()
	nameLabel.Text = targetName and ("Spectating " .. targetName) or "Free Camera"
	indexLabel.Text = total > 0 and (index .. " / " .. total) or ""
	screenGui.Enabled = true
end

function SpectateHud.Hide()
	if screenGui then
		screenGui.Enabled = false
	end
end

return SpectateHud
