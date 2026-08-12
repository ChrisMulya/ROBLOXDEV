-- The server end of the HUD's event announcer line. One entry point --
-- Announce(eventId) -- which validates the ID against the shared MatchEvents
-- catalog and broadcasts it to every client.
--
-- Owns no schedule and no policy: WHAT is announced and WHEN is entirely the
-- caller's business (see Exit/ExitAnnounceHook for the first one). That's the
-- same split MatchTimeEvents uses -- this module is the channel, not the
-- programme.
--
-- Deliberately not a per-player remote: every event on this line is
-- identical-for-everyone match news.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local MatchEvents = require(ReplicatedStorage.Modules.MatchTime.MatchEvents)

local MatchEventService = {}

local remote: RemoteEvent? = nil

-- An unknown ID warns and drops rather than erroring: callers are hooks
-- running under signal handlers, and a typo'd announcement must not take the
-- handler (and whatever else it was going to do) down with it.
function MatchEventService.Announce(eventId: string)
	if not MatchEvents.Get(eventId) then
		warn(("MatchEventService: unknown event id '%s' -- nothing announced"):format(tostring(eventId)))
		return
	end

	if not remote then
		warn("MatchEventService: Announce called before Start -- nothing announced")
		return
	end

	remote:FireAllClients(eventId)
end

local started = false

function MatchEventService.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	-- Resolved once at boot, for the same reason ExitService resolves
	-- ExitDwellSync there: Remotes.Get does a WaitForChild, and Announce is
	-- called from signal handlers that must stay yield-free.
	remote = Remotes.Get("MatchEventAnnounce")
end

return MatchEventService
