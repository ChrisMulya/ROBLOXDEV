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

	Since roadmap 8.1 (debt #14), this ALSO checks source drift for any entry
	InstallGameMirror stamped with a MirrorHash attribute: the same FNV-1a
	hash is recomputed here from the instance's live Source and compared.
	A mismatch means the instance was hand-edited (or the installer's
	embedded copy is stale) after the last install. An entry with no
	MirrorHash attribute at all was placed before this stamping existed (an
	older installer run) -- reported separately as "unstamped", not treated
	as drift, since there's nothing to compare against.

	Update this list whenever the Phase 7.5/Phase 8 migration cut line changes.
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

	-- Tier 4: Match lifecycle + result codes (added post-Phase-8, roadmap 8.1)
	"RS/Modules/Shared/MatchResultCodes",
	"RS/Modules/Shared/MatchLaunchResultCodes",
	"RS/Modules/UI/MatchReceipt",
	"RS/Modules/UI/MatchReceiptController",
	"S/GameService/Match/MatchManager",
	"S/GameService/Match/MatchParticipants",
	"S/GameService/Match/MatchEndCondition",
	"S/GameService/Match/MatchResultBuilder",
	"S/GameService/Match/MatchReplicator",
	"S/GameService/Match/MatchCleanup",
	"S/GameService/Match/MatchArrival",
	"S/GameService/Match/MatchClock",
	"S/GameService/Match/ReturnToLobbyService",
	"S/GameService/Reward/RewardResultHook",
	"S/GameService/Lobby/MatchLauncher",
	"S/GameService/Lobby/ArrivalService",

	-- Tier 5: Participant onboarding / kit lifecycle (Phase 8.5)
	"RS/Modules/Shared/MatchStates",
	"RS/Modules/Shared/MatchConfig",
	"RS/Modules/PlayerStats",
	"RS/Modules/Loadout/LoadoutService",
	"S/GameService/CameraShelf/CameraInventory",
	"S/GameService/Player/StartGame",
	"S/GameService/Player/EndGame",
	"S/GameService/Player/KitLifecycleHook",
	"S/GameService/Match/MatchSpawner",
}

-- Identical to InstallGameMirror.luau's hashSource -- kept as a duplicated
-- copy rather than a shared module since these are two independent
-- paste-scripts, never co-resident as Roblox instances.
local function hashSource(source: string): string
	local hash = 2166136261
	for i = 1, #source do
		hash = bit32.bxor(hash, string.byte(source, i))
		hash = (hash * 16777619) % 4294967296
	end
	return string.format("%08x", hash)
end

local function resolve(path: string): Instance?
	local root, rest = path:match("^(%a+)/(.+)$")
	local cur = (root == "RS") and RS or SSS
	for seg in rest:gmatch("[^/]+") do
		cur = cur and cur:FindFirstChild(seg)
	end
	return cur
end

local missing, wrongClass, drifted, unstamped = {}, {}, {}, {}
for _, entry in ipairs(MANIFEST) do
	local path, expectedClass = entry:match("^(.-)|(%a+)$")
	path = path or entry
	expectedClass = expectedClass or "ModuleScript"

	local inst = resolve(path)
	if not inst then
		table.insert(missing, path)
	elseif not inst:IsA(expectedClass) then
		table.insert(wrongClass, path .. " (is " .. inst.ClassName .. ", expected " .. expectedClass .. ")")
	elseif inst:IsA("LuaSourceContainer") then
		local stampedHash = inst:GetAttribute("MirrorHash")
		if stampedHash == nil then
			table.insert(unstamped, path)
		elseif hashSource(inst.Source) ~= stampedHash then
			table.insert(drifted, path)
		end
	end
end

print(("PlaceId %d | checked %d | missing %d | wrong class %d | drifted %d | unstamped %d"):format(
	game.PlaceId, #MANIFEST, #missing, #wrongClass, #drifted, #unstamped))

if #missing > 0 then
	print("MISSING:\n" .. table.concat(missing, "\n"))
end
if #wrongClass > 0 then
	print("WRONG CLASS:\n" .. table.concat(wrongClass, "\n"))
end
if #drifted > 0 then
	print("DRIFTED (hand-edited since last install, or installer copy is stale):\n" .. table.concat(drifted, "\n"))
end
if #unstamped > 0 then
	print("UNSTAMPED (placed before MirrorHash existed -- re-run InstallGameMirror to get drift coverage):\n" .. table.concat(unstamped, "\n"))
end
if #missing == 0 and #wrongClass == 0 and #drifted == 0 and #unstamped == 0 then
	print("Manifest complete and drift-free.")
end
