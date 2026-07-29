-- The client-local "a flash occurred" broadcast. Camera fires it; renderers
-- (and, later, any other cosmetic reactor) subscribe. Never crosses the
-- network -- see ServerScriptService/GameService/Flash/FlashEvents for the
-- server-side perceptual bus that monster AI will subscribe to instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)

-- flashContext: { cameraId, shotQuality, origin: Vector3, direction: Vector3 }
return Signal.new()
