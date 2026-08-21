-- The server-side perceptual bus for camera flashes. Raised by
-- CameraShotHandler from a shot it has already validated -- there is no
-- client->server "I flashed" remote, so nothing decides WHETHER this fires
-- except the server. That is not the same as every field in the payload
-- being server-derived, though: origin/direction below are the client-
-- reported shot origin/direction (CaptureGuard bounds origin to +-10 studs
-- of the shooter's Head, nothing more), and hitPosition derives from a
-- raycast that starts at that origin. A subscriber that wants a position to
-- act on should resolve it from the shooter's own Head/Character, the way
-- FlashStimulusAdapter (the one subscriber today) does -- not from these
-- fields directly.
--
-- Ships with zero subscribers beyond FlashStimulusAdapter; a future
-- MonsterPerception module connects here to add detection radius/angle/
-- line-of-sight without any change to the Camera or to this module.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)

-- flashInfo: { player, origin: Vector3, direction: Vector3, cameraId,
--              shotQuality, hitPosition: Vector3?, timestamp: number }
return Signal.new()
