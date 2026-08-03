-- The third instance of the RewardCleanupHook pattern: registers into
-- another layer's registry from its own Start(), rather than at module
-- scope, so the registration's existence depends only on this file being in
-- LobbyBoot's list. Lives in Reward/ (feature layer) despite requiring down
-- into Lobby/LaunchGate, same shape as RewardCleanupHook/RewardResultHook
-- requiring down into Match/.
--
-- Registers the Progression precondition (session-lock cheap gate, roadmap
-- decision 1): confirms every candidate's Lobby session actually loaded,
-- forces their save to complete before the teleport (converts the
-- cross-server race into a happens-before), then marks them HandedOff so no
-- other writer touches their session while the teleport is in flight.
--
-- Also registers the matching rollback: if a later precondition fails, or
-- MatchLauncher.Launch itself fails, LaunchGate.Rollback un-hands-off every
-- candidate this hook actually marked -- ClearHandoff is a no-op for anyone
-- it didn't touch, so it's safe to call over the whole candidate list.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local RewardStore = require(script.Parent.RewardStore)
local RewardLedger = require(script.Parent.RewardLedger)
local LaunchGate = require(script.Parent.Parent.Lobby.LaunchGate)

local RewardLaunchHook = {}

local function checkProgression(players: { Player }): (boolean, string)
	for _, player in ipairs(players) do
		if not RewardStore.IsReady(player) then
			return false, "ProgressionNotReady"
		end
	end

	for _, player in ipairs(players) do
		if not RewardStore.Save(player, RewardLedger.CurrentPersistentValues(player)) then
			return false, "ProgressionSaveFailed"
		end
		RewardStore.MarkHandedOff(player)
	end

	return true, "Ok"
end

local function rollbackProgression(players: { Player })
	for _, player in ipairs(players) do
		RewardStore.ClearHandoff(player)
	end
end

local started = false

function RewardLaunchHook.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertLobbyServer()

	LaunchGate.RegisterPrecondition("Progression", checkProgression)
	LaunchGate.RegisterRollback("Progression", rollbackProgression)
end

return RewardLaunchHook
