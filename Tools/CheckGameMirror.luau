--[[
	CheckGameMirror -- paste into Roblox Studio's command bar (Edit mode,
	on the Game place) to check whether the Phase 7.5 migration cut line
	(plans/before-phase-8-perform-scalable-mochi.md section 3) is present.

	This file is NOT synced into either place -- "Tools/" is not a
	Roblox-service-named folder, so the disk-sync pipeline ignores it
	(see MAINHANDOFF.md: "folder names at repo root map 1:1 to Roblox
	services"). It exists purely as a checked-in, version-controlled copy
	of the drift-check script referenced by the Phase 7.5 audit.

	What this checks: each manifest path exists as the right instance type
	(ModuleScript, except the two disk `.legacy.luau` files below, which are
	Script -- RunContext Legacy -- per this repo's own suffix convention).
	What this does NOT check: whether that instance's Source text matches
	the corresponding disk file. Comparing Source to disk content requires
	either a real Studio plugin (filesystem access) or a Rojo-style sync
	tool -- this repo intentionally has neither (see the audit's sync-
	strategy recommendation). Treat a clean run of this script as "nothing
	is missing," not as "nothing has drifted."

	Update this list whenever the Phase 7.5 migration cut line changes.
]]

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

-- root prefix "RS/" = ReplicatedStorage, "S/" = ServerScriptService.
-- Entries are ModuleScript unless marked "|Script" (disk .legacy.luau files).
local MANIFEST = {
	-- Tier 1: Reward closure (required for Phase 7.5 and Phase 8)
	"RS/Modules/Shared/Units",
	"RS/Modules/Reward/CaptureTargets",
	"RS/Modules/Reward/CaptureRules",
	"RS/Modules/Reward/RewardCalculator",
	"RS/Modules/Reward/RewardTypes",
	"RS/Modules/Reward/RewardModifiers",
	"RS/Modules/Reward/ShotResultCodes",
	"RS/Modules/Reward/Curves/CurveFactory",
	"RS/Modules/Reward/Curves/DistanceMultiplierCurve",
	"RS/Modules/Reward/Curves/DistanceBandLabels",
	"RS/Modules/Reward/Curves/XPRewardCurve",
	"RS/Modules/Reward/Curves/ScoreRewardCurve",
	"RS/Modules/Camera/CameraStats",
	"RS/Modules/Camera/CameraStability",
	"S/GameService/Reward/RewardStore",
	"S/GameService/Reward/RewardLedger",
	"S/GameService/Reward/RewardService",
	"S/GameService/Reward/CaptureGuard",
	"S/GameService/Reward/RewardCleanupHook",
	"S/GameService/Camera/PhotoCapture",
	"S/GameService/Camera/CameraShotHandler|Script",
	"S/GameService/Player/PlayerCurrency|Script",
	"S/GameService/Flash/FlashEvents",

	-- Tier 2: objective reward path
	"RS/Modules/Objective/ObjectiveStates",
	"RS/Modules/Objective/ObjectiveTypes",
	"S/GameService/Objective/ObjectiveRegistry",
	"S/GameService/Objective/ObjectiveService",
	"S/GameService/Objective/ObjectiveReplicator",

	-- Tier 3: monster gates
	"RS/Modules/Monster/MonsterStats",
	"S/GameService/Monster/MonsterService",
	"S/GameService/Monster/MonsterAgent",
	"S/GameService/Monster/MonsterDamage",
	"S/GameService/Monster/MonsterSensing",
	"S/GameService/Monster/MonsterMovement",
	"S/GameService/Monster/States/Chase",
	"S/GameService/Monster/Behaviors/GreyCube",
}

local function resolve(path: string): Instance?
	local root, rest = path:match("^(%a+)/(.+)$")
	local cur = (root == "RS") and RS or SSS
	for seg in rest:gmatch("[^/]+") do
		cur = cur and cur:FindFirstChild(seg)
	end
	return cur
end

local missing, wrongClass = {}, {}
for _, entry in ipairs(MANIFEST) do
	local path, expectedClass = entry:match("^(.-)|(%a+)$")
	path = path or entry
	expectedClass = expectedClass or "ModuleScript"

	local inst = resolve(path)
	if not inst then
		table.insert(missing, path)
	elseif not inst:IsA(expectedClass) then
		table.insert(wrongClass, path .. " (is " .. inst.ClassName .. ", expected " .. expectedClass .. ")")
	end
end

print(("PlaceId %d | checked %d | missing %d | wrong class %d"):format(
	game.PlaceId, #MANIFEST, #missing, #wrongClass))

if #missing > 0 then
	print("MISSING:\n" .. table.concat(missing, "\n"))
end
if #wrongClass > 0 then
	print("WRONG CLASS:\n" .. table.concat(wrongClass, "\n"))
end
if #missing == 0 and #wrongClass == 0 then
	print("Manifest complete. (Source-content drift is NOT checked -- see header.)")
end
