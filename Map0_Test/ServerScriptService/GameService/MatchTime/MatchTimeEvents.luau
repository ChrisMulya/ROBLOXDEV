-- Registry + dispatcher for "at in-game hour H, run this". Server only.
-- Populated at boot (registry before registrant, same rule as
-- MatchCleanup.RegisterSaveStep) and dispatched by MatchTimeService.
--
-- Ships with zero entries by design -- same shape as RewardModifiers. The
-- registry existing is what makes a scheduled spawn wave or an extraction
-- window a one-line registration instead of a new timer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)

local MatchTimeEvents = {}

type Entry = {
	name: string,
	atHour: number,
	fn: (hour: number) -> (),
}

local entries: { Entry } = {}
local cursor = 1

function MatchTimeEvents.Register(name: string, atHour: number, fn: (hour: number) -> ())
	assert(typeof(name) == "string" and name ~= "", "MatchTimeEvents.Register: name must be a non-empty string")
	assert(typeof(atHour) == "number", ("MatchTimeEvents.Register: '%s' atHour must be a number"):format(name))
	assert(typeof(fn) == "function", ("MatchTimeEvents.Register: '%s' fn must be a function"):format(name))

	table.insert(entries, { name = name, atHour = atHour, fn = fn })
end

-- Called by MatchTimeService when Playing begins. Sorts once and rewinds the
-- cursor so a second match on the same server (or a Studio re-run) dispatches
-- the full set again rather than starting from wherever the last one stopped.
function MatchTimeEvents.Reset()
	table.sort(entries, function(a, b)
		return a.atHour < b.atHour
	end)
	cursor = 1
end

-- Match time only ever moves forward within a match, so this is a monotonic
-- cursor rather than a scan: O(1) per sample in the common case. A sample
-- that straddles several entries fires all of them, in order -- none skipped,
-- none fired twice.
--
-- Handlers run under task.spawn: a yielding or erroring handler must not be
-- able to stall the clock or block the entries queued behind it. Same
-- defensive posture as MatchCleanup.runWithTimeout.
function MatchTimeEvents.Dispatch(currentHour: number)
	while cursor <= #entries and entries[cursor].atHour <= currentHour do
		local entry = entries[cursor]
		cursor += 1
		task.spawn(function()
			local ok, err = pcall(entry.fn, entry.atHour)
			if not ok then
				warn(("MatchTimeEvents: handler '%s' errored: %s"):format(entry.name, tostring(err)))
			end
		end)
	end
end

local started = false

function MatchTimeEvents.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()
end

return MatchTimeEvents
