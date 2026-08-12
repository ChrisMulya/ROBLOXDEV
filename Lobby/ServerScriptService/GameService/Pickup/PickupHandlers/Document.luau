-- The Document pickup: a match-scoped mission collectible. Grants no
-- currency and no per-player state -- collecting one is the event itself,
-- and MissionProgress (subscribed to PickupService.Collected) owns the
-- shared count. Nothing here persists past the match: the instance is
-- destroyed by PickupService and the counter resets with the match.
--
-- Not gated on KitGiven the way Cash is -- that gate exists only because a
-- late kit grant could overwrite leaderstats.Cash, and this handler never
-- touches the wallet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local MatchManager = require(ServerScriptService.GameService.Match.MatchManager)
local MatchParticipants = require(ServerScriptService.GameService.Match.MatchParticipants)

local Document = {}

Document.Name = "Document"

function Document.CanCollect(player: Player, _instance: Instance, _typeDef: any): (boolean, string?)
	if not ServerRole.Is("GameServer") then
		return false, "NotInMatch"
	end
	if not MatchStates.IsScoringActive(MatchManager.Get()) then
		return false, "MatchNotActive"
	end
	if not MatchParticipants.IsParticipant(player) then
		return false, "NotInMatch"
	end
	return true, nil
end

function Document.Collect(_player: Player, _instance: Instance, _typeDef: any): (boolean, string?, number?)
	return true, "Success", 1
end

return Document
