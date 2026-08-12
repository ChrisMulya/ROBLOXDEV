-- The registry of spawn-selectable categories -- what SpawnSelection can
-- thin out at match start. Adding Gadgets/Keys/Consumables is a new row
-- here plus one MatchDifficulty.SpawnFraction entry per difficulty; the
-- selection algorithm in SpawnSelection never names a category itself.
--
-- Source selects which EXISTING registry answers "what instances are in
-- this category" -- this module defines no new marker attributes and owns
-- no identity. It only names existing PickupTypes/CaptureTargets keys, so
-- the project's attribute-ownership invariant (CaptureTargets owns
-- IsMonster/IsObjective, PickupTypes owns IsPickup/PickupType) holds.
--
-- Monster is deliberately NOT a category here: monsters are placed by
-- EncounterDirector from IsMonsterSpawn markers, not hand-placed, and are
-- out of scope for this feature.

local SpawnCategories = {}

-- Source = "Pickup": discovered via PickupRegistry.All(), filtered by
--   PickupTypes.TypeOf(instance) == PickupType.
-- Source = "CaptureTarget": discovered via CaptureRegistry.All(), filtered by
--   instance:GetAttribute(CaptureTargets.AttributeFor(TargetType)).
SpawnCategories.All = {
	Cash = {
		DisplayName = "Cash",
		Source = "Pickup",
		PickupType = "Cash",
	},
	Document = {
		DisplayName = "Document",
		Source = "Pickup",
		PickupType = "Document",
	},
	Objective = {
		DisplayName = "Objective",
		Source = "CaptureTarget",
		TargetType = "Objective",
	},
}

-- Ordered by DisplayName, computed once at module load. Iterating this
-- (rather than pairs(), whose order isn't guaranteed) is what makes
-- multi-category-marker resolution in SpawnSelection deterministic.
local orderedCategoryNames = {}
for categoryId in pairs(SpawnCategories.All) do
	table.insert(orderedCategoryNames, categoryId)
end
table.sort(orderedCategoryNames)

function SpawnCategories.OrderedNames(): { string }
	return table.clone(orderedCategoryNames)
end

function SpawnCategories.Get(categoryId: string?)
	if not categoryId then
		return nil
	end
	return SpawnCategories.All[categoryId]
end

-- Loud boot failure on a malformed row, same reasoning as
-- MatchDifficulty.Validate. Called from GameBoot alongside it.
function SpawnCategories.Validate()
	for categoryId, def in pairs(SpawnCategories.All) do
		assert(
			typeof(def.DisplayName) == "string",
			("SpawnCategories.Validate: '%s' is missing DisplayName"):format(categoryId)
		)
		if def.Source == "Pickup" then
			assert(
				typeof(def.PickupType) == "string",
				("SpawnCategories.Validate: '%s' has Source Pickup but no PickupType"):format(categoryId)
			)
		elseif def.Source == "CaptureTarget" then
			assert(
				typeof(def.TargetType) == "string",
				("SpawnCategories.Validate: '%s' has Source CaptureTarget but no TargetType"):format(categoryId)
			)
		else
			error(("SpawnCategories.Validate: '%s' has unknown Source '%s'"):format(categoryId, tostring(def.Source)))
		end
	end
end

return SpawnCategories
