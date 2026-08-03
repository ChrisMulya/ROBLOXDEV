-- Per-objective-type configuration, keyed by the ObjectiveType attribute
-- (defaults to "Standard" so plain IsObjective=true instances need no extra
-- authoring). Same registry shape as Reward/CaptureTargets -- adding Rare,
-- SecretCollectible, Mission, Daily, Seasonal, Cooperative, etc. is a new row
-- here, never a code change.

local ObjectiveTypes = {}

-- Ownership: "Player" (each player has independent state; everyone can
--   photograph the same one) or "Shared" (server-global; first completion
--   locks it for everyone).
-- ResetPolicy: "Never" | "OnRunEnd" | "Daily" | "OnEvent". Only "Never" and
--   "OnRunEnd" are wired (see ObjectiveService.Reset / EndGame); "Daily" and
--   "OnEvent" are declared for future use and require ObjectiveStore.
ObjectiveTypes.Types = {
	Standard = {
		Ownership = "Player",
		InitialState = "Available",
		ResetPolicy = "OnRunEnd",
		VisualStyle = "StandardGlow",
	},
	Rare = {
		Ownership = "Player",
		InitialState = "Available",
		ResetPolicy = "Never",
		VisualStyle = "RareGlow",
	},
	Cooperative = {
		Ownership = "Shared",
		InitialState = "Available",
		ResetPolicy = "OnRunEnd",
		VisualStyle = "CoopGlow",
	},
}

ObjectiveTypes.Default = ObjectiveTypes.Types.Standard
local DEFAULT_TYPE_NAME = "Standard"

function ObjectiveTypes.Get(typeName: string)
	return ObjectiveTypes.Types[typeName] or ObjectiveTypes.Default
end

-- Reads the ObjectiveType attribute off an instance, defaulting to Standard.
-- Does not check IsObjective -- that's ObjectiveRegistry's job.
function ObjectiveTypes.TypeOf(instance: Instance): string
	local typeName = instance:GetAttribute("ObjectiveType")
	if typeName and ObjectiveTypes.Types[typeName] then
		return typeName
	end
	return DEFAULT_TYPE_NAME
end

return ObjectiveTypes
