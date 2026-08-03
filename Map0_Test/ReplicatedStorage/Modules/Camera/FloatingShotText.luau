local TweenService = game:GetService("TweenService")

local FloatingShotText = {}

local RISE_DISTANCE = 3
local DURATION = 1.2

-- worldPosition: Vector3 where the shot landed
-- text: string to display, e.g. "Strong Shot 42.3 Studs"
-- color: Color3
function FloatingShotText.Show(worldPosition, text, color)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.Position = worldPosition
	part.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 220, 0, 80)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.5
	label.Text = text -- may be multi-line, e.g. "POINT BLANK\n4.2m\n+900 XP  +180 Score"
	label.Parent = billboard

	local endPosition = worldPosition + Vector3.new(0, RISE_DISTANCE, 0)
	local tween = TweenService:Create(
		part,
		TweenInfo.new(DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Position = endPosition}
	)
	local fadeTween = TweenService:Create(
		label,
		TweenInfo.new(DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{TextTransparency = 1, TextStrokeTransparency = 1}
	)

	tween:Play()
	fadeTween:Play()

	tween.Completed:Connect(function()
		part:Destroy()
	end)
end

return FloatingShotText