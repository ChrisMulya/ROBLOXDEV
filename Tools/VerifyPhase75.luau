--[[
	VerifyPhase75 -- paste into Studio's command bar, SERVER datamodel, while
	in Play mode on the Game place. Covers audit checklist items 2, 3, 5, 6,
	7, 8 in one call (G3-safe: all evidence read within this single
	execution). Requires Test -> API Services enabled for item 6.

	Assumes Tools/InstallGameMirror.luau and the Bootstrap fix have already
	run, and Phase7_5MonsterTarget / Phase7_5ObjectiveTarget exist in
	Workspace (paste the spawn/target placement script first if not).
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local results = {}
local function report(name, ok, detail)
	table.insert(results, ("[%s] %s%s"):format(ok and "PASS" or "FAIL", name, detail and (" -- " .. detail) or ""))
end

local player = Players:GetPlayers()[1]
if not player then
	print("ABORT: no player in this server. Join with Test -> Players: 1+ first.")
	return
end

-- ---- manual boot (Studio Play always reports a non-reserved server) ----
local PlayerStateService = require(ServerScriptService.GameService.PlayerState.PlayerStateService)
local MatchParticipants = require(ServerScriptService.GameService.Match.MatchParticipants)
local MatchManager = require(ServerScriptService.GameService.Match.MatchManager)
local MatchEndCondition = require(ServerScriptService.GameService.Match.MatchEndCondition)
local MatchResultBuilder = require(ServerScriptService.GameService.Match.MatchResultBuilder)
local MatchReplicator = require(ServerScriptService.GameService.Match.MatchReplicator)
local MatchCleanup = require(ServerScriptService.GameService.Match.MatchCleanup)
local RewardCleanupHook = require(ServerScriptService.GameService.Reward.RewardCleanupHook)
local RewardService = require(ServerScriptService.GameService.Reward.RewardService)
local RewardLedger = require(ServerScriptService.GameService.Reward.RewardLedger)
local RewardStore = require(ServerScriptService.GameService.Reward.RewardStore)
local MonsterService = require(ServerScriptService.GameService.Monster.MonsterService)

-- Diagnostic only: registered AFTER whatever real providers already
-- registered at server boot (registration order == call order), so it can
-- observe exactly what they contributed to the context so far.
RewardService.RegisterContextProvider(function(_player, subject, context)
	print("DEBUG provider-chain -- subject:", subject:GetFullName(),
		"| context.objectiveRegistered:", context.objectiveRegistered,
		"| context.objectiveState:", context.objectiveState)
	return nil
end)

PlayerStateService.Start()
MatchParticipants.Start()
MatchManager.Start()
MatchEndCondition.Start()
MatchResultBuilder.Start()
MatchReplicator.Start()
MatchCleanup.Start()
RewardCleanupHook.Start()

-- NOTE: deliberately NOT calling RewardLedger.SetupPlayer(player) here.
-- PlayerCurrency.legacy already calls it once via its own PlayerAdded
-- handler now that it's mirrored and Bootstrap requires it correctly.
-- Calling it a second time here spawns a SECOND concurrent
-- RewardStore.Load(), which can reset the session back to "Loading" right
-- as MatchCleanup's save step runs -- Save() then correctly refuses
-- (RewardStore's own Ready-gate), which looked like a lost save but was
-- actually this script racing itself.

local waited = 0
while not RewardStore.IsReady(player) and waited < 10 do
	task.wait(0.2)
	waited += 0.2
end
local storeReady = RewardStore.IsReady(player)
if not storeReady then
	print("NOTE: RewardStore session not Ready after 10s -- likely API Services is OFF (G7). Item 6 will report accordingly, not error.")
else
	-- RewardLedger flips a session to Ready slightly before it finishes
	-- adding the loaded baseline to the XP leaderstat (that add happens on
	-- a separate thread) -- this buffer reduces, but doesn't eliminate, the
	-- chance of reading xpBefore mid-application. Pre-existing timing gap,
	-- not something this script fixes.
	task.wait(0.5)
end

local monsterTarget = Workspace:FindFirstChild("Phase7_5MonsterTarget")
local objectiveTarget = Workspace:FindFirstChild("Phase7_5ObjectiveTarget")
if not monsterTarget or not objectiveTarget then
	print("ABORT: Phase7_5MonsterTarget/Phase7_5ObjectiveTarget missing from Workspace -- run the placement script first.")
	return
end

-- ObjectiveRegistry.bootstrap() does one synchronous workspace:GetDescendants()
-- scan at require-time and only catches later additions via DescendantAdded --
-- a pre-existing timing gap (not touched this phase, see MAINHANDOFF "Found,
-- not fixed") that can leave a part registered a few frames late relative to
-- server start. Poll rather than assume it's already registered, so this
-- test is robust instead of flaky against that gap.
local ObjectiveRegistry = require(ServerScriptService.GameService.Objective.ObjectiveRegistry)
local registryWaited = 0
while not ObjectiveRegistry.IsRegistered(objectiveTarget) and registryWaited < 5 do
	task.wait(0.2)
	registryWaited += 0.2
end
if not ObjectiveRegistry.IsRegistered(objectiveTarget) then
	print("NOTE: Phase7_5ObjectiveTarget still not registered after 5s -- item 5 will likely fail; this is the pre-existing ObjectiveRegistry timing gap, not a Phase 7.5 defect.")
end

-- ---- drive to Playing ----
MatchParticipants.Seed({ player.UserId })
MatchManager.RequestTransition("WaitingForPlayers", "Test")
MatchManager.RequestTransition("Countdown", "Test")
MatchManager.RequestTransition("Playing", "Test")
report("Drive to Playing", MatchManager.Is("Playing"), "state=" .. MatchManager.Get())

local xpBefore = RewardLedger.Get(player, "XP") or 0

-- ---- item 2 (part 1): scoring gate allows a capture while Playing ----
local monsterResult = RewardService.AwardFromCapture(player, {
	player = player, subject = monsterTarget, shotQuality = "Strong",
	distanceStuds = 30, cameraId = "Camera1",
})
local xpAfterMonster = RewardLedger.Get(player, "XP") or 0
report("2. Capture awarded during Playing", monsterResult.resultCode == "Awarded" and xpAfterMonster > xpBefore,
	("resultCode=%s xpBefore=%d xpAfter=%d"):format(tostring(monsterResult.resultCode), xpBefore, xpAfterMonster))

-- ---- item 5: objective reward path ----
print("DEBUG right before objective capture -- IsRegistered:", ObjectiveRegistry.IsRegistered(objectiveTarget),
	"| ObjectiveState attr:", objectiveTarget:GetAttribute("ObjectiveState"),
	"| distanceStuds=30 -> meters:", 30 / 3)
local objectiveResult = RewardService.AwardFromCapture(player, {
	player = player, subject = objectiveTarget, shotQuality = "Strong",
	distanceStuds = 30, cameraId = "Camera1",
})
local objectiveState = objectiveTarget:GetAttribute("ObjectiveState")
report("5a. Objective capture awarded + marked Completed",
	objectiveResult.resultCode == "Awarded" and objectiveState == "Completed",
	("resultCode=%s state=%s"):format(tostring(objectiveResult.resultCode), tostring(objectiveState)))

local objectiveRepeat = RewardService.AwardFromCapture(player, {
	player = player, subject = objectiveTarget, shotQuality = "Strong",
	distanceStuds = 30, cameraId = "Camera1",
})
report("5b. Re-shooting completed objective is refused",
	objectiveRepeat.resultCode == "AlreadyCompleted", "resultCode=" .. tostring(objectiveRepeat.resultCode))

-- ---- item 8 (part 1): monster spawn allowed during Playing ----
local spawnedDuringPlaying = MonsterService.Spawn("GreyCube", CFrame.new(0, 3, 20))
report("8a. MonsterService.Spawn succeeds during Playing", spawnedDuringPlaying ~= nil)

local cframeBeforeFreeze
if spawnedDuringPlaying then
	cframeBeforeFreeze = spawnedDuringPlaying.PrimaryPart.CFrame
end

-- ---- trigger Ending: kill the sole participant ----
local xpBeforeEnding = RewardLedger.Get(player, "XP") or 0
PlayerStateService.Set(player, "Dead", "Phase7_5Test")
task.wait(0.3) -- deferred Signal -- let MatchEndCondition react
report("Auto-transition Playing -> Ending on last death", MatchManager.Is("Ending"), "state=" .. MatchManager.Get())

-- ---- item 2 (part 2) + item 3: gates refuse once not Playing ----
local monsterResultEnding = RewardService.AwardFromCapture(player, {
	player = player, subject = monsterTarget, shotQuality = "Strong",
	distanceStuds = 30, cameraId = "Camera1",
})
local xpAfterEnding = RewardLedger.Get(player, "XP") or 0
report("2. Capture refused during Ending (MatchNotScoring)",
	monsterResultEnding.resultCode == "MatchNotScoring" and xpAfterEnding == xpBeforeEnding,
	("resultCode=%s xpBefore=%d xpAfter=%d"):format(tostring(monsterResultEnding.resultCode), xpBeforeEnding, xpAfterEnding))

local grantDuringEnding = RewardService.Grant(player, { XP = 999 }, {})
local xpAfterGrantAttempt = RewardLedger.Get(player, "XP") or 0
report("3. Grant refused during Ending", grantDuringEnding == false and xpAfterGrantAttempt == xpAfterEnding,
	("grantReturned=%s xp=%d"):format(tostring(grantDuringEnding), xpAfterGrantAttempt))

-- ---- item 8 (part 2): spawn refused + existing monster frozen during Ending ----
local spawnedDuringEnding = MonsterService.Spawn("GreyCube", CFrame.new(0, 3, -20))
report("8b. MonsterService.Spawn refused during Ending", spawnedDuringEnding == nil)

if spawnedDuringPlaying then
	task.wait(0.5)
	local cframeAfterWait = spawnedDuringPlaying.PrimaryPart.CFrame
	report("8c. Existing monster frozen (CFrame unchanged) during Ending",
		cframeAfterWait == cframeBeforeFreeze)
	spawnedDuringPlaying:Destroy()
end

-- ---- item 7 / item 6: let the Ending hold elapse, confirm Cleanup + save ----
local waitedForCleanup = 0
while not (MatchManager.Is("Cleanup") or MatchManager.Is("Finished")) and waitedForCleanup < 15 do
	task.wait(0.5)
	waitedForCleanup += 0.5
end
report("7. Unattended Ending -> Cleanup/Finished", MatchManager.Is("Cleanup") or MatchManager.Is("Finished"),
	"state=" .. MatchManager.Get() .. " waited=" .. waitedForCleanup .. "s")

if storeReady then
	-- Read the DataStore back directly WHILE THE PLAYER IS STILL CONNECTED --
	-- TeardownPlayer's own PlayerRemoving save would otherwise mask whether
	-- the Cleanup-time save step actually ran (see audit section 5, item 6).
	local key = "Player_" .. player.UserId
	local ok, stored = pcall(function()
		return RewardStore.Backend:GetAsync(key)
	end)
	local storedXP = ok and stored and stored.XP
	report("6. Cleanup save step persisted current XP (read back live)",
		ok and storedXP == xpAfterMonster,
		("ok=%s storedXP=%s expectedXP=%d"):format(tostring(ok), tostring(storedXP), xpAfterMonster))
else
	report("6. Cleanup save step persisted current XP", false, "SKIPPED -- RewardStore session never reached Ready (API Services likely off)")
end

print("=== Phase 7.5 verification results ===")
for _, line in ipairs(results) do
	print(line)
end
