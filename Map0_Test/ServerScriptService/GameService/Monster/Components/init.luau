-- Component name -> module. A capability's Enables list names components
-- (CanSee -> "Perception"), and MonsterInstance constructs exactly the ones a
-- monster's capabilities resolve to.
--
-- Planned lists components that capabilities already reference but that later
-- steps implement. Get() returns nil for those without warning, so a config can
-- declare CanEvolve today and get the Evolution component when step 10 lands.
-- Anything in NEITHER table is a typo and warns. Without that split, a phased
-- build either spams warnings or hides real mistakes.

local Components = {}

local modules = {
	Perception    = require(script.Perception),
	Targeting     = require(script.Targeting),
	Investigation = require(script.Investigation),
	Aggression    = require(script.Aggression),
	Navigation    = require(script.Navigation),
	Combat        = require(script.Combat),
	Evolution     = require(script.Evolution),
}

local planned = {
	Presentation = "step 11",
	Abilities    = "step 11",
	Interaction  = "step 11",
	Memory       = "later",
}

function Components.Get(name: string)
	local module = modules[name]
	if module then
		return module
	end

	if not planned[name] then
		warn(("Components: unknown component '%s' -- check the capability's Enables list"):format(tostring(name)))
	end
	return nil
end

function Components.IsPlanned(name: string): boolean
	return planned[name] ~= nil
end

-- Boot diagnostic: what a monster declared that doesn't exist yet. Reported
-- once by MonsterFramework rather than per spawn.
function Components.PlannedFor(names: { [string]: boolean }): { string }
	local pending = {}
	for name in pairs(names) do
		if not modules[name] and planned[name] then
			table.insert(pending, ("%s (%s)"):format(name, planned[name]))
		end
	end
	table.sort(pending)
	return pending
end

return Components
