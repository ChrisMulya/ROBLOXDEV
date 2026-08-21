-- Translates FlashEvents into a CameraFlash stimulus. The only subscriber
-- FlashEvents has ever had -- its own header has said as much since before
-- this file existed, reserving exactly this seam. No second flash event
-- system, no change to FlashEvents or CameraShotHandler: this is purely an
-- adapter sitting downstream of an already-validated event.
--
-- The EVENT is server-derived (FlashEvents is raised by CameraShotHandler
-- from a shot it validated -- cooldown, range, quality; there is no client
-- "I flashed" remote), but NOT every field in its payload is: flashInfo.origin
-- is the client-reported shot origin, only bounded to +-10 studs of the
-- shooter's Head by CaptureGuard, not server-derived. An earlier version of
-- this adapter used it directly as Position -- a client could steer a
-- monster's investigation destination by that same 10 studs. Position below
-- is resolved fresh from the shooter's own Head instead, so this stimulus is
-- now genuinely fully server-derived, not just server-triggered.
--
-- NARROWS the payload, does not forward it. FlashEvents carries {player,
-- origin, direction, cameraId, shotQuality, hitPosition, timestamp}; only
-- player (-> Source, and -> the Position resolved below) and timestamp
-- survive. origin, direction, cameraId, shotQuality and hitPosition are
-- camera-domain detail a monster's perception has no use for.
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
		-- Server-resolved, not flashInfo.origin -- see header. Fails
		-- closed (no stimulus) if the shooter's Head can't be found
		-- rather than falling back to the client-reported value.
		local character = flashInfo.player and flashInfo.player.Character
		local head = character and character:FindFirstChild("Head")
		local position = head and head.Position
		if not position then
			return
		end

		StimulusBus.Publish({
			Kind      = StimulusKinds.CameraFlash,
			Position  = position,
			Timestamp = flashInfo.timestamp or os.clock(),
			Strength  = STIMULUS_STRENGTH,
			Source    = flashInfo.player,
		})
	end)
end

return FlashStimulusAdapter
