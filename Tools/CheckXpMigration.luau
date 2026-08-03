--[[
	CheckXpMigration -- READ-ONLY diagnostic. Paste into Studio's command bar.
	Confirmed working from the EDIT-mode command bar (no Play needed) as long
	as Studio Access to API Services is on (MAINHANDOFF G7). With it off every
	read fails and every row reports UNKNOWN rather than pretending the key is
	empty -- those two are not the same and this script never conflates them.

	WHAT THIS IS FOR
	Phase 12 moved XP from RewardStore_v1 (flat {XP = n}, written by raw
	DataStoreService) to RewardStore_v2 (ProfileStore envelope). Phase 12.5
	item 1 fixed the migration gate (it used to be
	`profile.SessionLoadCount == 1`, which fires exactly once per player,
	ever -- a single failed legacy read on that one attempt orphaned the
	real v1 total permanently, with no retry possible on any later join).
	The gate is now a durable `RobloxMetaData.MigratedFromV1` marker, set
	only when the legacy read definitively succeeds, so a failed read
	retries on the next join instead.

	This script still exists post-fix for two reasons: to audit any account
	that migrated (or tried to) BEFORE the fix landed, and as the ongoing
	sanity check that the marker is doing its job (a healthy population
	should trend toward zero "STILL EXPOSED" over time, not stay flat).

	AT-RISK POPULATION is narrower than it first looks: only accounts that
	earned XP into v1 AND have not joined since Phase 12. A brand-new player
	has nothing to copy, so a failed read costs them nothing; an account that
	already migrated is done. MODE B below measures exactly that population.

	TWO MODES
	  A. Explicit accounts -- set USER_IDS. Verbose per-account report.
	  B. Full sweep -- set SWEEP_ALL_V1 = true. Enumerates every key that
	     ever saved to v1 and classifies all of them. Slower (two reads per
	     account, budget-throttled) but it is the only way to answer "how
	     many accounts are still exposed".
	Both modes run through the same classify() below, so they cannot disagree.

	IT WRITES NOTHING. No SetAsync, no UpdateAsync, no ProfileStore calls at
	all -- deliberately raw GetAsync/ListKeysAsync against both stores, so it
	cannot start a session, steal a session lock, bump SessionLoadCount, or
	trigger an autosave on a profile someone is actively using. Safe to run
	against a live game.

	G3 note: safe from the command bar despite the isolated require() cache.
	The only project module required is RewardTypes, a pure data table with
	no runtime state populated by a real Script -- unlike RewardService or
	RewardStore, whose in-memory state WOULD be invisible here.
--]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RewardTypes = require(ReplicatedStorage.Modules.Reward.RewardTypes)

----- Config -------------------------------------------------------------

-- MODE A: explicit accounts. In Edit mode Players:GetPlayers() is empty, so
-- leaving this blank without enabling the sweep checks nobody.
local USER_IDS: { number } = {}

-- MODE B: enumerate every account that ever wrote to v1. Overrides USER_IDS.
local SWEEP_ALL_V1 = false

-- Hard cap so an unexpectedly large store can't run unbounded. If the sweep
-- hits this, it says so rather than silently reporting a partial picture.
local SWEEP_MAX_KEYS = 2000

----- Setup --------------------------------------------------------------

local LEGACY_STORE_NAME = "RewardStore_v1"
local CURRENT_STORE_NAME = "RewardStore_v2"

local legacyStore = DataStoreService:GetDataStore(LEGACY_STORE_NAME)
local currentStore = DataStoreService:GetDataStore(CURRENT_STORE_NAME)

local MAX_ATTEMPTS = 3
local RETRY_BASE_SECONDS = 0.5

local persistentTypes = RewardTypes.Persistent()

local function keyFor(userId: number): string
	return "Player_" .. userId
end

-- Yields until Roblox will accept another request of this type. A sweep is
-- two GetAsync per account on top of the ListAsync calls, which will exhaust
-- the budget on any real key count -- without this the reads start failing
-- and every account would be misreported as UNKNOWN.
local function waitForBudget(requestType: Enum.DataStoreRequestType)
	local waited = 0
	while DataStoreService:GetRequestBudgetForRequestType(requestType) < 1 do
		task.wait(1)
		waited += 1
		if waited % 15 == 0 then
			print(("    (waiting on DataStore request budget... %ds)"):format(waited))
		end
	end
end

-- Returns (ok, value). Distinguishing "every attempt errored" from "the key
-- is genuinely empty" is the entire point of this script.
local function read(store, key: string)
	waitForBudget(Enum.DataStoreRequestType.GetAsync)
	for tries = 1, MAX_ATTEMPTS do
		local ok, result = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			return true, result
		end
		if tries < MAX_ATTEMPTS then
			task.wait(RETRY_BASE_SECONDS * 2 ^ (tries - 1))
		end
	end
	return false, nil
end

local function describeTotals(values: { [string]: number }?): string
	if not values then
		return "-"
	end
	local parts = {}
	for _, typeName in ipairs(persistentTypes) do
		table.insert(parts, ("%s=%s"):format(typeName, tostring(values[typeName] or 0)))
	end
	return table.concat(parts, " ")
end

----- Shared classifier --------------------------------------------------

-- The single source of truth for what a given account's state means. Both
-- modes call this, so a sweep verdict and a single-account verdict for the
-- same player are guaranteed identical.
--
-- status is one of:
--   "Unknown"      -- a read failed; no conclusion is safe
--   "NothingAnywhere" -- brand-new, nothing stored in either store
--   "NewSincePhase12" -- v2 only; joined after the migration, nothing to copy
--   "Unmigrated"   -- v1 only; has NOT joined since Phase 12. STILL EXPOSED.
--   "Migrated"     -- both present, v2 >= v1
--   "Suspect"      -- both present, v2 < v1. Migration ran but did not copy.
local function classify(userId: number)
	local legacyOk, legacyRaw = read(legacyStore, keyFor(userId))
	local currentOk, currentRaw = read(currentStore, keyFor(userId))

	local result = {
		userId = userId,
		legacyOk = legacyOk,
		currentOk = currentOk,
		legacyValues = legacyRaw,
		-- v1 is the old flat record: { XP = n }. v2 is the ProfileStore
		-- envelope: { Data, MetaData, RobloxMetaData, UserIds, GlobalUpdates }.
		currentValues = currentRaw and currentRaw.Data or nil,
		meta = currentRaw and currentRaw.MetaData or nil,
		robloxMeta = currentRaw and currentRaw.RobloxMetaData or nil,
		detail = nil,
	}

	if not legacyOk or not currentOk then
		result.status = "Unknown"
		return result
	end

	if not result.legacyValues and not result.currentValues then
		result.status = "NothingAnywhere"
	elseif not result.legacyValues then
		result.status = "NewSincePhase12"
	elseif not result.currentValues then
		result.status = "Unmigrated"
	else
		-- XP is never spent in this game (it only accumulates) and v1 is
		-- frozen -- nothing writes to it anymore. So a v2 total BELOW the
		-- v1 total cannot be explained by normal play, which makes it a
		-- reliable signature of a migration that copied nothing.
		for _, typeName in ipairs(persistentTypes) do
			local before = result.legacyValues[typeName] or 0
			local after = result.currentValues[typeName] or 0
			if after < before then
				result.status = "Suspect"
				result.detail = ("%s: v1=%d > v2=%d (%d unaccounted for)"):format(
					typeName, before, after, before - after)
				break
			end
		end
		result.status = result.status or "Migrated"
	end

	return result
end

----- Mode A: explicit accounts ------------------------------------------

local function reportVerbose(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	local label = player and ("%s (%d)"):format(player.Name, userId) or tostring(userId)
	local r = classify(userId)

	print(("--- %s ---"):format(label))

	if r.status == "Unknown" then
		print(("  v1 read: %s"):format(r.legacyOk and "ok" or "READ FAILED"))
		print(("  v2 read: %s"):format(r.currentOk and "ok" or "READ FAILED"))
		print("  VERDICT: UNKNOWN -- a read failed, re-run before concluding anything.\n")
		return r
	end

	print(("  v1 (legacy, frozen): %s"):format(describeTotals(r.legacyValues)))
	print(("  v2 (live):           %s"):format(describeTotals(r.currentValues)))

	if r.meta then
		print(("  v2 SessionLoadCount: %s | LastUpdate: %s"):format(
			tostring(r.meta.SessionLoadCount), tostring(r.meta.LastUpdate)))
		-- A live session means v2's stored values may lag the player's true
		-- in-memory total, so a small v2 < v1 gap could be timing, not loss.
		print(("  v2 session active right now: %s"):format(r.meta.ActiveSession and "YES" or "no"))
	end
	-- Written by Phase 12.5 item 1. "absent" = no v2 profile at all (fine --
	-- nothing to migrate yet). "nil" on an account with v1 data = migrated
	-- BEFORE the 12.5 fix landed (pre-fix code never set this marker) or the
	-- legacy read is still failing/retrying; check the VERDICT below, not
	-- this line alone. "true" = migrated under the fixed code -- expected
	-- and healthy going forward.
	print(("  MigratedFromV1 marker: %s"):format(
		r.robloxMeta and tostring(r.robloxMeta.MigratedFromV1) or "absent"))

	if r.status == "NothingAnywhere" then
		print("  VERDICT: brand-new player, nothing stored anywhere. Fine.\n")
	elseif r.status == "NewSincePhase12" then
		print("  VERDICT: v2 only -- joined after Phase 12, nothing to migrate. Fine.\n")
	elseif r.status == "Unmigrated" then
		print("  VERDICT: v1 only -- has NOT joined since Phase 12.")
		print("           STILL EXPOSED to the one-shot gate on their next join.\n")
	elseif r.status == "Suspect" then
		print(("  VERDICT: *** SUSPECT -- %s"):format(r.detail))
		print("           v1 is frozen and XP only increases, so v2 below v1 means")
		print("           the migration copy did not land. Repair candidate.\n")
	else
		print("  VERDICT: v2 >= v1 -- migration landed (or earned more since). Fine.\n")
	end

	return r
end

----- Mode B: full v1 sweep ----------------------------------------------

-- Returns (realUserIds, testUserIds, truncated, err). Split, not filtered:
-- a key this couldn't classify at all (doesn't even match Player_<number>)
-- is reported separately too, rather than silently vanishing either way.
--
-- Bug fixed here (found during a live sweep): the original pattern was
-- "^Player_(%d+)$", and %d does not match a minus sign -- Studio Play-test
-- players use negative UserIds (-1, -2, -3, ...), so every one of those
-- keys silently failed the match and never appeared in the sweep at all.
-- In that run the omission happened to be the right OUTCOME (they aren't
-- real accounts) but for the wrong reason (silent parse failure, not a
-- deliberate classification) -- a key this script can't account for must
-- never just disappear.
local function listAllV1UserIds(): ({ number }, { number }, boolean, string?)
	local realUserIds = {}
	local testUserIds = {}
	local unparsed = {}
	local truncated = false

	local listOk, pages = pcall(function()
		waitForBudget(Enum.DataStoreRequestType.ListAsync)
		return legacyStore:ListKeysAsync("Player_")
	end)
	if not listOk then
		return {}, {}, false, tostring(pages)
	end

	while true do
		local page = pages:GetCurrentPage()
		for _, entry in ipairs(page) do
			local matched = entry.KeyName:match("^Player_(%-?%d+)$")
			local userId = matched and tonumber(matched)
			if not userId then
				table.insert(unparsed, entry.KeyName)
			elseif userId < 0 then
				table.insert(testUserIds, userId)
			else
				table.insert(realUserIds, userId)
			end

			if #realUserIds >= SWEEP_MAX_KEYS then
				truncated = true
				return realUserIds, testUserIds, truncated, nil
			end
		end

		if pages.IsFinished then
			break
		end

		local advanceOk, advanceErr = pcall(function()
			waitForBudget(Enum.DataStoreRequestType.ListAsync)
			pages:AdvanceToNextPageAsync()
		end)
		if not advanceOk then
			return realUserIds, testUserIds, truncated, tostring(advanceErr)
		end
	end

	if #unparsed > 0 then
		print(("  (%d key(s) did not match Player_<number> and were not classified: %s)"):format(
			#unparsed, table.concat(unparsed, ", ")))
	end

	return realUserIds, testUserIds, truncated, nil
end

----- Run ----------------------------------------------------------------

print(("\n=== XP migration check (%s -> %s) ==="):format(LEGACY_STORE_NAME, CURRENT_STORE_NAME))
print("READ-ONLY. Nothing below writes to any DataStore.\n")

local counts = {
	Unknown = 0,
	NothingAnywhere = 0,
	NewSincePhase12 = 0,
	Unmigrated = 0,
	Migrated = 0,
	Suspect = 0,
}
local exposed = {}
local suspects = {}
local unknowns = {}

local function tally(r)
	counts[r.status] = (counts[r.status] or 0) + 1
	if r.status == "Unmigrated" then
		table.insert(exposed, r.userId)
	elseif r.status == "Suspect" then
		table.insert(suspects, ("%d -- %s"):format(r.userId, r.detail or "?"))
	elseif r.status == "Unknown" then
		table.insert(unknowns, r.userId)
	end
end

if SWEEP_ALL_V1 then
	print(("Sweeping every key in %s (this is slow -- two reads per account,"):format(LEGACY_STORE_NAME))
	print(" throttled to Roblox's DataStore request budget)...\n")

	local userIds, testUserIds, truncated, listErr = listAllV1UserIds()

	if listErr then
		print(("!! Key enumeration failed or stopped early: %s"):format(listErr))
		print("   Results below cover only what was listed before the failure.\n")
	end
	print(("Found %d real account(s) with data in %s."):format(#userIds, LEGACY_STORE_NAME))
	if #testUserIds > 0 then
		print(("Also found %d Studio Play-test key(s) (negative UserId -- not real accounts), excluded from the sweep below: %s"):format(
			#testUserIds, table.concat(testUserIds, ", ")))
	end
	print("")

	for index, userId in ipairs(userIds) do
		local r = classify(userId)
		tally(r)
		-- Only problems are printed individually; a clean sweep of hundreds
		-- of accounts should not bury its own summary in noise.
		if r.status == "Unmigrated" then
			print(("  [%d/%d] %d -- UNMIGRATED (%s) -- still exposed"):format(
				index, #userIds, userId, describeTotals(r.legacyValues)))
		elseif r.status == "Suspect" then
			print(("  [%d/%d] %d -- *** SUSPECT -- %s"):format(index, #userIds, userId, r.detail))
		elseif r.status == "Unknown" then
			print(("  [%d/%d] %d -- UNKNOWN (a read failed)"):format(index, #userIds, userId))
		end
		if index % 25 == 0 then
			print(("  ...%d/%d checked"):format(index, #userIds))
		end
	end

	if truncated then
		print(("\n!! Stopped at the SWEEP_MAX_KEYS cap (%d). More accounts exist"):format(SWEEP_MAX_KEYS))
		print("   than were checked -- raise the cap for a complete picture.")
	end
else
	local targets = USER_IDS
	if #targets == 0 then
		local ids = {}
		for _, player in ipairs(Players:GetPlayers()) do
			table.insert(ids, player.UserId)
		end
		targets = ids
	end

	if #targets == 0 then
		print("Nothing to check: USER_IDS is empty and no players are connected.")
		print("Set USER_IDS = { <userId>, ... }, or set SWEEP_ALL_V1 = true for a full sweep.\n")
	end

	for _, userId in ipairs(targets) do
		tally(reportVerbose(userId))
	end
end

----- Summary ------------------------------------------------------------

print("=== summary ===")
print(("  migrated cleanly:        %d"):format(counts.Migrated))
print(("  joined after Phase 12:   %d"):format(counts.NewSincePhase12))
print(("  nothing stored:          %d"):format(counts.NothingAnywhere))
print(("  STILL EXPOSED (v1 only): %d"):format(counts.Unmigrated))
print(("  SUSPECT (lost on copy):  %d"):format(counts.Suspect))
print(("  unknown (read failed):   %d"):format(counts.Unknown))

if #suspects > 0 then
	print("\nSUSPECT accounts -- migration ran but copied nothing:")
	for _, line in ipairs(suspects) do
		print("  - " .. line)
	end
end

if #exposed > 0 then
	print("\nSTILL EXPOSED -- these have v1 XP and have not joined since Phase 12.")
	print("Each gets exactly one migration attempt on their next join, with no")
	print("retry if it fails. This is the population Phase 12.5 section 1 protects:")
	for _, userId in ipairs(exposed) do
		print("  - " .. tostring(userId))
	end
end

if #unknowns > 0 then
	print("\nUNKNOWN -- re-run before drawing conclusions about these:")
	for _, userId in ipairs(unknowns) do
		print("  - " .. tostring(userId))
	end
end

if #suspects == 0 and #exposed == 0 and #unknowns == 0 then
	print("\nNo suspects, no exposed accounts, no failed reads.")
end

print("\nNothing has been changed. Any repair is a separate, deliberate step.")
print("=== end ===\n")
