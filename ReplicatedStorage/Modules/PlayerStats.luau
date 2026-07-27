-- PlayerStats ModuleScript
-- Place in: ReplicatedStorage.Modules (so both server and client can require it)
--
-- Central place for every tunable player stat so other systems (movement,
-- combat, UI, etc.) read/write the same numbers instead of hardcoding values
-- scattered across scripts. Add new stats here and everything else can use
-- PlayerStats.Get/Set/Add without needing to know where the number lives.

local PlayerStats = {}

-- Fires (statName: string, newValue: number, oldValue: number) any time Set/Add
-- actually changes a value. Lets HUDs and other systems react instead of polling.
local changedEvent = Instance.new("BindableEvent")
PlayerStats.Changed = changedEvent.Event
	
-- ===== Movement =====
PlayerStats.WalkSpeed   = 16     -- studs/sec, normal top speed
PlayerStats.SprintSpeed = 25      -- studs/sec, top speed while sprinting
PlayerStats.JumpHeight = 4        -- studs; Roblox's default is 7.2
PlayerStats.AccelRate   = 18      -- higher = snappier ramp-up to top speed while input is held
PlayerStats.DecelRate   = 5       -- lower = longer slide-to-stop after input is released
PlayerStats.MaxAxisForce = 100000 -- LinearVelocity force cap on X/Z
PlayerStats.BaseFOV      = 70     -- degrees, normal camera field of view
PlayerStats.SprintFOV    = 80     -- degrees, camera field of view while sprinting
PlayerStats.FOVChangeRate = 8     -- higher = faster FOV transition in/out of sprint
PlayerStats.MaxCameraTilt = 2     -- degrees, camera roll at full left/right strafe
PlayerStats.CameraTiltRate = 3    -- higher = snappier tilt response to strafing

-- ===== Stamina =====
PlayerStats.MaxStamina        = 100
PlayerStats.Stamina           = 100
PlayerStats.StaminaDrainRate  = 15   -- per second while sprinting
PlayerStats.StaminaRegenRate  = 10   -- per second while not sprinting
PlayerStats.MinStaminaToSprint = 15   -- can't start sprinting below this

-- ===== Money =====
PlayerStats.StartingCash = 100

-- Generic getter/setter so other scripts never poke the table directly.
-- Gives us one place to add validation, clamping, or change-events later.
function PlayerStats.Get(statName: string): number?
	return PlayerStats[statName]
end

function PlayerStats.Set(statName: string, value: number)
	local oldValue = PlayerStats[statName]
	if oldValue == nil then
		warn(("PlayerStats.Set: unknown stat '%s'"):format(statName))
		return
	end
	if oldValue == value then return end
	PlayerStats[statName] = value
	changedEvent:Fire(statName, value, oldValue)
end

-- Adds delta to a stat, auto-clamping to [0, MaxX] if a "MaxX" counterpart exists
-- (works for Stamina/MaxStamina automatically).
function PlayerStats.Add(statName: string, delta: number): number?
	local current = PlayerStats[statName]
	if current == nil then
		warn(("PlayerStats.Add: unknown stat '%s'"):format(statName))
		return nil
	end

	local newValue = current + delta
	local maxValue = PlayerStats["Max" .. statName]
	if maxValue then
		newValue = math.clamp(newValue, 0, maxValue)
	end
	if newValue == current then return newValue end
	PlayerStats[statName] = newValue
	changedEvent:Fire(statName, newValue, current)
	return newValue
end

return PlayerStats