-- The set of live monsters. Takes over the `liveAgents` table that used to be
-- module state inside MonsterService, so that "who exists right now" has one
-- owner and the scheduler, the director and the evolution hook can all read it
-- without requiring MonsterService (and without MonsterService requiring them).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Modules.Shared.Signal)

local MonsterRegistry = {}

-- [model] = MonsterInstance
local instances = {}
local liveCount = 0

-- Cross-service boundary, so Shared/Signal is correct here (one signal total,
-- deferred fire harmless) -- unlike the per-instance MonsterBus.
--
-- Both fire (model, monsterId), never the instance table: Signal wraps a
-- BindableEvent, which deep-copies table arguments and would strip the
-- instance's metatable. Subscribers call MonsterRegistry.Get(model).
MonsterRegistry.Spawned = Signal.new()
MonsterRegistry.Died = Signal.new()

function MonsterRegistry.Add(model: Model, instance): boolean
	if instances[model] then
		warn(("MonsterRegistry.Add: '%s' is already registered"):format(model.Name))
		return false
	end

	instances[model] = instance
	liveCount += 1
	MonsterRegistry.Spawned:Fire(model, instance.monsterId)
	return true
end

-- Idempotent: both teardown paths call it (model.Destroying, and the
-- scheduler's sweep for models unparented via `model.Parent = nil`, which does
-- NOT fire Destroying). Whichever runs first wins and the other no-ops.
function MonsterRegistry.Remove(model: Model): boolean
	local instance = instances[model]
	if not instance then
		return false
	end

	instances[model] = nil
	liveCount -= 1

	instance:Destroy()
	MonsterRegistry.Died:Fire(model, instance.monsterId)
	return true
end

function MonsterRegistry.Get(model: Model)
	return instances[model]
end

function MonsterRegistry.Count(): number
	return liveCount
end

-- Snapshot buffer, reused across calls. MonsterScheduler calls ForEach every
-- Heartbeat, so allocating a fresh table (plus one per monster) here meant
-- 60+ throwaway tables a second before a single monster existed. table.clear
-- keeps the allocation and drops the garbage.
--
-- Not reentrant, which is fine and worth stating: nothing nests ForEach, and
-- the alternative (allocating per call) is what this exists to avoid.
local snapshotModels = {}

-- Iterates a snapshot so a callback may despawn the monster it's handed, or
-- any other, without invalidating the loop. The scheduler's orphan sweep and
-- evolution both do exactly that.
function MonsterRegistry.ForEach(fn: (Model, any) -> ())
	local count = 0
	for model in pairs(instances) do
		count += 1
		snapshotModels[count] = model
	end

	for index = 1, count do
		local model = snapshotModels[index]
		-- Still registered? An earlier callback may have removed it.
		local instance = instances[model]
		if instance then
			fn(model, instance)
		end
		-- Release the reference immediately rather than pinning destroyed
		-- models alive in the buffer until the next call overwrites the slot.
		snapshotModels[index] = nil
	end
end

local started = false

function MonsterRegistry.Start()
	if started then
		return
	end
	started = true
end

return MonsterRegistry
