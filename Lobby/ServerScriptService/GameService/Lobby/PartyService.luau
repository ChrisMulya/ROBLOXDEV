-- Unit abstraction only, per the roadmap's own scope call: no invite UI, no
-- party remotes yet. GetParty returning {player} for an unpartied player
-- makes "the queue takes parties as atomic units from day one" structurally
-- true at zero UI cost -- adding real invites later touches this file plus a
-- new controller; QueueService never changes.
--
-- Membership model: every player is implicitly the leader of their own
-- solo party until Join(player, leaderUserId) moves them under someone
-- else's. A leader disconnecting (PlayerRemoving) dissolves their party --
-- there is no reassignment policy yet because there is no UI to drive one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)

local PartyService = {}

PartyService.Changed = Signal.new() -- fires no payload; listeners re-read state

local leaderOf: { [number]: number } = {} -- [memberUserId] = leaderUserId, only set for non-leaders
local membersOf: { [number]: { number } } = {} -- [leaderUserId] = { memberUserId, ... }, excludes the leader themselves

local function removeFromCurrentParty(player: Player)
	local currentLeaderId = leaderOf[player.UserId]
	if currentLeaderId then
		local members = membersOf[currentLeaderId]
		if members then
			for i, memberUserId in ipairs(members) do
				if memberUserId == player.UserId then
					table.remove(members, i)
					break
				end
			end
			if #members == 0 then
				membersOf[currentLeaderId] = nil
			end
		end
		leaderOf[player.UserId] = nil
		return
	end

	-- player is themselves a leader with followers: dissolve, everyone goes solo.
	local members = membersOf[player.UserId]
	if members then
		for _, memberUserId in ipairs(members) do
			leaderOf[memberUserId] = nil
		end
		membersOf[player.UserId] = nil
	end
end

function PartyService.GetLeader(player: Player): Player?
	local leaderUserId = leaderOf[player.UserId]
	if not leaderUserId then
		return player
	end
	return Players:GetPlayerByUserId(leaderUserId)
end

function PartyService.IsLeader(player: Player): boolean
	return PartyService.GetLeader(player) == player
end

function PartyService.GetParty(player: Player): { Player }
	local leader = PartyService.GetLeader(player)
	if not leader then
		return { player }
	end

	local result = { leader }
	for _, memberUserId in ipairs(membersOf[leader.UserId] or {}) do
		local member = Players:GetPlayerByUserId(memberUserId)
		if member then
			table.insert(result, member)
		end
	end
	return result
end

function PartyService.Join(player: Player, leaderUserId: number): (boolean, string)
	if leaderUserId == player.UserId then
		return false, "InvalidRequest"
	end

	local leader = Players:GetPlayerByUserId(leaderUserId)
	if not leader then
		return false, "InvalidRequest"
	end

	-- Joining a follower folds into that follower's own leader instead --
	-- there is only ever one leader per party.
	local resolvedLeader = PartyService.GetLeader(leader)
	if resolvedLeader == player then
		return false, "InvalidRequest" -- would create a two-leader cycle
	end

	removeFromCurrentParty(player)

	membersOf[resolvedLeader.UserId] = membersOf[resolvedLeader.UserId] or {}
	table.insert(membersOf[resolvedLeader.UserId], player.UserId)
	leaderOf[player.UserId] = resolvedLeader.UserId

	PartyService.Changed:Fire()
	return true, "Ok"
end

function PartyService.Leave(player: Player): (boolean, string)
	if PartyService.IsLeader(player) and not membersOf[player.UserId] then
		return false, "NotInParty"
	end

	removeFromCurrentParty(player)
	PartyService.Changed:Fire()
	return true, "Ok"
end

local function onPlayerRemoving(player: Player)
	removeFromCurrentParty(player)
end

local started = false

function PartyService.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertLobbyServer()

	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return PartyService
