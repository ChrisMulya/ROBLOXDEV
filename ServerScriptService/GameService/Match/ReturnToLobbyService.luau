-- Teleports everyone home once the match reaches Finished, then lets the
-- server drain and destroy itself naturally -- Roblox destroys an empty
-- reserved server automatically; there is no "shut down now" API. A watchdog
-- force-kicks any stragglers if the return teleport hasn't emptied the
-- server after a grace period, so the server always empties.
--
-- Must not teleport before Cleanup has actually saved -- it only ever reacts
-- to "Finished", which MatchCleanup reaches only after every registered save
-- step has resolved. Must not compute rewards; it only relays the
-- already-built MatchResultBuilder result as a display-only receipt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local PlaceIds = require(ReplicatedStorage.Modules.Shared.PlaceIds)

local MatchManager = require(script.Parent.MatchManager)
local MatchResultBuilder = require(script.Parent.MatchResultBuilder)

local ReturnToLobbyService = {}

local WATCHDOG_SECONDS = 30
-- Capped backoff for a player whose return teleport's init failed. Indexed
-- by attempt number; running out of entries means give up and kick.
local RETRY_DELAYS_SECONDS = { 2, 5, 10 }

-- TeleportAsync's data table is shared across the whole batch (there's no
-- per-player slot in a single call), so the full perPlayer table rides
-- along and ArrivalService picks out each player's own slice server-side --
-- no information leaks to the wrong client, and this avoids one TeleportAsync
-- call per player.
local function buildTeleportData()
	return { summary = MatchResultBuilder.Build() }
end

local function attemptReturn(players: { Player })
	if #players == 0 then
		return
	end

	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions:SetTeleportData(buildTeleportData())

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(PlaceIds.Lobby, players, teleportOptions)
	end)
	if not ok then
		warn("ReturnToLobbyService: TeleportAsync failed:", err)
	end
end

local retryAttempts: { [number]: number } = {} -- [userId] = attempts so far

local function handleInitFailed(player: Player, _teleportResult, message: string, placeId: number)
	if placeId ~= PlaceIds.Lobby then
		return
	end

	local attempt = (retryAttempts[player.UserId] or 0) + 1
	retryAttempts[player.UserId] = attempt

	local delaySeconds = RETRY_DELAYS_SECONDS[attempt]
	if not delaySeconds then
		warn(("ReturnToLobbyService: %s failed to return after %d attempts (%s) -- kicking"):format(
			player.Name, attempt, tostring(message)))
		player:Kick("Could not return you to the lobby -- please rejoin.")
		return
	end

	warn(("ReturnToLobbyService: %s's return teleport failed (%s), retrying in %ds"):format(
		player.Name, tostring(message), delaySeconds))
	task.delay(delaySeconds, function()
		if player.Parent then
			attemptReturn({ player })
		end
	end)
end

function ReturnToLobbyService.ReturnAll()
	attemptReturn(Players:GetPlayers())

	task.delay(WATCHDOG_SECONDS, function()
		local remaining = Players:GetPlayers()
		if #remaining > 0 then
			warn("ReturnToLobbyService: watchdog elapsed with players still present -- force-kicking to empty the server")
			for _, player in ipairs(remaining) do
				player:Kick("Match ended -- please rejoin the lobby.")
			end
		end
	end)
end

local started = false

function ReturnToLobbyService.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	TeleportService.TeleportInitFailed:Connect(handleInitFailed)

	MatchManager.StateChanged:Connect(function(newState: string)
		if newState == "Finished" then
			ReturnToLobbyService.ReturnAll()
		end
	end)
end

return ReturnToLobbyService
