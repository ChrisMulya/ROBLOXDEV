-- Read-only mirror of the local player's state, client-side. Reads the
-- PlayerState attribute set by the server's PlayerStateReplicator -- never
-- sets it. One source of truth: the client computes what to show from
-- state; the server never sends a "ShowDeathScreen" command (plan
-- section 12, rule 3).

local Players = game:GetService("Players")
local Signal = require(script.Parent.Signal)

local PlayerStateClient = {}

local localPlayer = Players.LocalPlayer

PlayerStateClient.Changed = Signal.new() -- fires (newState, oldState) for the local player

function PlayerStateClient.Get(player: Player?): string?
	player = player or localPlayer
	return player:GetAttribute("PlayerState")
end

local started = false

function PlayerStateClient.Start()
	if started then
		return
	end
	started = true

	local lastState = localPlayer:GetAttribute("PlayerState")
	localPlayer:GetAttributeChangedSignal("PlayerState"):Connect(function()
		local newState = localPlayer:GetAttribute("PlayerState")
		local oldState = lastState
		lastState = newState
		PlayerStateClient.Changed:Fire(newState, oldState)
	end)
end

return PlayerStateClient
