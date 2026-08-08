-- Publishes a Footstep stimulus as a player moves fast. Entirely
-- server-derived: there is no footstep remote, no position remote, and no
-- client claim of any kind feeding this.
--
-- Security model, in one line: THE CLIENT HAS NO INPUT HERE. Both halves of
-- the emit condition are server-owned -- speed is measured from the server's
-- own copy of the character, and the sprint flag is the one
-- CharacterMovementService GRANTED after its stamina gate, not the one the
-- client requested. Position comes from the server's character too. There is
-- nothing to rate-limit, spoof-check or validate because there is nothing
-- incoming to distrust.
--
-- (This replaced an earlier Silent Walk design where the client toggled a
-- "I am being quiet" claim and this module had to re-check it against measured
-- speed. Deriving quietness from speed alone removes both the remote and the
-- claim -- strictly less trust surface for the same outcome.)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerStats = require(ReplicatedStorage.Modules.PlayerStats)
local StimulusKinds = require(ReplicatedStorage.Modules.Stimulus.StimulusKinds)
local StimulusBus = require(ServerScriptService.GameService.Stimulus.StimulusBus)
local CharacterMovementService = require(ServerScriptService.GameService.Player.CharacterMovementService)

local FootstepEmitter = {}

-- Distance between emitted footsteps, not a fixed time interval -- cadence
-- rises with speed for free, and a player below the noise threshold never
-- accumulates one at all (the accumulator resets rather than carrying).
local STRIDE_LENGTH = 4

-- Move faster than this and you are audible. Sits between WalkSpeed (10) and
-- SprintSpeed (25) with wide margin on both sides: walking is silent no matter
-- how the accel lerp overshoots, and sprinting is audible no matter how a
-- slope or a corner drags it down. Anything in between -- knockback, a
-- conveyor, a future movement gadget -- is audible on its actual speed
-- without needing to know this rule exists.
local NOISE_SPEED = 20

type Entry = {
	rootPart: BasePart,
	humanoid: Humanoid,
	accumulator: number,
}

local entries: { [Player]: Entry } = {}

-- 0.6 at the noise threshold, 1.0 at sprint speed. Only fast movement gets
-- here at all, so the floor is high -- a footstep that qualifies is always
-- worth investigating, and the remaining range just distinguishes "moving
-- quickly" from "flat out".
local function strengthFor(speed: number): number
	local span = math.max(PlayerStats.SprintSpeed - NOISE_SPEED, 1)
	local t = math.clamp((speed - NOISE_SPEED) / span, 0, 1)
	return 0.6 + 0.4 * t
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", 10)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
		or character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not rootPart or not rootPart:IsA("BasePart") then
		return
	end
	if player.Character ~= character then
		return
	end

	entries[player] = {
		rootPart    = rootPart,
		humanoid    = humanoid,
		accumulator = 0,
	}
end

local function step(dt: number)
	for player, entry in pairs(entries) do
		local rootPart = entry.rootPart
		if rootPart.Parent == nil or entry.humanoid.Health <= 0 then
			continue
		end

		-- The server's own physics property, not anything the client reports.
		-- Flattened: vertical velocity (falling, a jump's arc) must not count
		-- as ground speed or a fall would sound like a sprint.
		local velocity = rootPart.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

		-- Audible if EITHER holds. Speed is the general rule; the sprint flag
		-- is the special case that covers a sprint whose measured speed is
		-- momentarily under the threshold -- ramping up out of a standstill,
		-- rounding a corner, fighting a slope. Without it, a sprinting player
		-- would flicker in and out of being heard, which reads as the monster
		-- randomly losing track of someone running right past it.
		if speed <= NOISE_SPEED and not CharacterMovementService.IsSprinting(player) then
			entry.accumulator = 0
			continue
		end

		entry.accumulator += speed * dt
		if entry.accumulator < STRIDE_LENGTH then
			continue
		end
		-- Subtract rather than zero: keeps cadence smooth across frames instead
		-- of losing the remainder of a stride every time one completes.
		entry.accumulator -= STRIDE_LENGTH

		StimulusBus.Publish({
			Kind      = StimulusKinds.Footstep,
			Position  = rootPart.Position,
			Timestamp = os.clock(),
			Strength  = strengthFor(speed),
			Source    = player,
		})
	end
end

local function setupPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

local started = false

function FootstepEmitter.Start()
	if started then
		return
	end
	started = true

	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player)
		entries[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayer(player)
	end

	RunService.Heartbeat:Connect(step)
end

return FootstepEmitter
