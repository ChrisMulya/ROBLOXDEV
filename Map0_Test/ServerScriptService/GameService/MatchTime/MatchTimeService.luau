-- The single authority on match time. Owns the anchor, samples the clock
-- while Playing, derives the phase, dispatches scheduled events, and fires
-- Completed exactly once at EndHour. Game Server only.
--
-- Does NOT own: match state (MatchManager), the replicated attributes
-- (MatchTimeReplicator), or what happens at sunrise (SunriseEndHook). This
-- module answers "what time is it" and nothing else.
--
-- The clock is match-scoped. It starts on Playing and is fully torn down on
-- any transition out of Playing -- sunrise, AllPlayersDown, or an Abort. The
-- Heartbeat connection is disconnected, not merely left idle: a connection
-- running for the life of the server doing nothing is exactly the parallel
-- timer this system exists to eliminate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)
local MatchConfig = require(ReplicatedStorage.Modules.Shared.MatchConfig)
local MatchSchedule = require(ReplicatedStorage.Modules.MatchTime.MatchSchedule)
local MatchTimeMath = require(ReplicatedStorage.Modules.MatchTime.MatchTimeMath)
local MatchPhases = require(ReplicatedStorage.Modules.MatchTime.MatchPhases)

local MatchManager = require(script.Parent.Parent.Match.MatchManager)
local MatchArrival = require(script.Parent.Parent.Match.MatchArrival)
local MatchTimeEvents = require(script.Parent.MatchTimeEvents)

local MatchTimeService = {}

-- 0.25s: fine enough that a scheduled event lands within a quarter second of
-- its hour, coarse enough that the per-sample work is negligible. The HUD
-- ticks on its own, faster, client-side.
local SAMPLE_INTERVAL = 0.25

local activeSchedule = nil
local scheduleId: string? = nil
local anchorAt: number? = nil -- workspace:GetServerTimeNow() when the clock was anchored
local anchorHour: number? = nil -- continuous in-game hour at that anchor
local startedAt: number? = nil -- server time Playing began (bar denominator; never re-anchored)
local endsAt: number? = nil
local currentPhase: string? = nil
local completedFired = false

local heartbeatConnection: RBXScriptConnection? = nil
local sampleAccumulator = 0

MatchTimeService.PhaseChanged = Signal.new() -- fires (newPhase, oldPhase)
MatchTimeService.Completed = Signal.new() -- fires () once, when EndHour is reached

-- Started/Stopped bracket the clock's lifetime. Consumers (the replicator,
-- the lighting hook) subscribe to these rather than to MatchManager
-- .StateChanged, which would make them depend on this module's listener
-- happening to run first. By the time a deferred Started fire is handled the
-- anchors are already set; by the time Stopped is handled they are already
-- cleared. No ordering assumption either way.
MatchTimeService.Started = Signal.new() -- fires (scheduleId)
MatchTimeService.Stopped = Signal.new() -- fires ()

-- Fires (hour) every sample while Playing. For consumers that need a
-- continuous value rather than a discrete boundary -- lighting, and later
-- weather or ambience. Subscribing to this instead of opening a second
-- Heartbeat is what keeps "one clock" true; rate-limit inside the handler if
-- the sample rate is finer than you need.
MatchTimeService.Ticked = Signal.new() -- fires (hour)

-- All three return nil outside Playing. That nil is the contract: every
-- consumer must handle "there is no match time right now" rather than
-- defaulting to a number. Do not make these return StartHour as a
-- convenience.
function MatchTimeService.GetHour(): number?
	if not activeSchedule or not anchorAt or not anchorHour then
		return nil
	end
	local elapsedSinceAnchor = workspace:GetServerTimeNow() - anchorAt
	local anchorReal = MatchTimeMath.HourToReal(activeSchedule, anchorHour)
	return MatchTimeMath.RealToHour(activeSchedule, anchorReal + elapsedSinceAnchor)
end

function MatchTimeService.GetPhase(): string?
	local hour = MatchTimeService.GetHour()
	if not hour then
		return nil
	end
	return MatchPhases.FromHour(hour)
end

function MatchTimeService.GetProgress(): number?
	if not startedAt or not endsAt or endsAt <= startedAt then
		return nil
	end
	local now = workspace:GetServerTimeNow()
	return math.clamp((now - startedAt) / (endsAt - startedAt), 0, 1)
end

function MatchTimeService.GetSchedule()
	return activeSchedule
end

function MatchTimeService.GetScheduleId(): string?
	return scheduleId
end

-- Read by MatchTimeReplicator to publish. Returns nil outside Playing, which
-- is what tells the replicator to clear the attributes.
function MatchTimeService.GetAnchors(): { [string]: any }?
	if not activeSchedule then
		return nil
	end
	return {
		scheduleId = scheduleId,
		startedAt = startedAt,
		endsAt = endsAt,
		anchorAt = anchorAt,
		anchorHour = anchorHour,
	}
end

local function sample()
	local hour = MatchTimeService.GetHour()
	if not hour then
		return
	end

	MatchTimeEvents.Dispatch(hour)
	MatchTimeService.Ticked:Fire(hour)

	local phase = MatchPhases.FromHour(hour)
	if phase ~= currentPhase then
		local oldPhase = currentPhase
		currentPhase = phase
		MatchTimeService.PhaseChanged:Fire(phase, oldPhase)
	end

	if not completedFired and hour >= activeSchedule.EndHour then
		completedFired = true
		MatchTimeService.Completed:Fire()
	end
end

-- Full teardown. Disconnecting the Heartbeat is the point -- clearing the
-- anchors alone would leave a live connection for the lifetime of the server.
local function stopClock()
	local wasRunning = activeSchedule ~= nil

	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end

	activeSchedule = nil
	scheduleId = nil
	anchorAt = nil
	anchorHour = nil
	startedAt = nil
	endsAt = nil
	currentPhase = nil
	completedFired = false
	sampleAccumulator = 0

	if wasRunning then
		MatchTimeService.Stopped:Fire()
	end
end

local function startClock()
	-- Defensive: a re-entry into Playing is not a legal transition today, but
	-- anchoring twice would silently produce two Heartbeats.
	stopClock()

	scheduleId = MatchConfig.Get(MatchArrival.GetModeId()).ScheduleId or "Default"
	activeSchedule = MatchSchedule.Get(scheduleId)

	local now = workspace:GetServerTimeNow()
	startedAt = now
	anchorAt = now
	anchorHour = activeSchedule.StartHour
	endsAt = now + MatchTimeMath.TotalRealSeconds(activeSchedule)
	currentPhase = MatchPhases.FromHour(activeSchedule.StartHour)
	completedFired = false

	MatchTimeEvents.Reset()
	MatchTimeService.Started:Fire(scheduleId)

	heartbeatConnection = RunService.Heartbeat:Connect(function(delta)
		sampleAccumulator += delta
		if sampleAccumulator < SAMPLE_INTERVAL then
			return
		end
		sampleAccumulator = 0
		sample()
	end)
end

local started = false

function MatchTimeService.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	MatchManager.StateChanged:Connect(function(newState: string, oldState: string)
		if newState == "Playing" then
			startClock()
		elseif oldState == "Playing" then
			stopClock()
		end
	end)
end

return MatchTimeService
