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

local function runEndingHold()
	local cfg = config()
	task.delay(cfg.EndingHoldSeconds, function()
		if MatchManager.Is("Ending") then
			MatchManager.RequestTransition("Cleanup", "EndingHoldElapsed")
		end
	end)
end

local started = false

function MatchClock.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	MatchManager.StateChanged:Connect(function(newState: string)
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
