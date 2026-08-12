-- The frozen per-match configuration snapshot: mode, difficulty, expected
-- player count, and a random seed. Captured ONCE from MatchArrival,
-- immediately after MatchParticipants.Seed(...) and before the
-- Loading -> WaitingForPlayers transition fires -- so "settings exist" is a
-- precondition of every WaitingForPlayers subscriber (SpawnSelection among
-- them) rather than a race between them (Roblox does not guarantee handler
-- order on one signal).
--
-- Never recomputed after Capture(). playerCount is the EXPECTED roster
-- (#MatchParticipants.All()), not a live headcount -- a disconnect mid-match
-- must not change spawn-selection math retroactively.
--
-- difficultyId is read from TeleportData.difficultyId, the seam for a future
-- lobby difficulty selector. No selector exists yet, so every match is
-- MatchDifficulty.Default until one is built -- that is a working default,
-- not a stub.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchDifficulty = require(ReplicatedStorage.Modules.Shared.MatchDifficulty)
local MatchParticipants = require(script.Parent.MatchParticipants)

local MatchSettings = {}

local settings: {
	modeId: string,
	difficultyId: string,
	playerCount: number,
	randomSeed: number,
}? = nil

-- teleportData may be nil (Studio Play-test / direct join fallback -- see
-- MatchArrival.seedFrom). modeId is always known by the time this is called,
-- since MatchArrival resolves it (or its DEFAULT_MODE fallback) first.
function MatchSettings.Capture(teleportData: any?, modeId: string)
	ServerRole.AssertGameServer()

	if settings then
		return
	end

	local difficultyId = teleportData and teleportData.difficultyId
	if not difficultyId or not MatchDifficulty.IsValid(difficultyId) then
		if difficultyId then
			warn(("MatchSettings.Capture: unknown difficulty '%s', falling back to '%s'"):format(
				tostring(difficultyId), MatchDifficulty.Default))
		end
		difficultyId = MatchDifficulty.Default
	end

	local randomSeed = (teleportData and teleportData.spawnSeed) or os.clock() * 1e6 // 1

	settings = {
		modeId = modeId,
		difficultyId = difficultyId,
		playerCount = #MatchParticipants.All(),
		randomSeed = randomSeed,
	}

	print(("MatchSettings.Capture: mode=%s difficulty=%s playerCount=%d seed=%d"):format(
		settings.modeId, settings.difficultyId, settings.playerCount, settings.randomSeed))
end

-- Asserts. For callers whose position in the lifecycle guarantees Capture()
-- already ran (SpawnSelection, which only runs on WaitingForPlayers) -- there,
-- a missing snapshot is a programming error and should be loud.
function MatchSettings.Get()
	assert(settings, "MatchSettings.Get: called before Capture()")
	return settings
end

-- Non-asserting. For callers on a path where throwing would strand state --
-- PickupHandlers/Cash runs inside PickupService's claim window, which is NOT
-- pcalled and has already disabled the prompt, so an error there would brick
-- the pickup for the rest of the match instead of failing it cleanly.
function MatchSettings.TryGet()
	return settings
end

return MatchSettings
