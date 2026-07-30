--[[
	InstallVerifyScript -- paste into Studio's command bar (Edit mode, Game
	place) to create a TEMPORARY real Script that verifies audit checklist
	items 5 and 6.

	Why a real Script instead of the command bar: the command bar runs with
	plugin identity and therefore an ISOLATED require() cache (MAINHANDOFF
	G3). A command-bar `require(RewardService)` returns a fresh copy whose
	contextProviders list is empty -- ObjectiveService registered its provider
	into the copy loaded by the real Bootstrap Script, so the objective rule
	`objectiveRegistered == true` can never pass there. Same for RewardStore:
	the isolated copy has no loaded session, so IsReady() is false forever.
	Only a real Script shares the cache that Bootstrap/PlayerCurrency
	populated.

	AFTER READING THE RESULTS, DELETE the created Script:
		game.ServerScriptService:FindFirstChild("Phase75Verify"):Destroy()

	Item 6 additionally requires Game Settings -> Security -> "Enable Studio
	Access to API Services" to be ON, or RewardStore.Load can never resolve
	to Ready and the save step is correctly refused.
]]

local SSS = game:GetService("ServerScriptService")

local existing = SSS:FindFirstChild("Phase75Verify")
if existing then
	existing:Destroy()
end

local s = Instance.new("Script")
s.Name = "Phase75Verify"
s.RunContext = Enum.RunContext.Legacy
s.Source = [====[
-- TEMPORARY Phase 7.5 verification Script. Delete after reading output.
-- Runs in the REAL require cache, unlike the command bar (MAINHANDOFF G3).

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
if not ServerRole.Is("GameServer") then
	return
end

-- Once per server. Pasting the installer again while Play is running creates a
-- second copy of this Script in the live server, and MatchManager is a
-- singleton whose Finished state is terminal by design -- a second run can
-- never succeed, it just reports confusing stale-state failures.
if _G.__Phase75VerifyRan then
	print("Phase75Verify: already ran in this server -- skipping. Stop Play and start it again for a clean run.")
	return
end
_G.__Phase75VerifyRan = true

local results = {}
local function report(name, ok, detail)
	table.insert(results, ("[%s] %s%s"):format(ok and "PASS" or "FAIL", name, detail and (" -- " .. detail) or ""))
end

-- Wait for a player to actually be present and set up.
local player = Players:GetPlayers()[1]
local waitedForPlayer = 0
while not player and waitedForPlayer < 30 do
	task.wait(0.5)
	waitedForPlayer += 0.5
	player = Players:GetPlayers()[1]
end
if not player then
	print("Phase75Verify ABORT: no player joined within 30s")
	return
end

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
local ObjectiveService = require(ServerScriptService.GameService.Objective.ObjectiveService)
local ObjectiveRegistry = require(ServerScriptService.GameService.Objective.ObjectiveRegistry)

-- Hard precondition: a match must not already be underway/over. Aborting with
-- a clear message beats reporting six stale-state failures.
if not MatchManager.Is("Loading") then
	print(("Phase75Verify ABORT: MatchManager is at '%s', expected 'Loading'. This server already ran a match -- stop Play and start it again."):format(MatchManager.Get()))
	return
end

-- GameBoot bails on a non-reserved Studio server, so start these by hand --
-- all Start() functions are idempotent, so this is safe either way.
PlayerStateService.Start()
MatchParticipants.Start()
MatchManager.Start()
MatchEndCondition.Start()
MatchResultBuilder.Start()
MatchReplicator.Start()
MatchCleanup.Start()
RewardCleanupHook.Start()

-- PlayerCurrency.legacy already called SetupPlayer for this player; just wait
-- for its async RewardStore.Load to resolve. Do NOT call SetupPlayer again --
-- a second concurrent Load can reset the session back to "Loading".
local storeWaited = 0
while not RewardStore.IsReady(player) and storeWaited < 15 do
	task.wait(0.25)
	storeWaited += 0.25
end
local storeReady = RewardStore.IsReady(player)
if storeReady then
	task.wait(0.5) -- let the loaded baseline finish applying to leaderstats
end

local objectiveTarget = Workspace:FindFirstChild("Phase7_5ObjectiveTarget")
if not objectiveTarget then
	print("Phase75Verify ABORT: Phase7_5ObjectiveTarget missing from Workspace")
	return
end

local registryWaited = 0
while not ObjectiveRegistry.IsRegistered(objectiveTarget) and registryWaited < 5 do
	task.wait(0.2)
	registryWaited += 0.2
end
report("5-pre. ObjectiveRegistry registered the target",
	ObjectiveRegistry.IsRegistered(objectiveTarget), "waited=" .. registryWaited .. "s")

MatchParticipants.Seed({ player.UserId })
MatchManager.RequestTransition("WaitingForPlayers", "Phase75Verify")
MatchManager.RequestTransition("Countdown", "Phase75Verify")
MatchManager.RequestTransition("Playing", "Phase75Verify")

-- ---- item 5: objective reward path ----
-- Phase7_5ObjectiveTarget has no ObjectiveType attribute -> defaults to
-- "Standard" -> Ownership = "Player". Player-owned state lives in a Lua table
-- inside ObjectiveService, NOT the ObjectiveState attribute (that attribute is
-- only written for Shared ownership) -- so assert via GetState, not the
-- attribute. The audit's checklist text was wrong on this point.
local stateBefore = ObjectiveService.GetState(player, objectiveTarget)
local xpBeforeObjective = RewardLedger.Get(player, "XP") or 0

local objectiveResult = RewardService.AwardFromCapture(player, {
	player = player, subject = objectiveTarget, shotQuality = "Strong",
	distanceStuds = 30, cameraId = "Camera1", -- 30 studs = 10m, inside the 15m rule
})

-- RewardService.Awarded is a Signal (BindableEvent) and Fire is DEFERRED, so
-- ObjectiveService's subscriber -- the only thing that calls
-- ObjectiveService.Complete -- has NOT run yet when AwardFromCapture returns.
-- Reading state synchronously here sees the pre-completion value. Same gotcha
-- MAINHANDOFF records from Phase 3.
task.wait()

local stateAfter = ObjectiveService.GetState(player, objectiveTarget)
local xpAfterObjective = RewardLedger.Get(player, "XP") or 0

report("5a. Objective capture awarded + marked Completed",
	objectiveResult.resultCode == "Awarded" and stateBefore == "Available" and stateAfter == "Completed"
		and xpAfterObjective > xpBeforeObjective,
	("resultCode=%s stateBefore=%s stateAfter=%s xp %d->%d"):format(
		tostring(objectiveResult.resultCode), tostring(stateBefore), tostring(stateAfter),
		xpBeforeObjective, xpAfterObjective))

local xpBeforeRepeat = RewardLedger.Get(player, "XP") or 0
local objectiveRepeat = RewardService.AwardFromCapture(player, {
	player = player, subject = objectiveTarget, shotQuality = "Strong",
	distanceStuds = 30, cameraId = "Camera1",
})
task.wait()
local xpAfterRepeat = RewardLedger.Get(player, "XP") or 0
report("5b. Re-shooting a completed objective is refused",
	objectiveRepeat.resultCode == "AlreadyCompleted" and xpAfterRepeat == xpBeforeRepeat,
	("resultCode=%s xp %d->%d"):format(tostring(objectiveRepeat.resultCode), xpBeforeRepeat, xpAfterRepeat))

-- ---- item 6: Cleanup save step ----
local xpAtEnd = RewardLedger.Get(player, "XP") or 0

PlayerStateService.Set(player, "Dead", "Phase75Verify")
task.wait(0.3)

local cleanupWaited = 0
while not (MatchManager.Is("Cleanup") or MatchManager.Is("Finished")) and cleanupWaited < 20 do
	task.wait(0.5)
	cleanupWaited += 0.5
end
report("6-pre. Reached Cleanup/Finished", MatchManager.Is("Cleanup") or MatchManager.Is("Finished"),
	"state=" .. MatchManager.Get())

task.wait(1) -- let the save step's own thread finish

if storeReady then
	-- Read back WHILE THE PLAYER IS STILL CONNECTED: TeardownPlayer's
	-- PlayerRemoving save would otherwise mask whether the Cleanup save step
	-- actually ran.
	local ok, stored = pcall(function()
		return RewardStore.Backend:GetAsync("Player_" .. player.UserId)
	end)
	local storedXP = ok and stored and stored.XP
	report("6. Cleanup save step persisted XP (live read-back)",
		ok and storedXP == xpAtEnd,
		("ok=%s storedXP=%s expected=%d"):format(tostring(ok), tostring(storedXP), xpAtEnd))
else
	report("6. Cleanup save step persisted XP", false,
		"BLOCKED -- RewardStore session never reached Ready after 15s. Enable Game Settings -> Security -> Studio Access to API Services (G7).")
end

print("=== Phase 7.5 verification (real Script, items 5 & 6) ===")
for _, line in ipairs(results) do
	print(line)
end
print("=== Delete ServerScriptService.Phase75Verify when done ===")
]====]
s.Parent = SSS

print("Created ServerScriptService.Phase75Verify (temporary).")
print("1. Enable Game Settings -> Security -> Studio Access to API Services (for item 6)")
print("2. Press Play -- results print automatically after ~15-25s")
print("3. Then delete it: game.ServerScriptService:FindFirstChild('Phase75Verify'):Destroy()")
