-- State name -> module.
--
-- Which of these a monster can actually enter is the intersection of its
-- capabilities (MonsterCapabilities.StatesFor) and its config's per-state
-- weights. A monster that never chases simply has no Chase weight; nothing
-- guards against it and no code branches on monster type.
--
-- Wander / Patrol / Lurk / Check / Attack landed across D4 and D7. Teleport
-- (CanTeleport) is deferred to the Abilities work in Phase E -- it needs a
-- component that does not exist yet. Adding a state is a file here plus a
-- weight row in a monster's config -- no existing state changes, which is the
-- property the old MonsterAgent.States require-table made impossible.

local States = {}

local modules = {
	Idle   = require(script.Idle),
	Chase  = require(script.Chase),
	Check  = require(script.Check),
	Wander = require(script.Wander),
	Patrol = require(script.Patrol),
	Lurk   = require(script.Lurk),
	Attack = require(script.Attack),
	Reset  = require(script.Reset),
}

-- Candidates the Brain adds regardless of capabilities or config weights.
--
-- Idle is the floor -- without it a monster whose every state scores nil has
-- nothing valid to run. Reset is the recovery path, and a monster that can get
-- stuck or leashed must be able to reach it even if its author never thought
-- about it. Both are inert when they have nothing to do (Idle scores 0.01,
-- Reset scores nil unless the monster defines LeashDistance).
States.Always = { "Idle", "Reset" }

States.FallbackName = "Idle"

function States.Get(name: string?)
	if not name then
		return nil
	end
	return modules[name]
end

function States.Exists(name: string): boolean
	return modules[name] ~= nil
end

return States
