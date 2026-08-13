-- Shared aim math for the flashlight emitter. Server-authoritative only: the
-- server is the sole writer of the emitter's CFrame, at FlashlightAim.SEND_RATE,
-- for every client including the holder -- there is no client-side prediction
-- to keep in sync with this, unlike the split-rate design this replaced.
--
-- The beam is deliberately NOT welded to the Head. A weld would pin the beam
-- to head ORIENTATION, and a Roblox Head only yaws -- it does not pitch with
-- the camera -- so a welded flashlight cannot be aimed up or down at all. The
-- emitter is an anchored part posed from a client-reported look vector
-- instead, which is the only source of true vertical aim.

local FlashlightAim = {}

-- How often the server re-poses the emitter, for everyone. 30Hz: four
-- players' worth of FlashlightAim traffic at this rate is ~120 Vector3
-- remote fires/sec server-wide, trivial next to the game's other remotes
-- (StaminaSync alone is a 10Hz broadcast to every client). No measured cost,
-- just headroom -- raise SEND_RATE further only if a real profile calls for it.
FlashlightAim.SEND_RATE = 1 / 30

-- Negative = the emitter sits BEHIND the head, along the look vector. It used
-- to sit 1.2 studs in FRONT, which put the light source inside the geometry
-- whenever the player faced a near wall or looked down at the floor -- a
-- SpotLight originating inside a part lights nothing, so the beam simply
-- vanished at exactly the moments it mattered. Pulling the origin back keeps
-- the source in open air with the surface still inside its cone.
local FORWARD_OFFSET = -2

function FlashlightAim.GetPose(headCFrame: CFrame, lookDirection: Vector3): CFrame
	local origin = headCFrame.Position + lookDirection * FORWARD_OFFSET
	return CFrame.lookAt(origin, origin + lookDirection)
end

return FlashlightAim
