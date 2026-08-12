-- The catalog of announceable match events -- the shared contract between
-- MatchEventService (server, fires) and MatchTimeHudController (client,
-- renders).
--
-- The wire carries an event ID and nothing else. Text, colour and font are
-- resolved client-side from this table, so no server caller can push an
-- arbitrary string onto every player's screen, and the wording lives in one
-- place instead of being duplicated at each announcing call site.
--
-- Pure data + lookups: no instances, no services, no state. Same role
-- MatchAnnouncerState plays for the line above this one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage.Modules.UI.UITheme)

local MatchEvents = {}

-- Roblox's "Source Sans Pro" is exposed as Enum.Font.SourceSans -- there is no
-- SourceSansPro member on the enum. Named once here so every announced event
-- renders in the same face regardless of who announced it.
MatchEvents.Font = Enum.Font.SourceSans

-- Real seconds an announcement stays on screen before clearing itself. Real,
-- not match-time: this is a readability window for a human, so it must not
-- stretch or compress with the Debug schedule's time scale.
MatchEvents.DisplaySeconds = 10

export type MatchEvent = {
	Text: string,
	Color: Color3,
}

local events: { [string]: MatchEvent } = {
	AlternateExitOpened = {
		-- Deliberately vague about WHERE: exactly one of the map's alternate
		-- exits is live (ExitState rolls it at ExitConfig.AlternateUnlockHour)
		-- and finding out which one is the players' problem.
		Text = "An alternate exit is opened somewhere",
		Color = UITheme.Colors.Warning,
	},
}

MatchEvents.Events = events

-- nil for an unknown ID rather than an error: a stale client that doesn't know
-- a newly-added event should render nothing, not throw inside a remote handler.
function MatchEvents.Get(eventId: string?): MatchEvent?
	if typeof(eventId) ~= "string" then
		return nil
	end
	return MatchEvents.Events[eventId]
end

return MatchEvents
