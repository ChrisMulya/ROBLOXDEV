-- Subscribes every flash renderer to FlashSignal exactly once. Adding a new
-- renderer (e.g. a future viewfinder shutter animation) is one require + one
-- Connect here -- nothing else in the Flash or Camera systems changes.
--
-- Boot: required (for its side effect) from StarterPlayerScripts/ClientBootstrap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlashSignal = require(ReplicatedStorage.Modules.Flash.FlashSignal)
local CameraStats = require(ReplicatedStorage.Modules.Camera.CameraStats)
local ScreenFlashRenderer = require(script.ScreenFlashRenderer)
local WorldLightRenderer = require(script.WorldLightRenderer)
local FlashSoundRenderer = require(script.FlashSoundRenderer)

-- flashContext.mode selects which beat of a capture timeline this fire is.
-- Omitted entirely (the legacy shape) means "one self-contained flash that
-- fades from peak" -- that path is unchanged and is what any non-capture
-- flash still gets.
--
--   "solid" -- snap to peak and HOLD; the caller ends it later
--   "off"   -- hard cut to nothing, no easing
--   "fade"  -- ease whatever is showing out over flashContext.fadeDuration
--
-- withSound is separate from mode because the shutter lands on one specific
-- beat (the last), not on every flash -- firing it per-flash would give one
-- photo a double shutter.
--
-- The screen flash and the world light run the SAME beat, always. They were
-- briefly split (light on a self-fading Play, screen on hold) and the result
-- was a light that had already faded out while the screen was still solid --
-- the capture's first beat has to read as the scene being lit for its whole
-- duration, not as a flash that dies immediately.
FlashSignal:Connect(function(flashContext)
	local flashSettings = CameraStats.GetFlashSettings(flashContext.cameraId)
	local mode = flashContext.mode

	-- screen == false lights the world WITHOUT whiting out the player's view.
	-- That is the capture's first beat: a camera light the player sees cast on
	-- the scene, not a flash in their face. Only the second beat -- the actual
	-- shutter -- blows the screen out.
	local wantsScreen = flashContext.screen ~= false

	-- Per-beat dimming. Cloned, never mutated in place: flashSettings is the
	-- live CameraStats table, so scaling LightBrightness on it would leave
	-- that camera permanently dimmer for every flash afterwards -- and
	-- compound on every capture.
	if flashContext.brightnessScale then
		flashSettings = table.clone(flashSettings)
		flashSettings.LightBrightness = flashSettings.LightBrightness * flashContext.brightnessScale
	end

	if mode == "solid" then
		if wantsScreen then
			ScreenFlashRenderer.ShowSolid(flashSettings)
		end
		WorldLightRenderer.ShowSolid(flashContext, flashSettings)
	elseif mode == "off" then
		ScreenFlashRenderer.HideInstant()
		WorldLightRenderer.HideInstant()
	elseif mode == "fade" then
		local fade = flashContext.fadeDuration or flashSettings.Duration
		ScreenFlashRenderer.FadeOut(fade)
		WorldLightRenderer.FadeOut(fade)
	else
		ScreenFlashRenderer.Play(flashSettings)
		WorldLightRenderer.Play(flashContext, flashSettings)
	end

	if flashContext.withSound then
		FlashSoundRenderer.Play(flashSettings)
	end
end)

return true
