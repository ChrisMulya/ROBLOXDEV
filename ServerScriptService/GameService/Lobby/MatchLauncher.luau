-- Reserves a Game Server, builds the teleport payload (participant roster +
-- mode id), and teleports the group there. Handles ReserveServer/TeleportAsync
-- failure by reporting it back rather than teleporting a partial/broken group.
--
-- No caller of its own yet -- Phase 9's QueueService calls this once a
-- threshold is met. Until then it's exercised directly (the "manual launch
-- button" the plan calls sufficient to exercise phases 1-8 end to end).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local PlaceIds = require(ReplicatedStorage.Modules.Shared.PlaceIds)

local MatchLauncher = {}

function MatchLauncher.Launch(players: { Player }, modeId: string?): (boolean, string)
	modeId = modeId or "Default"

	local placeId = PlaceIds.GameModes[modeId]
	if not placeId then
		return false, "UnknownMode"
	end

	if #players == 0 then
		return false, "NoPlayers"
	end

	local reserveOk, reserveResult = pcall(function()
		return TeleportService:ReserveServer(placeId)
	end)
	if not reserveOk then
		warn("MatchLauncher: ReserveServer failed:", reserveResult)
		return false, "ReserveFailed"
	end
	local accessCode = reserveResult

	local userIds = {}
	for _, player in ipairs(players) do
		table.insert(userIds, player.UserId)
	end

	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions.ReservedServerAccessCode = accessCode
	teleportOptions:SetTeleportData({
		participantUserIds = userIds,
		modeId = modeId,
	})

	local teleportOk, teleportErr = pcall(function()
		TeleportService:TeleportAsync(placeId, players, teleportOptions)
	end)
	if not teleportOk then
		warn("MatchLauncher: TeleportAsync failed:", teleportErr)
		return false, "TeleportFailed"
	end

	return true, "Launched"
end

local started = false

function MatchLauncher.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertLobbyServer()
end

return MatchLauncher
