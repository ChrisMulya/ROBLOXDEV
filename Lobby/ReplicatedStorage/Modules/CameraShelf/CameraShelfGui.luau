local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraStats = require(ReplicatedStorage.Modules.Camera.CameraStats)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local TakeCameraRequest = Remotes.Get("TakeCameraRequest")

local CameraShelfGui = {}

local HIGHLIGHT_COLOR = Color3.fromRGB(80, 120, 80)
local NORMAL_COLOR = Color3.fromRGB(50, 50, 50)

local function buildPanel()
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 320, 0, 300)
	panel.Position = UDim2.new(0.5, -160, 0.5, -150)
	panel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	return panel
end

local function buildTitle()
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "Change Camera"
	return title
end

local function buildCloseButton(onClose)
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 30, 0, 30)
	closeButton.Position = UDim2.new(1, -35, 0, 5)
	closeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.MouseButton1Click:Connect(onClose)
	return closeButton
end

local function buildMessageLabel()
	local label = Instance.new("TextLabel")
	label.Name = "MessageLabel"
	label.Size = UDim2.new(1, -20, 0, 20)
	label.Position = UDim2.new(0, 10, 0, 40)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(210, 200, 120)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = ""
	return label
end

local function buildListHolder()
	local listHolder = Instance.new("Frame")
	listHolder.Name = "ListHolder"
	listHolder.Size = UDim2.new(1, -20, 1, -110)
	listHolder.Position = UDim2.new(0, 10, 0, 65)
	listHolder.BackgroundTransparency = 1

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = listHolder

	return listHolder
end

local function buildCameraRow(cameraId: string, order: number)
	local stats = CameraStats.GetStats(cameraId)

	local button = Instance.new("TextButton")
	button.Name = cameraId
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 48)
	button.BackgroundColor3 = NORMAL_COLOR
	button.AutoButtonColor = false
	button.Text = ""

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -12, 0, 22)
	nameLabel.Position = UDim2.new(0, 8, 0, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextSize = 16
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = stats.DisplayName or cameraId
	nameLabel.Parent = button

	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "DescLabel"
	descLabel.Size = UDim2.new(1, -12, 0, 18)
	descLabel.Position = UDim2.new(0, 8, 0, 24)
	descLabel.BackgroundTransparency = 1
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 12
	descLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Text = stats.Description or ""
	descLabel.Parent = button

	button.MouseButton1Click:Connect(function()
		TakeCameraRequest:FireServer(cameraId)
	end)

	return button
end

-- onClose: function passed in by CameraShelfClient, called when the X
-- button is clicked. The GUI itself no longer decides what "closing" means
-- (unlocking movement, unbinding mouse, firing CloseCameraShelf, etc.) --
-- it just reports the click and lets the caller own that logic in one place.
--
-- Enumerates cameras from CameraStats.GetOrderedIds() -- adding a new camera
-- entry there automatically adds a button here, in a stable order, no UI
-- code changes needed.
function CameraShelfGui.Build(onClose)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CameraShelfGui"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false

	local panel = buildPanel()
	panel.Parent = screenGui

	buildTitle().Parent = panel
	buildCloseButton(onClose).Parent = panel
	buildMessageLabel().Parent = panel

	local listHolder = buildListHolder()
	listHolder.Parent = panel

	for order, cameraId in ipairs(CameraStats.GetOrderedIds()) do
		buildCameraRow(cameraId, order).Parent = listHolder
	end

	screenGui.Parent = playerGui
	return screenGui
end

function CameraShelfGui.ShowMessage(screenGui: ScreenGui, text: string)
	local label = screenGui.Panel.MessageLabel
	label.Text = text
end

-- Visually marks whichever camera row matches currentCameraId.
function CameraShelfGui.Refresh(screenGui: ScreenGui, currentCameraId: string?)
	local listHolder = screenGui.Panel.ListHolder
	for _, button in ipairs(listHolder:GetChildren()) do
		if button:IsA("TextButton") then
			button.BackgroundColor3 = (button.Name == currentCameraId) and HIGHLIGHT_COLOR or NORMAL_COLOR
		end
	end
end

return CameraShelfGui
