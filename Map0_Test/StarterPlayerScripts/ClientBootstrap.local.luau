-- Boots client subsystems that have no natural first caller of their own --
-- previously these were required as a side effect of CameraSession loading,
-- which meant an unrelated failure in either of them (e.g. the objective
-- remote never replicating) could take the camera down with it. Now they
-- boot independently, at game start, regardless of whether the player has
-- ever touched a camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Modules.Flash.FlashRenderers)
require(ReplicatedStorage.Modules.Objective.ObjectiveVisualsController)
-- Pickup visuals (idle spin + light pillar) are purely cosmetic and place-
-- agnostic -- boots on both places, regardless of match state. The
-- ProximityPrompt and any actual grant stay Game-place + active-match gated
-- server-side (PickupRegistry/PickupService/PickupHandlers), so a pickup
-- placed on the Lobby spins and glows but is never interactable and never
-- pays out.
require(ReplicatedStorage.Modules.Pickup.PickupVisualsController)

-- Mirrors the server-side role branch in Bootstrap.legacy.luau.
local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)

if ServerRole.Is("LobbyServer") then
	require(ReplicatedStorage.Modules.UI.MatchReceiptController)
	require(ReplicatedStorage.Modules.Queue.QueueController)
	require(ReplicatedStorage.Modules.Queue.QueuePadDisplay)
elseif ServerRole.Is("GameServer") then
	-- First in the branch, for its side effects, same convention as every
	-- other controller here (DeathScreenController et al.): it acquires
	-- ControlLock immediately on require, so no other controller below can
	-- plausibly grab input before the curtain has a chance to lock it.
	require(ReplicatedStorage.Modules.UI.LoadingController)
	require(ReplicatedStorage.Modules.UI.DeathScreenController)
	require(ReplicatedStorage.Modules.Spectate.SpectateController)
	require(ReplicatedStorage.Modules.UI.MatchReceiptController)
	-- Game place only: the match clock exists for the duration of a match and
	-- nowhere else, so the Lobby never builds this HUD. (It would fail safe
	-- anyway -- the Lobby has no MatchInfo folder, so the controller would
	-- find no anchors and stay hidden -- but not requiring it is the actual
	-- guarantee.)
	require(ReplicatedStorage.Modules.MatchTime.MatchTimeHudController)
	-- Game place only, same reasoning as the clock: the Mission List is
	-- match-scoped shared progress and the Lobby has no MatchInfo mission
	-- attributes to read.
	require(ReplicatedStorage.Modules.Mission.MissionHudController)
	-- Game place only: ExitDwellSync is only ever fired by ExitService, which
	-- asserts GameServer. The Lobby provisions the remote (so the two trees
	-- stay byte-identical) but nothing there ever fires it.
	require(ReplicatedStorage.Modules.Exit.ExitCountdownController)
end
