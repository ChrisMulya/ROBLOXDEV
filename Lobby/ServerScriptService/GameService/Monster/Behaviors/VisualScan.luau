-- A deliberate visual scan: rotate slowly to one side, then the other, then
-- back to the original heading, pausing briefly at each extreme. Transient --
-- constructed by whichever state needs it (today only Check) and discarded
-- afterward, not a component, so it is reusable for future monster-specific
-- search behaviours without adding another always-on Tick.
--
-- Perception keeps ticking independently and VisionSensor reads facing
-- straight off rootPart.CFrame.LookVector, so the rotating root genuinely
-- widens detection coverage during the scan -- no extra wiring needed for
-- "detects the player mid-scan and resumes Chase".
--
-- Orientation math is done entirely through CFrame composition (CFrame.new
-- with a lookAt point, then CFrame.Angles offsets), never raw trig, so it
-- can't get the coordinate convention backwards -- Roblox's own operations
-- stay self-consistent regardless of which direction ends up "left".

local VisualScan = {}
VisualScan.__index = VisualScan

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConstants = require(ReplicatedStorage.Modules.Monster.MonsterConstants)

local function investigationConfig(instance)
	return instance.config.Investigation or {}
end

-- opts: SweepDegrees, Speed (deg/s), Pause (seconds at each extreme). All
-- fall back to Config.Investigation, then MonsterConstants defaults.
function VisualScan.new(instance, opts)
	opts = opts or {}

	local rootPart = instance.rootPart
	local humanoid = instance.humanoid

	local cfg = investigationConfig(instance)
	local sweepDegrees = opts.SweepDegrees or cfg.ScanSweepDegrees or MonsterConstants.DefaultScanSweepDegrees
	local speed = opts.Speed or cfg.ScanSpeed or MonsterConstants.DefaultScanSpeed
	local pause = opts.Pause or cfg.ScanPause or MonsterConstants.DefaultScanPause

	local navigation = instance:GetComponent("Navigation")
	if navigation then
		navigation:Stop()
	end

	local previousAutoRotate = humanoid and humanoid.AutoRotate
	if humanoid then
		humanoid.AutoRotate = false
	end

	-- Pure-orientation CFrame (position zeroed) looking along the monster's
	-- CURRENT facing at the moment the scan starts. Every leg target below is
	-- a Y-rotation offset from this, so the sweep is always relative to
	-- however the monster happened to be facing, never a world axis.
	local lookVector = rootPart and rootPart.CFrame.LookVector or Vector3.new(0, 0, -1)
	local baseOrientation = CFrame.new(Vector3.zero, lookVector)
	local sweepRadians = math.rad(sweepDegrees)

	local self = setmetatable({
		instance = instance,
		rootPart = rootPart,
		humanoid = humanoid,
		previousAutoRotate = previousAutoRotate,
		baseOrientation = baseOrientation,
		currentOffset = 0,
		speedRadians = math.rad(speed),
		pauseDuration = pause,
		-- Out to one extreme, across to the other, back to base. Which
		-- extreme Roblox's rotation convention calls "left" doesn't matter --
		-- the requirement is the shape of the sweep, not a stage direction.
		legTargets = { -sweepRadians, sweepRadians, 0 },
		legIndex = 1,
		pauseUntil = nil,
		done = false,
	}, VisualScan)

	return self
end

function VisualScan:_restore()
	if self.humanoid then
		self.humanoid.AutoRotate = self.previousAutoRotate
	end
end

-- Returns true once the sweep has fully completed (including the final pause
-- at base heading).
function VisualScan:Tick(dt: number): boolean
	if self.done then
		return true
	end

	local rootPart = self.rootPart
	local humanoid = self.humanoid
	if not rootPart or not rootPart.Parent then
		self.done = true
		return true
	end

	-- Required every tick: MoveDirection persists from whatever last called
	-- Move/MoveTo, so skipping this would carry the monster forward through
	-- its own scan (HumanoidPathLocomotion's MoveTo contract).
	if humanoid then
		humanoid:Move(Vector3.zero, false)
	end

	if self.pauseUntil then
		if os.clock() < self.pauseUntil then
			return false
		end
		self.pauseUntil = nil
		self.legIndex += 1
		if self.legIndex > #self.legTargets then
			self.done = true
			self:_restore()
			return true
		end
	end

	local target = self.legTargets[self.legIndex]
	local delta = target - self.currentOffset
	local step = self.speedRadians * dt

	if math.abs(delta) <= step then
		self.currentOffset = target
		self.pauseUntil = os.clock() + self.pauseDuration
	else
		self.currentOffset += (delta >= 0 and step or -step)
	end

	-- Yaw-only: pitch/roll are never touched, so a slope under the monster
	-- doesn't get tipped by the sweep.
	rootPart.CFrame = CFrame.new(rootPart.Position) * self.baseOrientation * CFrame.Angles(0, self.currentOffset, 0)

	return false
end

function VisualScan:Cancel()
	if self.done then
		return
	end
	self.done = true
	self:_restore()
end

return VisualScan
