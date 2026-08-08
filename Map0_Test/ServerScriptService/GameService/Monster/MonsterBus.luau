-- Per-instance event dispatch. One bus per live monster; components publish and
-- subscribe without requiring each other.
--
-- Deliberately NOT Shared/Signal, which is the repo's pub-sub primitive
-- everywhere else. Two properties of BindableEvent disqualify it here:
--
--   1. Fires are DEFERRED. The Brain re-evaluates off stimuli, so a deferred
--      fire adds a frame of latency and makes ordering between sensors
--      non-deterministic. This is the disqualifying one.
--   2. Every Signal.new() allocates a real Instance. One per signal per monster
--      is hundreds of DataModel objects with their own lifetime and GC cost.
--
-- Table-identity loss (Signal's documented caveat) is NOT the reason -- a
-- stimulus is flat primitives plus a Player, which copies fine. But the safety
-- that copying gave us for free is worth keeping deliberately, so payloads are
-- frozen before dispatch: no subscriber can mutate a record another subscriber
-- has not read yet.
--
-- Shared/Signal remains correct for cross-service boundaries (MonsterRegistry
-- .Spawned/.Died) where there's one signal total and deferral is harmless.

local MonsterBus = {}
MonsterBus.__index = MonsterBus

function MonsterBus.new()
	return setmetatable({ _handlers = {} }, MonsterBus)
end

-- Returns an unsubscribe function, which Trove accepts directly:
--   trove:Add(bus:On("StimulusReceived", fn))
function MonsterBus:On(event: string, fn: (any) -> ()): () -> ()
	local list = self._handlers[event]
	if not list then
		list = {}
		self._handlers[event] = list
	end
	table.insert(list, fn)

	local disconnected = false
	return function()
		if disconnected then return end
		disconnected = true

		local current = self._handlers[event]
		if not current then return end
		local index = table.find(current, fn)
		if index then
			table.remove(current, index)
		end
	end
end

-- Immediate and synchronous -- that's the whole point. Handlers are called on
-- a snapshot so a handler may unsubscribe itself (or another) mid-dispatch
-- without the iteration skipping an entry.
--
-- Each handler is pcall'd: components are optional and independently authored,
-- so one erroring sensor must not stop the others from seeing the event or
-- abort the scheduler tick that published it. Same posture as
-- MatchTimeEvents.Dispatch.
function MonsterBus:Fire(event: string, payload: any?)
	local list = self._handlers[event]
	if not list or #list == 0 then
		return
	end

	if type(payload) == "table" and not table.isfrozen(payload) then
		table.freeze(payload)
	end

	local snapshot = table.clone(list)
	for _, fn in ipairs(snapshot) do
		local ok, err = pcall(fn, payload)
		if not ok then
			warn(("MonsterBus: handler for '%s' errored -- %s"):format(event, tostring(err)))
		end
	end
end

function MonsterBus:Destroy()
	table.clear(self._handlers)
end

return MonsterBus
