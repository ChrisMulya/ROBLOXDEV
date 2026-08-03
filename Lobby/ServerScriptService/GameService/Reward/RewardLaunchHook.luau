-- The third instance of the RewardCleanupHook pattern: registers into
-- another layer's registry from its own Start(), rather than at module
-- scope, so the registration's existence depends only on this file being in
-- LobbyBoot's list. Lives in Reward/ (feature layer) despite requiring down
-- into Lobby/LaunchGate, same shape as RewardCleanupHook/RewardResultHook
-- requiring down into Match/.
--
-- Registers the Progression precondition: confirms every candidate's Lobby
-- session is genuinely active, then forces their save to complete before the
-- teleport (converts the cross-server race into a happens-before -- Save now
-- waits on ProfileStore's own confirmation, see RewardStore.Save).
--
-- Phase 12 change: no longer marks anyone "handed off", and registers no
-- rollback. ProfileStore's session lock means the Lobby's session for a
-- candidate simply STAYS active/exclusive through a failed Check or a failed
-- Launch -- there is nothing to undo. Instead, registers an OnLaunched
-- handler that only fires once MatchLauncher.Launch has actually succeeded,
-- releasing the session for real (RewardStore.ClearSession -> Profile:
-- EndSession) now that it's certain those players are leaving this server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local RewardStore = require(script.Parent.RewardStore)
local RewardLedger = require(script.Parent.RewardLedger)
local LaunchGate = require(script.Parent.Parent.Lobby.LaunchGate)

local RewardLaunchHook = {}

-- Concurrent, not sequential: RewardStore.Save waits (bounded, see its own
-- SAVE_CONFIRM_TIMEOUT_SECONDS) for a real ProfileStore confirmation per
-- player, so saving N candidates one at a time could take N times that
-- long. Same task.spawn + BindableEvent shape as RewardStore.SaveAll.
local function checkProgression(players: { Player }): (boolean, string)
	for _, player in ipairs(players) do
		if not RewardStore.IsReady(player) then
			return false, "ProgressionNotReady"
		end
	end

	local results: { [Player]: boolean } = {}
	local pending = #players
	local done = Instance.new("BindableEvent")

	for _, player in ipairs(players) do
		task.spawn(function()
			results[player] = RewardStore.Save(player, RewardLedger.CurrentPersistentValues(player))
			pending -= 1
			if pending == 0 then
				done:Fire()
			end
		end)
	end

	if pending > 0 then
		done.Event:Wait()
	end
	done:Destroy()

	for _, player in ipairs(players) do
		if not results[player] then
			return false, "ProgressionSaveFailed"
		end
	end

	return true, "Ok"
end

local function onLaunched(players: { Player })
	for _, player in ipairs(players) do
		RewardStore.ClearSession(player)
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
	LaunchGate.RegisterOnLaunched("Progression", onLaunched)
end

return RewardLaunchHook
