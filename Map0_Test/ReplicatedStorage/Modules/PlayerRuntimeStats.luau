-- Client-only mutable runtime state, split out of PlayerStats. PlayerStats is
-- now purely shared tuning constants (WalkSpeed, MaxStamina, StaminaDrainRate,
-- ...); Stamina itself changes every frame while sprinting/regenerating and
-- was, before this split, one value shared by every player on the server
-- (PlayerStats is required on both sides) with no guard stopping
-- PlayerStats.Set("WalkSpeed", 0) either. Nothing server-side reads Stamina,
-- so this only needs to exist on the client.
--
-- Stamina here is now a client-side *mirror* of server state, written only by
-- PlayerMovementController's StaminaSync handler. CharacterMovementService
-- owns the real value. Treat it as display state, never as an authority, and
-- do not simulate it here -- a second implementation of the drain/regen rule
-- is what made the bar appear frozen while the two sides disagreed.

local PlayerRuntimeStats = {}

-- Fires (statName: string, newValue: number, oldValue: number), same shape as
-- PlayerStats.Changed used to.
local changedEvent = Instance.new("BindableEvent")
PlayerRuntimeStats.Changed = changedEvent.Event

local state: { [string]: number } = {}

function PlayerRuntimeStats.Get(statName: string): number?
	return state[statName]
end

function PlayerRuntimeStats.Set(statName: string, value: number)
	local oldValue = state[statName]
	if oldValue == value then
		return
	end
	state[statName] = value
	changedEvent:Fire(statName, value, oldValue)
end

-- maxValue is passed in explicitly rather than looked up by convention
-- (PlayerStats used a "Max" .. statName string build every call) -- callers
-- already know their own cap.
function PlayerRuntimeStats.Add(statName: string, delta: number, maxValue: number?): number
	local current = state[statName] or 0
	local newValue = current + delta
	if maxValue then
		newValue = math.clamp(newValue, 0, maxValue)
	end
	if newValue == current then
		return newValue
	end
	state[statName] = newValue
	changedEvent:Fire(statName, newValue, current)
	return newValue
end

return PlayerRuntimeStats
