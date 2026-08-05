-- Per-match personal stats: how long a player survived and how many of each
-- capture type they photographed. Registers the "Stats" MatchResultBuilder
-- contributor, same pattern as MatchRosterHook/RewardResultHook.
--
-- The letter grade itself is computed by Shared/MatchGrade.luau (an explicit
-- placeholder formula, tuned later) -- this file only assembles the stats a
-- grade is computed FROM, and calls it once at the very end, so the actual
-- grading logic lives in exactly one place shared by nothing else here.
--
-- survivedSeconds is anchored to this module's OWN clock (set on entering
-- Playing), not MatchManager.GetElapsed() -- that measures from server boot
-- and silently includes Loading/WaitingForPlayers/Countdown. A player who
-- died 10s into Playing must not be told they "survived" the full
-- WaitTimeout + Countdown + 10s.
--
-- captureType counts come from RewardService.Awarded, not RewardService.Grant
-- (unlike MatchEarnings): Awarded fires only on a successful capture and
-- carries fullContext.targetType, so a refused shot (TooFar,
-- OnRepeatCooldown, WrongShotQuality, AlreadyCompleted, ...) correctly never
-- increments a count. A non-capture Grant (missions, achievements, whenever
-- those exist) has no targetType and isn't a "capture" in the first place --
-- Awarded is the right choke point, not Granted.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local CaptureTargets = require(ReplicatedStorage.Modules.Reward.CaptureTargets)
local MatchGrade = require(ReplicatedStorage.Modules.Shared.MatchGrade)

local RewardService = require(script.Parent.Parent.Reward.RewardService)
local PlayerStateService = require(script.Parent.Parent.PlayerState.PlayerStateService)
local MatchManager = require(script.Parent.MatchManager)
local MatchResultBuilder = require(script.Parent.MatchResultBuilder)

local MatchStats = {}

local playingStartedAt: number? = nil
-- [userId] = os.clock() of first death this match. Never overwritten after
-- the first write -- a later Dead/Alive/Dead cycle (a mid-match respawn
-- policy, if one ever exists) must not erase how long they lasted the FIRST
-- time.
local deathAt: { [number]: number } = {}
-- [userId][targetType] = count
local captures: { [number]: { [string]: number } } = {}

local function ensureCaptureRow(userId: number): { [string]: number }
	local row = captures[userId]
	if not row then
		row = {}
		captures[userId] = row
	end
	return row
end

local function onAwarded(player: Player, context)
	local targetType = context and context.targetType
	if not targetType then
		return
	end
	local row = ensureCaptureRow(player.UserId)
	row[targetType] = (row[targetType] or 0) + 1
end

local function onPlayerStateChanged(player: Player, newState: string)
	if newState ~= "Dead" then
		return
	end
	local userId = player.UserId
	if deathAt[userId] then
		return
	end
	deathAt[userId] = os.clock()
end

-- Still-alive participants (or anyone read before the match ever reached
-- Playing) are timed against "now" -- the contributor runs synchronously
-- inside the Ending handler, so "now" IS the moment the match ended.
local function survivedSeconds(userId: number): number
	if not playingStartedAt then
		return 0
	end
	local endedAt = deathAt[userId] or os.clock()
	return math.max(0, endedAt - playingStartedAt)
end

local function reset()
	playingStartedAt = nil
	deathAt = {}
	captures = {}
end

local started = false

function MatchStats.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	RewardService.Awarded:Connect(onAwarded)
	PlayerStateService.StateChanged:Connect(onPlayerStateChanged)

	MatchManager.StateChanged:Connect(function(newState: string)
		if newState == "Playing" then
			playingStartedAt = os.clock()
		elseif newState == "WaitingForPlayers" then
			-- Same reset point as MatchEarnings: a reserved server hosts one
			-- match, but Studio Play and MatchArrival's solo-seed fallback
			-- can re-run a cycle in one session.
			reset()
		end
	end)

	MatchResultBuilder.RegisterContributor("Stats", function(userId: number)
		local row = captures[userId] or {}

		-- Pre-seeded with every known capture type, so a category the player
		-- never scored renders as 0 instead of being absent from the slice.
		-- Iterates CaptureTargets.Types directly rather than OrderedNames()
		-- -- order doesn't matter for a count map, only for the display
		-- layer's print order, which reads OrderedNames() itself.
		local seeded: { [string]: number } = {}
		for typeName in pairs(CaptureTargets.Types) do
			seeded[typeName] = row[typeName] or 0
		end

		local slice = {
			survivedSeconds = math.floor(survivedSeconds(userId)),
			captures = seeded,
		}
		-- Computed last, from the finished slice, so MatchGrade.Evaluate's
		-- input is exactly what the receipt itself will display -- no chance
		-- of the grade and the numbers next to it disagreeing.
		slice.grade = MatchGrade.Evaluate(slice)
		return slice
	end)
end

return MatchStats
