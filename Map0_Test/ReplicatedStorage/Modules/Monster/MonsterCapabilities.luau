-- What a monster CAN do, declared as data.
--
-- A capability is not a behaviour -- it's a switch that decides which
-- components get constructed, which states are eligible, and which stimuli are
-- subscribed to. A blind monster doesn't have vision code that early-returns;
-- it has no VisionSensor at all.
--
-- Capabilities are additive only. There is no CannotSee -- a monster that
-- can't see simply omits CanSee. That keeps `Capabilities` readable as a
-- description of the monster rather than a diff against some default one.
--
-- Adding a capability is the one case that edits this file. That's deliberate:
-- it's a registry, the same shape as MatchStates.All.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StimulusKinds = require(ReplicatedStorage.Modules.Stimulus.StimulusKinds)

local MonsterCapabilities = {}

-- Requires : capabilities that must also be present (expanded transitively)
-- Enables  : components constructed when this capability is present
-- States   : states this capability makes eligible
-- Stimuli  : stimulus kinds the perception layer subscribes to
MonsterCapabilities.All = {
	CanNavigate     = { Enables = { "Navigation" } },

	-- "Vision" is not a StimulusKinds entry -- it is sensed by VisionSensor
	-- pulling the world every tick, not published to the bus. See
	-- Components/Perception's Pull/push split.
	CanSee          = { Enables = { "Perception" }, Stimuli = { "Vision" } },
	CanHear         = { Enables = { "Perception" }, Stimuli = { StimulusKinds.Sound, StimulusKinds.Footstep, StimulusKinds.Sprint } },
	CanSeeFlash     = { Enables = { "Perception" }, Stimuli = { StimulusKinds.CameraFlash } },
	-- Reacting to being the SUBJECT of a photo, which CameraFlash cannot
	-- express: FlashEvents fires on every shot and carries no subject.
	CanFeelPhoto    = { Enables = { "Perception" }, Stimuli = { StimulusKinds.Photographed } },

	CanWander       = { Requires = { "CanNavigate" }, States = { "Wander" } },
	CanPatrol       = { Requires = { "CanNavigate" }, States = { "Patrol" } },
	CanChase        = { Requires = { "CanNavigate" }, States = { "Chase" } },
	CanInvestigate  = { Requires = { "CanNavigate" }, States = { "Check" } },
	-- No CanNavigate: lurking is what a stationary monster does.
	CanLurk         = { States = { "Lurk" } },

	CanAttack       = { Enables = { "Combat" }, States = { "Attack" } },
	CanInteract     = { Enables = { "Interaction" } },
	CanEvolve       = { Enables = { "Evolution" } },

	CanTeleport     = { Enables = { "Abilities" }, States = { "Teleport" } },
	CanSpawnMinions = { Enables = { "Abilities" } },

	-- Modify Navigation's AgentParams rather than enabling anything new.
	CanClimb        = { Requires = { "CanNavigate" } },
	CanFly          = { Requires = { "CanNavigate" } },
	CanOpenDoors    = { Requires = { "CanNavigate", "CanInteract" } },
}

-- Every monster gets these regardless of what it declares. Both are sole
-- writers of a Blackboard key that many things read (see blueprint 2):
-- Targeting owns Target, Aggression owns Aggression. Without them there is
-- nobody to own the key, and every reader would have to nil-check.
--
-- Note this is the ONE place the additive-capability rule bends, and it bends
-- toward ownership rather than behaviour: a monster with no Aggression config
-- gets the component but no modifiers, so it sits at 0 and behaves exactly as
-- if it had none. There is no CanBeAngry because there is nothing to switch
-- off.
MonsterCapabilities.AlwaysOn = { "Targeting", "Aggression" }

local function expand(name: string, into: { [string]: boolean }, seen: { [string]: boolean }, monsterId: string?)
	if into[name] then
		return
	end

	local def = MonsterCapabilities.All[name]
	if not def then
		warn(("MonsterCapabilities: unknown capability '%s'%s -- ignored")
			:format(tostring(name), monsterId and (" on monster '" .. monsterId .. "'") or ""))
		return
	end

	if seen[name] then
		warn(("MonsterCapabilities: capability cycle through '%s'"):format(name))
		return
	end
	seen[name] = true

	for _, required in ipairs(def.Requires or {}) do
		expand(required, into, seen, monsterId)
	end

	into[name] = true
	seen[name] = nil
end

-- Turns a declared list into a set with every Requires pulled in. A config
-- that says CanChase gets CanNavigate for free -- declaring the implied
-- capability is optional, not an error.
function MonsterCapabilities.Resolve(list: { string }, monsterId: string?): { [string]: boolean }
	local set = {}
	for _, name in ipairs(list or {}) do
		expand(name, set, {}, monsterId)
	end
	return set
end

function MonsterCapabilities.Has(set: { [string]: boolean }, name: string): boolean
	return set[name] == true
end

local function collect(set: { [string]: boolean }, field: string): { [string]: boolean }
	local out = {}
	for name in pairs(set) do
		local def = MonsterCapabilities.All[name]
		for _, value in ipairs(def and def[field] or {}) do
			out[value] = true
		end
	end
	return out
end

-- Components to construct. AlwaysOn is folded in here so callers can't forget.
function MonsterCapabilities.ComponentsFor(set: { [string]: boolean }): { [string]: boolean }
	local components = collect(set, "Enables")
	for _, name in ipairs(MonsterCapabilities.AlwaysOn) do
		components[name] = true
	end
	return components
end

function MonsterCapabilities.StatesFor(set: { [string]: boolean }): { [string]: boolean }
	return collect(set, "States")
end

function MonsterCapabilities.StimuliFor(set: { [string]: boolean }): { [string]: boolean }
	return collect(set, "Stimuli")
end

-- Internal consistency only: every Requires target exists and no cycles. It
-- deliberately does NOT check that named components/states exist -- those live
-- in ServerScriptService and this module must not reach across that boundary.
-- MonsterConfig.Validate covers the per-monster half.
function MonsterCapabilities.Validate()
	for name, def in pairs(MonsterCapabilities.All) do
		assert(type(def) == "table", ("MonsterCapabilities: '%s' is not a table"):format(name))

		for _, required in ipairs(def.Requires or {}) do
			assert(MonsterCapabilities.All[required],
				("MonsterCapabilities: '%s' requires unknown capability '%s'"):format(name, required))
		end

		for _, field in ipairs({ "Enables", "States", "Stimuli" }) do
			assert(def[field] == nil or type(def[field]) == "table",
				("MonsterCapabilities: '%s'.%s must be a table"):format(name, field))
		end
	end

	-- Resolving every capability in isolation surfaces any cycle as a warn
	-- from expand() at boot rather than during a match.
	for name in pairs(MonsterCapabilities.All) do
		MonsterCapabilities.Resolve({ name })
	end
end

return MonsterCapabilities
