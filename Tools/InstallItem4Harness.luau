--[[
	InstallItem4Harness -- paste into Studio's command bar, SERVER datamodel,
	Edit mode, Game place. Creates a TEMPORARY real Script that verifies audit
	checklist item 4 (capture -> reward end-to-end, fired from a REAL client).

	Why this needs a real Script (same reason as InstallVerifyScript, G3):
	command-bar Server execute_luau has an isolated require() cache. Driving
	MatchManager to "Playing" from that isolated copy would be invisible to
	the real CameraShotHandler.legacy Script, which reads MatchManager/
	RewardService through the real Bootstrap-loaded cache -- the remote would
	fire, hit the real handler, and get refused as MatchNotScoring even though
	nothing is actually wrong.

	Why the CLIENT half does NOT need a real Script (unlike items 5/6): firing
	a RemoteEvent is an Instance-level action, not a same-process function
	call -- WeakCameraShot:FireServer(...) crosses the real client/server
	boundary and lands on the real OnServerEvent connection regardless of
	which require() cache the calling script's `Remotes` copy came from. A
	plain command-bar paste in the CLIENT datamodel is a legitimate "real
	client" fire for G5 purposes: it exercises no plugin-only capability, only
	the same FireServer(origin, direction) a real player's LocalScript sends.
	See Tools/FireItem4Shot.luau for that half.

	Sequence:
		1. Paste this file in the SERVER datamodel command bar (Edit mode).
		2. Press Play. Wait for the console line "Item4Harness: READY -- fire
		   the client shot now."
		3. Paste Tools/FireItem4Shot.luau in the CLIENT datamodel command bar
		   (while still in Play mode) and run it once.
		4. Watch the server console for the PASS/FAIL line (it polls for up to
		   15s after step 2's ready message).
		5. Delete the temporary Script when done:
			game.ServerScriptService:FindFirstChild("Phase75Item4"):Destroy()
]]

local SSS = game:GetService("ServerScriptService")

local existing = SSS:FindFirstChild("Phase75Item4")
if existing then
	existing:Destroy()
end

local s = Instance.new("Script")
s.Name = "Phase75Item4"
s.RunContext = Enum.RunContext.Legacy
s.Source = [====[
-- TEMPORARY Phase 7.5 item-4 verification Script. Delete after reading output.
-- Runs in the REAL require cache, unlike the command bar (MAINHANDOFF G3).

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
if not ServerRole.Is("GameServer") then
	return
end

-- Once per server, same reason as Phase75Verify: MatchManager is a singleton
-- and a second drive-to-Playing in an already-ended server produces
-- confusing stale-state noise instead of a clean result.
if _G.__Phase75Item4Ran then
	print("Phase75Item4: already ran in this server -- skipping. Stop Play and start it again for a clean run.")
	return
end
_G.__Phase75Item4Ran = true

local PlayerStateService = require(ServerScriptService.GameService.PlayerState.PlayerStateService)
local MatchParticipants = require(ServerScriptService.GameService.Match.MatchParticipants)
local MatchManager = require(ServerScriptService.GameService.Match.MatchManager)
local MatchEndCondition = require(ServerScriptService.GameService.Match.MatchEndCondition)
local MatchResultBuilder = require(ServerScriptService.GameService.Match.MatchResultBuilder)
local MatchReplicator = require(ServerScriptService.GameService.Match.MatchReplicator)
local MatchCleanup = require(ServerScriptService.GameService.Match.MatchCleanup)
local RewardCleanupHook = require(ServerScriptService.GameService.Reward.RewardCleanupHook)
local RewardLedger = require(ServerScriptService.GameService.Reward.RewardLedger)

local player = Players:GetPlayers()[1]
local waitedForPlayer = 0
while not player and waitedForPlayer < 30 do
	task.wait(0.5)
	waitedForPlayer += 0.5
	player = Players:GetPlayers()[1]
end
if not player then
	print("Phase75Item4 ABORT: no player joined within 30s")
	return
end

if not MatchManager.Is("Loading") then
	print(("Phase75Item4 ABORT: MatchManager is at '%s', expected 'Loading'. This server already ran a match -- stop Play and start it again."):format(MatchManager.Get()))
	return
end

-- GameBoot bails on a non-reserved Studio server -- start by hand, idempotent.
PlayerStateService.Start()
MatchParticipants.Start()
MatchManager.Start()
MatchEndCondition.Start()
MatchResultBuilder.Start()
MatchReplicator.Start()
MatchCleanup.Start()
RewardCleanupHook.Start()

if not player.Character then
	player:LoadCharacter()
end
local character = player.Character or player.CharacterAdded:Wait()
character:WaitForChild("Head", 10)
character:WaitForChild("HumanoidRootPart", 10)

-- Server-authoritative equip: CameraShotHandler reads the equipped tool's
-- attributes only, not how it got equipped, so parenting straight onto the
-- character (skipping Backpack/Humanoid:EquipTool) is a legitimate shortcut
-- here -- the thing under test is the remote pipeline, not the equip UX.
local existingTool = character:FindFirstChildOfClass("Tool")
if existingTool then
	existingTool:Destroy()
end
local tool = Instance.new("Tool")
tool.Name = "Phase75TestCamera"
tool.RequiresHandle = false
tool:SetAttribute("IsCameraTool", true)
tool:SetAttribute("CameraId", "Camera1")
tool.Parent = character

local monsterTarget = Workspace:FindFirstChild("Phase7_5MonsterTarget")
if not monsterTarget then
	print("Phase75Item4 ABORT: Phase7_5MonsterTarget missing from Workspace")
	return
end

MatchParticipants.Seed({ player.UserId })
MatchManager.RequestTransition("WaitingForPlayers", "Phase75Item4")
MatchManager.RequestTransition("Countdown", "Phase75Item4")
MatchManager.RequestTransition("Playing", "Phase75Item4")

local xpBefore = RewardLedger.Get(player, "XP") or 0
print(("Item4Harness: READY -- fire the client shot now. xpBefore=%d, MatchManager=%s"):format(xpBefore, MatchManager.Get()))

-- Poll leaderstats directly (Instance-backed, G3-safe) rather than requiring
-- anything stateful again -- this loop only needs to observe a value change.
local xpAfter = xpBefore
local waitedForShot = 0
while xpAfter == xpBefore and waitedForShot < 20 do
	task.wait(0.5)
	waitedForShot += 0.5
	xpAfter = RewardLedger.Get(player, "XP") or 0
end

local stillScoring = MatchManager.Is("Playing")
local ok = xpAfter > xpBefore and stillScoring
print(("[%s] 4. Capture -> reward end-to-end via real client -- xpBefore=%d xpAfter=%d waited=%.1fs match=%s"):format(
	ok and "PASS" or "FAIL", xpBefore, xpAfter, waitedForShot, MatchManager.Get()))
if not ok and waitedForShot >= 20 then
	print("Item4Harness: timed out waiting for an XP change -- did you paste and run Tools/FireItem4Shot.luau in the CLIENT datamodel?")
end

print("=== Delete ServerScriptService.Phase75Item4 when done ===")
]====]
s.Parent = SSS

print("Created ServerScriptService.Phase75Item4 (temporary).")
print("1. Wait for 'Item4Harness: READY -- fire the client shot now.'")
print("2. Then paste Tools/FireItem4Shot.luau in the CLIENT datamodel command bar and run it once.")
print("3. Then delete it: game.ServerScriptService:FindFirstChild('Phase75Item4'):Destroy()")
