-- Distance only: no cone, no line-of-sight, no stimulus subscription. The
-- fallback for a monster that declares no real senses but still has to notice
-- someone standing on top of it, and the cheapest thing Perception can run.
--
-- Deliberately NOT tied to a capability. Perception falls back to it when a
-- monster's capabilities resolve to no sensors at all, so "senses nothing"
-- degrades to "senses contact" rather than to a monster that can never react.

local Players = game:GetService("Players")

local ProximitySensor = {}
ProximitySensor.__index = ProximitySensor
ProximitySensor.Name = "Proximity"

function ProximitySensor.new(instance, _sensorConfig)
	return setmetatable({ instance = instance }, ProximitySensor)
end

-- Read fresh for the same reason as VisionSensor: instance.config is replaced
-- wholesale on re-stage and evolution, so caching in new() would pin the
-- sensor to stage-1 numbers.
function ProximitySensor:GetRange(): number?
	local config = self.instance.config
	local perception = config.Perception
	local sensorConfig = perception and perception.Sensors and perception.Sensors[ProximitySensor.Name]

	return (sensorConfig and sensorConfig.Range) or config.Stats.DetectRadius
end

function ProximitySensor:Sense(out: { any })
	local rootPart = self.instance.rootPart
	if not rootPart or not rootPart.Parent then
		return
	end

	local range = self:GetRange()
	if not range then
		return
	end

	local origin = rootPart.Position

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if targetRoot and humanoid and humanoid.Health > 0 then
			local distance = (targetRoot.Position - origin).Magnitude
			if distance <= range then
				table.insert(out, {
					player   = player,
					position = targetRoot.Position,
					distance = distance,
					source   = ProximitySensor.Name,
				})
			end
		end
	end
end

function ProximitySensor:Destroy() end

return ProximitySensor
