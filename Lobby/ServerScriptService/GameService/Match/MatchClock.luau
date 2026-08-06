-- Optional per-mode timers: WaitingForPlayers timeout, Countdown ticks, and
-- the Ending -> Cleanup hold. Drives transitions via MatchManager only and
-- holds no state of its own beyond reading the mode id through MatchArrival.
--
-- Supersedes MatchCleanup's placeholder ENDING_HOLD_SECONDS constant, per
-- that module's own comment inviting this swap once MatchClock landed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchConfig = require(ReplicatedStorage.Modules.Shared.MatchConfig)

local MatchManager = require(script.Parent.MatchManager)
local MatchParticipants = require(script.Parent.MatchParticipants)
local MatchArrival = require(script.Parent.MatchArrival)

local MatchClock = {}

local function config()
	return MatchConfig.Get(MatchArrival.GetModeId())
end

-- Polls rather than building a fully event-driven state machine -- same
-- style as MatchCleanup.runWithTimeout. Checking MatchManager.Is(expected)
-- every iteration means a transition from anywhere else (manual command-bar
-- drive, an abort) simply falls out of the loop instead of needing an
-- explicit cancellation flag.
local function runWaitingForPlayers()
	local cfg = config()
	local waited = 0

	while MatchManager.Is("WaitingForPlayers") do
		local present = MatchParticipants.CountActive()
		local expected = #MatchParticipants.All()

		if present > 0 and present >= expected then
			MatchManager.RequestTransition("Countdown", "RosterComplete")
			return
		end

		if waited >= cfg.WaitTimeout then
			if present >= cfg.MinPlayers then
				MatchManager.RequestTransition("Countdown", "WaitTimeoutWithPlayers")
			else
				MatchManager.RequestTransition("Cleanup", "WaitTimeoutEmpty")
			end
			return
		end

		task.wait(1)
		waited += 1
	end
end

local function runCountdown()
	local cfg = config()
	local waited = 0

	while MatchManager.Is("Countdown") do
		if MatchParticipants.CountActive() == 0 then
			MatchManager.RequestTransition("WaitingForPlayers", "CountdownEmptied")
			return
		end

		if waited >= cfg.CountdownSeconds then
			MatchManager.RequestTransition("Playing", "CountdownElapsed")
			return
		end

		task.wait(1)
		waited += 1
	end
end

-- Absolute server timestamp when the Ending hold expires, or nil outside
-- Ending. This module is the authority on when Cleanup actually fires, and
-- MatchReplicator puts the same instant on the receipt's return button --
-- two independent computations of one deadline is exactly the drift the
-- Match Time System removed from match length.
local endingDeadline: number? = nil

-- Computed on FIRST REQUEST, not only inside runEndingHold. Roblox does not
-- order multiple handlers connected to one event, so "MatchClock's
-- StateChanged handler runs before the reader's" is not a guarantee this
-- module is entitled to make. Whoever asks first anchors the deadline;
-- runEndingHold then times the hold to that same instant. Order-independent
-- by construction, so no caller needs a fallback.
function MatchClock.GetEndingDeadline(): number?
	if not MatchManager.Is("Ending") then
		return nil
	end
	if not endingDeadline then
		endingDeadline = workspace:GetServerTimeNow() + config().EndingHoldSeconds
	end
	return endingDeadline
end

local function runEndingHold()
	local deadline = MatchClock.GetEndingDeadline()
	if not deadline then
		return
	end

	-- Timed to the shared deadline rather than to a fresh EndingHoldSeconds
	-- from now: if the replicator anchored it a moment earlier, the receipt's
	-- countdown and the real transition still land together.
	task.delay(math.max(0, deadline - workspace:GetServerTimeNow()), function()
		if MatchManager.Is("Ending") then
			MatchManager.RequestTransition("Cleanup", "EndingHoldElapsed")
		end
	end)
end

-- There is deliberately no runPlaying here. Ending the match on time is
-- MatchTimeService's job: it reaches EndHour (6 AM), fires Completed, and
-- SunriseEndHook calls RequestEnd("Sunrise"). A second countdown here would
-- be a duplicate authority on match length -- the exact thing the Match Time
-- System was built to remove. MatchEndCondition still covers "everyone died
-- early", and RequestEnd remains idempotent so the two cannot conflict.

local started = false

function MatchClock.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	MatchManager.StateChanged:Connect(function(newState: string)
		-- Ending is unreachable twice in one match (Ending -> Cleanup only),
		-- but clearing here means a stale deadline can never outlive the
		-- state it belongs to, whatever transitions are added later.
		if newState ~= "Ending" then
			endingDeadline = nil
		end

		if newState == "WaitingForPlayers" then
			task.spawn(runWaitingForPlayers)
		elseif newState == "Countdown" then
			task.spawn(runCountdown)
		elseif newState == "Ending" then
			runEndingHold()
		end
	end)
end

return MatchClock
