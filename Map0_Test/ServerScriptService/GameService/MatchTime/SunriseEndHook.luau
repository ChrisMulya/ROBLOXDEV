-- Ends the match at 6 AM. Replaces MatchClock's deleted runPlaying as the
-- "the match ran out of time" authority -- but the time it reads is the
-- schedule's, not a second countdown of its own.
--
-- Adds no new ending system: it calls MatchManager.RequestEnd and the
-- existing Ending -> Cleanup -> Finished chain does the rest.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local PlayerStates = require(ReplicatedStorage.Modules.Shared.PlayerStates)

local MatchManager = require(script.Parent.Parent.Match.MatchManager)
local MatchParticipants = require(script.Parent.Parent.Match.MatchParticipants)
local PlayerStateService = require(script.Parent.Parent.PlayerState.PlayerStateService)
local MatchTimeService = require(script.Parent.MatchTimeService)

local SunriseEndHook = {}

local RESULT_CODE = "Sunrise"

-- Order matters, and there must be no yield between the two halves.
--
-- RequestEnd FIRST: MatchEndCondition fires RequestEnd("AllPlayersDown") as
-- soon as nobody counts as active. If the kills landed first that would win
-- the race and stamp the wrong resultCode -- "everyone died" instead of "you
-- reached sunrise", a meaningfully different outcome to the player. Ending
-- first makes MatchEndCondition's later call the idempotent no-op it was
-- designed to be.
--
-- No yield between them: Signal:Fire is deferred (gotcha G11), so staying in
-- one uninterrupted resumption means the transition is committed before any
-- deferred StateChanged handler can observe a half-applied sunrise.
--
-- The kills then land while the match is already Ending, where
-- MatchStates.RespawnsOnDeath is false -- that flag is what stops
-- DeathService respawning every eliminated player under the result receipt.
local function onCompleted()
	if not MatchManager.Is("Playing") then
		-- The match already ended some other way (everyone died at 5:59).
		-- Nothing to do -- the clock reaching 6 AM is now just trivia.
		return
	end

	MatchManager.RequestEnd(RESULT_CODE)

	for _, userId in ipairs(MatchParticipants.All()) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local state = PlayerStateService.Get(player)
			-- Skip anyone already Dead/Spectating/Disconnected: they are not
			-- survivors, and re-killing them would be a no-op at best.
			if state and PlayerStates.CountsAsActive(state) then
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.Health = 0
				else
					-- No character to kill (mid-respawn, or never loaded).
					-- Move the state directly so the roster still reflects
					-- that they did not survive.
					PlayerStateService.Set(player, "Dead", "SunriseNoCharacter")
				end
			end
		end
	end
end

local started = false

function SunriseEndHook.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	MatchTimeService.Completed:Connect(onCompleted)
end

return SunriseEndHook
