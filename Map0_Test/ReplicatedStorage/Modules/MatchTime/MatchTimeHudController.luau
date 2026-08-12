-- Wires MatchTimeClient to MatchTimeHud. Owns no state and no UI -- the same
-- controller/hud split as SpectateController/SpectateHud.
--
-- Required for its side effects from ClientBootstrap's GameServer branch
-- only. The Lobby never requires this, so no clock is ever built there.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local MatchTimeClient = require(script.Parent.MatchTimeClient)
local MatchTimeHud = require(script.Parent.MatchTimeHud)
local MatchAnnouncerState = require(script.Parent.MatchAnnouncerState)
local MatchTimeAnnouncer = require(script.Parent.MatchTimeAnnouncer)
local MatchEvents = require(script.Parent.MatchEvents)
local MatchEventAnnouncer = require(script.Parent.MatchEventAnnouncer)

-- 0.1s: the bar advances ~0.03% of its width per tick on the Default
-- schedule, well under a pixel, so this reads as continuous without costing
-- a per-frame update.
local TICK_INTERVAL = 0.1

local tickAccumulator = 0

-- The currently-displayed event announcement, if any. os.clock() rather than
-- the match clock: the display window is a real-time readability budget, and
-- the Debug schedule would otherwise blink a 10-second message away in one.
local eventText: string? = nil
local eventColor: Color3? = nil
local eventExpiry: number = 0

local function clearEvent()
	eventText = nil
	eventColor = nil
	eventExpiry = 0
end

-- A second announcement arriving inside the first one's window REPLACES it
-- (and restarts the 10 seconds) rather than queueing: the line is one line,
-- and a queue would show players an event that is already minutes stale.
local function onEventAnnounced(eventId: string)
	local event = MatchEvents.Get(eventId)
	if not event then
		return
	end
	eventText = event.Text
	eventColor = event.Color
	eventExpiry = os.clock() + MatchEvents.DisplaySeconds
end

-- Remotes.Get does two WaitForChild calls. Spawned rather than awaited so a
-- not-yet-replicated Remotes folder can't stall ClientBootstrap's remaining
-- requires -- the tick loop below is already nil-safe until this lands.
task.spawn(function()
	Remotes.Get("MatchEventAnnounce").OnClientEvent:Connect(onEventAnnounced)
end)

local function getMatchState(): string?
	local matchInfo = ReplicatedStorage:FindFirstChild("MatchInfo")
	if not matchInfo then
		return nil
	end
	return matchInfo:GetAttribute("MatchState")
end

local function tick()
	-- Gate on the flag, never on the state name. ShowsMatchTime is true for
	-- Playing only -- the clock is match-scoped and its anchors are cleared
	-- the moment Playing ends. Progress is clamped to 1, so the last frame
	-- drawn before that is a completely full bar.
	local state = getMatchState()
	if not state or not MatchStates.ShowsMatchTime(state) then
		MatchTimeHud.Hide()
		MatchTimeAnnouncer.Hide()
		-- Dropped, not just hidden: an announcement is about the match that is
		-- ending, so it must not reappear part-used when the next one starts.
		clearEvent()
		MatchEventAnnouncer.Hide()
		return
	end

	-- Anchors absent: the clock hasn't been published yet, or has been
	-- cleared. Either way there is no match time to draw -- hide rather than
	-- rendering a zeroed bar.
	local progress = MatchTimeClient.GetProgress()
	local hourText = MatchTimeClient.GetHourText()
	local hour = MatchTimeClient.GetHour()
	if not progress or not hourText or not hour then
		MatchTimeHud.Hide()
		MatchTimeAnnouncer.Hide()
		-- Hidden but NOT cleared: the match is still Playing, the anchors are
		-- just momentarily absent, so a live announcement resumes on the tick
		-- they come back rather than being lost.
		MatchEventAnnouncer.Hide()
		return
	end

	MatchTimeHud.Update(progress, hourText, hour)

	-- Same anchors, a second pure sample of the same clock -- not a second
	-- timer. Resolve is total-order over elapsedReal, so a schedule change
	-- (or a slow frame that skips several seconds) still lands on the right
	-- state next tick with no catch-up logic needed.
	local schedule = MatchTimeClient.GetSchedule()
	local elapsedReal = MatchTimeClient.GetElapsedReal()
	if schedule and elapsedReal then
		local text, color, font = MatchAnnouncerState.Resolve(schedule, elapsedReal)
		MatchTimeAnnouncer.Update(text, color, font)
	else
		MatchTimeAnnouncer.Hide()
	end

	-- Expiry is checked here rather than by a per-message task.delay so the
	-- message can't outlive the HUD it is drawn on, and so a message that
	-- arrived while the tab was throttled still clears on the first tick past
	-- its window instead of hanging around for a full extra 10 seconds.
	if eventText and os.clock() >= eventExpiry then
		clearEvent()
	end
	MatchEventAnnouncer.Update(eventText, eventColor)
end

RunService.Heartbeat:Connect(function(delta)
	tickAccumulator += delta
	if tickAccumulator < TICK_INTERVAL then
		return
	end
	tickAccumulator = 0
	tick()
end)

return {}
