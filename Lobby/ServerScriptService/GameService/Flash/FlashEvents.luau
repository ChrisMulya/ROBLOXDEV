-- The server-side perceptual bus for camera flashes. Raised by
-- CameraShotHandler from a shot it has already validated -- there is no
-- client->server "I flashed" remote; the server derives the event from
-- information it already possesses, so nothing new is trusted from the
-- client. Ships with zero subscribers; a future MonsterPerception module
-- connects here to add detection radius/angle/line-of-sight without any
-- change to the Camera or to this module.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)

-- flashInfo: { player, origin: Vector3, direction: Vector3, cameraId,
--              shotQuality, hitPosition: Vector3?, timestamp: number }
return Signal.new()
