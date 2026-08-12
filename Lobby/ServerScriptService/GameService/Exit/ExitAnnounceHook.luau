-- Announces the Alternate exit opening on the HUD's event announcer line.
--
-- A hook rather than a call inside ExitState, for the same reason
-- ExitResultHook/ExitCleanupHook are hooks: deciding availability is
-- ExitState's job, telling players about it is not, and ExitState must not
-- grow a dependency on a presentation channel.
--
-- Fires on the availability flip, NOT at the unlock hour: the alternate is
-- rolled at hour 27 but stays shut until its requirement is met, and
-- announcing an exit that isn't open yet is a lie the players would walk
-- across the map to discover. The wording is deliberately vague about which
-- exit -- see MatchEvents.AlternateExitOpened.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)

local MatchManager = require(script.Parent.Parent.Match.MatchManager)
local MatchEventService = require(script.Parent.Parent.MatchTime.MatchEventService)
local ExitState = require(script.Parent.ExitState)

local ExitAnnounceHook = {}

local EVENT_ID = "AlternateExitOpened"

-- Once per match. ExitState.Changed fires for every mission-progress-driven
-- recompute, and the Alternate can flip back to unavailable if a requirement
-- stops being satisfied -- without this the line would flicker the same news
-- at players repeatedly.
local announced = false

local function onExitStateChanged()
	if announced then
		return
	end
	if not MatchManager.Is("Playing") then
		return
	end
	if not ExitState.IsAvailable("Alternate") then
		return
	end

	announced = true
	MatchEventService.Announce(EVENT_ID)
end

local started = false

function ExitAnnounceHook.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	ExitState.Changed:Connect(onExitStateChanged)

	-- Same reset trigger ExitState.Reset uses, so a second match on the same
	-- server announces its own alternate opening.
	MatchManager.StateChanged:Connect(function(newState: string)
		if newState == "WaitingForPlayers" then
			announced = false
		end
	end)
end

return ExitAnnounceHook
