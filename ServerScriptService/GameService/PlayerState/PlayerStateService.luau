-- Player state only. Owns the per-player state map and the transition guard
-- against PlayerStates.Transitions. Must not know WHY a state changed --
-- DeathService (Phase 5) will call Set(player, "Dead", ...) and this module
-- has no idea what a monster is. Must not touch remotes or attributes --
-- that's PlayerStateReplicator's job (state managers don't self-replicate).
-- Runs on both places.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStates = require(ReplicatedStorage.Modules.Shared.PlayerStates)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)

local PlayerStateService = {}

local INITIAL_STATE = "Alive"

local states: { [number]: string } = {}

PlayerStateService.StateChanged = Signal.new() -- fires (player, newState, oldState, reason?)

function PlayerStateService.Get(player: Player): string?
	return states[player.UserId]
end

function PlayerStateService.Is(player: Player, state: string): boolean
	return states[player.UserId] == state
end

function PlayerStateService.GetAll(): { [number]: string }
	local snapshot = {}
	for userId, state in pairs(states) do
		snapshot[userId] = state
	end
	return snapshot
end

-- Only ever server-initiated. Rejects illegal transitions and returns
-- false; never silently coerces to something adjacent.
function PlayerStateService.Set(player: Player, state: string, reason: string?): boolean
	if not PlayerStates.IsValid(state) then
		warn(("PlayerStateService.Set: '%s' is not a valid PlayerState"):format(tostring(state)))
		return false
	end

	local userId = player.UserId
	local current = states[userId]
	if current == nil then
		warn(("PlayerStateService.Set: %s has not been seeded yet"):format(player.Name))
		return false
	end

	if not PlayerStates.CanTransition(current, state) then
		warn(("PlayerStateService.Set: illegal transition %s -> %s for %s"):format(current, state, player.Name))
		return false
	end

	states[userId] = state
	PlayerStateService.StateChanged:Fire(player, state, current, reason)
	return true
end

local function seed(player: Player)
	if states[player.UserId] ~= nil then
		return
	end
	states[player.UserId] = INITIAL_STATE
	PlayerStateService.StateChanged:Fire(player, INITIAL_STATE, nil, "Seeded")
end

-- PlayerRemoving prefers Disconnected (legal from every non-terminal state,
-- and keeps a reconnect possible) over Leaving. Choosing between the two
-- based on whether a match is still live (see plan section 6) is Phase 4's
-- job once MatchManager exists -- this module must not know what a match is.
local function onPlayerRemoving(player: Player)
	local current = states[player.UserId]
	if current == nil then
		return
	end

	if PlayerStates.CanTransition(current, "Disconnected") then
		PlayerStateService.Set(player, "Disconnected", "PlayerRemoving")
	elseif PlayerStates.CanTransition(current, "Leaving") then
		PlayerStateService.Set(player, "Leaving", "PlayerRemoving")
	end
end

local started = false

function PlayerStateService.Start()
	if started then
		return
	end
	started = true

	Players.PlayerAdded:Connect(seed)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Backfill players who joined before Start() ran. Shouldn't happen given
	-- boot order, but keeps Start() safe to call at any point, matching the
	-- repo's existing late-join catch-up convention (PlayerCurrency.legacy).
	for _, player in ipairs(Players:GetPlayers()) do
		seed(player)
	end
end

return PlayerStateService
