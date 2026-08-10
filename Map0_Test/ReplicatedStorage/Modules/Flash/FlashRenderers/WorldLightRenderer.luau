-- Short-lived world-space light at the shot origin, so a flash is visible to
-- more than just the shooter's screen. Follows the FloatingShotText pattern
-- for a throwaway anchored Part; pooled to one Part per client so rapid
-- shutter presses can't leak instances into workspace.
--
-- Mirrors ScreenFlashRenderer's four entry points, and for the same reason:
-- a capture is an authored timeline, not one fade-from-peak. Play() is the
-- original one-shot (still used by any flash outside a capture sequence);
-- ShowSolid/HideInstant/FadeOut are the beats a capture drives.
--
-- ShowSolid HOLDS full brightness with no tween -- that is what makes the
-- capture's first beat read as the scene being LIT for a full second, rather
-- than as a light that starts fading the instant it appears.

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

local function cancelTween()
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
end

-- Positions and arms the light at full brightness. Shared by Play/ShowSolid;
-- neither starts a tween, so the caller decides how it ends.
local function arm(flashContext, flashSettings)
	ensurePart()
	cancelTween()

	lightPart.Position = flashContext.origin + flashContext.direction * 2
	light.Color = flashSettings.Color
	light.Range = flashSettings.LightRange
	light.Brightness = flashSettings.LightBrightness
	light.Enabled = true
end

-- flashContext: { origin: Vector3, direction: Vector3 }
-- flashSettings: CameraStats Flash block -- { Color, Duration, LightBrightness, LightRange, ... }
function WorldLightRenderer.Play(flashContext, flashSettings)
	if not flashSettings.Enabled or flashSettings.LightBrightness <= 0 then
		return
	end

	arm(flashContext, flashSettings)

	activeTween = TweenService:Create(
		light,
		TweenInfo.new(flashSettings.Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Brightness = 0 }
	)
	activeTween:Play()
end

-- Full brightness, HELD -- no tween. The caller ends it (HideInstant/FadeOut).
function WorldLightRenderer.ShowSolid(flashContext, flashSettings)
	if not flashSettings.Enabled or flashSettings.LightBrightness <= 0 then
		return
	end
	arm(flashContext, flashSettings)
end

-- Hard cut to dark, one frame, no easing.
function WorldLightRenderer.HideInstant()
	if not light then
		return
	end
	cancelTween()
	light.Brightness = 0
	light.Enabled = false
end

-- Eases the current brightness down to nothing.
function WorldLightRenderer.FadeOut(duration: number)
	if not light then
		return
	end
	cancelTween()

	activeTween = TweenService:Create(
		light,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Brightness = 0 }
	)
	activeTween:Play()
end

return WorldLightRenderer
