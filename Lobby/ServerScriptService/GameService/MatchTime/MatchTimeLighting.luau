-- The Match Time System's proving consumer: drives Lighting.ClockTime from
-- the match clock so the sky actually moves 6 PM -> 6 AM.
--
-- Lighting is currently unowned -- nothing else in the repo touches
-- ClockTime/TimeOfDay/Atmosphere -- so this is zero-conflict. It is also the
-- first thing the time system mutates that OUTLIVES the clock, which is why
-- the capture/restore below is mandatory rather than tidy: without it the
-- map sits frozen at dawn after the match.
--
-- Restores at Cleanup, not at Ending. During the Ending hold players are
-- still standing in the world reading the receipt; snapping the sky back to
-- its authored value underneath them is a jarring, meaningless flash.
-- Cleanup is where the world is already being torn down, and it is the seam
-- KitLifecycleHook and EncounterDirector already use for exactly this job.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)

local MatchCleanup = require(script.Parent.Parent.Match.MatchCleanup)
local MatchTimeService = require(script.Parent.MatchTimeService)

local MatchTimeLighting = {}

-- ClockTime drives a sky gradient nobody can perceive moving faster than
-- this. Sampling at the service's own 0.25s rate would be four times the
-- property writes for no visible difference.
local UPDATE_INTERVAL = 1

local authoredClockTime: number? = nil
local lastWriteAt = 0

-- Captured once, before the first write, and never re-captured -- a second
-- capture mid-match would save a value this module itself wrote and restore
-- the match's dawn instead of the map's authored lighting.
local function captureAuthored()
	if authoredClockTime == nil then
		authoredClockTime = Lighting.ClockTime
	end
end

local function restoreAuthored()
	if authoredClockTime ~= nil then
		Lighting.ClockTime = authoredClockTime
		authoredClockTime = nil
	end
end

local function onPhaseOrTick()
	local hour = MatchTimeService.GetHour()
	-- nil means there is no match time right now. Stop writing rather than
	-- falling back to a number -- see MatchTimeService's getter contract.
	if not hour then
		return
	end

	local now = os.clock()
	if now - lastWriteAt < UPDATE_INTERVAL then
		return
	end
	lastWriteAt = now

	-- The one legal `% 24` outside MatchTimeMath.FormatHour: ClockTime is a
	-- 0-24 engine property, so the continuous scale has to wrap here.
	Lighting.ClockTime = hour % 24
end

local started = false

function MatchTimeLighting.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	MatchTimeService.Started:Connect(function()
		captureAuthored()
		lastWriteAt = 0
		onPhaseOrTick()
	end)

	-- Piggybacks the service's existing sample loop rather than opening a
	-- second Heartbeat -- PhaseChanged is too coarse (four fires a match) to
	-- animate a sky, so this uses the per-sample tick and rate-limits itself.
	MatchTimeService.Ticked:Connect(onPhaseOrTick)

	-- Registry before registrant: MatchCleanup is started earlier in
	-- GameBoot's list, so this registration always lands.
	MatchCleanup.RegisterTeardownStep("MatchTimeLighting", restoreAuthored)
end

return MatchTimeLighting
