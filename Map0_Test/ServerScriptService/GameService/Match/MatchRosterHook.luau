-- Registers the "Player" MatchResultBuilder contributor: each participant's
-- display name, captured at Ending.
--
-- The end-of-match scoreboard can't resolve names client-side. On the Game
-- place it nearly could (everyone is still connected), but the same receipt
-- is shown again after the teleport back to the Lobby -- where the other
-- participants are in a different server, or gone. A name resolved at
-- Ending and carried in the payload works on both screens; a client-side
-- Players:GetPlayerByUserId only works on one of them.
--
-- A contributor rather than a field inside MatchResultBuilder, so R2 holds:
-- adding data to the summary never edits the builder.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchResultBuilder = require(script.Parent.MatchResultBuilder)

local MatchRosterHook = {}

local started = false

function MatchRosterHook.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	MatchResultBuilder.RegisterContributor("Player", function(userId: number)
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			-- Already disconnected. Returning nil leaves this slice out
			-- entirely; the scoreboard falls back to the userId.
			return nil
		end

		return {
			name = player.DisplayName ~= "" and player.DisplayName or player.Name,
		}
	end)
end

return MatchRosterHook
