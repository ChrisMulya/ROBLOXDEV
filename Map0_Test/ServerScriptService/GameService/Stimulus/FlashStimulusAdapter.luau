-- Translates FlashEvents into a CameraFlash stimulus. The only subscriber
-- FlashEvents has ever had -- its own header has said as much since before
-- this file existed, reserving exactly this seam. No second flash event
-- system, no change to FlashEvents or CameraShotHandler: this is purely an
-- adapter sitting downstream of an already-validated event.
--
-- Already server-authoritative and already trustworthy: FlashEvents is raised
-- by CameraShotHandler from a shot it validated itself (cooldown, range,
-- quality). There is no client "I flashed" remote feeding this, so nothing new
-- is trusted here -- same posture StimulusBus's own header describes.
--
-- NARROWS the payload, does not forward it. FlashEvents carries {player,
-- origin, direction, cameraId, shotQuality, hitPosition, timestamp}; only
-- origin (-> Position), player (-> Source) and timestamp survive. direction,
-- cameraId, shotQuality and hitPosition are camera-domain detail a monster's
-- perception has no use for.
--
-- This is "a light went off near me" (CameraFlash), not "I was photographed."
-- FlashEvents fires on every shot -- hits, misses, shots at objectives -- and
-- carries no subject. Reacting to being the SUBJECT of a photo is a distinct
-- stimulus (Photographed, off RewardService.Awarded) and deliberately out of
-- scope for this adapter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local StimulusKinds = require(ReplicatedStorage.Modules.Stimulus.StimulusKinds)
local StimulusBus = require(ServerScriptService.GameService.Stimulus.StimulusBus)
local FlashEvents = require(ServerScriptService.GameService.Flash.FlashEvents)

local FlashStimulusAdapter = {}

-- A flash is a single bright, unmistakable event, not something whose
-- loudness scales with effort the way a footstep's does. Maximal and fixed.
local STIMULUS_STRENGTH = 1

local started = false

function FlashStimulusAdapter.Start()
	if started then
		return
	end
	started = true

	FlashEvents:Connect(function(flashInfo)
		StimulusBus.Publish({
			Kind      = StimulusKinds.CameraFlash,
			Position  = flashInfo.origin,
			Timestamp = flashInfo.timestamp or os.clock(),
			Strength  = STIMULUS_STRENGTH,
			Source    = flashInfo.player,
		})
	end)
end

return FlashStimulusAdapter
