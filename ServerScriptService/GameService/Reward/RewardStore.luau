-- DataStore wrapper for persistent reward types (currently XP only).
--
-- The central rule: A SESSION IS NOT SAVABLE UNTIL A LOAD HAS DEFINITIVELY
-- COMPLETED. Previously a failed read was indistinguishable from a brand-new
-- player -- both produced zeros, which were then written back over the
-- player's real total on leave. One transient DataStore outage would wipe
-- every online player's progress. Save() now refuses unless the session
-- reached "Ready".

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RewardTypes = require(ReplicatedStorage.Modules.Reward.RewardTypes)

local MAX_ATTEMPTS = 3
local RETRY_BASE_SECONDS = 0.5 -- doubled each retry; a throttled DataStore
                               -- must not be hammered with immediate retries
local AUTOSAVE_INTERVAL = 120

local RewardStore = {}

-- Swappable so failure paths can be exercised deterministically in tests --
-- a real outage can't be waited for, and the Ready gate is exactly what needs
-- coverage. Defaults to the real DataStore.
RewardStore.Backend = DataStoreService:GetDataStore("RewardStore_v1")

-- [userId] = { state: "Loading" | "Ready" | "Failed", baseline: {[type]: number} }
local sessions = {}

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

-- Returns (ok, result). Distinguishing failure from a nil result is the whole
-- point -- GetAsync returns nil for a new key, which must NOT be conflated
-- with "every attempt errored".
local function attempt(fn, ...)
	local args = { ... }
	for tries = 1, MAX_ATTEMPTS do
		local ok, result = pcall(fn, table.unpack(args))
		if ok then
			return true, result
		end
		warn(("RewardStore: DataStore call failed (attempt %d/%d) - %s"):format(tries, MAX_ATTEMPTS, tostring(result)))
		if tries < MAX_ATTEMPTS then
			task.wait(RETRY_BASE_SECONDS * 2 ^ (tries - 1))
		end
	end
	return false, nil
end

local function zeroedBaseline(): { [string]: number }
	local baseline = {}
	for _, typeName in ipairs(RewardTypes.Persistent()) do
		baseline[typeName] = 0
	end
	return baseline
end

-- Resolves the session to Ready (with a trustworthy baseline) or Failed.
-- Returns (baseline, ok). On failure the baseline is all zeros purely so the
-- caller has a shape to work with -- it is NOT trustworthy, and the Failed
-- state means it will never be written back.
function RewardStore.Load(player: Player): ({ [string]: number }, boolean)
	sessions[player.UserId] = { state = "Loading", baseline = nil }

	local ok, data = attempt(function()
		return RewardStore.Backend:GetAsync(keyFor(player))
	end)

	if not ok then
		sessions[player.UserId] = { state = "Failed", baseline = nil }
		warn(("RewardStore: could not load %s -- session will NOT be saved, stored data left untouched"):format(player.Name))
		return zeroedBaseline(), false
	end

	-- ok with nil data is a genuinely new player, not an error.
	local stored = data or {}
	local baseline = {}
	for _, typeName in ipairs(RewardTypes.Persistent()) do
		baseline[typeName] = stored[typeName] or 0
	end

	sessions[player.UserId] = { state = "Ready", baseline = baseline }
	return baseline, true
end

function RewardStore.IsReady(player: Player): boolean
	local session = sessions[player.UserId]
	return session ~= nil and session.state == "Ready"
end

-- values: { [rewardTypeName]: number } -- the persistent totals to store, as
-- read from the player's ledger. Callers are responsible for passing only
-- persistent types (see RewardTypes.Persistent).
--
-- Refuses outright unless the session is Ready. UpdateAsync (not SetAsync) so
-- the write merges into the stored record instead of replacing it wholesale.
function RewardStore.Save(player: Player, values: { [string]: number }?): boolean
	if not RewardStore.IsReady(player) then
		warn(("RewardStore: refusing to save %s -- session never loaded cleanly"):format(player.Name))
		return false
	end

	-- nil means the ledger couldn't produce a complete set of totals; writing
	-- a partial record is exactly the kind of guess this module now refuses.
	if not values then
		warn(("RewardStore: refusing to save %s -- incomplete ledger values"):format(player.Name))
		return false
	end

	local ok = attempt(function()
		RewardStore.Backend:UpdateAsync(keyFor(player), function(stored)
			local merged = stored or {}
			for typeName, amount in pairs(values) do
				merged[typeName] = amount
			end
			return merged
		end)
	end)

	return ok
end

-- Saves every player concurrently. Sequential saves could exceed Roblox's
-- ~30s BindToClose budget once retries/backoff are involved, silently
-- dropping whoever sat at the end of the list.
function RewardStore.SaveAll(getValues: (Player) -> { [string]: number })
	local pending = 0
	local done = Instance.new("BindableEvent")

	for _, player in ipairs(Players:GetPlayers()) do
		pending += 1
		task.spawn(function()
			pcall(function()
				RewardStore.Save(player, getValues(player))
			end)
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
end

function RewardStore.ClearSession(player: Player)
	sessions[player.UserId] = nil
end

-- Periodic autosave so a server crash doesn't cost a whole session. The Ready
-- gate inside Save applies here too, so Failed sessions stay unwritten.
function RewardStore.StartAutosave(getValues: (Player) -> { [string]: number })
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				if RewardStore.IsReady(player) then
					task.spawn(function()
						pcall(function()
							RewardStore.Save(player, getValues(player))
						end)
					end)
				end
			end
		end
	end)
end

return RewardStore
