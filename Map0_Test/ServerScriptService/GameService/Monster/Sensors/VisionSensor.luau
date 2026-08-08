-- Sight. Extracted from MonsterSensing.GetNearestPlayer, which was a pure
-- distance scan with no cone and no line-of-sight -- monsters saw through
-- walls, and every monster sensed identically.
--
-- FOV and RequiresLOS are both per-monster config, not debug switches: "blind
-- but omnidirectional" (FOV 360) and "senses you through geometry"
-- (RequiresLOS false) are both legitimate monster designs.
--
-- Note that enabling LOS shrinks a monster's effective detection volume to
-- roughly a third of the same radius without it, so DetectRadius has to be
-- re-tuned alongside -- it is not an independent switch.

local Players = game:GetService("Players")

local VisionSensor = {}
VisionSensor.__index = VisionSensor
VisionSensor.Name = "Vision"

function VisionSensor.new(instance, _sensorConfig)
	local self = setmetatable({ instance = instance }, VisionSensor)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- TRUE, so only physically solid geometry blocks sight. With this false
	-- (the engine default) the ray hits every part regardless of CanCollide,
	-- which means invisible trigger volumes, effect parts and decorative
	-- non-colliding meshes all blind the monster. The symptom is "it can't see
	-- me while I'm standing in the open", which is close to undiagnosable
	-- without knowing to look here.
	--
	-- CanCollide is a proxy for "blocks sight", not a perfect one -- a glass
	-- window collides and will block vision. Revisit if that becomes a real
	-- level-design problem; a CollisionGroup or a tag would be the fix.
	params.RespectCanCollide = true
	self.raycastParams = params

	return self
end

-- Read fresh every tick, never captured in new(). instance.config is REPLACED
-- wholesale on re-stage and on evolution -- an evolution tier can widen FOV or
-- switch LOS on -- so anything cached at construction would pin the sensor to
-- stage-1 numbers for the monster's entire life. The constructor's
-- sensorConfig argument is accepted for interface symmetry and ignored.
function VisionSensor:GetSettings(): (number, number, boolean)
	local config = self.instance.config
	local perception = config.Perception
	local sensorConfig = perception and perception.Sensors and perception.Sensors[VisionSensor.Name] or {}

	return sensorConfig.Range or config.Stats.DetectRadius,
		sensorConfig.FOV or 360,
		sensorConfig.RequiresLOS == true
end

-- Eye height, not root height. HumanoidRootPart sits at TORSO height, so
-- casting from it means the monster looks out of its stomach and every
-- waist-high counter, railing or display blocks sight it should have straight
-- over. Falls back to the root for models with no Head.
local function eyePosition(model: Model, rootPart: BasePart): Vector3
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	return rootPart.Position
end

-- Aim at the target's head for the same reason: a player behind a counter with
-- their head clearly visible should be seen. Their root is mid-torso and would
-- be occluded.
local function aimPosition(character: Model, targetRoot: BasePart): Vector3
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	return targetRoot.Position
end

local function isBlocked(self, origin: Vector3, targetPos: Vector3, character: Model): boolean
	-- Exclude both ends of the ray: the monster's own model would block every
	-- cast from inside it, and the target's character would register as the
	-- thing occluding itself.
	self.raycastParams.FilterDescendantsInstances = { self.instance.model, character }

	local direction = targetPos - origin
	local result = workspace:Raycast(origin, direction, self.raycastParams)
	return result ~= nil
end

-- Appends {player, position, distance} for everything seen. Does NOT pick a
-- target or draw any conclusion -- that's Targeting's job. A sensor reports.
function VisionSensor:Sense(out: { any })
	local rootPart = self.instance.rootPart
	if not rootPart or not rootPart.Parent then
		return
	end

	local range, fov, requiresLOS = self:GetSettings()
	if not range then
		return
	end

	-- Distance and the FOV cone are measured from the ROOT (body position and
	-- body facing); only the occlusion ray starts at the eyes. Using the head
	-- for facing would let an animated head-turn swing the cone around.
	local origin = rootPart.Position
	local eye = eyePosition(self.instance.model, rootPart)
	local halfFov = fov * 0.5
	local facing = rootPart.CFrame.LookVector

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if targetRoot and humanoid and humanoid.Health > 0 then
			local targetPos = targetRoot.Position
			local offset = targetPos - origin
			local distance = offset.Magnitude
			local visible = distance <= range

			if visible and fov < 360 and distance > 0 then
				local angle = math.deg(math.acos(math.clamp(facing:Dot(offset.Unit), -1, 1)))
				visible = angle <= halfFov
			end

			if visible and requiresLOS then
				visible = not isBlocked(self, eye, aimPosition(character, targetRoot), character)
			end

			if visible then
				table.insert(out, {
					player   = player,
					position = targetPos,
					distance = distance,
					source   = VisionSensor.Name,
				})
			end
		end
	end
end

function VisionSensor:Destroy()
	self.raycastParams = nil
end

return VisionSensor
