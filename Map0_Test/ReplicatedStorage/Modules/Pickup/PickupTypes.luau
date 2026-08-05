-- The registry of collectible pickup KINDS. IsPickup (the discovery marker)
-- and PickupType (the kind selector) are defined here and nowhere else --
-- consumers must go through MarkerAttribute/TypeAttribute rather than
-- hardcoding either string, the coupling CaptureTargets.luau exists to
-- prevent for capture targets and that ObjectiveRegistry/
-- ObjectiveVisualsController failed to avoid for IsObjective.
--
-- Adding Keys/Gadgets/Buffs/etc. is a new row here plus one module in
-- ServerScriptService/GameService/Pickup/PickupHandlers/ -- never a change to
-- PickupService, PickupRegistry, or the visuals layer.
--
-- Deliberately has NO Default row (unlike ObjectiveTypes/DeathPolicy): an
-- unregistered PickupType must refuse to pay out, not silently fall back to
-- Cash. See PickupService for the corresponding refuse-and-warn behavior.

local PickupTypes = {}

PickupTypes.MarkerAttribute = "IsPickup"
PickupTypes.TypeAttribute = "PickupType"

-- Params is opaque to PickupService -- only the named Handler module reads
-- it. That's what lets a future Key row carry {DoorId = "Vault"} or a Buff
-- row carry {Stat = "WalkSpeed", ...} with zero service changes.
PickupTypes.Types = {
	Cash = {
		DisplayName = "Cash",
		Handler = "Cash", -- key into PickupHandlers
		VisualStyle = "CashGlow", -- key into PickupVisuals.Styles
		ClaimPolicy = "Consume", -- Consume today; Respawn/Shared are future ClaimPolicy values
		MaxInteractDistance = 12, -- studs; server re-check, independent of the prompt's own range
		Prompt = {
			ActionText = "Collect",
			ObjectText = "Cash",
			HoldDuration = 0.35,
			MaxActivationDistance = 10, -- must stay below MaxInteractDistance (see CameraShelfHandler's identical margin)
			RequiresLineOfSight = false,
		},
		Params = {
			Amount = 50,
		},
	},
}

-- Ordered by DisplayName, computed once at module load rather than on every
-- call -- pairs() iteration order isn't guaranteed and this table rarely
-- changes. Precedent: CaptureTargets.OrderedNames / CameraStats.GetOrderedIds.
local orderedTypeNames = {}
for typeName in pairs(PickupTypes.Types) do
	table.insert(orderedTypeNames, typeName)
end
table.sort(orderedTypeNames)

function PickupTypes.Get(typeName: string?)
	if not typeName then
		return nil
	end
	return PickupTypes.Types[typeName]
end

function PickupTypes.OrderedNames(): { string }
	return table.clone(orderedTypeNames)
end

-- The PickupType string on this exact instance, but ONLY if it names a
-- registered row -- an authored typo or a not-yet-implemented kind returns
-- nil here rather than a string PickupService would have to re-validate.
function PickupTypes.TypeOf(instance: Instance): string?
	local typeName = instance:GetAttribute(PickupTypes.TypeAttribute)
	if typeof(typeName) ~= "string" then
		return nil
	end
	if not PickupTypes.Types[typeName] then
		return nil
	end
	return typeName
end

-- Walks from hitInstance up through its ancestors (stopping at workspace),
-- returning the first Instance carrying the marker attribute, or nil. Mirrors
-- CaptureTargets.Resolve -- maps e.g. prompt.Parent back to the pickup root.
function PickupTypes.Resolve(hitInstance: Instance?): Instance?
	local current = hitInstance
	while current and current ~= workspace do
		if current:GetAttribute(PickupTypes.MarkerAttribute) == true then
			return current
		end
		current = current.Parent
	end
	return nil
end

return PickupTypes
