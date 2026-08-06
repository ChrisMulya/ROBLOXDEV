-- Read-only client mirror of the match clock. Reads the MatchInfo attributes
-- MatchTimeReplicator writes -- never sets them. Modelled on
-- PlayerStateClient: one source of truth, the client computes what to show
-- from replicated state and the server never sends a "show the clock"
-- command.
--
-- Runs the SAME MatchTimeMath functions the server runs, over the same
-- anchors. Neither side accumulates a running total, so the two cannot drift
-- against each other -- this is a second sample of one clock, not a second
-- clock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchSchedule = require(script.Parent.MatchSchedule)
local MatchTimeMath = require(script.Parent.MatchTimeMath)
local MatchPhases = require(script.Parent.MatchPhases)

local MatchTimeClient = {}

local function getMatchInfo(): Folder?
	return ReplicatedStorage:FindFirstChild("MatchInfo")
end

-- Returns nil whenever the clock isn't running -- no MatchInfo folder (the
-- Lobby place never creates one), or attributes cleared on match end. Absent
-- data must read as "no match time", never as hour 0.
function MatchTimeClient.GetAnchors(): { [string]: any }?
	local matchInfo = getMatchInfo()
	if not matchInfo then
		return nil
	end

	local scheduleId = matchInfo:GetAttribute("MatchScheduleId")
	local startedAt = matchInfo:GetAttribute("MatchTimeStartedAt")
	local endsAt = matchInfo:GetAttribute("MatchTimeEndsAt")
	local anchorAt = matchInfo:GetAttribute("MatchTimeAnchorAt")
	local anchorHour = matchInfo:GetAttribute("MatchTimeAnchorHour")

	if not scheduleId or not startedAt or not endsAt or not anchorAt or not anchorHour then
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

function MatchTimeClient.GetHour(): number?
	local anchors = MatchTimeClient.GetAnchors()
	if not anchors then
		return nil
	end

	local schedule = MatchSchedule.Get(anchors.scheduleId)
	local elapsedSinceAnchor = workspace:GetServerTimeNow() - anchors.anchorAt
	local anchorReal = MatchTimeMath.HourToReal(schedule, anchors.anchorHour)
	return MatchTimeMath.RealToHour(schedule, anchorReal + elapsedSinceAnchor)
end

-- Linear in REAL time, not game time: the bar answers "how much longer?",
-- which is the question the player is actually asking. Consequence to
-- accept: with variable-rate segments the hour label does not advance at a
-- constant distance along the bar.
function MatchTimeClient.GetProgress(): number?
	local anchors = MatchTimeClient.GetAnchors()
	if not anchors or anchors.endsAt <= anchors.startedAt then
		return nil
	end

	local now = workspace:GetServerTimeNow()
	return math.clamp((now - anchors.startedAt) / (anchors.endsAt - anchors.startedAt), 0, 1)
end

function MatchTimeClient.GetPhase(): string?
	local hour = MatchTimeClient.GetHour()
	if not hour then
		return nil
	end
	return MatchPhases.FromHour(hour)
end

function MatchTimeClient.GetHourText(): string?
	local hour = MatchTimeClient.GetHour()
	if not hour then
		return nil
	end
	return MatchTimeMath.FormatHour(hour)
end

return MatchTimeClient
