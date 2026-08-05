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
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local Cooldown = require(ReplicatedStorage.Modules.Shared.Cooldown)

local MatchManager = require(script.Parent.MatchManager)
local MatchResultBuilder = require(script.Parent.MatchResultBuilder)

local ReturnToLobbyService = {}

local WATCHDOG_SECONDS = 30
-- Capped backoff for a player whose return teleport's init failed. Indexed
-- by attempt number; running out of entries means give up and kick.
local RETRY_DELAYS_SECONDS = { 2, 5, 10 }

-- TeleportAsync's data table is shared across the whole batch (there's no
-- per-player slot in a single call), so the whole summary rides along and
-- ArrivalService fans it out server-side -- one call instead of one per
-- returning player.
--
-- The summary is deliberately not private: `roster` carries every
-- participant's name/score/XP so the arrival receipt can show the same
-- end-of-match scoreboard the in-match screen showed. Anything genuinely
-- per-player-secret must NOT be added to a contributor slice, because every
-- participant receives all of them.
local function buildTeleportData()
	return { summary = MatchResultBuilder.Build() }
end

-- [userId] = true while a return teleport for that player is outstanding
-- (queued via TeleportAsync, including its retry chain). Prevents the manual
-- ReturnToLobbyRequest handler from double-firing a teleport for a player
-- who already clicked once, or from racing ReturnAll() at Finished.
local returningPlayers: { [number]: boolean } = {}

local function attemptReturn(players: { Player })
	if #players == 0 then
		return
	end

	for _, player in ipairs(players) do
		returningPlayers[player.UserId] = true
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

-- States in which an early manual return is meaningful: too early
-- (WaitingForPlayers/Countdown/Playing) means there's no result to show yet
-- and nothing to return FROM; ReturnAll() already owns Finished, this just
-- lets an individual player jump the automatic 60s Ending hold.
local ALLOWED_RETURN_STATES = { Ending = true, Cleanup = true, Finished = true }

-- Rate-limited per player so a spammed click (or a resent client event)
-- can't queue duplicate TeleportAsync calls before returningPlayers catches
-- up -- the flag above is the real guard, this is just cheap backpressure.
local requestCooldown = Cooldown.new(3)

local function handleReturnRequest(player: Player)
	if not ALLOWED_RETURN_STATES[MatchManager.Get()] then
		return
	end
	if returningPlayers[player.UserId] then
		return
	end
	if not requestCooldown:Check(player.UserId) then
		return
	end
	attemptReturn({ player })
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
	Remotes.Get("ReturnToLobbyRequest").OnServerEvent:Connect(handleReturnRequest)

	MatchManager.StateChanged:Connect(function(newState: string)
		if newState == "Finished" then
			ReturnToLobbyService.ReturnAll()
		end
	end)
end

return ReturnToLobbyService
