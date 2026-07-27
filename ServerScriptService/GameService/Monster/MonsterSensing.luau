local Players = game:GetService("Players")

local MonsterSensing = {}

-- MVP: pure distance check, no line-of-sight/noise yet (see MONSTERS.md build
-- order step 4). Ignores dead/characterless players.
function MonsterSensing.GetNearestPlayer(fromPosition: Vector3, maxDistance: number): (Player?, Vector3?, number?)
	local nearestPlayer, nearestPos, nearestDist = nil, nil, math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if rootPart and humanoid and humanoid.Health > 0 then
			local dist = (rootPart.Position - fromPosition).Magnitude
			if dist <= maxDistance and dist < nearestDist then
				nearestPlayer, nearestPos, nearestDist = player, rootPart.Position, dist
			end
		end
	end

	return nearestPlayer, nearestPos, nearestDist
end

return MonsterSensing
