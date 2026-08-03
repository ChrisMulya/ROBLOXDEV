-- DataStore wrapper for persistent reward types (currently XP only).
-- Phase 12: backed by ProfileStore (Vendor/ProfileStore.luau, loleris,
-- asset 109379033046155) instead of raw DataStoreService. Session locking
-- is now real -- ProfileStore.StartSessionAsync/EndSession/OnSessionEnd --
-- rather than the Phase 10 cheap-gate approximation (MarkHandedOff/
-- ClearHandoff, both deleted; see RewardLaunchHook and LaunchGate).
--
-- NEW STORE NAME ("RewardStore_v2"), not a reused "RewardStore_v1": every
-- existing player's XP is a flat record ({XP = number}) written by raw
-- DataStoreService calls. ProfileStore wraps everything in its own envelope
-- ({Data=..., MetaData=..., GlobalUpdates=...}) and its own OnOverwrite
-- signal is documented to fire when a key "was likely used to store data
-- that wasn't a ProfileStore profile" -- pointing ProfileStore at the old
-- name would very likely read every existing player's real progress as
-- corrupt. Load() below falls back to a read-only legacy GetAsync against
-- the OLD store, once, only on a profile's very first-ever session
-- (SessionLoadCount == 1) -- covers both a genuinely new player (legacy
-- read finds nothing, harmless) and a pre-Phase-12 player (their real XP
-- gets copied in before Reconcile's defaults would otherwise stick).
--
-- The central rule from before this phase still holds: A SESSION IS NOT
-- SAVABLE UNTIL A LOAD HAS DEFINITIVELY COMPLETED. Save() refuses unless
-- the session has an active ProfileStore session.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RewardTypes = require(ReplicatedStorage.Modules.Reward.RewardTypes)
local ProfileStoreLib = require(ServerScriptService.Vendor.ProfileStore)

-- Sized against Match/MatchCleanup.luau's own STEP_TIMEOUT_SECONDS = 10 (R-6):
-- RewardCleanupHook's save step wraps a full RewardStore.SaveAll call in that
-- 10s budget, so every individual confirmation wait here must leave margin
-- for the DataStore round trip itself, not consume the whole budget alone.
local SAVE_CONFIRM_TIMEOUT_SECONDS = 8

local RewardStore = {}

local function zeroedBaseline(): { [string]: number }
	local baseline = {}
	for _, typeName in ipairs(RewardTypes.Persistent()) do
		baseline[typeName] = 0
	end
	return baseline
end

RewardStore.Backend = ProfileStoreLib.New("RewardStore_v2", zeroedBaseline())

-- Read-only. Never written again -- ProfileStore owns "RewardStore_v2" from
-- here on. Only consulted once, for a profile's first-ever session.
local legacyBackend = DataStoreService:GetDataStore("RewardStore_v1")
local LEGACY_MAX_ATTEMPTS = 3
local LEGACY_RETRY_BASE_SECONDS = 0.5

-- [userId] = Profile -- the ProfileStore session object itself. No separate
-- state enum needed: Profile:IsActive() IS the ready-check, and
-- Profile.OnSessionEnd (below) keeps this table honest if the lock is ever
-- lost for a reason outside this module's own control.
local sessions: { [number]: any } = {}

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function attemptLegacyRead(fn)
	for tries = 1, LEGACY_MAX_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(("RewardStore: legacy read failed (attempt %d/%d) - %s"):format(tries, LEGACY_MAX_ATTEMPTS, tostring(result)))
		if tries < LEGACY_MAX_ATTEMPTS then
			task.wait(LEGACY_RETRY_BASE_SECONDS * 2 ^ (tries - 1))
		end
	end
	return false, nil
end

-- Fire-and-forget from PlayerCurrency.legacy's PlayerAdded handler, same
-- call site as before this phase. Returns (baseline, ok) unchanged in
-- shape -- RewardLedger.SetupPlayer's existing "add baseline into the
-- IntValues" logic needs no changes.
function RewardStore.Load(player: Player): ({ [string]: number }, boolean)
	local profile = RewardStore.Backend:StartSessionAsync(keyFor(player), {
		-- Stop waiting on a session-lock conflict (or any other retry loop)
		-- once the player isn't here to receive the result anymore.
		Cancel = function()
			return player.Parent == nil
		end,
	})

	if not profile then
		sessions[player.UserId] = nil
		warn(("RewardStore: could not start a session for %s -- will NOT be saved this visit"):format(player.Name))
		return zeroedBaseline(), false
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile() -- fills any RewardTypes.Persistent() key missing from Data with the template's 0, without touching a real stored value

	-- One-time legacy fallback -- see file header. SessionLoadCount == 1
	-- means this ProfileStore profile has never existed before now, which
	-- is true for both a brand-new player (legacy read finds nothing) and
	-- a pre-Phase-12 player (legacy read finds their real total).
	if profile.SessionLoadCount == 1 then
		local legacyOk, legacyData = attemptLegacyRead(function()
			return legacyBackend:GetAsync(keyFor(player))
		end)
		if legacyOk and legacyData then
			for _, typeName in ipairs(RewardTypes.Persistent()) do
				if legacyData[typeName] ~= nil then
					profile.Data[typeName] = legacyData[typeName]
				end
			end
		end
	end

	-- Covers every way a session can end that this module didn't itself
	-- trigger (another server stealing the lock, ProfileStore's own
	-- critical-state handling) -- not just the Phase 10 teleport-handoff
	-- case, which is the whole point of a real session lock over the old
	-- cheap gate.
	profile.OnSessionEnd:Connect(function()
		if sessions[player.UserId] == profile then
			sessions[player.UserId] = nil
		end
	end)

	if not player.Parent then
		-- Player left while StartSessionAsync was waiting on a lock
		-- conflict. Release immediately rather than leaking an active
		-- session for someone who's already gone.
		profile:EndSession()
		return zeroedBaseline(), false
	end

	sessions[player.UserId] = profile
	return profile.Data, true
end

function RewardStore.IsReady(player: Player): boolean
	local profile = sessions[player.UserId]
	return profile ~= nil and profile:IsActive()
end

-- values: { [rewardTypeName]: number } -- the persistent totals to store, as
-- read from the player's ledger.
--
-- Profile:Save() itself is fire-and-forget (it only re-queues the profile
-- for ProfileStore's next internal autosave pass, per ProfileStore's own
-- source -- not a synchronous write). Callers of THIS function (RewardLedger,
-- RewardCleanupHook's save step, RewardLaunchHook's Progression precondition)
-- all need a trustworthy boolean, so this waits (bounded) on Profile.OnAfterSave
-- before returning.
function RewardStore.Save(player: Player, values: { [string]: number }?): boolean
	local profile = sessions[player.UserId]
	if not profile or not profile:IsActive() then
		warn(("RewardStore: refusing to save %s -- no active session"):format(player.Name))
		return false
	end

	if not values then
		warn(("RewardStore: refusing to save %s -- incomplete ledger values"):format(player.Name))
		return false
	end

	for typeName, amount in pairs(values) do
		profile.Data[typeName] = amount
	end

	local confirmed = false
	local connection
	connection = profile.OnAfterSave:Connect(function()
		confirmed = true
	end)

	profile:Save()

	local waited = 0
	while not confirmed and waited < SAVE_CONFIRM_TIMEOUT_SECONDS and profile:IsActive() do
		task.wait(0.1)
		waited += 0.1
	end
	connection:Disconnect()

	if not confirmed then
		warn(("RewardStore: save for %s did not confirm within %ds"):format(player.Name, SAVE_CONFIRM_TIMEOUT_SECONDS))
	end

	return confirmed
end

-- Saves every currently connected player concurrently -- unchanged shape
-- from before this phase. Each Save() now internally waits up to
-- SAVE_CONFIRM_TIMEOUT_SECONDS, but since every player's save runs on its
-- own spawned thread, the whole call's wall-clock cost stays bounded by
-- that same ~8s, not multiplied by player count.
--
-- Returns (successCount, total) so a caller (MatchCleanup's save step) can
-- tell a real failure from success.
function RewardStore.SaveAll(getValues: (Player) -> { [string]: number }): (number, number)
	local players = Players:GetPlayers()
	local total = #players
	local successCount = 0
	local pending = 0
	local done = Instance.new("BindableEvent")

	for _, player in ipairs(players) do
		pending += 1
		task.spawn(function()
			local ok, saved = pcall(function()
				return RewardStore.Save(player, getValues(player))
			end)
			if ok and saved then
				successCount += 1
			end
			pending -= 1
			if pending == 0 then
				done:Fire()
			end
		end)
	end

	if pending > 0 then
		done.Event:Wait()
	end
	done:Destroy()

	return successCount, total
end

-- Real session release (ProfileStore:EndSession, fire-and-forget: it spawns
-- its own save-then-unlock on a background thread) -- not just dropping a
-- local table entry. Called from RewardLedger.TeardownPlayer on a normal
-- disconnect, and from LaunchGate's OnLaunched handlers (RewardLaunchHook)
-- once a match launch is confirmed successful, so the Game place's own
-- StartSessionAsync isn't left waiting out a session-lock conflict against
-- a Lobby session nobody meant to keep open.
function RewardStore.ClearSession(player: Player)
	local profile = sessions[player.UserId]
	if profile then
		profile:EndSession()
	end
	sessions[player.UserId] = nil
end

return RewardStore
