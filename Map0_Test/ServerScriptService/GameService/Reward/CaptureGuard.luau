-- Capture-specific anti-exploit validation, kept out of CameraShotHandler so
-- the handler stays a thin adapter. Distance and shot quality drive money,
-- so every check here runs before a reward is ever calculated.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraStats = require(ReplicatedStorage.Modules.Camera.CameraStats)
local CameraStability = require(ReplicatedStorage.Modules.Camera.CameraStability)

local MAX_ORIGIN_DEVIATION_STUDS = 10
local SUBJECT_COOLDOWN_SECONDS = 8

local CaptureGuard = {}

-- [player.UserId] = weak-keyed { [subject Instance]: os.clock() timestamp }.
-- Weak-keyed per-player table so a destroyed subject's entry can be
-- collected instead of leaking forever. Not built on Shared/Cooldown because
-- that module's key is a single flat value, not a (player, subject) pair --
-- Instance:GetDebugId() looked like a fit but requires plugin capability and
-- can't be called from a normal runtime Script.
--
-- LIVE: both shipped CaptureTargets entries (Monster, Objective) set
-- RepeatPolicy = "Cooldown" as of Phase 8.5, so this table is populated on
-- every real capture. (An earlier version of this comment said the opposite
-- -- "Unlimited", "currently unreachable" -- that was true before 8.5 and is
-- corrected here; REWARD_SYSTEM.md carried the same stale claim.) Extending
-- Cooldown-gated protection to a future target type is still a one-line
-- config flip, not a re-implementation -- that part remains true.
local lastCaptureTime = {}

Players.PlayerRemoving:Connect(function(player)
	lastCaptureTime[player.UserId] = nil
end)

local function isFiniteVector(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z -- NaN ~= itself
		and v.Magnitude < math.huge
end

-- Rejects shots whose client-reported origin is implausibly far from the
-- player's own head -- the cheap version of "don't trust the client's camera
-- position" (CameraSession.Capture sends camera.CFrame.Position unchecked).
-- Does not fully re-derive origin server-side; see REWARD_SYSTEM.md for why
-- that's deferred.
local function validateOrigin(player: Player, origin: Vector3): boolean
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return false
	end

	return (origin - head.Position).Magnitude <= MAX_ORIGIN_DEVIATION_STUDS
end

-- Combined entry point for the parts of validation known before the raycast
-- runs: vector sanity and origin plausibility.
function CaptureGuard.ValidateShot(player: Player, origin: Vector3, direction: Vector3): boolean
	if not isFiniteVector(origin) or not isFiniteVector(direction) then
		return false
	end
	-- direction.Unit is (nan, nan, nan) for a zero vector, which isFiniteVector
	-- already passed (0 < math.huge) -- that NaN then flows into PhotoCapture's
	-- raycast basis, producing 25 NaN raycasts per shot for free.
	if direction.Magnitude == 0 then
		return false
	end
	return validateOrigin(player, origin)
end

-- Re-derives shot quality server-side from the character's REPLICATED
-- movement state instead of trusting which remote (Weak/Strong) the client
-- fired. An honest client claiming Strong while moving is downgraded to Weak,
-- never upgraded. Accepted risk, not a hard guarantee: MoveDirection/
-- AssemblyLinearVelocity/HumanoidState are all properties the client's own
-- character owns and replicates, so a modified client can report stillness
-- while actually moving and keep Strong. See CameraShotHandler's call site
-- for the full posture and REWARD_SYSTEM.md for the equivalent, already-
-- documented origin-trust risk this shares its shape with.
function CaptureGuard.ResolveShotQuality(player: Player, requestedQuality: string, cameraId: string): string
	if requestedQuality ~= "Strong" then
		return requestedQuality
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return "Weak"
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	local thresholds = CameraStats.GetStabilitySettings(cameraId)
	if CameraStability.IsMoving(humanoid, rootPart, thresholds) then
		return "Weak"
	end

	return "Strong"
end

-- Blocks repeated rewards for the same (player, subject) inside the farm
-- window. Independent of the per-shot rate-limit Cooldown already in
-- CameraShotHandler, which only throttles fire rate, not repetition. Only
-- reached via CheckRepeatPolicy when a type opts into "Cooldown".
local function checkCooldown(player: Player, subject: Instance): boolean
	local now = os.clock()
	local perPlayer = lastCaptureTime[player.UserId]
	if not perPlayer then
		perPlayer = setmetatable({}, { __mode = "k" })
		lastCaptureTime[player.UserId] = perPlayer
	end

	local last = perPlayer[subject]
	if last and now - last < SUBJECT_COOLDOWN_SECONDS then
		return false
	end

	perPlayer[subject] = now
	return true
end

-- Gate for repeated rewards on the same (player, subject), driven by the
-- target type's RepeatPolicy (see CaptureTargets.Types). "Unlimited" always
-- passes; "Cooldown" is the original always-on 8s window, now opt-in per
-- type instead of global. An unrecognized/future policy (e.g. "Diminishing",
-- "Once") fails safe by falling back to Cooldown rather than defaulting open.
function CaptureGuard.CheckRepeatPolicy(player: Player, subject: Instance, typeDef): boolean
	local policy = typeDef and typeDef.RepeatPolicy or "Cooldown"

	if policy == "Unlimited" then
		return true
	elseif policy == "Cooldown" then
		return checkCooldown(player, subject)
	end

	warn(("CaptureGuard: unimplemented RepeatPolicy '%s' -- falling back to Cooldown"):format(tostring(policy)))
	return checkCooldown(player, subject)
end

return CaptureGuard
