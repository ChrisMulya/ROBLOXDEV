-- Full-screen white fade. Moved verbatim out of the old CameraFlashEffect,
-- with one fix: the GUI + tween are now created once and reused instead of
-- stacking a fresh ScreenGui per call (rapid shutter presses used to leave
-- N overlapping fades all racing to Destroy the wrong instance).
--
-- Four entry points, because a camera capture is a hand-authored timeline
-- (hold solid, cut to black, hold solid again, then fade) rather than one
-- fade-from-peak. Play() is the original one-shot and is still what any flash
-- outside a capture sequence uses; ShowSolid/HideInstant/FadeOut are the
-- primitives CameraSession's sequence drives beat by beat.
--
-- Every entry point cancels the in-flight tween first. Without that, a
-- HideInstant landing mid-fade gets immediately overwritten by the next tween
-- frame and the screen stays lit.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ScreenFlashRenderer = {}

local player = Players.LocalPlayer

local screenGui: ScreenGui? = nil
local flashFrame: Frame? = nil
local activeTween: Tween? = nil

local function ensureGui()
	if screenGui and screenGui.Parent then
		return
	end

	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CameraFlashGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 1000 -- above the viewfinder and everything else
	-- Exempts this from CameraSession.hideOtherGuis, same as the viewfinder
	-- and CameraTouchHud. Load-bearing, not tidiness: the flash only ever
	-- fires DURING a camera session, so without this it is disabled for
	-- exactly the situation it exists for.
	--
	-- The bug this fixes was self-hiding and easy to misread. This GUI is
	-- built lazily on the first flash, which happens AFTER hideOtherGuis has
	-- already run -- so the first capture of a session rendered normally, left
	-- the GUI at Enabled = true, and every camera entry after that disabled it.
	-- Symptom: "the first photo flashes, the rest don't".
	screenGui:SetAttribute("KeepDuringCamera", true)
	screenGui.Parent = playerGui

	flashFrame = Instance.new("Frame")
	flashFrame.Size = UDim2.new(1, 0, 1, 0)
	flashFrame.BorderSizePixel = 0
	flashFrame.BackgroundTransparency = 1
	flashFrame.Parent = screenGui
end

local function cancelTween()
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
end

-- flashSettings: CameraStats Flash block -- { Color, Duration, ScreenIntensity, ... }
function ScreenFlashRenderer.Play(flashSettings)
	if not flashSettings.Enabled or flashSettings.ScreenIntensity <= 0 then
		return
	end

	ensureGui()
	cancelTween()

	flashFrame.BackgroundColor3 = flashSettings.Color
	flashFrame.BackgroundTransparency = 1 - flashSettings.ScreenIntensity

	activeTween = TweenService:Create(
		flashFrame,
		TweenInfo.new(flashSettings.Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)
	activeTween:Play()
end

-- Snaps to peak opacity and HOLDS there -- no tween is started, so the caller
-- owns when it ends (via HideInstant or FadeOut).
function ScreenFlashRenderer.ShowSolid(flashSettings)
	if not flashSettings.Enabled or flashSettings.ScreenIntensity <= 0 then
		return
	end

	ensureGui()
	cancelTween()

	flashFrame.BackgroundColor3 = flashSettings.Color
	flashFrame.BackgroundTransparency = 1 - flashSettings.ScreenIntensity
end

-- Hard cut to nothing, one frame, no easing.
function ScreenFlashRenderer.HideInstant()
	if not flashFrame then
		return
	end
	cancelTween()
	flashFrame.BackgroundTransparency = 1
end

-- Eases whatever is currently on screen out to nothing. Safe to call when
-- nothing is showing -- it just tweens 1 -> 1.
function ScreenFlashRenderer.FadeOut(duration: number)
	if not flashFrame then
		return
	end
	cancelTween()

	activeTween = TweenService:Create(
		flashFrame,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)
	activeTween:Play()
end

return ScreenFlashRenderer
