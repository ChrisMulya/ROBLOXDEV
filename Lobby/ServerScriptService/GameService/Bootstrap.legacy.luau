-- Boots the objective modules that used to load as a side effect of
-- PlayerCurrency requiring them. Previously deleting a file named "currency"
-- silently broke every objective (ObjectiveService never wired the Reward
-- seams) and hung objective replication -- two unrelated failure domains
-- fused to one file by name accident. RewardLedger stays required directly
-- by PlayerCurrency, which actually calls RewardLedger.SetupPlayer/
-- TeardownPlayer -- that was never a side-effect-only require.
--
-- Also provisions every RemoteEvent up front (Remotes.Init()), before
-- anything else on the server can call Remotes.Get() and block on a folder
-- that doesn't exist yet.
--
-- Roblox does not guarantee Script execution order, so this is not a
-- traditional ordered bootstrap -- it exists to decouple these three
-- modules' boot from an unrelated file, not to sequence them relative to
-- the other five Scripts in GameService. require() is synchronous and
-- memoized, so it makes no difference whether this Script or PlayerCurrency
-- happens to run first.
--
-- The role branch below is the exception: LobbyBoot/GameBoot hold an
-- ORDERED service list (see plans/planning-mode-do-not-rustling-firefly.md,
-- Service lifecycle convention) because the match rearchitecture has
-- services that subscribe to each other's Signals at boot, where require
-- order silently mattering would be a bug with no error message. That's a
-- convention for new services only -- the two requires below are untouched.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
Remotes.Init()

require(ServerScriptService.GameService.Objective.ObjectiveService)
require(ServerScriptService.GameService.Objective.ObjectiveReplicator)

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)

if ServerRole.Is("LobbyServer") then
	require(ServerScriptService.GameService.Boot.LobbyBoot).Start()
elseif ServerRole.Is("GameServer") then
	require(ServerScriptService.GameService.Boot.GameBoot).Start()
end
