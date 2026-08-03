-- Detects a player arriving from a completed match and relays the
-- non-authoritative summary receipt to the client, if TeleportData carried
-- one. Progression itself needs no action here -- PlayerCurrency.legacy's
-- own PlayerAdded handler already calls RewardLedger.SetupPlayer for every
-- join regardless of origin, so the reload this module's name implies is
-- already automatic and unconditional. The receipt is display-only and is
-- never written back to the DataStore.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)

local ArrivalService = {}

local function handleArrival(player: Player)
	local joinData = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData
	local summary = teleportData and teleportData.summary
	if not summary then
		return
	end

	local perPlayer = (summary.perPlayer and summary.perPlayer[player.UserId]) or {}
	local resultSync = Remotes.Get("MatchResultSync")
	resultSync:FireClient(player, {
		resultCode = summary.resultCode,
		durationSeconds = summary.durationSeconds,
		perPlayer = perPlayer,
	})
end

local started = false

function ArrivalService.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertLobbyServer()

	for _, player in ipairs(Players:GetPlayers()) do
		handleArrival(player)
	end

	Players.PlayerAdded:Connect(handleArrival)
end

return ArrivalService
