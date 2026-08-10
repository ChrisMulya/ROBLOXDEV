-- Camera shutter/flash audio. Third renderer on FlashSignal, same shape as
-- ScreenFlashRenderer/WorldLightRenderer -- see the parent init.
--
-- The Sound instance is authored in Studio (ReplicatedStorage.Sounds.Tool
-- .CameraFlashSound), not created here, matching how FlashLightSound is
-- already handled: a Sound needs an asset id, and inventing one in code would
-- either be silent or wrong.
--
-- Missing sound degrades to silence with a single warn rather than erroring --
-- the same "missing fields degrade rather than error" rule MatchReceipt
-- follows. A capture with no shutter audio is a missing polish detail; a
-- capture that throws would take the whole flash sequence down with it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlashSoundRenderer = {}

local SOUND_NAME = "CameraFlashSound"

local resolved: Sound? = nil
local warned = false

local function getSound(): Sound?
	if resolved and resolved.Parent then
		return resolved
	end

	-- FindFirstChild, not WaitForChild: this runs on the capture hot path and
	-- must never yield the flash sequence waiting on an instance that may
	-- simply not exist.
	local sounds = ReplicatedStorage:FindFirstChild("Sounds")
	local tools = sounds and sounds:FindFirstChild("Tool")
	local sound = tools and tools:FindFirstChild(SOUND_NAME)

	if sound and sound:IsA("Sound") then
		resolved = sound
		return resolved
	end

	if not warned then
		warned = true
		warn(
			("FlashSoundRenderer: no Sound at ReplicatedStorage.Sounds.Tool.%s -- camera flash will be silent."):format(
				SOUND_NAME
			)
		)
	end
	return nil
end

function FlashSoundRenderer.Play(flashSettings)
	if not flashSettings.Enabled then
		return
	end

	local sound = getSound()
	if not sound then
		return
	end

	-- Played on a clone, not the template: two captures close together (or the
	-- two flashes of one capture, if both ever asked for audio) would otherwise
	-- restart the single shared Sound and cut the first one off mid-shutter.
	local instance = sound:Clone()
	instance.Parent = sound.Parent
	instance.PlayOnRemove = false
	instance:Play()
	instance.Ended:Once(function()
		instance:Destroy()
	end)
	-- Backstop: Ended never fires for a Sound whose asset failed to load, which
	-- would leak a clone per capture for the whole session.
	task.delay(10, function()
		if instance.Parent then
			instance:Destroy()
		end
	end)
end

return FlashSoundRenderer
