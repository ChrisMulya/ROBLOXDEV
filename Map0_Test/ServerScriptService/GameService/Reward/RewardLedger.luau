-- Owns the actual per-player reward numbers. Creates leaderstat values from
-- RewardTypes, adds/reads through one API, and resets exactly the types
-- RewardTypes marks ResetOnRunEnd -- EndGame never touches a currency by
-- name. Setup/Teardown are called explicitly by PlayerCurrency's
-- PlayerAdded/PlayerRemoving handlers rather than connecting here, so there
-- is one obvious place player lifecycle wiring happens.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RewardTypes = require(ReplicatedStorage.Modules.Reward.RewardTypes)
local RewardStore = require(script.Parent.RewardStore)

local RewardLedger = {}

local function getOrCreateLeaderstats(player: Player): Folder
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	return leaderstats
end

local function getValue(player: Player, rewardType: string): IntValue?
	local typeDef = RewardTypes.Get(rewardType)
	if not typeDef then
		warn(("RewardLedger: unknown reward type '%s'"):format(tostring(rewardType)))
		return nil
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild(typeDef.LeaderstatName)
end

-- Creates one IntValue per RewardTypes.All entry at 0, IMMEDIATELY and
-- without yielding, then loads the saved baseline on a separate thread and
-- adds it in when it lands.
--
-- The ordering matters twice over. Creating the values up front means
-- RewardLedger.Add never hits a missing IntValue during the DataStore round
-- trip, so an award earned in that window isn't silently dropped. Adding the
-- baseline (rather than assigning it) means that award survives the load:
-- earn 1000 while Loading, resolve against a stored 5000, end at 6000.
--
-- Idempotent -- safe to call if leaderstats/values already exist.
function RewardLedger.SetupPlayer(player: Player)
	local leaderstats = getOrCreateLeaderstats(player)

	for _, typeDef in pairs(RewardTypes.All) do
		if not leaderstats:FindFirstChild(typeDef.LeaderstatName) then
			local value = Instance.new("IntValue")
			value.Name = typeDef.LeaderstatName
			value.Value = 0
			value.Parent = leaderstats
		end
	end

	task.spawn(function()
		local baseline, ok = RewardStore.Load(player)
		if not ok then
			-- Session is Failed; RewardStore.Save will refuse it, so the
			-- player's stored total stays intact. Nothing to apply here.
			return
		end

		-- Player may have left mid-load.
		if not player.Parent then
			return
		end

		for typeName, amount in pairs(baseline) do
			if amount ~= 0 then
				local value = getValue(player, typeName)
				if value then
					value.Value += amount
				end
			end
		end
	end)
end

function RewardLedger.Add(player: Player, rewardType: string, amount: number): number?
	local value = getValue(player, rewardType)
	if not value then return nil end

	value.Value += amount
	return value.Value
end

function RewardLedger.Get(player: Player, rewardType: string): number?
	local value = getValue(player, rewardType)
	return value and value.Value
end

-- Resets every RewardTypes entry with ResetOnRunEnd = true (currently
-- Score). Persistent types (XP) are untouched.
function RewardLedger.ResetRunScoped(player: Player)
	for _, typeName in ipairs(RewardTypes.RunScoped()) do
		local value = getValue(player, typeName)
		if value then
			value.Value = 0
		end
	end
end

-- { [rewardTypeName]: number } for every persistent type, or nil if any of
-- them is missing. Deliberately no `or 0` fallback: a zero standing in for
-- "we don't know" is what let a failed load overwrite real saved totals.
-- Exported (not a local) because RewardCleanupHook needs this exact
-- nil-safe logic for its Cleanup-time save step, rather than duplicating it.
function RewardLedger.CurrentPersistentValues(player: Player): { [string]: number }?
	local values = {}
	for _, typeName in ipairs(RewardTypes.Persistent()) do
		local amount = RewardLedger.Get(player, typeName)
		if amount == nil then
			warn(("RewardLedger: %s has no '%s' value -- refusing to build save data"):format(player.Name, typeName))
			return nil
		end
		values[typeName] = amount
	end
	return values
end

function RewardLedger.TeardownPlayer(player: Player)
	RewardStore.Save(player, RewardLedger.CurrentPersistentValues(player))
	RewardStore.ClearSession(player)
end

-- Phase 12 (debt #21): the module-scope StartAutosave/BindToClose that used
-- to live here are deleted, not relocated into a Start(). ProfileStore
-- (RewardStore's new backend) installs its own AUTO_SAVE_PERIOD loop and its
-- own game:BindToClose -- both apply globally, to every active session
-- across every ProfileStore instance, the moment the library is required.
-- Duplicating either here would just be a second, redundant writer racing
-- the library's own. This resolves debt #21 by elimination rather than by
-- giving RewardLedger a Start() it would otherwise now have no other reason
-- to need.

return RewardLedger
