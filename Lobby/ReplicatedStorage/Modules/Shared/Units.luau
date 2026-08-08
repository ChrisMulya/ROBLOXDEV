-- Stud<->meter conversion. Roblox distances (raycasts, WalkSpeed, monster
-- radii, etc.) stay in studs everywhere internally -- this only exists for the
-- boundary where a stud distance becomes something a player reads.

local Units = {}

Units.STUDS_PER_METER = 3

function Units.StudsToMeters(studs: number): number
	return studs / Units.STUDS_PER_METER
end

return Units
