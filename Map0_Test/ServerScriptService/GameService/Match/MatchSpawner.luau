-- Loads a character for each match participant. Character loading is a
-- Match-layer concern (participants existing in the server as embodied
-- players), not a feature -- requires nothing above MatchParticipants (R2/R3).
--
-- With CharacterAutoLoads = false (GameBoot), nothing else calls
-- LoadCharacter for an arriving participant -- MatchParticipants.Joined was
-- built for exactly this and had zero subscribers until this module. Without
-- it, a teleported player arrives as a disembodied camera and the match can
-- never end (MatchEndCondition needs a Humanoid to die with).
--
-- Reacts to MatchArrival.Seeded rather than StateChanged -> WaitingForPlayers
-- now: the match loading screen spawns characters DURING Loading, under the
-- curtain, so the pop-in and camera snap never reach the player's screen.
-- Loading.AcceptsJoins is true precisely so the MatchParticipants.Joined
-- backfill below still fires for a participant who joins mid-Loading.
--
-- Respawn after death is deliberately NOT this module's job -- DeathService
-- calls LoadCharacter itself for a death outside GameplayActive, and a death
-- during Playing is meant to leave the player Dead/Spectating until the
-- match ends, not respawn them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local MatchManager = require(script.Parent.MatchManager)
local MatchParticipants = require(script.Parent.MatchParticipants)
local MatchArrival = require(script.Parent.MatchArrival)

local MatchSpawner = {}

local function loadIfNeeded(player: Player)
	if not player.Character then
		player:LoadCharacter()
	end
end

local started = false

function MatchSpawner.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	MatchArrival.Seeded:Connect(function()
		for _, player in ipairs(MatchParticipants.GetPresent()) do
			loadIfNeeded(player)
		end
	end)

	-- MatchParticipants.Joined's first subscriber ever -- covers a
	-- participant whose Player instance appears after Seeded already fired.
	-- Non-participants never fire Joined (it only tracks seeded userIds), so
	-- they never get a character here -- explicit, not accidental:
	-- MatchStates.AcceptsJoins gates whether that's expected.
	MatchParticipants.Joined:Connect(function(player: Player)
		if MatchStates.AcceptsJoins(MatchManager.Get()) then
			loadIfNeeded(player)
		end
	end)
end

return MatchSpawner
