-- The authoritative roster: who was teleported into this match and is
-- expected, independent of who is currently connected -- a disconnected
-- participant is still a participant. Distinct from Players:GetPlayers().
--
-- Requires nothing but Players -- must not require PlayerStateService or
-- MatchManager. The one module allowed to correlate the roster with player
-- state is MatchEndCondition (Phase 7); this module only tracks presence.
-- CountActive() here means "participants currently present in the server",
-- not "participants in a PlayerStates.CountsAsActive state" -- that
-- PlayerState-aware correlation is explicitly MatchEndCondition's job, not
-- this module's, per the dependency rule above.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)

local MatchParticipants = {}

local expectedUserIds: { [number]: boolean } = {}

MatchParticipants.Joined = Signal.new() -- fires (player) when a seeded participant's Player instance is present

function MatchParticipants.Seed(userIds: { number })
	for _, userId in ipairs(userIds) do
		expectedUserIds[userId] = true
	end

	-- Anyone already present when Seed runs fires Joined immediately --
	-- boot order doesn't guarantee Seed runs before every participant's
	-- Player instance exists.
	for _, player in ipairs(Players:GetPlayers()) do
		if expectedUserIds[player.UserId] then
			MatchParticipants.Joined:Fire(player)
		end
	end
end

function MatchParticipants.All(): { number }
	local list = {}
	for userId in pairs(expectedUserIds) do
		table.insert(list, userId)
	end
	return list
end

function MatchParticipants.IsParticipant(player: Player): boolean
	return expectedUserIds[player.UserId] == true
end

function MatchParticipants.GetPresent(): { Player }
	local present = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if expectedUserIds[player.UserId] then
			table.insert(present, player)
		end
	end
	return present
end

function MatchParticipants.CountActive(): number
	return #MatchParticipants.GetPresent()
end

local started = false

function MatchParticipants.Start()
	if started then
		return
	end
	started = true

	Players.PlayerAdded:Connect(function(player)
		if expectedUserIds[player.UserId] then
			MatchParticipants.Joined:Fire(player)
		end
	end)
end

return MatchParticipants
