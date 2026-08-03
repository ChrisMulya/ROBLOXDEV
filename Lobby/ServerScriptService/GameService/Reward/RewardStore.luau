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
-- the OLD store, once per profile, and copies matching values in before
-- Reconcile's defaults would otherwise stick.
--
-- Phase 12.5 fix (item 1): the one-time gate used to be
-- `profile.SessionLoadCount == 1`, which fires exactly once per player,
-- ever. If that single legacy read failed (transient outage/throttle),
-- nothing was copied but the profile was still marked Ready, and every
-- later join saw SessionLoadCount >= 2 -- the copy never retried and the
-- v1 total was orphaned permanently. Gated on a durable
-- `RobloxMetaData.MigratedFromV1` marker instead (ProfileStore saves that
-- table automatically), set ONLY when the legacy read definitively
-- succeeds -- a failed read leaves the marker unset and retries next join.
--
-- Why RobloxMetaData and not Profile.Data: zeroedBaseline() below does
-- double duty as the ProfileStore template AND as the failure-shape
-- returned to RewardLedger.SetupPlayer, which iterates pairs(baseline) and
-- calls getValue() per key -- a non-reward-type key there would trigger
-- RewardLedger's "unknown reward type" warning on every load.
-- RobloxMetaData never enters that loop.
--
-- SUNSET: the v1 read is temporary. Once RewardStoreDiagnostics/this
-- module's migration logging shows no migrations for a full retention
-- window, delete legacyBackend, attemptLegacyRead, and the migration block
-- in Load(). See MAINHANDOFF.md for the tracked sunset condition.
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

local RewardStore = {}

-- Real module fields, not locals (Phase 12.5 item 3): this value and
-- Match/MatchCleanup.STEP_TIMEOUT_SECONDS must maintain
-- SAVE_CONFIRM_TIMEOUT_SECONDS < STEP_TIMEOUT_SECONDS, or
-- RewardCleanupHook's save step gets abandoned before a save can ever
-- confirm (roadmap R-6). RewardCleanupHook.Start() asserts this
-- relationship at boot -- a comment alone didn't stop either number
-- drifting independently.
RewardStore.SAVE_CONFIRM_TIMEOUT_SECONDS = 8

local function zeroedBaseline(): { [string]: number }
	local baseline = {}
	for _, typeName in ipairs(RewardTypes.Persistent()) do
		baseline[typeName] = 0
	end
	return baseline
end

RewardStore.Backend = ProfileStoreLib.New("RewardStore_v2", zeroedBaseline())

-- Read-only. Never written again -- ProfileStore owns "RewardStore_v2" from
-- here on. Only consulted once per profile (see MigratedFromV1 above).
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

-- Item 6: ProfileStore.DataStoreState starts as "NotReady" and resolves
-- asynchronously (driven by StartSessionAsync's own internal
-- WaitForStoreReady), so reading it at module scope -- or on the very first
-- call of a freshly-started server -- would see "NotReady" and wrongly
-- conclude Mock is needed even on a perfectly healthy server. Gives
-- resolution up to 5s before concluding the real DataStore genuinely isn't
-- reachable. Only called from Load/Reacquire (the two places that call
-- :StartSessionAsync) -- Save and friends operate on the Profile object
-- StartSessionAsync already returned, via profile:Save()/EndSession(), so
-- they must not independently re-select a backend.
local function activeStore()
	local state = ProfileStoreLib.DataStoreState
	if state == "NotReady" then
		local waited = 0
		while ProfileStoreLib.DataStoreState == "NotReady" and waited < 5 do
			task.wait(0.25)
			waited += 0.25
		end
		state = ProfileStoreLib.DataStoreState
	end

	if state == "Access" then
		return RewardStore.Backend
	end

	warn(("RewardStore: DataStoreState is '%s' -- routing through ProfileStore.Backend.Mock. Nothing will persist to the real DataStore this session."):format(state))
	return RewardStore.Backend.Mock
end

-- Fire-and-forget from PlayerCurrency.legacy's PlayerAdded handler, same
-- call site as before this phase. Returns (baseline, ok) unchanged in
-- shape -- RewardLedger.SetupPlayer's existing "add baseline into the
-- IntValues" logic needs no changes.
function RewardStore.Load(player: Player): ({ [string]: number }, boolean)
	local profile = activeStore():StartSessionAsync(keyFor(player), {
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

	-- One-time-per-profile legacy fallback -- see file header. The marker
	-- is only set once the legacy read DEFINITIVELY succeeds (legacyOk ==
	-- true), whether or not it actually found data -- "new player, nothing
	-- stored" is a successful migration; a failed read is not, and must
	-- retry on the next join.
	if not profile.RobloxMetaData.MigratedFromV1 then
		local legacyOk, legacyData = attemptLegacyRead(function()
			return legacyBackend:GetAsync(keyFor(player))
		end)

		if legacyOk then
			profile.RobloxMetaData.MigratedFromV1 = true

			if legacyData then
				local copied = {}
				for _, typeName in ipairs(RewardTypes.Persistent()) do
					if legacyData[typeName] ~= nil then
						profile.Data[typeName] = legacyData[typeName]
						table.insert(copied, ("%s=%s"):format(typeName, tostring(legacyData[typeName])))
					end
				end
				print(("RewardStore: migrated %s from v1 -- %s"):format(player.Name, table.concat(copied, " ")))
			else
				print(("RewardStore: migration check for %s -- no v1 data found (new player)"):format(player.Name))
			end
		else
			warn(("RewardStore: legacy migration read failed for %s -- will retry on next join"):format(player.Name))
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
	while not confirmed and waited < RewardStore.SAVE_CONFIRM_TIMEOUT_SECONDS and profile:IsActive() do
		task.wait(0.1)
		waited += 0.1
	end
	connection:Disconnect()

	if not confirmed then
		warn(("RewardStore: save for %s did not confirm within %ds"):format(player.Name, RewardStore.SAVE_CONFIRM_TIMEOUT_SECONDS))
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

-- Phase 12.5 item 2 (roadmap R-3, resurfaced): re-establishes a Lobby
-- session for a candidate whose launch was aborted AFTER OnLaunched already
-- released it. TeleportAsync returning true means the request was accepted,
-- not that anyone arrived -- an async TeleportInitFailed can still strand a
-- player here with no session, refusing every future write until rejoin.
--
-- Deliberately does NOT route through RewardLedger.SetupPlayer, which ADDS
-- a baseline into the existing IntValues -- correct for a fresh join, wrong
-- here, since those IntValues already hold the correct total (OnLaunched
-- only fires after LaunchGate.Check forced a confirmed save, so stored ==
-- live at the moment of release). Re-adding would double-count -- the exact
-- hazard the roadmap flags, and it already bit once in Phase 7.5. This only
-- re-acquires the lock; the leaderstat values are untouched.
function RewardStore.Reacquire(player: Player)
	if RewardStore.IsReady(player) then
		return
	end

	local profile = activeStore():StartSessionAsync(keyFor(player), {
		Cancel = function()
			return player.Parent == nil
		end,
	})

	if not profile then
		warn(("RewardStore: could not reacquire a session for %s after an aborted launch -- writes refused until rejoin"):format(player.Name))
		return
	end

	profile.OnSessionEnd:Connect(function()
		if sessions[player.UserId] == profile then
			sessions[player.UserId] = nil
		end
	end)

	if not player.Parent then
		profile:EndSession()
		return
	end

	sessions[player.UserId] = profile
end

return RewardStore
