-- The registry of exit KINDS. IsExit (the discovery marker), ExitType (the
-- kind selector), and CanExit (the availability attribute) are defined here
-- and nowhere else -- consumers must go through MarkerAttribute/
-- TypeAttribute/AvailabilityAttribute rather than hardcoding any of the three
-- strings. Modelled directly on Pickup/PickupTypes.luau.
--
-- No CollectionService tag: the project has zero CollectionService usage
-- anywhere, and every other discovery system (Pickup, Objective, Capture,
-- MonsterSpawn) uses a boolean marker attribute + a per-domain registry.

local ExitTypes = {}

ExitTypes.MarkerAttribute = "IsExit"
ExitTypes.TypeAttribute = "ExitType"
ExitTypes.AvailabilityAttribute = "CanExit"

-- Authored part holding the world-space requirement sign
-- (DisplayLabel > BillboardGui > TextLabel). In the current map the marker
-- attributes sit on the exit's collision Part and DisplayLabel is its
-- SIBLING inside a shared Model, so ExitLabel resolves upward through the
-- Model rather than assuming a descendant. Named here for the same reason
-- the attributes are: one definition site, no hardcoded strings elsewhere.
ExitTypes.LabelPartName = "DisplayLabel"

-- No prompt config and no interact distance: escaping is a dwell inside the
-- marked Part's own volume (see ExitService), so the Part's Size IS the
-- interaction range and there is nothing per-kind left to tune here.
ExitTypes.Types = {
	Main = {
		DisplayName = "Main Exit",
	},
	Alternate = {
		DisplayName = "Alternate Exit",
	},
}

-- Ordered by DisplayName, computed once at module load. Precedent:
-- CaptureTargets.OrderedNames / PickupTypes.OrderedNames.
local orderedTypeNames = {}
for typeName in pairs(ExitTypes.Types) do
	table.insert(orderedTypeNames, typeName)
end
table.sort(orderedTypeNames)

function ExitTypes.Get(typeName: string?)
	if not typeName then
		return nil
	end
	return ExitTypes.Types[typeName]
end

function ExitTypes.OrderedNames(): { string }
	return table.clone(orderedTypeNames)
end

-- The ExitType string on this exact instance, but ONLY if it names a
-- registered row -- an authored typo returns nil rather than a string
-- callers would have to re-validate.
function ExitTypes.TypeOf(instance: Instance): string?
	local typeName = instance:GetAttribute(ExitTypes.TypeAttribute)
	if typeof(typeName) ~= "string" then
		return nil
	end
	if not ExitTypes.Types[typeName] then
		return nil
	end
	return typeName
end

-- Walks from hitInstance up through its ancestors (stopping at workspace),
-- returning the first Instance carrying the marker attribute, or nil. Mirrors
-- PickupTypes.Resolve / CaptureTargets.Resolve.
function ExitTypes.Resolve(hitInstance: Instance?): Instance?
	local current = hitInstance
	while current and current ~= workspace do
		if current:GetAttribute(ExitTypes.MarkerAttribute) == true then
			return current
		end
		current = current.Parent
	end
	return nil
end

return ExitTypes
