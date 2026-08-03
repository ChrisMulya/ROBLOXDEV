-- Owns the Lighting-level camera effects: the movement BlurEffect and the
-- optional ColorCorrectionEffect. Everything acquired in Apply() is
-- registered with a Trove immediately, so Clear() can never half-finish.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Modules.Shared.Trove)

local CameraEffects = {}

local trove = nil
local blurEffect = nil
local blurSettings = nil
local currentBlurAlpha = 0

-- blurSettingsIn: { MinSize, MaxSize, MaxSpeedForFullBlur, SmoothingFactor }
-- colorGradeSettings: { Brightness, Contrast, Saturation, TintColor } or nil
function CameraEffects.Apply(colorGradeSettings, blurSettingsIn)
	CameraEffects.Clear()

	blurSettings = blurSettingsIn
	currentBlurAlpha = 0
	trove = Trove.new()

	blurEffect = Instance.new("BlurEffect")
	blurEffect.Name = "CameraMovementBlur"
	blurEffect.Size = blurSettings.MinSize
	blurEffect.Parent = Lighting
	trove:Add(blurEffect)

	if colorGradeSettings then
		local colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "CameraColorGrade"
		colorCorrection.Brightness = colorGradeSettings.Brightness
		colorCorrection.Contrast = colorGradeSettings.Contrast
		colorCorrection.Saturation = colorGradeSettings.Saturation
		colorCorrection.TintColor = colorGradeSettings.TintColor
		colorCorrection.Parent = Lighting
		trove:Add(colorCorrection)
	end
end

function CameraEffects.UpdateFromSpeed(speed: number)
	if not blurEffect or not blurSettings then return end

	local alpha = math.clamp(speed / blurSettings.MaxSpeedForFullBlur, 0, 1)
	currentBlurAlpha = alpha

	local targetSize = blurSettings.MinSize + (blurSettings.MaxSize - blurSettings.MinSize) * alpha
	blurEffect.Size += (targetSize - blurEffect.Size) * blurSettings.SmoothingFactor
end

function CameraEffects.GetBlurAlpha(): number
	return currentBlurAlpha
end

function CameraEffects.Clear()
	if trove then
		trove:Clean()
		trove = nil
	end
	blurEffect = nil
	blurSettings = nil
	currentBlurAlpha = 0
end

return CameraEffects
