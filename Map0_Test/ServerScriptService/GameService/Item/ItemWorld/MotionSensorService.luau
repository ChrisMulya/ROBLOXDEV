-- Detection loop for every placed Motion Sensor. One shared 2Hz sweep for
-- all of them, not a loop per sensor. Candidates come from
-- MonsterRegistry.ForEach, never a Workspace scan -- the same source every
-- other monster-aware system in the repo uses.
--
-- 360 degrees, no cone: that's what distinguishes this from VisionSensor.
-- Walls block it (SensorVision.HasLineOfSight) -- Euclidean distance alone is
-- explicitly not enough, per the design.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local SensorVision = require(script.Parent.SensorVision)
local DeployableRegistry = require(script.Parent.DeployableRegistry)
local MonsterRegistry = require(ServerScriptService.GameService.Monster.MonsterRegistry)
local DeathService = require(ServerScriptService.GameService.Death.DeathService)

local MotionSensorService = {}

local TICK_INTERVAL = 0.5 -- 2Hz
-- Edge-triggered alert with a hysteresis hold: a monster skimming the
-- boundary of the radius would otherwise strobe the remote every tick it
-- crosses in and out.
local ALERT_HOLD = 1.5

-- [model] = { record, radius, active, lastDetectedAt }
local tracked = {}
local motionSensorAlert: RemoteEvent

local function setActive(record, active: boolean)
	motionSensorAlert:FireClient(record.owner, active)
end

local function untrack(model: Instance)
	local state = tracked[model]
	if not state then
		return
	end
	tracked[model] = nil
	if state.active then
		setActive(state.record, false)
	end
end

function MotionSensorService.Track(record, radius: number)
	tracked[record.model] = { record = record, radius = radius, active = false, lastDetectedAt = 0 }
end

local function sweep()
	local now = os.clock()
	for model, state in pairs(tracked) do
		if not model.Parent then
			untrack(model)
			continue
		end

		local sensorPos = model:IsA("Model") and model:GetPivot().Position or (model :: BasePart).Position
		local detected = false

		MonsterRegistry.ForEach(function(monsterModel, instance)
			if detected then
				return
			end
			local rootPart = instance.rootPart
			if not rootPart or not rootPart.Parent then
				return
			end

			local distance = (rootPart.Position - sensorPos).Magnitude
			if distance > state.radius then
				return
			end

			if SensorVision.HasLineOfSight(sensorPos, rootPart.Position, { model, monsterModel }) then
				detected = true
			end
		end)

		if detected then
			state.lastDetectedAt = now
			if not state.active then
				state.active = true
				setActive(state.record, true)
			end
		elseif state.active and (now - state.lastDetectedAt) > ALERT_HOLD then
			state.active = false
			setActive(state.record, false)
		end
	end
end

local accumulator = 0
local started = false

function MotionSensorService.Start()
	if started then
		return
	end
	started = true

	motionSensorAlert = Remotes.Get("MotionSensorAlert")

	-- Lifetime is "until match end or owner death" -- match end is
	-- DeployableRegistry's own MatchCleanup teardown step; this is the death
	-- half, scoped to MotionSensor records only (Compact Speaker and
	-- Portable CCTV each define their own, different death behaviour).
	DeathService.Died:Connect(function(payload)
		for _, record in ipairs(DeployableRegistry.ForOwner(payload.player)) do
			if record.kind == "MotionSensor" then
				DeployableRegistry.Unregister(record.model)
			end
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < TICK_INTERVAL then
			return
		end
		accumulator = 0
		sweep()
	end)
end

return MotionSensorService
