-- Reserves a Game Server, builds the teleport payload (participant roster +
-- mode id), and teleports the group there. Handles ReserveServer/TeleportAsync
-- failure by reporting it back rather than teleporting a partial/broken group.
--
-- Codes returned below match keys in Shared/QueueResultCodes exactly -- see
-- that module for the display strings, same pattern as ShotResultCodes.
--
-- Phase 12.5 item 2: Launch() returning true only means TeleportAsync's
-- initial request was ACCEPTED, not that anyone arrived -- Roblox can still
-- fail the teleport asynchronously per player via TeleportInitFailed. By
-- then LaunchGate.OnLaunched has already fired (QueueService calls it right
-- after Launch returns true) and RewardLaunchHook has already released that
-- player's Lobby session. handleInitFailed below retries with the same
-- capped backoff as ReturnToLobbyService's inbound leg, reusing the exact
-- TeleportOptions Roblox handed back (same ReservedServerAccessCode, so a
-- retry still lands in the correct reserved server) -- and once retries are
-- exhausted, reports LaunchGate.OnLaunchAborted for that one player so
-- RewardLaunchHook can reacquire their session. No auto-requeue (roadmap
-- 4.3 already ruled on the sibling ReserveFailed case for the same reason:
-- don't hammer a Roblox-side outage) -- the client is told to queue again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local PlaceIds = require(ReplicatedStorage.Modules.Shared.PlaceIds)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)

local LaunchGate = require(script.Parent.LaunchGate)

local MatchLauncher = {}

-- Same capped backoff as Match/ReturnToLobbyService.luau's RETRY_DELAYS_SECONDS.
local RETRY_DELAYS_SECONDS = { 2, 5, 10 }
local retryAttempts: { [number]: number } = {} -- [userId] = attempts so far

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

-- Only fires for a placeId this module itself teleports to -- Launch is the
-- only teleport-initiating call on the Lobby (ReturnToLobbyService's own
-- TeleportInitFailed handling is the Game place's inbound leg), so nothing
-- else could produce this event here.
local function handleInitFailed(player: Player, _teleportResult, message: string, placeId: number, teleportOptions: TeleportOptions)
	if placeId ~= PlaceIds.Game then
		return
	end

	local attempt = (retryAttempts[player.UserId] or 0) + 1
	retryAttempts[player.UserId] = attempt

	local delaySeconds = RETRY_DELAYS_SECONDS[attempt]
	if not delaySeconds then
		warn(("MatchLauncher: %s failed to launch after %d attempts (%s) -- giving up, reverting their reward session"):format(
			player.Name, attempt, tostring(message)))
		retryAttempts[player.UserId] = nil
		LaunchGate.OnLaunchAborted({ player })
		Remotes.Get("QueueResult"):FireClient(player, "TeleportInitFailed")
		return
	end

	warn(("MatchLauncher: %s's launch teleport failed (%s), retrying in %ds"):format(
		player.Name, tostring(message), delaySeconds))
	task.delay(delaySeconds, function()
		if player.Parent then
			-- Reuses the exact TeleportOptions Roblox handed back, including
			-- its ReservedServerAccessCode -- this player still lands in the
			-- same reserved server the rest of their launch batch went to.
			local ok, err = pcall(function()
				TeleportService:TeleportAsync(placeId, { player }, teleportOptions)
			end)
			if not ok then
				warn("MatchLauncher: retry TeleportAsync itself failed:", err)
			end
		end
	end)
end

local started = false

function MatchLauncher.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertLobbyServer()

	TeleportService.TeleportInitFailed:Connect(handleInitFailed)

	Players.PlayerRemoving:Connect(function(player)
		retryAttempts[player.UserId] = nil
	end)
end

return MatchLauncher
