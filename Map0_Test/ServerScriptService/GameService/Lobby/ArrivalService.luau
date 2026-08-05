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

	-- roster survives the TeleportData JSON round-trip intact (integer
	-- userId keys would not -- see summary.perPlayer's own note in
	-- MatchResultBuilder). The Arrival variant renders only the roster
	-- scoreboard, so perPlayer isn't needed here at all -- Match/MatchStats'
	-- grade and personal-stats block is the in-match receipt's job, not the
	-- arrival one's.
	local roster = summary.roster or {}

	local resultSync = Remotes.Get("MatchResultSync")
	resultSync:FireClient(player, {
		resultCode = summary.resultCode,
		durationSeconds = summary.durationSeconds,
		roster = roster,
		-- Tells MatchReceipt to show the scoreboard regardless of roster
		-- size (a solo run still deserves to see its own Score/XP), and to
		-- never show the grade/personal-stats block or the Return button --
		-- there's nothing left to return FROM once you're already back.
		variant = "Arrival",
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
