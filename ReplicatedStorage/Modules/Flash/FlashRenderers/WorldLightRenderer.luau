-- Short-lived world-space light at the shot origin, so a flash is visible to
-- more than just the shooter's screen. Follows the FloatingShotText pattern
-- for a throwaway anchored Part; pooled to one Part per client so rapid
-- shutter presses can't leak instances into workspace.

local TweenService = game:GetService("TweenService")

local WorldLightRenderer = {}

local lightPart: Part? = nil
local light: PointLight? = nil
local activeTween: Tween? = nil

local function ensurePart()
	if lightPart and lightPart.Parent then
		return
	end

	lightPart = Instance.new("Part")
	lightPart.Name = "CameraFlashLight"
	lightPart.Anchored = true
	lightPart.CanCollide = false
	lightPart.CanQuery = false
	lightPart.CanTouch = false
	lightPart.Transparency = 1
	lightPart.Size = Vector3.new(0.2, 0.2, 0.2)
	lightPart.Parent = workspace

	light = Instance.new("PointLight")
	light.Parent = lightPart
end

-- flashContext: { origin: Vector3, direction: Vector3 }
-- flashSettings: CameraStats Flash block -- { Color, Duration, LightBrightness, LightRange, ... }
function WorldLightRenderer.Play(flashContext, flashSettings)
	if not flashSettings.Enabled or flashSettings.LightBrightness <= 0 then
		return
	end

	ensurePart()

	if activeTween then
		activeTween:Cancel()
	end

	lightPart.Position = flashContext.origin + flashContext.direction * 2
	light.Color = flashSettings.Color
	light.Range = flashSettings.LightRange
	light.Brightness = flashSettings.LightBrightness
	light.Enabled = true

	activeTween = TweenService:Create(
		light,
		TweenInfo.new(flashSettings.Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Brightness = 0 }
	)
	activeTween:Play()
end

return WorldLightRenderer
