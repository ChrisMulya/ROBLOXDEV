-- PlayerStats ModuleScript
-- Place in: ReplicatedStorage.Modules (so both server and client can require it)
--
-- Shared, read-mostly tuning constants only -- movement/camera numbers and
-- stat caps. Per-player mutable runtime values (Stamina) live in
-- PlayerRuntimeStats instead: PlayerStats is required on both server and
-- client, so a Set/Add here was one value shared by every player on the
-- server, and nothing stopped an accidental PlayerStats.Set("WalkSpeed", 0).
-- Get/Set/Add are kept for the constants that do get tuned at runtime (there
-- are none currently, but see StartGame.luau's use of StartingCash as a
-- pure read) -- Set/Add still work for any of the fields below.

local PlayerStats = {}

-- Fires (statName: string, newValue: number, oldValue: number) any time Set/Add
-- actually changes a value.
local changedEvent = Instance.new("BindableEvent")
PlayerStats.Changed = changedEvent.Event

-- ===== Movement =====
-- 10, not Roblox's default 16. Walking is deliberately slower than every
-- monster's WalkSpeed (Monster1 is 18), so walking away from something that
-- has seen you is not an option -- sprinting is. That makes stamina the real
-- escape resource rather than a convenience, and it is what makes the
-- footstep stimulus a meaningful trade: see Stimulus/FootstepEmitter, which
-- only emits above 20 studs/sec, so a walking player is silent.
PlayerStats.WalkSpeed   = 10
PlayerStats.SprintSpeed = 25      -- studs/sec, top speed while sprinting
PlayerStats.JumpHeight = 4        -- studs; Roblox's default is 7.2
PlayerStats.JumpCooldown = 0.3    -- seconds on the ground before the next jump
PlayerStats.AccelRate   = 18      -- higher = snappier ramp-up to top speed while input is held
PlayerStats.DecelRate   = 5       -- lower = longer slide-to-stop after input is released
PlayerStats.MaxAxisForce = 100000 -- LinearVelocity force cap on X/Z
PlayerStats.BaseFOV      = 70     -- degrees, normal camera field of view
PlayerStats.SprintFOV    = 80     -- degrees, camera field of view while sprinting
PlayerStats.FOVChangeRate = 8     -- higher = faster FOV transition in/out of sprint
PlayerStats.MaxCameraTilt = 2     -- degrees, camera roll at full left/right strafe
PlayerStats.CameraTiltRate = 3    -- higher = snappier tilt response to strafing

-- ===== Stamina =====
-- Stamina itself (the mutable, per-player, per-frame value) lives in
-- PlayerRuntimeStats now -- MaxStamina/DrainRate/RegenRate/MinToSprint are
-- tuning constants, not runtime state, so they stay here.
PlayerStats.MaxStamina        = 100
PlayerStats.StaminaDrainRate  = 15   -- per second while sprinting
PlayerStats.StaminaRegenRate  = 10   -- per second while not sprinting
PlayerStats.MinStaminaToSprint = 15   -- can't start sprinting below this
-- Holding Shift while standing still neither drains nor regens, or you could
-- park on the key and never recover. After this many seconds of no movement,
-- regen starts anyway -- holding Shift shouldn't punish a player who stopped.
PlayerStats.StaminaIdleRegenDelay = 3

-- ===== Flashlight =====
-- BASE values -- the level-1 flashlight every player starts with. Read by
-- Player/FlashlightService when it builds the beam.
--
-- Tuned against the match's own 6-7 PM lighting: at the original Angle 50 /
-- Brightness 3 the beam was a wide, dim, warm pool indistinguishable from the
-- sunset ambient -- it read as "the flashlight is broken" even though it was
-- lit. A narrow cone in a near-white tint is what makes it read as a
-- flashlight rather than as ambience.
--
-- A "Better Flashlight" upgrade must NOT be PlayerStats.Set on these. This
-- table is required on both server and client, so a Set is one value shared by
-- every player on the server -- upgrading one player would upgrade the whole
-- lobby. See the header, and the Stamina/PlayerRuntimeStats split for the
-- same lesson learned the hard way. A per-player upgrade needs per-player
-- storage (a Player attribute, or the reward profile) with these as the
-- fallback when the player has no upgrade.
-- Range is capped by the engine at 120 -- Roblox silently clamps
-- SpotLight.Range to that, so an upgrade tier above 120 buys nothing. Angle is
-- likewise clamped to 180. Verified by setting 151 and reading back 120.
PlayerStats.FlashlightRange      = 80  -- studs the beam reaches (engine max 120)
PlayerStats.FlashlightBrightness = 4   -- SpotLight Brightness (no engine cap)
PlayerStats.FlashlightAngle      = 32  -- degrees, full cone width (engine max 180)

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

-- Adds delta to a stat, auto-clamping to [0, MaxX] if a "MaxX" counterpart exists.
-- (Stamina itself is no longer one of these -- see PlayerRuntimeStats.Add.)
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